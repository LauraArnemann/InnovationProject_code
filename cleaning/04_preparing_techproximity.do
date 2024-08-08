////////////////////////////////////////////////////////////////////////////////
// Project:        	Moving innovation
// Creation Date:  	11/07/2024
// Last Update:    	11/07/2024
// Authors:         Laura Arnemann
//					Theresa Bührle
// Goal: 			Technological proximity 
///////////////////////////////////////////////////////////////////////////////




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
use "${TEMP}/new_dataset3.dta", clear

duplicates drop patnum assignee_id gvkey, force
keep patnum assignee_id gvkey app_year 	
drop if patnum == .
duplicates report patnum // unique identifier

merge 1:m patnum using "${IN}/main_data/data_new/Patentsview/Classification/g_ipc_at_issue.dta"	

/*
    Result                      Number of obs
    -----------------------------------------
    Not matched                     6,730,652
        from master                       140  (_merge==1)
        from using                  6,730,512  (_merge==2)

    Matched                         4,142,816  (_merge==3)
    -----------------------------------------
*/

keep if _merge == 3

keep patnum assignee_id section ipc_class ipc_group
duplicates drop

egen assignee_id_num = group(assignee_id)

preserve

keep assignee_id assignee_id_num
duplicates drop
	
save "${TEMP}/new_dataset3_techspill_assignee_ids.dta", replace

restore
drop assignee_id
rename assignee_id_num assignee_id

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

foreach cz of local all_cz {
	use "${TEMP}/final_cz_4.dta", clear
	keep if czone == `cz' 
	keep assignee_id czone	
	duplicates drop	

	merge m:1 assignee_id using "${TEMP}/new_dataset3_techspill_assignee_ids.dta", nogen keep(3)
	keep assignee_id_num czone
	rename assignee_id_num assignee_id
	
	save "${TEMP}/final_cz_4_preaggregate_`cz'.dta", replace
}

*A2 - Crete technological spillover measure	x	x	x	x	x	x	x	x	x

*xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
*PYTHON	...
*xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx


*Combine Python-generated files
use "${TEMP}/final_cz_4_corp_new.dta", clear

levelsof czone, local(all_cz) 
local tmin=1988
local tmax=2018

display `all_cz'

use "${TEMP}/tech_index/tech_index100_1988.0year.dta", clear

foreach cz of local all_cz {
	forv y=`tmin'(1)`tmax' {
		cap append using "${TEMP}/tech_index/tech_index`cz'_`y'.0year.dta"
	}
	display `cz'
}


drop index 

duplicates drop
duplicates report assignee_id czone year // should be unique id

*Merge back string ids
rename assignee_id assignee_id_num
merge m:1 assignee_id_num using "${TEMP}/new_dataset3_techspill_assignee_ids.dta", nogen keep(3)

save "${TEMP}/spill_output", replace
	
use "${TEMP}/final_cz_4_corp_new.dta", clear
	merge m:1 assignee_id czone year using "${TEMP}/spill_output"
	drop if _merge == 2
	drop _merge
	
	label var weightedtec_change1 "Tech weighting excl inv"
	label var weightedtec_change2 "Tech weighting incl inv"
	
	replace weightedtec_change1 = 0 if missing(weightedtec_change1) 
	replace weightedtec_change2 = 0 if missing(weightedtec_change2)

save "${TEMP}/final_cz_4_tech.dta", replace


/*


***************GENERATING PILLTEC
use "${TEMP}/spill_output", clear
*CPI: https://www.usinflationcalculator.com/inflation/consumer-price-index-and-annual-percent-changes-from-1913-to-2008/
merge m:1 year using "${IN}/var_other/cpi_us.dta" 

sort assignee_id year 

lab var cpi_norm "CPI price index used to deflate all variables" 	

foreach var in "tec covtec maltec malcovtec" {	//  tecIV  tecIV_mal
	gen rspill`var'=spill`var'*pindex
	gen gspill`var'=spill`var'/0.1
	qui by assignee_id:replace gspill`var'=gspill`var'[_n-1]*0.85 + rspill`var' if gspill`var'[_n-1]~=.
	gen lgspill`var'=log(gspill`var')
	sort assignee_id year
	qui by assignee_id: gen lgspill`var'1=lgspill`var'[_n-1]
}




