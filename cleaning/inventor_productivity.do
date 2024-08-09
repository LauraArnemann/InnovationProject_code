// Project: Inventor Relocation
// Creation Date: 05/08/2024
// Last Update: 05/08/2024
// Author: Laura Arnemann 
// Goal: Generating a measure of inventor productivity

********************************************************************************
* Inventor Productivity on State Level 
********************************************************************************
* Generating the helper file
use "${TEMP}/new_dataset3.dta", clear 
duplicates drop state_fips_inventor assignee_id inventor_id, force
keep state_fips_inventor assignee_id inventor_id
drop if state_fips_inventor == . 

expand 51 
bysort state_fips_inventor assignee_id inventor_id: gen count_obs = _n
gen app_year = 1969+count_obs
save "${TEMP}/helper_$dataset.dta", replace 



********************************************************************************
* Inventor Productivity on State Level 
********************************************************************************

use "${TEMP}/new_dataset3.dta", clear 
* Drop if missings in important variables
drop if missing(app_year)
drop if missing(assignee_id)
drop if missing(state_fips_inventor)
drop if missing(county_fips_inventor)

* Drop duplicates (we only want to count inventors once per recorded patent)
duplicates drop patnum inventor_id county_fips_inventor assignee_id, force
	// 132 observations deleted
duplicates report patnum inventor_id assignee_id // differences in geocoding (missings or two different locations recorded); 190 cases
* Drop all patents for which two locations were reported
duplicates tag patnum inventor_id assignee_id, gen(dup) 
drop if dup!=0
drop dup

* Patent count by inventor - assignee - state - year
collapse (count) n_patents=patnum, by(inventor_id assignee_id state_fips_inventor app_year disambig_assignee_organization)

* Drop all inventors working in 3 or more firms and working in 3 or more states 
bysort inventor_id app_year: gen count=_N
drop if count>=3 	// 148,111 observations deleted
drop count 

save "${TEMP}/inventor_helper_$dataset_assignee.dta", replace 

********************************************************************************
* Merging the data set 
********************************************************************************


use "${TEMP}/inventor_helper_$dataset_assignee.dta", replace 

do "${CODE}/cleaning/02_03_cleaning_gov_uni.do"
   *gen pub_assg = 0 
   *replace pub_assg=1 if !missing(gvkey)

   gen noncorp_asg = 0 
   replace noncorp_asg =1 if asg_hospital ==1 | asg_institute==1 | asg_gov==1 

 * Generating indicator variables for the sample restrictions 
bysort inventor_id app_year: gen count_pats=_N 
bysort inventor_id app_year state_fips_inventor: gen count_state=_N
gen byte sample1 = count_state==count_pats

bysort inventor_id app_year: egen max_patents=max(n_patents)
gen byte sample2 = max_patents==n_patents 
bysort inventor_id app_year: gen count=_N 
replace sample2 = 0 if count>=2 
drop count 

* Merging in the helper dataset to also observe inventors in years without patenting activity
merge m:1 state_fips_inventor assignee_id inventor_id app_year using "${TEMP}/helper_$dataset.dta"
drop if _merge ==1 
bysort state_fips_inventor assignee_id inventor_id: egen max_merge=max(_merge)
	
*sum n_patents if max_merge!=3	// obs without any patents!
keep if max_merge==3

bysort state_fips_inventor assignee_id inventor_id _merge: egen max_helper = max(app_year)
bysort state_fips_inventor assignee_id inventor_id _merge: egen min_helper = min(app_year)
replace max_helper = . if _merge==2
replace min_helper = . if _merge==2

bysort state_fips_inventor assignee_id inventor_id: egen max_year = max(max_helper)
bysort state_fips_inventor assignee_id inventor_id: egen min_year = min(min_helper)
	
keep if inrange(app_year, min_year, max_year)

replace n_patents = 0 if _merge ==2 
drop _merge 

* Merging in variation at other states 
rename state_fips_inventor fips_state 
rename app_year year 

merge m:1 fips_state year assignee_id using "${TEMP}/final_state_zeros_new_${dataset}_assignee.dta", keepusing(other*)
keep if _merge ==3
drop _merge 

keep other* assignee_id inventor_id n_patents year sample1 sample2 asg_corp noncorp_asg fips_state 

