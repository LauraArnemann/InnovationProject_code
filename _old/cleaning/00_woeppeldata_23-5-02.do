/// PROJECT: Spillover Effects 
/// GOAL: Prepare patent data 
/// AUTHORS: Laura Arnemann, Theresa Bührle
/// CREATION: 27-12-2022
/// LAST UPDATE: 02-05-2023
/// SOURCE: Raw Data 

*Data Source: https://www.mikewoeppel.com/data

*Data Import -------------------------------------------------------------------

* Assignee data xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
forvalues i=5/12 {
  import delimited "${IN}/assignee/assignee_`i'm.tsv", clear
  duplicates drop patnum assignee_id location_id, force
	//There are several assignees that have more than one address for the same patnum
	
	foreach var of varlist city state country latitude longitude county state_fips county_fips {
	    rename `var' `var'_assignee	
	}
  save "${TEMP}/assignee/assignee_`i'm.dta", replace
 }
  
use  "${IN}/assignee/assignee_5m.dta", clear
 forvalues i=6/12 {
     merge 1:1 patnum assignee_id location_id using "${TEMP}/assignee/assignee_`i'm.dta", nogen
 }

rename type organization_type

label var patnum "Patent number"
label var assignee_id "USPTO assignee identification"
label var organization "Assignee"
label var city_assignee "City of assignee"
label var state_assignee "State of assign"
label var country_assignee "Country of assignee"
label var latitude_assignee "Geographic coordinate"
label var longitude_assignee "Geographic coordinate"
label var county_assignee "County of assignee"
label var state_fips_assignee "State FIPS code"
label var county_fips_assignee "County FIPS code"
label var organization_type "Organization type"
label var location_id "USPTO location identification"
 
save "${TEMP}/assignee/assignee_all.dta", replace

/*
use "${IN}/assignee/assignee_all.dta", clear

count if city == "both of" 
count if city == "BOTH OF"
	//There seems to be a problem in the code with double locations, as city is oftentimes named as "both of"
*/


* Citation Data xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
forvalues i=8/12 {
  import delimited "${IN}/citation/app_cites_`i'm.tsv", clear
  save "${TEMP}/citation/app_cites_`i'm.dta", replace
}

use  "${IN}/citation/app_cites_8m.dta", clear
 forvalues i=9/12 {
     merge m:m patnum using "${TEMP}/citation/app_cites_`i'm.dta", nogen
}

rename kind app_kind
/*
Explanation of application kind codes:
https://www.uspto.gov/learning-and-resources/support-centers/electronic-business-center/kind-codes-included-uspto-patent

Could kick out plant and design patents and check whether there is double counting with republications or corrected publications, but share less than 1%	
*/

label var patnum "Patent number"
label var appcite_num "Application number of application citation"
label var appcite_idate "Filing date of application citation (mm/yyyy)"
label var app_kind "Application kind"
label var cited_by "Person who cited patent (examiner, applicant, etc.)"
label var sequence "Patent-level position within application citations" 

save "${TEMP}/citation/app_cites_all.dta", replace 
/*
We might want to differentiate later on between citations 
- in the same vs in other fields
- from the same firm/group/inventor vs unrelated citations
Save as full sample for now, aggregate seperately.
*/

use "${TEMP}/citation/app_cites_all.dta", clear 

bysort patnum: gen count=_n 
  collapse (count) count, by(patnum)
  rename count citation_count
  label var citation_count "Count of citations" 
  
save "${TEMP}/citation/app_cites_aggr.dta", replace 

* Info Data xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
forvalue i=5/12 {
  import delimited "${IN}/info/info_`i'm.tsv", clear
  save "${TEMP}/info/info_`i'm.dta", replace
}

use  "${TEMP}/info/info_5m.dta", clear
 forvalues i=6/12 {
     merge 1:1 patnum using "${TEMP}/info/info_`i'm.dta", nogen
}
rename type patent_type
rename kind patent_kind
rename country patent_country

*Date variables 

**Filing date
gen fdate_day = substr(fdate, 4, 2)
	destring fdate_day, replace
	
gen fdate_month = substr(fdate, 1, 2)
	destring fdate_month, replace
	
