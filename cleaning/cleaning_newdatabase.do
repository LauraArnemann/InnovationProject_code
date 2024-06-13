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
* Data available until 2018: https://dataverse.harvard.edu/dataset.xhtml?persistentId=doi:10.7910/DVN/KPMMPV
*/

********************************************************************************
*Woeppel data
********************************************************************************

use patnum withdrawn app_year ///
	inventor_id  state_fips_inventor county_fips_inventor ///
	assignee_id state_fips_assignee county_fips_assignee  ///
	using "${PATENTDTA}/inventor_applications.dta", clear
	
drop if withdrawn==1 
drop withdrawn

drop if missing(app_year)
drop if missing(assignee_id)
drop if missing(state_fips_inventor)

*-Drop duplicates (we only want to count inventors once per recorded patent)
duplicates drop patnum inventor_id county_fips_inventor assignee_id, force

duplicates report patnum inventor_id assignee_id // differences in geocoding (missings or two different locations recorded); 190 cases
duplicates tag patnum inventor_id assignee_id, gen(dup)
drop if dup!=0 
drop dup

* Merge in information on county_fips_information 
rename county_fips_inventor county_fips_helper 

merge 1:1 patnum assignee_id inventor_id using "${TEMP}/inventor_helper_v3.dta", keepusing(county_fips_inventor)
drop if _merge==2 
drop _merge 
replace county_fips_helper = county_fips_inventor if missing(county_fips_helper)
drop county_fips_inventor 
rename county_fips_helper county_fips_inventor

drop if missing(county_fips_inventor)
	
save "${TEMP}/woeppel_dataset.dta", replace 
	
********************************************************************************
*2018 Data 
********************************************************************************

* 1. Importing the Dyevre data 
*-------------------------------------------------------------------------------

forvalues i =1/8 { 
import delimited "${IN}/main_data/data_new/staticTranche`i'.csv", clear 
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


* 2. Importing the Data set starting 2018 
*-------------------------------------------------------------------------------

import delimited "${IN}/main_data/data_new/inventor.geo.assignee.combo.disambig.tsv", clear 

keep if country=="US"
rename patno patent 
replace patent = "0" + patent if strlen(patent)==7
gen app_year = substr(application_date, 1, 4)
destring app_year, replace force 
keep if inrange(app_year,1975, 2018)

merge m:1 patent using "${TEMP}/dyevre_link.dta" 
/* Result                      Number of obs
    -----------------------------------------
    Not matched                     5,857,674
        from master                 3,828,327  (_merge==1)
        from using                  2,029,347  (_merge==2)

    Matched                         4,194,677  (_merge==3)
    -----------------------------------------
*/ 
	//Matching looks quite shitty 
keep if _merge ==3 
drop _merge 

drop gvkeyfr6-gvkeyfr9	// empty

rename patent patnum
rename lastname last_name
rename firstname first_name
rename state state_inventor
rename city city_inventor
rename county county_inventor
rename country country_inventor
rename latitude latitude_inventor
rename longitude longitude_inventor
rename fips_state state_fips_inventor 
rename fips_county county_fips_inventor
rename grant_date date_grant 

rename gvkeyfr1 assignee_id

drop name geo 

destring patnum, replace force
drop if patnum == .

save "${TEMP}/new_dataset2.dta", replace 


********************************************************************************
*2010 Data 
********************************************************************************


*Importing the new data set and merging it with the dorn link to patents 
import delimited "${IN}/main_data/data_new/full_disambiguation.csv", clear

egen assignee_id = group(assignee) 
rename unique_inventor_id inventor_id 
drop applyyear 
rename state state_abbr 

merge m:1 patent using "${IN}/main_data/data_new/cw_patent_compustat_adhps.dta", keepusing(usinv gvkey assignee_clean corpasg) 
	//All patents matched 
drop _merge 
drop if missing(latitude)

save "${TEMP}/new_dataset1.dta", replace 

*MATCHING IN PYTHON	x	x	x	x	x	x	x

use  "${TEMP}/new_dataset1_county_states.dta", clear 

keep if country=="US"

rename patent patnum
rename lastname last_name
rename firstname first_name
rename state_abbr state_inventor
rename city city_inventor
rename country country_inventor
rename latitude latitude_inventor
rename longitude longitude_inventor
rename appyear app_year
rename STATEFP state_fips_inventor 
rename COUNTYFP county_fips_inventor
rename NAME county_inventor

drop NAMELSAD - INTPTLON

destring patnum, replace force
drop if patnum == .
	
save "${TEMP}/new_dataset1_county_states_clean.dta", replace 	
