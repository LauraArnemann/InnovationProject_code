////////////////////////////////////////////////////////////////////////////////
// Project:        	Moving innovation
// Creation Date:  	06/12/2023
// Last Update:    	02/10/2024
// Authors:         Laura Arnemann
// Goal: 			Cleaning the data from the Harvard Patent Database 
///////////////////////////////////////////////////////////////////////////////

/* Data sources: 
* Dyevre data set : https://github.com/arnauddyevre/compustat-patents
* Dorn data set: https://www.ddorn.net/data.htm
* Data avaialable until 2010: https://dataverse.harvard.edu/dataset.xhtml?persistentId=doi:10.7910/DVN/5F1RRI
* Data available until 2018: https://dataverse.harvard.edu/dataset.xhtml?persistentId=doi:10.7910/DVN/KPMMPV
* Data used in Dyevre Paper: https://patentsview.org/download/data-download-tables; Data downloaded: g_location_disambiguated; g_assignee_disambiguated; g_application.tsv; g_inventor_disambiguated.tsv
*/

********************************************************************************
* Reading in the State data 
********************************************************************************

do "${CODE}/cleaning/02_02_cleaning_state.do"


********************************************************************************
* Filling in the county data for the observations with missing county information
********************************************************************************

do "${CODE}/cleaning/01_filling_counties.do"
// Requires running some Python Code inbetween 


********************************************************************************
*2018 Data from PatentsView used in the Dyevre data set  
********************************************************************************

import delimited "${IN}/main_data/data_new/Patentsview/g_location_disambiguated.tsv", clear
save "${TEMP}/location.dta", replace 

import delimited "${IN}/main_data/data_new/Patentsview/g_assignee_disambiguated.tsv", clear
* Drop all patents with multiple assignees
duplicates tag patent_id, gen(dup)
drop if dup>0 
*538,141 observations deleted)
drop dup
save "${TEMP}/assignee.dta", replace 

import delimited "${IN}/main_data/data_new/Patentsview/g_application.tsv", clear 
save "${TEMP}/application.dta", replace 


import delimited "${IN}/main_data/data_new/Patentsview/g_inventor_disambiguated.tsv", clear
merge m:1 patent_id using "${TEMP}/assignee.dta"
keep if _merge==3 
drop _merge 

merge m:1 location_id using "${TEMP}/location.dta"
keep if _merge ==3 
drop _merge 
keep if disambig_country =="US"

merge m:1 patent_id using "${TEMP}/application.dta"
gen app_year = substr(filing_date, 1,4)
destring app_year, replace 
keep if inrange(app_year,1975, 2018)
drop if _merge !=3 
drop _merge

merge m:1 patent_id using "${TEMP}/dyevre_link.dta", keepusing(gvkeyfr*)
drop if _merge ==2 
drop _merge 

/*
  Result                      Number of obs
    -----------------------------------------
    Not matched                     5,612,717
        from master                 3,726,763  (_merge==1)
        from using                  1,885,954  (_merge==2)

    Matched                         4,627,128  (_merge==3)
    -----------------------------------------


* When matching directly to the disambiguated inventor data set; 655.613 observations not matched: I assume these are the patents from the 50s
*/
rename gvkeyfr1 gvkey 
drop gvkeyfr2-gvkeyfr9	
rename patent_id patnum
rename disambig_inventor_name_first last_name
rename disambig_inventor_name_last first_name
rename disambig_country country_inventor
rename latitude latitude_inventor
rename longitude longitude_inventor
rename state_fips state_fips_inventor 
rename county_fips county_fips_inventor
rename county county_inventor
rename disambig_state assignee_state

drop assignee_sequence disambig_assignee_individual_nam v5 location_id filing_date series_code rule_47_flag

drop if missing(patnum)
destring patnum, replace force 

save "${TEMP}/new_dataset3.dta", replace 

*erase ${TEMP}/assignee.dta
*erase ${TEMP}/application.dta
*erase ${TEMP}/location.dta








