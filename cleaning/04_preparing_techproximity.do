////////////////////////////////////////////////////////////////////////////////
// Project:        	Moving innovation
// Creation Date:  	11/07/2024
// Last Update:    	11/07/2024
// Authors:         Laura Arnemann
//					Theresa Bührle
// Goal: 			Technological proximity 
///////////////////////////////////////////////////////////////////////////////

global dataset 4
	



*Data source: Patensview, https://patentsview.org/download/data-download-tables

*A. CITATIONS
*-------------------------------------------------------------------------------
*Files: g_us_patent_citation

import delimited "${IN}/main_data/data_new/Patentsview/Citation/g_us_patent_citation.tsv", clear
drop citation_category // cited by examiner/applicant/other/third party/imported from related application

split citation_date, parse("-")
rename citation_date1 year
rename citation_date2 month
rename citation_date3 day

destring year, replace
destring month, replace
destring day, replace

gen cite_date = mdy(month, day, year)
format cite_date %d 

drop citation_date year month day

compress
save "${IN}/main_data/data_new/Patentsview/Citation/g_us_patent_citation.dta", replace


*B. TECHNOLOGICAL CLASS
*-------------------------------------------------------------------------------
*Files: g_ipc_at_issue

*A1 - Prepare data	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x

/* We need:
- Unique ID: patent_id x assignee_id (or gvkey)
- Variables: assignee_id ind_class patent_id
*/


*Prepare technological class data	-	-	-	-	-	-	-	-	-	-	-	
import delimited "${IN}/main_data/data_new/Patentsview/Classification/g_ipc_at_issue.tsv", clear

egen ipc_group = group(section ipc_class subclass main_group subgroup)
duplicates drop patent_id ipc_group, force

drop if missing(patent_id)
destring patent_id, replace force 

rename patent_id patnum
drop if patnum == .	// 239,069 obs

egen ipc_group_1 = group(section ipc_class subclass main_group)
egen ipc_group_2 = group(section ipc_class subclass)
egen ipc_group_3 = group(section ipc_class)

distinct ipc_group		// 223,523 distinct 
distinct ipc_group_1	// 40,502 distinct 
distinct ipc_group_2	// 4,914 distinct 	
distinct ipc_group_3	// 940 distinct - let's got for this level !

keep patnum section ipc_class ipc_group_3
rename ipc_group_3 ipc_group
duplicates drop

save "${IN}/main_data/data_new/Patentsview/Classification/g_ipc_at_issue.dta", replace

*Create patent dataset 	-	-	-	-	-	-	-	-	-	-	-	-	-	-

* Prepare sub-files with assignee_ids by group
// Problem: Limit on the number of rows to 65,534 in MP version; matrix doesn't work with too many observations 
/*
Just drop like this for now to test code; but we do need the full set of pairwaise correlations.
Solution: By state
*/

* Read in the patents data from Patentsview

use "${TEMP}/patents_helper_4.dta", clear 

rename county_fips_inventor county_fips
rename state_fips_inventor fips_state
* Broomfield county (8014) was formed out of Boulder County in 2001
replace county_fips = 8013 if county_fips == 8014 

* Merging in the Commuting Zone level data 
merge m:1 county_fips using "$IN/var_CommutingZones/CZ_combined.dta"
drop if _merge!=3  
drop _merge	

rename CZ_depagri_1990 czone 
keep assignee_id patnum czone 

drop if missing(patnum)
bysort patnum czone: gen count = _n 
bysort patnum: egen max_count =max(count) 
keep if count == max_count 
drop count max_count 
bysort patnum: gen count =_n 

reshape wide czone, i(patnum) j(count)
merge 1:m patnum using "${IN}/main_data/data_new/Patentsview/Classification/g_ipc_at_issue.dta"	

keep if _merge == 3

keep patnum assignee_id czone* ipc_group
duplicates drop

egen assignee_id_num = group(assignee_id)

preserve

keep assignee_id assignee_id_num
duplicates drop
save "${TEMP}/new_dataset3_techspill_assignee_ids.dta", replace