/*
*WE DO THE FOLLOWING PART IN PYTHON NOW


***************************************************************************
*	PART 1: CALCULATING TECHNOLOGICAL MEASURES (INDEPENDENT OF DISTANCE)
***************************************************************************

// Code based on "Have R&D spillovers changed over time?" (Lucking, Bloom, Van Reenen; 2017)
// ADDITION: Loop over CZ due to limit on the number of rows to 65,534 in MP version; matrix doesn't work with too many observations

// OPEN QUESTIONS:
// Do we want to limit it to assignee_id x location pairs or to assignee_id in general as BVS?

use "${TEMP}/final_cz_4_preaggregate.dta", clear
levelsof czone, local(all_cz) 

*USING THE PATENTS TO CREATE A SHARE OF EACH SUBCATEGORY WITHIN EACH FIRM
foreach cz of local all_cz {	
	
	use "${TEMP}/new_dataset3_techspill.dta",clear
		
	drop section ipc_class 
		
	*Restrict filesize, run code by state
	merge m:1 assignee_id using "${TEMP}/final_cz_4_preaggregate_`cz'.dta", nogen keep(3)
	
	drop if missing(czone)
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
	reshape wide subsh, i(assignee_id) j(tclass)
	compress
	save "${TEMP}/new_dataset3_techspill_norounding_`cz'",replace
	
	*CREATING A N BY NY LIST WITH SHARES IN EACH SECTOR ACROSS (N*N DOWN AND J ACROSS)
	use "${TEMP}/new_dataset3_techspill_norounding_`cz'",clear
		cap drop ipc_group subcat tclass TECH total
	so assignee_id
	gen num=1
	replace num=num[_n-1]+1*(assignee_id!=assignee_id[_n-1]) if assignee_id[_n-1]!=.
	so num
	preserve
	egen tag=tag(num)
	keep num assignee_id
	save "${TEMP}/num_assignee_id_`cz'", replace
	rename num num_
	rename assignee_id assignee_id_
	save "${TEMP}/num_assignee_id__`cz'", replace
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
	save "${TEMP}/temp_`cz'",replace

	* BL: TOO LONG, NEED TO SPLIT UP MATRICES
	global X=ceil($num/500)*500 - 500
		forv mal=0(1)1{
		use "${TEMP}/temp_`cz'",clear
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
		
		gen czone = `cz'

		if `mal'==1 {
			rename *tec mal*tec
			save "${TEMP}/output_short70_malj`j'_`cz'",replace
		}
		else {
			save "${TEMP}/output_short70j`j'_`cz'",replace
		}
		restore
		}
	}

	foreach f in output_short70 output_short70_mal {
		clear
		forv j=1(500)`J' {
			append using "${TEMP}/`f'j`j'_`cz'"
		}
		sort assignee_id num_
		merge m:1 num_ using "${TEMP}/num_assignee_id__`cz'"
		assert _merge ==3
		drop _merge
		
		cap lab var tec "JAFFE Closeness in Technology Space (TECH)"
		cap lab var covtec "Covariance Closeness in Technology Space (TECH)"
		cap lab var maltec "Mahalanobis Closeness in Technology Space (TECH)"
		cap lab var malcovtec "Covariance Mahalonobis Closeness in Technology Space (TECH)"	
		
		save "${TEMP}/`f'_`cz'", replace
		* clean up
		forv j=1(500)`J' {
			erase "${TEMP}/`f'j`j'_`cz'.dta"
		}
	}
}


***************************************************************************
*	PART 2: CALCULATING GEOGRAPHIC MEASURES 
***************************************************************************

*tbd
*But: We need to run this on all locations; for now, let's stick to TEC within CZ

*A3 - Combine files	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x

foreach filename in "output_short70" "output_short70_mal" {
	use "${TEMP}/`filename'_1", clear
	foreach cz of local all_cz {
		cap append using "${TEMP}/`filename'_`cz'"
	}
	
	drop num_
	duplicates drop assignee_id assignee_id_, force
		// there are duplicates in the mal variable with different values for 7% of obs (59 distinct firms)
		// probably due to different correlations in tech classes in different states
		// Should we frame this as state-specific measure?
	 
	save "${TEMP}/`filename'", replace
}

use "${TEMP}/output_short70", clear
merge 1:1 assignee_id assignee_id_ using "${TEMP}/output_short70_mal"		
keep if _merge==3
drop _merge
sort assignee_id_ assignee_id  

drop if missing(assignee_id) | missing(assignee_id_)

sort assignee_id_

compress
save "${TEMP}/spill_tmp", replace

cap erase "${TEMP}/output_short70.dta"
cap erase "${TEMP}/output_short70_mal.dta"


*A4 - Create spillover variable	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x

/*
*Spillover weighted with R&D expenses (let's skip this for now, only for Compustat firms)


// xrd: Compustat variable; R&D expenses
foreach var in "tec covtec maltec malcovtec" {
egen spill`var'=sum(`var'*(1/100)*xrd*(assignee_id!=assignee_id_)), by(assignee_id)
drop `var'
}

//hxrd: derived from ivspillover.do
gen tecIV=tec
gen tecIV_mal=maltec
foreach var in tecIV tecIV_mal {
egen spill`var'=sum(`var'*(1/100)*hxrd*(assignee_id!=assignee_id_)), by(assignee_id)	
drop `var'
}
*/

