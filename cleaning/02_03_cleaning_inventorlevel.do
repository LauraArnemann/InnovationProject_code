////////////////////////////////////////////////////////////////////////////////
// Project: Inventor Relocation
// Creation Date: 	24/01/2025
// Last Update: 	24/01/2025
// Author: 			Laura Arnemann 
//					Theresa Bührle					
// Goal: 			Inventor-level dataset 
////////////////////////////////////////////////////////////////////////////////


use "${TEMP}/patentdata.dta", clear 

if $gvkey == 1 {
    drop assignee_id 
	rename gvkey assignee_id
}

********************************************************************************
*Cleam raw data
********************************************************************************

*-Drop if missings in important variables
drop if missing(patnum)
drop if missing(app_year)
drop if missing(assignee_id)
drop if missing(state_fips_inventor)
drop if missing(county_fips_inventor)

tostring county_fips_inventor, replace 
tostring state_fips_inventor, replace 
replace county_fips_inventor = "0" + county_fips_inventor if strlen(county_fips_inventor)==2
replace county_fips_inventor = "00" + county_fips_inventor if strlen(county_fips_inventor)==1
replace county_fips_inventor = state_fips_inventor + county_fips_inventor 
destring county_fips_inventor, replace 

*-Drop duplicates (we only want to count inventors once per recorded patent)
//Cases where we have slightly different geolocation, but within same county
duplicates drop patnum inventor_id county_fips_inventor assignee_id, force
	
// Cases where we have different geolocation in different counties
duplicates report patnum inventor_id assignee_id // differences in geocoding (missings or two different locations recorded); 247 cases
duplicates tag patnum inventor_id assignee_id, gen(dup)
drop if dup!=0 
drop dup

*Check: Should have unique pairs of patnum and inventors
duplicates report patnum inventor_id

*Numerical IDs for inventor and assignee_id
egen inv_ID = group(inventor_id)
egen firm_ID = group(assignee_id)

preserve
	keep inventor_id inv_ID
	duplicates drop
	save "${TEMP}/mapping_inv_ID.dta", replace 
restore

preserve
	keep assignee_id firm_ID
	duplicates drop
	save "${TEMP}/mapping_firm_ID.dta", replace 
restore

drop inventor_id assignee_id

********************************************************************************
*Generate inventor-level variables
********************************************************************************

*Number of patents per inventor
bysort inv_ID app_year: gen inv_patent_year = _N
bysort inv_ID: gen inv_patent_all = _N

*Moving inventors
sort inv_ID app_year

*- New location not recorded in previous year
tostring county_fips_inventor, replace

bysort inv_ID app_year: gen counter = _n
sum counter
local counter_max = r(max)
display `counter_max'

forvalues i = 1/`counter_max' {
	gen inv_loc`i' = county_fips_inventor if `i' == counter
}

gen inv_loc_all = ""
	replace inv_loc_all 



*- New main location as compared to last year
gen inv_move = 0
	replace inv_move = 1 if inventor_id == inventor_id[_n-1] & ///
		app_year > app_year[_n-1] & county_fips != county_fips[_n-1]

		
********************************************************************************
*Aggregation at inventor-year level
********************************************************************************

*Main location within a year

*Main workplace within a year

*Aggregate at inventor-year level
duplicates drop inventor_id app_year, force


********************************************************************************
*Treatment: Changes in other locations
********************************************************************************

*Merge in data for changes at other locations
rename county_fips_inventor county_fips
rename state_fips_inventor fips_state
rename app_year year

destring fips_state, replace

foreach num of numlist $patentvar {
merge m:1 fips_state year assignee_id using "${TEMP}/other_threelargest`num'_treated.dta"
	drop if _merge == 2
	drop _merge
	
merge m:1 fips_state year assignee_id using "${TEMP}/other_all`num'_treated.dta"
	drop if _merge == 2
	drop _merge
}

*Inventors associated with treated firms
gen inv_treat = change_other_threelargest_d == 1