restore
drop assignee_id
rename assignee_id_num assignee_id

egen pat_ipc = group(patnum ipc_group)
reshape long czone, i(pat_ipc) j(count)
drop if missing(czone) 

drop pat_ipc count 
compress
save "${TEMP}/new_dataset3_techspill.dta", replace


* Preparing the Commuting Zone data 
global dataset 4 

use "${TEMP}/final_cz_${dataset}.dta", clear 
merge m:1 assignee_id using "${TEMP}/new_dataset3_techspill_assignee_ids.dta", nogen keep(3) 
drop assignee_id 
rename assignee_id_num assignee_id

*Important to generate the sum of inventors on commuting zone level

bysort czone year: egen sum_inventors = sum(n_inventors3)
replace sum_inventors = sum_inventors - n_inventors3

keep if asg_corp ==1 
drop if missing(change_other_threelargest)
keep assignee_id czone year change_other_threelargest n_inventors3 sum_inventors
rename assignee_id assignee_id_pat 
save "${TEMP}/cz_preaggregate.dta", replace

 

/*
forvalues state = 1(1)56 {	// 1-56
	
	if `state' == 3 | `state' == 7 | `state' == 14 | `state' == 43 | `state' == 52 {
		display `state'	
	}
		
	else { 

	use fips_state assignee_id using "${TEMP}/final_cz_${dataset}.dta", clear
	keep if fips_state == `state'
	
	keep assignee_id
	cap duplicates drop	// capture bc of missing state_fips for 3 etc.
	
	merge m:1 assignee_id using "${TEMP}/new_dataset3_techspill_assignee_ids.dta", nogen keep(3)
	keep assignee_id_num
	rename assignee_id_num assignee_id
	
	save "${TEMP}/final_cz_${dataset}_preaggregate_`state'.dta", replace
	
}
}
*/






*A2 - Crete technological spillover measure	x	x	x	x	x	x	x	x	x
// Code based on "Have R&D spillovers changed over time?" (Lucking, Bloom, Van Reenen; 2017)

// OPEN QUESTIONS:
// Do we want to limit it to assignee_id x location pairs or to assignee_id in general as BVS?


*USING THE PATENTS TO CREATE A SHARE OF EACH SUBCATEGORY WITHIN EACH FIRM

