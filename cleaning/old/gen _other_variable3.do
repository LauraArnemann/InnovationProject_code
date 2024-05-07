////////////////////////////////////////////////////////////////////////////////
// Project:        	Moving innovation
// Creation Date:  	06/12/2023
// Last Update:    	24/04/2024
// Authors:         Laura Arnemann
//					Theresa Bührle
// Goal: 			Establishment-specific other variable 
////////////////////////////////////////////////////////////////////////////////

*set max_memory 80g, permanently
* Generating the Helper data set 
* Generating the other variables over different data sets (there is probably a more efficient way to do this; ATM I am not aware of it)

foreach num of numlist 0 1 3 {

if `num' == 0 {
use "${TEMP}/patentcount_state.dta", clear 
}

if `num' == 1 {
	use "${TEMP}/patents1.dta", clear 
}


if `num' == 3 {
	use "${TEMP}/patents3.dta", clear 
}

drop if missing(assignee_id)

bysort fips_state assignee_id: egen min_year_estab = min(app_year)
bysort fips_state assignee_id: egen max_year_estab = max(app_year)

bysort assignee_id: egen min_year_assignee = min(app_year)
bysort assignee_id: egen max_year_assignee = max(app_year)

keep fips_state assignee_id min_year_estab max_year_estab min_year_assignee max_year_assignee  
duplicates drop
expand 51 

bysort assignee_id fips_state: gen count_obs = _n
gen app_year = 1969+count_obs

keep if inrange(app_year, min_year_estab, max_year_estab)

gen new = 1 if app_year == min_year_estab 

bysort assignee_id app_year: gen count = _n 
egen id = group(assignee_id app_year)
tostring fips_state, replace
drop min_year_estab max_year_estab

reshape wide fips_state new, i(id) j(count)

gen states_present=""
gen new_states=""

forvalues i =1/51 {
	replace states_present = states_present + "," + fips_state`i' if fips_state`i'!="" 
	replace new_states = new_states + "," + fips_state`i' if new`i' ==1 & fips_state`i'!="" 	
}

keep assignee_id app_year states_present new_states 


save "${TEMP}/helper_dataset`num'.dta", replace 


use "${TEMP}/helper_dataset`num'.dta", clear 
rename app_year min_year_estab 
tempfile helper1 
save `helper1'

/*
* Prepare Inventor Data to merge later on
use "${TEMP}/inventorcount_state.dta"
rename fips_state other_fips_state 
rename app_year year 
tempfile inventors 
save `inventors'*/

* Prepare Patent Data to merge later on 
if `num' == 0 {
  use "${TEMP}/patentcount_state.dta", clear 
}

if `num' == 1 {
  use "${TEMP}/patents1.dta", clear 
}

if `num' == 3 {
  use "${TEMP}/patents3.dta", clear 
}

rename fips_state other_fips_state 
rename app_year year 
tempfile patents
save `patents'



* Merging based on whether there was RD activity in the state when the establishment was first active 
if `num' == 0 {
	use "${TEMP}/patentcount_state.dta", clear 
}

if `num' == 1 {
  use "${TEMP}/patents1.dta", clear 
}


if `num' == 3 {
  use "${TEMP}/patents3.dta", clear 
}


drop if missing(assignee_id)


* Only keep multi state firms 
bysort assignee_id app_year: gen count =_N 
bysort assignee_id: egen max_count = max(count)

keep if max_count>1 
drop max_count count 

bysort fips_state assignee_id: egen min_year_estab = min(app_year)
bysort fips_state assignee_id: egen max_year_estab = max(app_year)

keep fips_state assignee_id min_year_estab max_year_estab 
duplicates drop 
expand 51 

bysort assignee_id fips_state: gen count_obs = _n
gen app_year = 1969+count_obs

keep if inrange(app_year, min_year_estab, max_year_estab)

merge m:1 assignee_id min_year_estab using `helper1', keepusing(states_present)
keep if _merge ==3 
drop _merge 

split states_present, parse(,) generate(other_fips_state)
drop other_fips_state1 
* This observation is always empty 
rename app_year year 
egen id = group(fips_state assignee_id year)

reshape long other_fips_state, i(id) j(count)
drop if missing(other_fips_state)
destring other_fips_state, replace 

merge m:1 other_fips_state year using "${TEMP}/state_vars.dta", keepusing(rd_credit cit gdp unemployment pit)
drop if _merge!=3 
drop _merge 

bysort assignee_id year fips_state: gen nstates =_N 
bysort assignee_id year fips_state: egen total_credits = total(rd_credit)

gen other_first = total_credits/nstates 
label var other_first "RD Credits, first locations"

keep if count==1

keep fips_state assignee_id year other_first 
save "${TEMP}/other_first`num'.dta", replace 


********************************************************************************
* RD Credit at other locations based on presence during the time period in which we  
* observe patenting activity at this establishment
********************************************************************************
if `num' == 0 {
	use "${TEMP}/patentcount_state.dta", clear 
}

if `num' == 1 {
  use "${TEMP}/patents1.dta", clear 
}


if `num' == 3 {
  use "${TEMP}/patents3.dta", clear 
}

drop if missing(assignee_id)


* Only keep multi state firms 
bysort assignee_id app_year: gen count =_N 
bysort assignee_id: egen max_count = max(count)

keep if max_count>1 
drop max_count count 

bysort fips_state assignee_id: egen min_year_estab = min(app_year)
bysort fips_state assignee_id: egen max_year_estab = max(app_year)

keep fips_state assignee_id min_year_estab max_year_estab 
duplicates drop 
expand 51 

bysort assignee_id fips_state: gen count_obs = _n
gen app_year = 1969+count_obs

keep if inrange(app_year, min_year_estab, max_year_estab)

merge m:1 assignee_id app_year using "${TEMP}/helper_dataset`num'.dta"
keep if _merge ==3 
drop _merge 

