////////////////////////////////////////////////////////////////////////////////
// Project:        	Moving innovation
// Creation Date:  	06/12/2023
// Last Update:    	24/04/2024
// Authors:         Laura Arnemann
//					Theresa Bührle
// Goal: 			Merging the data set using the number of inventors in a state employed by the respective firm as outcome variable 
////////////////////////////////////////////////////////////////////////////////

* Checking Original Data Set yet again

use patnum date_filing date_grant app_year ///
	inventor_id ///
	assignee_id  state_fips_inventor ///
	using "${PATENTDTA}/inventor_applications.dta", clear

duplicates drop

merge 1:m patnum date_filing date_grant app_year inventor_id assignee_id state_fips_inventor using "C:\Users\laura\Dropbox\Mein PC (LAPTOP-AF29US2I)\Downloads\inventor_applications_string.dta"

* Perfect match + Information identifies all observations uniquely 

use "${TEMP}/id_match_assignee.dta", clear 


use "${TEMP}/final_state_zeros_new.dta", clear 

foreach var of varlist _all {
rename `var' `var'_old
}

rename fips_state_old fips_state 
rename assignee_id_old assignee_id_string 
rename year_old year 

merge m:1 assignee_id_string using "${TEMP}/id_match_assignee.dta"
keep if _merge==3 

drop _merge 

merge 1:1 assignee_id fips_state year using  "${TEMP}/final_state_zeros_new_tbl.dta"
/*
    Result                      Number of obs
    -----------------------------------------
    Not matched                            28
        from master                        20  (_merge==1)
        from using                          8  (_merge==2)

    Matched                         1,669,643  (_merge==3)
    -----------------------------------------
*/

*f111a00a-80bd-4a6b-8ba8-021a67142d90
*df71eb1e-8dd7-4233-9d2b-0448330c4e06
*05d85a41-744c-4129-abee-b3d6ca5ebafc (2010-2014: 0 patents)
*f111a00a-80bd-4a6b-8ba8-021a67142d90 (1990, 1989)

forvalues i =1/3 {
	gen diff`i'_pat = 1 if patents`i'!= patents`i'_old
	gen diff`i'_inv = 1 if n_inventors`i'!= n_inventors`i'_old
	
}

/* 
All zeros notmatched, patents missing and number of inventors not missing
*/