* Insufficient memory for California: fips state code 6  
forvalues state = 25(1)56 {	// 1-56
	
	if `state' == 3 | `state' == 7 | `state' == 14 | `state' == 43 | `state' == 52 {
		display `state'	
	}
		
	else { 
	 
	   use "${TEMP}/new_dataset3_techspill.dta",clear
		
		drop section ipc_class
		
		*Restrict filesize, run code by state
		merge m:1 assignee_id using "${TEMP}/final_cz_${dataset}_preaggregate_2.dta", nogen keep(3)
		
		save "${TEMP}/helper_2.dta", replace 
		
		// ADDITION: Limit on the number of rows to 65,534 in MP version; matrix doesn't work with too many observations
		// Just drop like this for now to test code; but we do need the full set of pairwaise correlations.
		gen counter = _n
		keep if counter < 10000
		drop counter
		*/
		sort ipc_group
		gen tclass=1
		replace tclass=tclass[_n-1]+1*(ipc_group!=ipc_group[_n-1]) if ipc_group[_n-1]!= .
		egen TECH=max(tclass)
		global define tech=TECH
		egen total=count(patnum),by(assignee_id)
		egen total_tech=count(patnum),by(assignee_id tclass)
		fillin assignee_id tclass
		drop _f
		so assignee_id tclass
		drop if assignee_id==assignee_id[_n-1]&tclass==tclass[_n-1]
		gen double subsh=100*(total_tech/total)
		keep assignee_id tclass subsh
		qui su tclass
		global tech=r(max)
		display $tech
		replace subsh=0 if subsh==.
			// NEED TO RUN UNTIL HERE TO OBTAIN VALUE FOR tech IF CODE IS RUN BIT BY BIT
		reshape wide subsh, i(assignee_id) j(tclass)
		compress

		save "${TECHDATA}/new_dataset3_techspill_norounding_`state'",replace

		*CREATING A N BY NY LIST WITH SHARES IN EACH SECTOR ACROSS (N*N DOWN AND J ACROSS)

		use "${TECHDATA}/new_dataset3_techspill_norounding_`state'",clear

		cap drop ipc_group subcat tclass TECH total
		so assignee_id
		gen num=1
		replace num=num[_n-1]+1*(assignee_id!=assignee_id[_n-1]) if assignee_id[_n-1]!=.
		so num
		preserve
		egen tag=tag(num)
		keep num assignee_id
		save "${TECHDATA}/num_assignee_id_`state'", replace
		rename num num_
		rename assignee_id assignee_id_
		save "${TECHDATA}/num_assignee_id__`state'", replace
		restore

		egen NUM=max(num)
		qui su num
		global num=r(max)

		*Generates a matrix of all the shares in dimensions (num, tech) 
		mkmat subsh*,mat(subsh)
		matrix normsubsh=subsh

		*Var is a (tech,tech) matrix of the correlations between tech classes. Used for Mahalanobis distance measures
		matrix var=subsh'*subsh
		matrix basevar=var
		forv i=1(1)$tech {
			forv j=1(1)$tech {
				matrix var[`i',`j']=var[`i',`j']/(basevar[`i',`i']^(1/2)*basevar[`j',`j']^(1/2))
			}
		}

		*Standard is a (num,num) matrix of the correlations between firms over tech classes
		matrix basestandard=subsh*subsh'
		forv j=1(1)$tech {
			forv i=1(1)$num {
				matrix normsubsh[`i',`j']=subsh[`i',`j']/(basestandard[`i',`i']^(1/2))
			}
		}

		matrix standard=normsubsh*normsubsh'
		matrix covstandard=subsh*subsh'
		save "${TECHDATA}/temp_`state'",replace


		* BL: TOO LONG, NEED TO SPLIT UP MATRICES
		global X=ceil($num/500)*500 - 500

		forv mal=0(1)1{
			use "${TECHDATA}/temp_`state'",clear

			*Generate the Malhabois measure
			if `mal'==1 {
				matrix mal_corr=normsubsh*var*normsubsh'
				matrix standard=mal_corr
				matrix covmal_corr=subsh*var*subsh'
				matrix covstandard=covmal_corr
			}
			*Convert back into scalar data
			keep assignee_id
			sort assignee_id
			local J=$X+1
			forv j=1(500)`J' {
				preserve
				local j2=`j'+499
				if `j'==`J' {
					local j2 .
			}
			
			matrix covstandardj`j'=covstandard[1...,`j'..`j2']
			matrix standardj`j'=standard[1...,`j'..`j2']
			svmat standardj`j',n(standard)
			svmat covstandardj`j',n(covstandard)
			compress
			reshape long standard covstandard,i(assignee_id) j(num_)
			cap drop subsh*
			ren *standard *tec
			replace num_ = `j'+num_-1
			so assignee_id num_
			*convert to integers to reduce memory size - renormalize later
			foreach var in tec covtec {
				cap replace `var'=100*round(`var',0.01)
			}
			compress
			
			if `mal'==1 {
				rename *tec mal*tec
				save "${TECHDATA}/output_short70_malj`j'_`state'",replace
			}
			else {
				save "${TECHDATA}/output_short70j`j'_`state'",replace
			}
			restore
			}
		}

		foreach f in output_short70 output_short70_mal {
			clear
			forv j=1(500)`J' {
				append using "${TECHDATA}/`f'j`j'_`state'"
			}
			sort assignee_id num_
			merge m:1 num_ using "${TECHDATA}/num_assignee_id__`state'"
			assert _m==3
			drop _m
			
			cap lab var tec "JAFFE Closeness in Technology Space (TECH)"
			cap lab var covtec "Covariance Closeness in Technology Space (TECH)"
			cap lab var maltec "Mahalanobis Closeness in Technology Space (TECH)"
			cap lab var malcovtec "Covariance Mahalonobis Closeness in Technology Space (TECH)"	
			
			save "${TECHDATA}/`f'_`state'", replace
			* clean up
			forv j=1(500)`J' {
				erase "${TECHDATA}/`f'j`j'_`state'.dta"
			}
		}
	}
}

/*
*A3 - Combine files	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x

foreach filename in "output_short70" "output_short70_mal" {
	use "${TECHDATA}/`filename'_1", clear
	forvalues state = 2(1)56 {
	
	if `state' == 3 | `state' == 6 | `state' == 7 | `state' == 14 | `state' == 43 | `state' == 52 {
		display `state'	
	}
		
	else { 
		cap append using "${TECHDATA}/`filename'_`state'"
	}
	}
	
	drop num_
	duplicates drop assignee_id assignee_id_, force
		// there are duplicates in the mal variable with different values for 7% of obs (59 distinct firms)
		// probably due to different correlations in tech classes in different states
		// Should we frame this as state-specific measure?
	 
	save "${TECHDATA}/`filename'", replace
}

