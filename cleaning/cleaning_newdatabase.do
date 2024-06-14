////////////////////////////////////////////////////////////////////////////////
// Project:        	Moving innovation
// Creation Date:  	06/12/2023
// Last Update:    	24/04/2024
// Authors:         Laura Arnemann
// Goal: 			Cleaning the data from the Harvard Patent Database 
///////////////////////////////////////////////////////////////////////////////

/* Data sources: 
* Dyevre data set : https://github.com/arnauddyevre/compustat-patents
* Dorn data set: https://www.ddorn.net/data.htm
* Data avaialable until 2010: https://dataverse.harvard.edu/dataset.xhtml?persistentId=doi:10.7910/DVN/5F1RRI
* Data available until 2018: Theresa add link? 
*/


* Importing the Dyevre data 
forvalues i =1/8 { 
import delimited "${IN}\main_data\data_new\staticTranche`i'.csv", clear 
tempfile static`i'
save `static`i''
}

clear 
forvalues i=1/8 {
	append using `static`i''
}
rename patent_id patent 
replace patent ="0" + patent if strlen(patent)==7
* around 20.000 duplicate observations; 3644430 unique patents 
bysort patent: gen count=_n 
keep gvkeyfr patent count 

* It is a bit questionable whether we also want information on the ultimate owner of a patent 
reshape wide gvkeyfr, i(patent) j(count)
save "${TEMP}/dyevre_link.dta", replace 


* Importing the Data set starting 2018 
import delimited "${IN}/main_data/data_new/inventor.geo.assignee.combo.disambig.tsv", clear 
keep if country=="US"
rename patno patent 
replace patent = "0" + patent if strlen(patent)==7
gen appyear = substr(application_date, 1, 4)
destring appyear, replace force 
keep if inrange(appyear,1975, 2018)

merge m:1 patent using "${TEMP}/dyevre_link.dta" 
/* Result                      Number of obs
    -----------------------------------------
    Not matched                     5,857,674
        from master                 3,828,327  (_merge==1)
        from using                  2,029,347  (_merge==2)

    Matched                         4,194,677  (_merge==3)
    -----------------------------------------
*/ 
 
* Matching looks quite shitty 
keep if _merge ==3 
drop _merge 
save "${TEMP}/new_dataset2.dta", replace 



* Importing the new data set and merging it with the dorn link to patents 
import delimited "${IN}/main_data/data_new/full_disambiguation.csv", clear
egen assignee_id = group(assignee) 
rename unique_inventor_id inventor_id 
drop applyyear 
rename state state_abbr 
merge m:1 patent using "${IN}/main_data/data_new/cw_patent_compustat_adhps.dta", keepusing(usinv gvkey assignee_clean corpasg) 
* All patents matched 
drop _merge 
drop if missing(latitude)
save "${TEMP}/new_dataset1.dta", replace 



import delimited "${IN}/main_data/data_new/g_location_disambiguated.tsv", clear
save "${TEMP}/location.dta", replace 

import delimited "${IN}/main_data/data_new/g_assignee_disambiguated.tsv", clear
* Drop all patents with multiple assignees
duplicates tag patent_id, gen(dup)
drop if dup>0 
*538,141 observations deleted)
drop dup
save "${TEMP}/assignee.dta", replace 

import delimited "${IN}\main_data\data_new\g_application.tsv", clear 
save "${TEMP}/application.dta", replace 


import delimited "${IN}/main_data/data_new/g_inventor_disambiguated.tsv", clear
merge m:1 patent_id using "${TEMP}/assignee.dta"
keep if _merge==3 
drop _merge 

merge m:1 location_id using "${TEMP}/location.dta"
keep if _merge ==3 
drop _merge 
keep if disambig_country =="US"

merge m:1 patent_id using "${TEMP}/application.dta"
gen year = substr(filing_date, 1,4)
destring year, replace 
keep if inrange(year,1975, 2018)

save "${TEMP}/new_dataset2.dta", replace 


/*
    Result                      Number of obs
    -----------------------------------------
    Not matched                       163,215
        from master                   160,265  (_merge==1)
        from using                      2,950  (_merge==2)

    Matched                        21,887,313  (_merge==3)
    -----------------------------------------

*/

