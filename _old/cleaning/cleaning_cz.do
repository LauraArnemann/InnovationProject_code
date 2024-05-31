// Project: Inventor Relocation
// Creation Date: 10/02/2024
// Last Update: 10/02/2024
// Author: Laura Arnemann 
// Goal: Merging the data set with the number of inventors 


********************************************************************************
* Generate Number of Patents on CZ level 
********************************************************************************

use patnum citation_count withdrawn date_filing date_grant app_year ///
	inventor_id first_name last_name male location_id state_fips_inventor county_fips_inventor ///
	assignee_id state_fips_assignee county_fips_assignee  ///
	using "$PATENTDTA\inventor_applications.dta", clear
	
	
drop if withdrawn==1 
drop withdrawn

*-Drop if missings in important variables
drop if app_year == .
drop if county_fips_inventor == .

* First step: Number of patents the firm records in a county and a state

*-Drop duplicates (we only want to count inventors once per recorded patent)
duplicates drop patnum inventor_id county_fips_inventor assignee_id, force 
* (132 observations deleted)	
duplicates drop patnum inventor_id assignee_id, force 

rename county_fips_inventor county_fips

* Merging in the Commuting Zone level data 
merge m:1 county_fips using "$IN\var_CommutingZones\CZ_combined.dta"
drop if _merge!=3  
drop _merge	

drop CZ_depagri_2000 CZ_UScensus county_name_depagri CZ_depagri_1980


*3 Assign Patent to the Commuting Zone where the most inventors are located
bysort patnum CZ_depagri_1990 app_year: gen cz_count=_N 
bysort patnum app_year: egen max_cz=max(cz_count)
keep if max_cz==cz_count 

bysort patnum: gen count=_N 
* If for example the same number of 
drop if count!=cz_count

duplicates drop patnum, force 
collapse (count) patnum, by(CZ_depagri_1990 assignee_id app_year)
rename patnum patents_cz3 
label var patents_cz3 "Patents, Option 3  CZ"

save "${TEMP}/patentcount_cz.dta", replace 


********************************************************************************
* Generate Number of Inventors on CZ level 
********************************************************************************


use patnum citation_count withdrawn date_filing date_grant app_year ///
	inventor_id first_name last_name male location_id state_fips_inventor county_fips_inventor ///
	assignee_id state_fips_assignee county_fips_assignee  ///
	using "$PATENTDTA\inventor_applications.dta", clear
	
	
drop if withdrawn==1 
drop withdrawn

*-Drop if missings in important variables
drop if app_year == .
drop if county_fips_inventor == .

* First step: Number of patents the firm records in a county and a state

*-Drop duplicates (we only want to count inventors once per recorded patent)
duplicates drop patnum inventor_id county_fips_inventor assignee_id, force 
* (132 observations deleted)	
duplicates drop patnum inventor_id assignee_id, force 

rename county_fips_inventor county_fips

* Merging in the Commuting Zone level data 
merge m:1 county_fips using "$IN\var_CommutingZones\CZ_combined.dta"
drop if _merge!=3  
drop _merge	

drop CZ_depagri_2000 CZ_UScensus county_name_depagri CZ_depagri_1980

*3 Assign Patent to the Commuting Zone where the most inventors are located
bysort inventor_id CZ_depagri_1990 app_year: gen cz_count=_N 
bysort inventor_id app_year: egen max_cz=max(cz_count)
keep if max_cz==cz_count 

bysort inventor_id app_year: gen count=_N 
* If for example the same number of 
drop if count!=cz_count
* unique inventor_id is  1634916

duplicates drop inventor_id, force 
gen helper=1
collapse (sum) helper, by(CZ_depagri_1990 assignee_id app_year)
rename helper inventors_cz3 
label var inventors_cz3 "Inventors, Option 3 CZ"

save "${TEMP}/inventorcount_cz.dta", replace 


********************************************************************************
* Merge the data together, only keep commuting zones which do not span multiple states
********************************************************************************

use "${TEMP}/patentcount_cz.dta", clear 
merge 1:1 CZ_depagri_1990 assignee_id app_year using "${TEMP}/inventorcount_cz.dta"
drop _merge 

* To Do Why is there such a large number of mismatches between Commuting Zone and Patents? For states this is not the case 
rename CZ_depagri_1990 czone 

* Merge Commuting Zones to States following Dorn Data 
merge m:1 czone using "${IN}/var_CommutingZones/cw_czone_state.dta"
* One Commuting Zone not matched, should be okay 
keep if _merge==3 
drop _merge 

rename app_year year 
rename statefip fips_state 

merge m:1 fips_state assignee_id year using "${TEMP}/final_state.dta", keepusing(rd_credit total_rd_credit multistatefirm_temp multistatefirm_max pit cit gdp unemployment total_pit total_cit total_gdp total_unemployment)
keep if _merge==3 
drop _merge 

/*   Result                      Number of obs
    -----------------------------------------
    Not matched                       247,689
        from master                    58,459  (_merge==1)
        from using                    189,230  (_merge==2)

    Matched                           873,285  (_merge==3)
    -----------------------------------------
	
* Not merged based on _merge==1, for the years from 2019 onwards; For the others possible explanations: Move across commuting zones could not be assigned anymore, but stayed in the same state  
*/ 

* Generate weights for the explaining variable
gen n_inventors_multiple = inventors_cz3 if multistatefirm_temp==1
replace n_inventors_multiple=0 if multistatefirm_temp==0

gen n_patents_multiple=patents_cz3 if multistatefirm_temp==1
replace n_patents_multiple=0 if multistatefirm_temp==0


bysort czone year: egen total_inventors_multiple=total(n_inventors_multiple)
bysort czone year: egen total_patents_multiple=total(n_patents_multiple)

gen weight_inventors = n_inventors_multiple/total_inventors_multiple
gen weight_patents = n_patents_multiple/total_patents_multiple 

foreach var of varlist rd_credit pit cit gdp unemployment {

gen `var'_helper_w1 = weight_inventors * total_`var'
gen `var'_helper_w2 = weight_patents * total_`var'

bysort czone year: egen `var'_other_w1 = total(`var'_helper_w1)
bysort czone year: egen `var'_other_w2 = total(`var'_helper_w2)
}

bysort assignee_id czone year: gen count=_n 
gen tag=1 if count==1 
bysort czone year: egen total_labs=total(tag)


label var rd_credit_other_w1 "R\&D Credit, Other (Inventor-Weighted)"
label var rd_credit_other_w2 "R\&D Credit, Other (Patent-Weighted)"

save "${TEMP}/final_cz.dta", replace 