*Create yearly files
use "${TEMP}/final_cz_4_preaggregate.dta", clear 
qui su year
local tmin=r(min)
local tmax=r(max)

forv y=`tmin'(1)`tmax' {
	use "${TEMP}/final_cz_4_preaggregate.dta" if year==`y', clear
	
	merge m:1 assignee_id using "${TEMP}/new_dataset3_techspill_assignee_ids.dta", nogen keep(3)
	keep assignee_id_num czone tag_local
	rename assignee_id_num assignee_id_
	
	drop if tag_local == 1	// kick local firms out
	
	drop tag_local
	duplicates drop
	
	save "${TEMP}/final_cz_4_preaggregate`y'.dta", replace
}

*Spillover variable
*- Sum over all other assignees
*[- Could think about weighting with average inventor count as replacement for R&D]

use "${TEMP}/final_cz_4_preaggregate.dta", clear
levelsof czone, local(all_cz) 

foreach cz of local all_cz {
	
	forv y=`tmin'(1)`tmax' {
		use "${TEMP}/technology`cz'.dta", clear
		rename assignee_id_pat assignee_id_
		drop index
		gen czone = `cz'
		merge m:1 assignee_id_ czone using "${TEMP}/final_cz_4_preaggregate`y'.dta", nogen keep(3)	// keep only multistate firms
		
		foreach var in tec covtec maltec malcovtec {
			*egen spill`var'=sum(`var'*(assignee_id!=assignee_id_)), by(assignee_id)
			egen spill`var'_cz=sum(`var'*(assignee_id!=assignee_id_)), by(assignee_id czone)	// TEC for all firms within CZ (addition doesn't actually matter when we only have CZ files)
			drop `var'
		}

		keep if assignee_id==assignee_id_
		drop assignee_id_
		
		gen year = `y'
		sort assignee_id year
		compress
		save "${TEMP}/spill_output_`cz'_`y'",replace
	}
	*Combine yearly files per CZ
	use "${TEMP}/spill_output_`cz'_`tmin'", clear
	local tmin1=`tmin'+1
	
	forv y=`tmin1'(1)`tmax' {
		append using "${TEMP}/spill_output_`cz'_`y'"
	}
	save "${TEMP}/spill_output_`cz'", replace
}

*Combine CZ files
use "${TEMP}/spill_output_100", clear
foreach cz of local all_cz {
	append using "${TEMP}/spill_output_`cz'"
	}

duplicates drop	// to kick out the CZ = 100 duplicates
save "${TEMP}/spill_output", replace

*Delete all intermediate files
forv y=`tmin'(1)`tmax' {
	erase "${TEMP}/final_cz_4_preaggregate`y'.dta"
	foreach cz of local all_cz {
		erase "${TEMP}/spill_output_`cz'_`y'.dta"
	}
}
*/