use "${TECHDATA}/output_short70", clear
merge 1:1 assignee_id assignee_id_ using "${TECHDATA}/output_short70_mal"		
keep if _merge==3
drop _merge
sort assignee_id assignee_id_ 

drop if missing(assignee_id) | missing(assignee_id_)

compress
save "${TEMP}/spill_tmp", replace

cap erase "${TECHDATA}/output_short70.dta"
cap erase "${TECHDATA}/output_short70_mal.dta"

/*
xxxx CODE CHECKED UNTIL HERE


*A4 - Create spillover variable	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x

gen tecIV=tec
gen tecIV_mal=maltec

	// xrd: Compustat variable; R&D expenses
	//hxrd: derived from ivspillover.do

foreach var in "tec covtec maltec malcovtec" {
egen spill`var'=sum(`var'*(1/100)*xrd*(assignee_id!=assignee_id_)), by(assignee_id)
drop `var'
}
foreach var in tecIV tecIV_mal {
egen spill`var'=sum(`var'*(1/100)*hxrd*(assignee_id!=assignee_id_)), by(assignee_id)	
drop `var'
}
keep if assignee_id==assignee_id_
drop assignee_id_
sort assignee_id year
compress
save "${TEMP}/spill_output`y'",replace
}
use "${TEMP}/spill_output`tmin'", clear
local tmin1=`tmin'+1
forv y=`tmin1'(1)`tmax' {
	append using "${TEMP}/spill_output`y'"
}
save "${TEMP}/spill_output", replace




***************GENERATING SPILLSIC, SPILLTEC and SPILLLOC STOCK

*CPI: https://www.usinflationcalculator.com/inflation/consumer-price-index-and-annual-percent-changes-from-1913-to-2008/
merge m:1 year using "${IN}/var_other/cpi_us.dta" 

lab var cpi_norm "CPI price index used to deflate all variables" 	

foreach var in "tec covtec maltec malcovtec tecIV  tecIV_mal" {
	gen rspill`var'=spill`var'*pindex
	gen gspill`var'=spill`var'/0.1
	qui by num:replace gspill`var'=gspill`var'[_n-1]*0.85 + rspill`var' if gspill`var'[_n-1]~=.
	gen lgspill`var'=log(gspill`var')
	sort num year
	qui by num: gen lgspill`var'1=lgspill`var'[_n-1]
}





/*

OLD STUFF

import delimited "${IN}/main_data/data_new/Patentsview/Classification/g_cpc_at_issue.tsv", clear

drop cpc_action_date cpc_type cpc_version_indicator
drop if cpc_group == ""

sort patent_id cpc_sequence
duplicates drop patent_id cpc_group, force

drop if missing(patent_id)
destring patent_id, replace force 

rename patent_id patnum
drop if patnum == .

distinct cpc_section	// 9 distinct sections
distinct cpc_class	// 198 distinct classes
distinct cpc_subclass	// 921 distinct subclasses	- let's got for this level !

keep patnum cpc_section cpc_class cpc_subclass 
duplicates drop

save "${IN}/main_data/data_new/Patentsview/Classification/g_cpc_at_issue.dta", replace

use "${TEMP}/new_dataset3.dta", clear

duplicates drop patnum assignee_id gvkey, force
keep patnum assignee_id gvkey app_year 	
drop if patnum == .
duplicates report patnum // unique identifier

merge 1:m patnum using "${IN}/main_data/data_new/Patentsview/Classification/g_cpc_at_issue.dta"	// only half are matched!
/*
    Result                      Number of obs
    -----------------------------------------
    Not matched                     6,509,366
        from master                 2,128,632  (_merge==1)
        from using                  4,380,734  (_merge==2)

    Matched                         2,056,266  (_merge==3)
    -----------------------------------------
	
	Seems to be driven by a year problem: Claassification onyl picks up from 2000s
	
*/

