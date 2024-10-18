////////////////////////////////////////////////////////////////////////////////
// Project:        	Moving innovation
// Creation Date:  	06/12/2023
// Last Update:    	02/10/2024
// Authors:         Laura Arnemann
//					Theresa Bührle
// Goal: 			Cleaning patent data
///////////////////////////////////////////////////////////////////////////////

/*
Data source: Patentsview (used in Dyevre Paper)
Link: https://patentsview.org/download/data-download-tables 
Data downloaded: g_location_disambiguated; g_assignee_disambiguated; g_application.tsv; g_inventor_disambiguated.tsv

Dyevre data set : https://github.com/arnauddyevre/compustat-patents
*/


********************************************************************************
* Import files
********************************************************************************

* Dyevre match patent data to Compustat
*-------------------------------------------------------------------------------

forvalues i =1/8 { 
import delimited "${IN}/main_data/data_new/Dyevre/staticTranche`i'.csv", clear 
tempfile static`i'
save `static`i''
}

clear 
forvalues i=1/8 {
	append using `static`i''
}

bysort patent_id: gen count=_n 
keep gvkeyfr patent_id count 
* It is a bit questionable whether we also want information on the ultimate owner of a patent 
reshape wide gvkeyfr, i(patent_id) j(count)
save "${TEMP}/dyevre_link.dta", replace 

* Patent info (g_application)
*-------------------------------------------------------------------------------
import delimited "${IN}/main_data/data_new/Patentsview/g_application.tsv", clear 
save "${TEMP}/application.dta", replace 

* Inventor location (g_location_disambiguated)
*-------------------------------------------------------------------------------
import delimited "${IN}/main_data/data_new/Patentsview/g_location_disambiguated.tsv", clear
save "${TEMP}/location.dta", replace 

* Assignee/ firm info (g_assignee_disambiguated)
*-------------------------------------------------------------------------------
import delimited "${IN}/main_data/data_new/Patentsview/g_assignee_disambiguated.tsv", clear

* Drop all patents with multiple assignees
duplicates tag patent_id, gen(dup)
drop if dup>0 // 538,141 observations deleted)
drop dup
save "${TEMP}/assignee.dta", replace 

* Inventor info (g_inventor_disambiguated)
*-------------------------------------------------------------------------------
import delimited "${IN}/main_data/data_new/Patentsview/g_inventor_disambiguated.tsv", clear


********************************************************************************
* Merge files
********************************************************************************

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

compress
save "${TEMP}/patentdata.dta", replace 

erase "${TEMP}/assignee.dta"
erase "${TEMP}/application.dta"
erase "${TEMP}/location.dta"
erase "${TEMP}/dyevre_link.dta"