save "${TEMP}/inventor_productivity_state.dta", replace 
/*
********************************************************************************
* Inventor Productivity on Commuting Zone Level 
********************************************************************************
*  Balanced panel from 1970 - 2020

use inventor_id county_fips_inventor state_fips_inventor assignee_id using "${TEMP}/new_dataset3.dta", clear 

drop if missing(assignee_id)
drop if missing(state_fips_inventor)
drop if missing(county_fips_inventor)

* Cleaning the Fips County Codes 
tostring county_fips_inventor, replace 
tostring state_fips_inventor, replace 
replace county_fips_inventor = "0" + county_fips_inventor if strlen(county_fips_inventor)==2
replace county_fips_inventor = "00" + county_fips_inventor if strlen(county_fips_inventor)==1
replace county_fips_inventor = state_fips_inventor + county_fips_inventor 
destring county_fips_inventor, replace 

replace county_fips_inventor = 8013 if county_fips_inventor == 8014 
rename county_fips_inventor county_fips
rename state_fips_inventor fips_state

* Merging in the Commuting Zone level data 
    merge m:1 county_fips using "$IN/var_CommutingZones/CZ_combined.dta"
    drop if _merge!=3  
    drop _merge	
	
	drop CZ_depagri_2000 CZ_UScensus county_name_depagri CZ_depagri_1980
	rename CZ_depagri_1990 czone
	
	duplicates drop fips_state czone assignee_id inventor_id, force
	drop if missing(czone)

	expand 51 
	bysort fips_state czone assignee_id inventor_id: gen count_obs = _n
	gen app_year = 1969+count_obs

save "${TEMP}/helper_${dataset}.dta", replace 

********************************************************************************
* Creating Inventor Count on CZ level 
*********************************************************************************

    use "${TEMP}/new_dataset3.dta", clear 

	* Drop if missings in important variables
	drop if missing(app_year)
	drop if missing(county_fips_inventor)
	drop if missing(assignee_id)
	
	* Cleaning the Fips County Codes 
      tostring county_fips_inventor, replace 
      tostring state_fips_inventor, replace 
      replace county_fips_inventor = "0" + county_fips_inventor if strlen(county_fips_inventor)==2
      replace county_fips_inventor = "00" + county_fips_inventor if strlen(county_fips_inventor)==1
      replace county_fips_inventor = state_fips_inventor + county_fips_inventor 
      destring county_fips_inventor, replace force
	  replace county_fips_inventor = 8013 if county_fips_inventor == 8014 
	
	rename county_fips_inventor county_fips
	rename state_fips_inventor fips_state

* Merging in the Commuting Zone level data 
    merge m:1 county_fips using "$IN/var_CommutingZones/CZ_combined.dta"
    drop if _merge!=3  
    drop _merge	
	
    drop CZ_depagri_2000 CZ_UScensus county_name_depagri CZ_depagri_1980
    rename CZ_depagri_1990 czone 
	
	
* Drop duplicates (we only want to count inventors once per recorded patent)
   duplicates tag patnum inventor_id fips_state czone assignee_id, gen(dup)
   drop if dup!=0 
   drop dup	// 132 observations deleted
   duplicates report patnum inventor_id assignee_id // differences in geocoding (missings or two different locations recorded); 190 cases
   duplicates tag patnum inventor_id assignee_id, gen(dup) 
   drop if dup!=0
   drop dup
* Patent count by inventor - assignee - state - year
   collapse (count) n_patents=patnum, by(inventor_id assignee_id fips_state czone app_year)

* Drop all inventors working in 3 or more firms and working in 3 or more czones
   bysort inventor_id app_year: gen pat_count=_N
   drop if pat_count>=3 
   drop pat_count 

save "${TEMP}/inventor_helper_${dataset}_czone.dta", replace 




 use "${TEMP}/inventor_helper_${dataset}_czone.dta", clear 

* Generate sample restriction equal to inventors1 
bysort inventor_id app_year: gen count_pats=_N 
bysort inventor_id app_year fips_state czone: gen count_state=_N
gen byte sample1 = count_state==count_pats
drop count_state count_pats

duplicates tag inventor_id fips_state czone assignee_id app_year, gen(dup)
replace sample1= .  if dup!=0
drop dup

* Generate sample restriction equal to inventors3 
bysort inventor_id app_year: egen max_patents=max(n_patents)
gen byte sample2 =  max_patents==n_patents 

bysort inventor_id app_year: gen inv_count=_N 
replace sample2 = . if inv_count>=2 
drop inv_count 

merge m:1 fips_state czone assignee_id inventor_id app_year using "${TEMP}/helper_${dataset}.dta"
drop if _merge==1 // Observations from year 2021
bysort fips_state czone assignee_id inventor_id: egen max_merge=max(_merge)
	
keep if max_merge==3 
			
* Keep inventor obs between first and last patent 
bysort fips_state czone assignee_id inventor_id _merge: egen max_helper = max(app_year)
bysort fips_state czone assignee_id inventor_id _merge: egen min_helper = min(app_year)
replace max_helper = . if _merge==2
replace min_helper = . if _merge==2

bysort fips_state czone assignee_id inventor_id: egen max_year = max(max_helper)
bysort fips_state czone assignee_id inventor_id: egen min_year = min(min_helper)

keep if inrange(app_year, min_year, max_year)
replace n_patents = 0 if _merge ==2 

* Drop all observations which cannot unqiuely be assigned to a state in a given year
duplicates tag inventor_id app_year, gen(dup)
replace sample1 = .  if dup>0
replace sample2 =. if dup>0
drop dup 
drop _merge 

rename app_year year 
destring fips_state, replace 
* Merging in variation from other states: 
merge m:1 fips_state year assignee_id czone using "${TEMP}/final_cz_${dataset}_corp_new_07_08.dta", keepusing(cz_treated* asg_corp)
keep if _merge ==3 
drop _merge 

save "${TEMP}/inventor_productivity_czone.dta", replace 



   