/*
use "${TEMP}/application.dta", clear
rename patent_id patnum
destring patnum, force replace	// 829,755 obs with nonnumeric characters
drop if patnum == .

keep application_id patnum filing_date 
merge 1:m patnum using "${IN}/main_data/data_new/Patentsview/Classification/g_cpc_at_issue.dta"

	Result                      Number of obs
    -----------------------------------------
    Not matched                     4,859,353
        from master                 4,859,353  (_merge==1)
        from using                          0  (_merge==2)

    Matched                         6,437,000  (_merge==3)
    -----------------------------------------
	
	
With string patnums:

    Result                      Number of obs
    -----------------------------------------
    Not matched                     5,679,188
        from master                 5,679,181  (_merge==1)
        from using                          7  (_merge==2)

    Matched                         6,450,794  (_merge==3)
    -----------------------------------------
	
	
use "${TEMP}/assignee.dta", clear	
rename patent_id patnum
destring patnum, force replace	// 615,076 obs with nonnumeric characters
drop if patnum == .

keep patnum assignee_id
merge m:m patnum using "${IN}/main_data/data_new/Patentsview/Classification/g_cpc_at_issue.dta"	
		
    Result                      Number of obs
    -----------------------------------------
    Not matched                     4,747,745
        from master                 4,144,300  (_merge==1)
        from using                    603,445  (_merge==2)

    Matched                         5,833,555  (_merge==3)
    -----------------------------------------

	
import delimited "${IN}/main_data/data_new/Patentsview/g_inventor_disambiguated.tsv", clear
rename patent_id patnum
destring patnum, force replace	// 1,537,968 obs with nonnumeric characters
drop if patnum == .

keep patnum inventor_id
merge m:m patnum using "${IN}/main_data/data_new/Patentsview/Classification/g_cpc_at_issue.dta"	
	
	Result                      Number of obs
    -----------------------------------------
    Not matched                    11,348,213
        from master                11,348,213  (_merge==1)
        from using                          0  (_merge==2)

    Matched                        10,532,933  (_merge==3)
    -----------------------------------------	
*/



/*
import delimited "${IN}/main_data/data_new/Patentsview/Classification/g_cpc_current.tsv", clear

drop if cpc_group == ""
sort patent_id cpc_sequence
duplicates drop patent_id cpc_group, force

drop if missing(patent_id)
destring patent_id, replace force 

rename patent_id patnum
drop if patnum == .

keep patnum cpc_section cpc_class cpc_subclass 
duplicates drop

save "${IN}/main_data/data_new/Patentsview/Classification/g_cpc_current.dta", replace

use "${TEMP}/new_dataset3.dta", clear

duplicates drop patnum assignee_id gvkey, force
keep patnum assignee_id gvkey app_year 	
drop if patnum == .
duplicates report patnum // unique identifier

merge 1:m patnum using "${IN}/main_data/data_new/Patentsview/Classification/g_cpc_at_issue.dta"	


    Result                      Number of obs
    -----------------------------------------
    Not matched                     6,509,366
        from master                 2,128,632  (_merge==1)
        from using                  4,380,734  (_merge==2)

    Matched                         2,056,266  (_merge==3)
    -----------------------------------------
*/
*/

