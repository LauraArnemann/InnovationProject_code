////////////////////////////////////////////////////////////////////////////////
// Project:        	Moving innovation
// Creation Date:  	06/12/2023
// Last Update:    	24/04/2024
// Authors:         Laura Arnemann
//					Theresa Bührle
// Goal: 			Merging county information for the inventors for which no county was recorded
////////////////////////////////////////////////////////////////////////////////

********************************************************************************
* Preparing File which Maps Cities to Counties 
********************************************************************************

import excel "${IN}/var_CommutingZones/uscities.xlsx", sheet("Sheet1") firstrow clear
keep city state_id county_fips 
rename state_id state_inventor
rename city city_inventor
egen citystate_id = group(state_inventor city_inventor)
bysort citystate_id: gen count=_n 
reshape wide county_fips, i(citystate_id) j(count)
keep county_fips* city_inventor state_inventor 
save "${TEMP}/counties.dta", replace 



********************************************************************************
* Correct for spelling mistakes 
********************************************************************************

use patnum citation_count withdrawn date_filing date_grant app_year ///
	inventor_id first_name last_name male location_id state_fips_inventor county_fips_inventor ///
	assignee_id state_fips_assignee county_fips_assignee city_inventor state_inventor latitude_inventor longitude_inventor ///
	using "${PATENTDTA}/inventor_applications.dta", clear
	
	drop if withdrawn==1 
	drop withdrawn
	
*-Drop duplicates (we only want to count inventors once per recorded patent)
duplicates drop patnum inventor_id county_fips_inventor assignee_id, force

* (132 observations deleted)
duplicates report patnum inventor_id assignee_id // differences in geocoding (missings or two different locations recorded); 190 cases
duplicates tag patnum inventor_id assignee_id, gen(dup)
drop if dup!=0 
drop dup
*-Drop if missings in important variables
drop if app_year == .
drop if missing(state_inventor)
gen tag = 0 
replace  tag = 1 if missing(county_fips_inventor)

* Sometimes the county is missing due to spelling mistakes of the city, Trying to correct this here 

   bysort inventor_id app_year: egen max_tag = max(tag)
   bysort inventor_id app_year: egen min_tag = min(tag)

   keep if min_tag ==0 & max_tag == 1
   *br inventor_id state_fips_inventor city_inventor county_fips_inventor app_year if max_tag == 1 & min_tag==0 

   bysort inventor_id app_year: gen pre_city = city_inventor[_n-1]
   bysort inventor_id app_year: gen post_city = city_inventor[_n+1]
   bysort inventor_id app_year: gen pre_county = county_fips_inventor[_n-1]
   bysort inventor_id app_year: gen post_county = county_fips_inventor[_n+1]

   matchit city_inventor pre_city , g(simil_1)
   matchit city_inventor post_city , g(simil_2)
   replace county_fips_inventor = pre_county if simil_1>=0.6 & tag==1 & pre_county!=. 
   replace county_fips_inventor = post_county if simil_2>=0.6 & tag==1 & post_county!=.
   replace tag = 0 if county_fips_inventor!=. 
    bysort city_inventor state_fips_inventor (tag): replace county_fips_inventor = county_fips_inventor[_n-1] if tag ==1  
    replace tag = 0 if county_fips_inventor!=. 
   rename county_fips_inventor county_fips_helper 
   tempfile helper 
   save `helper'

* Import the data again and match with the helper file, also match with the county information and generate a data set to geocode the respective counties 
use patnum citation_count withdrawn date_filing date_grant app_year ///
	inventor_id first_name last_name male location_id state_fips_inventor county_fips_inventor ///
	assignee_id state_fips_assignee county_fips_assignee city_inventor state_inventor latitude_inventor longitude_inventor ///
	using "${PATENTDTA}/inventor_applications.dta", clear
		
	drop if withdrawn==1 
	drop withdrawn
	
*-Drop duplicates (we only want to count inventors once per recorded patent)
duplicates drop patnum inventor_id county_fips_inventor assignee_id, force

* (132 observations deleted)
duplicates report patnum inventor_id assignee_id // differences in geocoding (missings or two different locations recorded); 190 cases
duplicates tag patnum inventor_id assignee_id, gen(dup)
drop if dup!=0 
drop dup

drop if app_year == .
drop if missing(state_inventor)

gen tag = 0 
replace  tag = 1 if missing(county_fips_inventor)
merge 1:1 app_year inventor_id patnum using `helper', keepusing(county_fips_helper)
replace county_fips_inventor = county_fips_helper if _merge==3 & missing(county_fips_inventor)
drop if _merge ==2 
drop _merge 

bysort city_inventor state_fips_inventor (tag): replace county_fips_inventor = county_fips_inventor[_n-1] if missing(county_fips_inventor)
bysort city_inventor state_fips_inventor (tag): replace county_fips_inventor = county_fips_inventor[_n-1] if missing(county_fips_inventor)

replace tag = 0 if county_fips_inventor!=. 

********************************************************************************
* Merge in information for missing 
********************************************************************************

merge m:1 city_inventor state_inventor using  "${TEMP}/counties.dta"
replace county_fips_inventor = county_fips1 if tag ==1 & _merge ==3 
drop if _merge ==2
drop _merge  
drop county_fips1 county_fips2 county_fips3  
drop tag 
gen tag = 1 if missing(county_fips_inventor)

preserve 
save "${TEMP}/inventor_helper_v2.dta", replace 
restore 

********************************************************************************
* Counties which are missing but we know latitude of inventor 
********************************************************************************
keep if tag ==1 & latitude_inventor!=. 
save "${TEMP}/county_match_prep.dta", replace 


*Recovering county Fips Codes in Python (county_codes.ipynb)	x	x	x	x	x	x	x 

use "${TEMP}/county_matched_cleaned.dta", replace 
destring STATEFP, replace 
destring COUNTYFP, replace 
replace state_fips_inventor = STATEFP if missing(state_fips_inventor)
gen check = 1 if STATEFP != state_fips_inventor
* drop the 819 values for which the state assigned based on the Python code differed from the state fips recoded in the inventor data set
drop if check ==1 
replace county_fips_inventor = COUNTYFP if missing(county_fips_inventor)
drop county_fips_helper 
rename county_fips_inventor county_fips_helper 
save "${TEMP}/county_matched_cleaned_v1.dta", replace 
 
*******************************************************************************
* Merging the different data sets together 
*******************************************************************************
 
 use "${TEMP}/inventor_helper_v2.dta", clear 
 drop county_fips_helper 
 merge  1:1 app_year inventor_id patnum using "${TEMP}/county_matched_cleaned_v1.dta", keepusing(county_fips_helper)
 replace county_fips_inventor = county_fips_helper if _merge ==3 & missing(county_fips_inventor)
 drop if _merge ==2 
 drop _merge 
 *  27,960  for which there are no county fips codes, hopefully this should not interfere with our analysis anymore 
 drop county_fips_helper tag 
 drop if missing(county_fips_inventor)
 save "${TEMP}/inventor_helper_v3.dta", replace 
 
 erase "${TEMP}/inventor_helper_v2.dta"
 erase "${TEMP}/county_matched_cleaned_v1.dta"
 
 