gen fdate_year = substr(fdate, 7, 4)
	// For some years, there seem to be coding mistakes with the first two digits (comparing filing to grant date)
	*-Split the year variable
	gen fdate_year1 = substr(fdate_year, 1, 2)
	gen fdate_year2 = substr(fdate_year, 3, 2)
	foreach var in "10" "11" "12" "13" "14" "15" "16" "17" "18" {
		replace fdate_year1 = "19" if fdate_year1 == "`var'"
	}
	replace fdate_year1 = "19" if fdate_year1 == "29"
	replace fdate_year1 = "19" if fdate_year1 == "91"
	*-Put year variable back together
	replace fdate_year = fdate_year1 + fdate_year2
	destring fdate_year, replace
	drop if fdate_year < 1900 | fdate_year > 2021 // We loose 14 obs
	
gen date_filing = mdy(fdate_month, fdate_day, fdate_year)
	format date_filing %d
	label var date_filing "Filing date of patent"
drop fdate fdate_month fdate_day fdate_year fdate_year1 fdate_year2

**Grant date
gen idate_day = substr(idate, 4, 2)
	destring idate_day, replace
gen idate_month = substr(idate, 1, 2)
	destring idate_month, replace
gen idate_year = substr(idate, 7, 4)
 	destring idate_year, replace
	
gen date_grant = mdy(idate_month, idate_day, idate_year)
	format date_grant %d
	label var date_grant "Issue (grant) date of patent"
drop idate idate_month idate_day idate_year

label var patnum "Patent number"
label var patent_type "Patent type"
label var appnum "Application number"
label var series_code "Application type"
label var num_claims "Number of claims"
label var num_figures "Number of figures"
label var num_sheets "Number of drawings"
label var patent_kind "Patent kind"
label var withdrawn "1=withdrawn, 0=not withdrawn"
label var patent_country "Country of patent (all US)"

save "${TEMP}/info/info_all.dta", replace

* Classification Data xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

