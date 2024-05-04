////////////////////////////////////////////////////////////////////////////////
// Project:        	Moving innovation
// Creation Date:  	06/12/2023
// Last Update:    	24/04/2024
// Authors:         Laura Arnemann
//					Theresa Bührle
// Goal: 			Establishment-specific other variable 
////////////////////////////////////////////////////////////////////////////////


* Generating the Helper data set 

use "${TEMP}/patentcount_state.dta", clear 
merge 1:1 fips_state assignee_id app_year using "${TEMP}/inventorcount_state.dta"
drop if _merge==2 // locations with inventors where we do not assign patents
drop _merge 
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

save "${TEMP}/helper_dataset.dta", replace 

use "${TEMP}/helper_dataset.dta", clear 
rename app_year min_year_estab 
tempfile helper1 
save `helper1'


* Prepare the RD credit data 
use "${IN}/indep_var/var_RDcredits/RD_credits_final.dta", clear 
rename fips_state other_fips_state 
tempfile rdcredit 
save `rdcredit'

* Prepare Inventor Data to merge later on
use "${TEMP}/inventorcount_state.dta"
rename fips_state other_fips_state 
rename app_year year 
tempfile inventors 
save `inventors'

* Prepare Patent Data to merge later on 
use "${TEMP}/patentcount_state.dta"
rename fips_state other_fips_state 
rename app_year year 
tempfile patents
save `patents'


/*
* Merging based on whether there was RD activity in the state when the establishment was first active 
use "${TEMP}/patentcount_state.dta", clear 
merge 1:1 fips_state assignee_id app_year using "${TEMP}/inventorcount_state.dta"
drop if _merge==2 // locations with inventors where we do not assign patents
drop _merge 
drop if missing(assignee_id)

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

merge m:1 other_fips_state year using `rdcredit'
drop if _merge ==3 
drop _merge 


bysort assignee_id year fips_state: gen nstates =_N 
bysort assignee_id year fips_state: egen total_credits = total(rd_credit)

gen other_first = total_credits/nstates 
label var other_first "RD Credits, first locations"

keep if count==1

keep fips_state assignee_id year other_first 
save "${TEMP}/other_first.dta", replace 

*/
********************************************************************************
* RD Credit at other locations based on presence during the time period in which we  
* observe patenting activity at this establishment
********************************************************************************

use "${TEMP}/patentcount_state.dta", clear 
merge 1:1 fips_state assignee_id app_year using "${TEMP}/inventorcount_state.dta"
drop if _merge==2 // locations with inventors where we do not assign patents
drop _merge 


bysort fips_state assignee_id: egen min_year_estab = min(app_year)
bysort fips_state assignee_id: egen max_year_estab = max(app_year)

keep fips_state assignee_id min_year_estab max_year_estab 
duplicates drop 
expand 51 

bysort assignee_id fips_state: gen count_obs = _n
gen app_year = 1969+count_obs

keep if inrange(app_year, min_year_estab, max_year_estab)

merge m:1 assignee_id app_year using "${TEMP}/helper_dataset.dta"
keep if _merge ==3 
drop _merge 

gen states_total = states_present if app_year == min_year_estab 

bysort assignee_id fips_state (app_year): replace states_total = states_total[_n-1] + new_states
split states_present, parse(,) generate(other_fips_state)
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

reshape long max_fips_state, i(id) j(count)
drop if missing(max_fips_state)

rename max_fips_state other_fips_state 

merge m:1 other_fips_state year using `rdcredit'
drop if _merge ==3 
drop _merge 

merge m:1 other_fips_state assignee_id year using `patents'
drop if _merge==3 
drop _merge 


merge m:1 other_fips_state assignee_id year using `inventors'
drop if _merge==3 
drop _merge 

* Save as a tempfile to use later on
tempfile estabs
save `estabs'

* Generate the different variables weighted by the patenters respective inventors 
bysort assignee_id year fips_state: gen nstates =_N 
bysort assignee_id year fips_state: egen total_credits = total(rd_credit)

bysort assignee_id fips_state other_fips_state: gen other_patents = total(patents3) 
bysort assignee_id fips_state: gen sum_other_patents = total(other_patents)

bysort assignee_id fips_state other_fips_state: gen other_inventors = total(inventors3) 
bysort assignee_id fips_state: gen sum_other_inventors = total(other_inventors)

gen weight_patents = other_patents/sum_other_patents 
gen rd_credit_weighted1 = weight_patents * rd_credit 

gen weight_inventors = other_inventors/sum_other_inventors 
gen rd_credit_weighted2 = weight_inventors * rd_credit 

bysort assignee_id year fips_state: egen total_credits_weighted1 = total(rd_credit_weighted1)
bysort assignee_id year fips_state: egen total_credits_weighted2 = total(rd_credit_weighted2)

gen other_all = total_credits/nstates 
label var other_all "RD Credits, all locations"

gen other_weighted1 = total_credits_weighted1/nstates 
label var other_weighted1 "RD Credit, weighted by patents" 

gen other_weighted2 = total_credits_weighted2/nstates 
label var other_weighted1 "RD Credit, weighted by Inventors" 

duplicates drop fips_state assignee_id year

keep fips_state assignee_id year other_all other_weighted1 other_weighted2 
save "${TEMP}/other_all.dta", replace 


********************************************************************************
* RD Credit at other locations based on presence during the time period in which we  
* observe patenting activity at this establishment, only three largest estabs
********************************************************************************

use `estabs'

bysort assignee_id fips_state other_fips_state: gen other_patents = total(patents3) 
bysort assignee_id fips_state: gen sum_other_patents = total(other_patents)
gen weight_patents = other_patents/sum_other_patents

replace weight_patents = . if year!=min_year_estab 

* Keep the observations with the largest weights 
bysort assignee_id fips_state year: egen rank = rank(weight_patents)
replace weight_patents = . if year!=min_year_estab 

bysort assignee_id fips_state other_fips_state: egen max_rank = max(rank)
keep if max_rank<=3 

bysort assignee_id year fips_state: egen total_credits = total(rd_credit)
bysort assignee_id year fips_state: gen nstates =_N 

gen other_threelargest = total_credits/ nstates 
label var other_threelargest "Changes in three largest locations"

save "${TEMP}/other_threelargest.dta", replace 









