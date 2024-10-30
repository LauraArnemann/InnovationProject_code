////////////////////////////////////////////////////////////////////////////////
// Project: 		Moving innovation
// Creation Date: 	05/08/2024
// Last Update: 	05/08/2024
// Author: 			Laura Arnemann 
// Goal: 			Generating a measure of inventor productivity
////////////////////////////////////////////////////////////////////////////////


********************************************************************************
* Inventor Productivity on State Level 
********************************************************************************

if $gvkey == 0 {
    use "${TEMP}/inventordata_clean_assignee.dta", clear 
}

if $gvkey == 1 {
    use "${TEMP}/inventordata_clean_gvkey.dta", clear 
}

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
if $gvkey == 0 {
	merge m:1 state_fips_inventor assignee_id inventor_id app_year using "${TEMP}/helper_inventor_assignee.dta"
}

if $gvkey == 1 {
	merge m:1 state_fips_inventor assignee_id inventor_id app_year using "${TEMP}/helper_inventor_gvkey.dta"
}

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

if $gvkey == 0 {
	merge m:1 fips_state year assignee_id using "${TEMP}/final_state_zeros_assignee.dta"
}

if $gvkey == 1 {
	merge m:1 fips_state year assignee_id using "${TEMP}/final_state_zeros_gvkey.dta"
}

keep if _merge ==3
drop _merge 

keep other* assignee_id inventor_id n_patents year sample1 sample2 pub_assg noncorp_asg fips_state 

if $gvkey == 0 {
    save "${TEMP}/inventor_productivity_state_assignee.dta", replace 
}

if $gvkey == 1 {
    save "${TEMP}/inventor_productivity_state_gvkey.dta", replace 
}


********************************************************************************
* Inventor Productivity on Commuting Zone Level 
********************************************************************************

if $gvkey == 0 {
    use "${TEMP}/inventordata_clean_cz_assignee.dta", clear 
}

if $gvkey == 1 {
    use "${TEMP}/inventordata_clean_cz_gvkey.dta", clear 
}

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

if $gvkey == 0 {
    merge m:1 fips_state czone assignee_id inventor_id app_year using "${TEMP}/helper_inventor_cz_assignee.dta"
}

if $gvkey == 1 {
    merge m:1 fips_state czone assignee_id inventor_id app_year using "${TEMP}/helper_inventor_cz_gvkey.dta"
}

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
if $gvkey == 0 {
	merge m:1 fips_state year assignee_id czone  using "${TEMP}/final_cz_corp_assignee.dta", keepusing(cz_treated* asg_corp)
}

if $gvkey == 1 {
	merge m:1 fips_state year assignee_id czone  using "${TEMP}/final_cz_corp_gvkey.dta", keepusing(cz_treated* asg_corp)
}

keep if _merge ==3 
drop _merge 

if $gvkey == 0 {
    save "${TEMP}/inventor_productivity_cz_assignee.dta", replace 
}

if $gvkey == 1 {
    save "${TEMP}/inventor_productivity_cz_gvkey.dta", replace 
}

   