gen states_total = states_present if app_year == min_year_estab 

bysort assignee_id fips_state (app_year): replace states_total = states_total[_n-1] + new_states
split states_total, parse(,) generate(other_fips_state)
drop other_fips_state1 

forvalues i=2/52 {
   replace other_fips_state`i' ="" if app_year!=max_year_estab 
   destring other_fips_state`i', replace 
}

forvalues i =2/52 {
	bysort fips_state assignee_id : egen max_fips_state`i' =max(other_fips_state`i')
}
  
rename app_year year 
egen id = group(fips_state assignee_id year)

gen count = _n
drop other_fips_state*

save "${TEMP}/helper_other_v`num'.dta", replace 

local b = 1 

forvalues i =1/10 {
	
	use  "${TEMP}/helper_other_v`num'.dta", clear 
	local a = `b'
	local b = `i' *100000
	keep if inrange(count, `a', `b')
	save "${TEMP}/helper_other`i'_v`num'.dta", replace 
	
}


forvalues i =1/10 {
	
	use "${TEMP}/helper_other`i'_v`num'.dta", clear 
	drop count
reshape long max_fips_state, i(id) j(count)
drop if missing(max_fips_state)
drop if fips_state==max_fips_state

rename max_fips_state other_fips_state 

merge m:1 other_fips_state year using "${TEMP}/state_vars.dta", keepusing(rd_credit cit gdp unemployment pit)
drop if _merge !=3 
drop _merge 

merge m:1 other_fips_state assignee_id year using `patents'
drop if _merge==2
replace patents3 = 0 if _merge ==1

drop _merge 


/*
merge m:1 other_fips_state assignee_id year using `inventors', keepusing(n_inventors3)
drop if _merge==2 
drop _merge 
*/

save "${TEMP}/helper_other`i'_cleaned`num'.dta", replace 

* Generate the different variables weighted by the patenters respective inventors 
bysort assignee_id year fips_state: gen nstates =_N 
bysort assignee_id year fips_state: egen total_credits = total(rd_credit)

if `patentcount' == 0 {
	bysort assignee_id fips_state other_fips_state: egen other_patents = total(patents3) 
}

if `patentcount'== 1 {
	bysort assignee_id fips_state other_fips_state: egen other_patents = total(patents1) 
}

if `patentcount' == 3 {
	bysort assignee_id fips_state other_fips_state: egen other_patents = total(patents3) 
}

bysort assignee_id fips_state year: egen sum_other_patents = total(other_patents)

*bysort assignee_id fips_state other_fips_state: egen other_inventors = total(n_inventors3) 
*bysort assignee_id fips_state: egen sum_other_inventors = total(other_inventors)

gen weight_patents = other_patents/sum_other_patents 
gen rd_credit_weighted1 = weight_patents * rd_credit 

*gen weight_inventors = other_inventors/sum_other_inventors 
*gen rd_credit_weighted2 = weight_inventors * rd_credit 

bysort assignee_id year fips_state: egen total_credits_weighted1 = total(rd_credit_weighted1)
*bysort assignee_id year fips_state: egen total_credits_weighted2 = total(rd_credit_weighted2)

gen other_all = total_credits/nstates 
label var other_all "RD Credits, all locations"

gen other_weighted1 = total_credits_weighted1/nstates 
label var other_weighted1 "RD Credit, weighted by patents" 

*gen other_weighted2 = total_credits_weighted2/nstates 
*label var other_weighted1 "RD Credit, weighted by Inventors" 

duplicates drop fips_state assignee_id year, force 

keep fips_state assignee_id year other_all other_weighted1 
save "${TEMP}/other_all`i'_`num'.dta", replace 
}


clear 

forvalues i = 1/10 {
	append using "${TEMP}/other_all`i'_`num'.dta"
}

save "${TEMP}/other_all_`num'.dta", replace 

********************************************************************************
* RD Credit at other locations based on presence during the time period in which we  
* observe patenting activity at this establishment, only three largest estabs
********************************************************************************
forvalues i =1/10 {

use "${TEMP}/helper_other`i'_cleaned`num'.dta", clear 
drop count_obs count 


if `num' == 0 {
	bysort assignee_id fips_state other_fips_state: egen other_patents = total(patents3) 
}

if `num'== 1 {
	bysort assignee_id fips_state other_fips_state: egen other_patents = total(patents1) 
}

if `num' == 3 {
	bysort assignee_id fips_state other_fips_state: egen other_patents = total(patents3) 
}

 
bysort assignee_id fips_state year: egen sum_other_patents = total(other_patents)


gen weight_patents = other_patents/sum_other_patents

* Keep the observations with the largest weights 
bysort assignee_id fips_state year: egen rank = rank(-weight_patents)

bysort assignee_id fips_state other_fips_state: egen max_rank = max(rank)
keep if max_rank<=3 

bysort assignee_id year fips_state: egen total_credits = total(rd_credit)
bysort assignee_id year fips_state: gen nstates =_N 

gen other_threelargest = total_credits/ nstates 
label var other_threelargest "Changes in three largest locations"

save "${TEMP}/other_threelargest`i'_`num'.dta", replace 

}

clear 

forvalues i = 1/10 {
	append using "${TEMP}/other_threelargest`i'_`num'.dta"
}

save "${TEMP}/other_threelargest_`num'.dta", replace 

* Erasing all the helper files I created along the way to keep storage space clean

forvalues i = 1/10 {
	
	erase "${TEMP}/other_all`i'_`num'.dta"
	erase "${TEMP}/helper_other`i'_v`num'.dta"
	erase  "${TEMP}/helper_other`i'_cleaned`num'.dta"
	
}


}