if ${classification}==1 {
**Cooperative patent classification (CPC) 
forvalue i=5/12 {
  import delimited "${IN}/classifications/cpc_`i'm.tsv", clear
  save "${IN}/classifications/cpc_`i'm.dta", replace
}

use  "${IN}/classifications/cpc_5m.dta", clear
 forvalues i=6/12 {
     merge 1:1 patnum cpc_sequence using "${IN}/classifications/cpc_`i'm.dta", nogen
}

label var patnum "Patent number"
label var cpc_section "CPC section"
label var cpc_subsection "CPC subsection"
label var cpc_group "CPC group"
label var cpc_subgroup "CPC subgroup"
label var cpc_sequence "Patent-level position within CPC fields"
label var cpc_category "0=additional; 1=inventional"

save "${TEMP}/classifications/cpc_all.dta", replace

**International patent classification (IPC)
forvalue i=5/12 {
  import delimited "${IN}/classifications/ipc_`i'm.tsv", clear
  
  forvalues n = 1/9 {
	capture replace ipc_class = "0`n'" if ipc_class == "O`n'"
  }
  
  capture replace ipc_subgroup = subinstr(ipc_subgroup, "/", "",.)
  
  foreach var of varlist ipc_class ipc_main_group ipc_subgroup {
	  capture gen byte notnumeric = real(`var') == .	//There seem to be problems with mixed up columns for a small number of obs
	  capture drop if notnumeric == 1
	  capture drop notnumeric
	  destring `var', replace
  }
  
  tostring ipc_date, replace
  
  save "${TEMP}/classifications/ipc_`i'm.dta", replace
}

use  "${IN}/classifications/ipc_5m.dta", clear
 forvalues i=6/12 {
     merge 1:1 patnum ipc_sequence using "${IN}/classifications/ipc_`i'm.dta", nogen
}

label var patnum "Patent number"
label var ipc_symbol "IPC section symbol"
label var ipc_class "IPC class symbol"
label var ipc_subclass "IPC subclass symbol"
label var ipc_main_group "IPC main group symbol"
label var ipc_subgroup "IPC subgroup symbol"
label var ipc_sequence "Patent-level position within IPC classifications"
label var ipc_date "IPC version date"

save "${TEMP}/classifications/ipc_all.dta", replace

**US patent classification (USPC)
forvalue i=5/10 {
  import delimited "${IN}/classifications/uspc_`i'm.csv", clear
  duplicates drop patnum uspc_sequence, force
  save "${TEMP}/classifications/uspc_`i'm.dta", replace
}

use  "${IN}/classifications/uspc_5m.dta", clear
 forvalues i=6/10 {
     merge 1:1 patnum uspc_sequence using "${TEMP}/classifications/uspc_`i'm.dta", nogen
}

label var patnum "Patent number"
label var uspc_main_class "USPC main classification"
label var uspc_sub_class "USPC sub-classification"
label var uspc_sequence "Patent-level position within USPC classifications"

save "${TEMP}/classifications/uspc_all.dta", replace

**World intellectual patent organization (WIPO)
forvalue i=5/12 {
  import delimited "${IN}/classifications/wipo_`i'm.tsv", clear
  save "${TEMP}/classifications/wipo_`i'm.dta", replace
}

use  "${IN}/classifications/wipo_5m.dta", clear
 forvalues i=6/12 {
     merge 1:1 patnum wipo_sequence using "${TEMP}/classifications/wipo_`i'm.dta", nogen
}

label var patnum "Patent number"
label var wipo_field_id "WIPO field"
label var wipo_sequence "Patent-level position within WIPO classifications"
label var wipo_sector_title "WIPO sector title"
label var wipo_field_title "WIPO field title"

save "${TEMP}/classifications/wipo_all.dta", replace

}


* Inventor Data xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
forvalues i=5/12 {
  import delimited "${IN}/inventors/inventor_`i'm.tsv", clear 

   foreach var of varlist city state country latitude longitude county state_fips county_fips {
	    rename `var' `var'_inventor
 }
 duplicates drop patnum inventor_id location_id, force
 
  save "${TEMP}/inventors/inventor_`i'm.dta", replace
}

use  "${TEMP}/inventors/inventor_5m.dta", clear
 forvalues i=6/12 {
     merge 1:1 patnum inventor_id location_id using "${TEMP}/inventors/inventor_`i'm.dta", nogen
}

label var inventor_id "USPTO inventor identification" 
label var first_name "First and middle name/initial (if present) of inventor" 
label var last_name "Last name of inventor" 
label var male "1=male, 0=female, .=missing" 
label var city_inventor "City of inventor" 
label var state_inventor "State of inventor" 
label var country_inventor "Country of inventor" 
label var latitude_inventor "Geographic coordinate" 
label var longitude_inventor "Geographic coordinate" 
label var county_inventor "County of inventor" 
label var state_fips_inventor "State FIPS code" 
label var county_fips_inventor "County FIPS code" 

save "${TEMP}/inventors/inventor_all.dta", replace

use "${TEMP}/inventors/inventor_all.dta", clear

gen location_US = 0
	replace location_US = 1 if country_inventor == "US"
bysort inventor_id: egen US_inventor = max(location_US)
// drop inventors that are not recorded as resident in the US at least once
// drops almost 50%; 8,430,653 obs; drops 117 observations for which there was a state record
drop if US_inventor == 0 
drop US_inventor location_US

save "${TEMP}/inventors/inventor_US.dta", replace

*Data Merge --------------------------------------------------------------------

use "${TEMP}/citation/app_cites_aggr.dta", clear
	merge 1:1 patnum using "${TEMP}/info/info_all.dta"
	drop _merge
	//There's only info for ~50% of patnums
	merge 1:m patnum using "${IN}/assignee/assignee_all.dta"
	drop _merge
	//Not all info can be matched to an assigned patent; 719.971 from master, 12 from using 

compress
 
save "${OUT}/citations_info_assignee.dta", replace 

if $classification==1 {
*Coverage classifications
use "${OUT}/citations_info_assignee.dta", clear 
/*
preserve
merge m:m patnum using "${IN}/classifications/cpc_all.dta"	// not matched master: 14,108 !BEST!
restore
preserve
merge m:m patnum using "${IN}/classifications/ipc_all.dta" // not matched master: 19,100
restore
preserve
merge m:m patnum using "${IN}/classifications/uspc_all.dta" // not matched master: 2,248,388 
restore
preserve
merge m:m patnum using "${IN}/classifications/wipo_all.dta" // not matched master: 21,635   
restore
*/
merge m:m patnum using "${IN}/classifications/cpc_all.dta", nogen

save "${OUT}/joint_applications.dta", replace 
}

***WE look at data without industry classification for now
use "${OUT}/citations_info_assignee.dta", clear 

duplicates drop

gen app_year = year(date_filing)
drop if app_year<1970 | app_year>2021 

keep patnum citation_count patent_type withdrawn date_filing date_grant assignee_id city_assignee state_assignee country_assignee latitude_assignee longitude_assignee county_assignee state_fips_assignee county_fips_assignee app_year

duplicates tag patnum app_year, gen(dup)

* Create an extra data set for the duplicates, since reshaping the data set with that many patents will take forever
preserve 
	keep if dup>0
	drop dup
	bysort patnum: gen count=_n
	drop if count>10
	* I cross-checked this, this bloats up the data set and there are only 5 patents that have so many different entries 
	reshape wide assignee_id city_assignee state_assignee country_assignee latitude_assignee longitude_assignee county_assignee state_fips_assignee county_fips_assignee, i(patnum) j(count) 
	save "${TEMP}/applications_v2.dta", replace 
restore 

keep if dup==0 
save "${TEMP}/applications_v1.dta", replace 


* Merging the two data sets together 
use "${TEMP}/inventors/inventor_US.dta", clear

merge m:1 patnum using "${TEMP}/applications_v1.dta"

/*
    Laura:
	
	Result                      Number of obs
    -----------------------------------------
    Not matched                     3,601,886
        from master                   293,968  (_merge==1)
        from using                  3,307,918  (_merge==2)

    Matched                         8,658,778  (_merge==3)
	-----------------------------------------

	
	Theresa:
	
	  Result                           # of obs.
    -----------------------------------------
    not matched                     2,943,974
        from master                   364,338  (_merge==1)
        from using                  2,579,636  (_merge==2)

    matched                         9,661,314  (_merge==3)
    -----------------------------------------
*/ 

preserve 
	keep if _merge==1 
	drop _merge 
	merge m:1 patnum using "${TEMP}/applications_v2.dta"
	keep if _merge==3 
	* If we also do this match we merge all but 88,975 observations, quite okay 
	* Theresa: 189,082 (?)
	drop _merge
	save "${TEMP}/inventor_matched_v2.dta", replace 
restore 

keep if _merge==3 
drop _merge 

append using "${TEMP}/inventor_matched_v2.dta", force
* The append takes super long, might need to make the data set before bit smaller 
* Theresa: results in dataset size ~ 21 GB
save  "${TEMP}/inventor_applications.dta", replace 


*Data analysis -----------------------------------------------------------------

use "${OUT}/citations_info_assignee.dta", clear 

*Location info for assignee
count if missing(county_fips) //  4,371,047
count if missing(county_fips) & country_assignee == "US" //  251,154
*-> We have a large number of applications for non-US companies (inventors could still be in the US though)
count if missing(county_fips) & country_assignee == "US" & missing(city_assignee) & missing(state_assignee) // 9,453
*-> In most US cases, there is a city and state recorded but the county fips is missing -> could be inserted
count if missing(latitude_assignee) & missing(longitude_assignee) & country_assignee == "US" //  20,792
**Absolute zero location info for US:
count if missing(county_fips) & missing(city_assignee) & missing(latitude_assignee) & missing(longitude_assignee) & country_assignee == "US"  // 1
*-> We can recover needed county location info by combining available data

*Firm movement
sort assignee_id date_filing 

gen move_d = .
	bysort assignee_id: replace move_d = 1 if ///
		location_id[_n] != location_id[_n-1] & assignee_id[_n] == assignee_id[_n-1]
	bysort assignee_id: replace move_d = 0 if ///
		location_id[_n] == location_id[_n-1] & assignee_id[_n] == assignee_id[_n-1]
	bysort assignee_id: replace move_d = 0 if ///
		assignee_id[_n] != assignee_id[_n-1] & move_d == .

tab move_d
bysort assignee_id: egen ever_moved = max(move_d) // 80% of firms have moved locations

tab ever_moved
tab ever_moved if country_assignee == "US" 

order ever_moved move_d assignee_id date_filing
br if ever_moved == 1
br if ever_moved == 1 & country_assignee == "US" 
/*
There seem to be a lot of cases where the firm "moves" location for one patent and then records
subsequent patent at old location
or: there are missing location variables in between, leading to new location_id and artifical moves

EXAMPLE: 89e5d47d-a6c8-4dbc-b190-2a0bb9fb5970 (Sony)
br if assignee_id == "89e5d47d-a6c8-4dbc-b190-2a0bb9fb5970"

-> There might be problems with differentiating between different subsidiaries
*/


/*
use  "${TEMP}/inventor_applications.dta", clear 




