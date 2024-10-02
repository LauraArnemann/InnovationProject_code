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
*Usually numlist 0 1 3 
foreach num of numlist 3 {
	
if `num' == 0 {
use "${TEMP}/patentcount_state.dta", clear 
}

if `num' == 1 {
	use "${TEMP}/patents1_$dataset.dta", clear 
}


if `num' == 3 {
	use "${TEMP}/patents3_$dataset.dta", clear 
}


bysort fips_state assignee_id: egen min_year_estab = min(app_year)
bysort fips_state assignee_id: egen max_year_estab = max(app_year)

* Only keep establishment were we observe at least 5 patents 
bysort fips_state assignee_id: egen total_patents = total(patents3)
keep if total_patents>=5  


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

sum count, detail 
local b =`r(max)'
di `b'

reshape wide fips_state new, i(id) j(count)

gen states_present=""
gen new_states=""

forvalues i =1/`b' {
	replace states_present = states_present + "," + fips_state`i' if fips_state`i'!="" 
	replace new_states = new_states + "," + fips_state`i' if new`i' ==1 & fips_state`i'!="" 	
}

keep assignee_id app_year states_present new_states 
save "${TEMP}/helper_dataset`num'_$dataset.dta", replace 



********************************************************************************
* First Location in which we observe R&D activity 
********************************************************************************

* Merging based on whether there was RD activity in the state when the establishment was first active 


use "${TEMP}/helper_dataset`num'_$dataset.dta", clear 
rename app_year min_year_estab 
tempfile helper1 
save `helper1'


if `num' == 0 {
	use "${TEMP}/patentcount_state_$dataset.dta", clear 
}

if `num' == 1 {
  use "${TEMP}/patents1_$dataset.dta", clear
 
}


if `num' == 3 {
  use "${TEMP}/patents3_$dataset.dta", clear 
}




/* Only keep multi state firms 
bysort assignee_id app_year: gen count =_N 
bysort assignee_id: egen max_count = max(count)

keep if max_count>1 
drop max_count count */

bysort fips_state assignee_id: egen min_year_estab = min(app_year)
bysort fips_state assignee_id: egen max_year_estab = max(app_year)


bysort fips_state assignee_id: egen total_patents = total(patents3)
keep if total_patents>=5  


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
egen id = group(fips_state assignee_id app_year)

reshape long other_fips_state, i(id) j(count)
drop if missing(other_fips_state)
destring other_fips_state, replace 

drop if fips_state==other_fips_state

merge m:1 other_fips_state app_year using  "${TEMP}/state_data_cleaned.dta", keepusing(rd_credit unemployment cit pit gdp)
keep if _merge ==3 
drop _merge

bysort assignee_id app_year fips_state: gen nstates =_N 

foreach var of varlist rd_credit unemployment cit pit gdp {
	
bysort assignee_id app_year fips_state: egen total_`var' = total(`var')
gen other_`var'_first = total_`var'/nstates

} 

label var other_rd_credit_first"RD Credits, first locations"
label var other_pit_first "PIT, first locations"
label var other_cit_first "CIT, first locations"
label var other_gdp_first "GDP, first locations"
label var other_unemployment_first "Unemployment, first locations"

drop count
bysort fips_state assignee_id app_year: gen count = _n 
keep if count==1 

keep fips_state assignee_id app_year other*
rename app_year year 
save "${TEMP}/other_first`num'_${dataset}_gvkey.dta", replace 




********************************************************************************
* RD Credit at other locations based on presence during the time period in which we  
* observe patenting activity at this establishment; 
/* Note: At the moment this does not account for the different ways in which the
outcome variables were constructed. (E.g. difference in patents1 and patents3)
might address this in a robustness check   */
********************************************************************************


if `num' == 0 {
	use "${TEMP}/patentcount_state_$dataset.dta", clear 
	rename fips_state other_fips_state
	tempfile patents
	save `patents'
}

if `num' == 1 {
  use "${TEMP}/patents1_$dataset.dta", clear
  rename fips_state other_fips_state
  tempfile patents
  save `patents'
}


if `num' == 3 {
  use "${TEMP}/patents3_$dataset.dta", clear 
  rename fips_state other_fips_state
  tempfile patents
  save `patents'
}



if `num' == 0 {
	use "${TEMP}/patentcount_state_$dataset.dta", clear 
}

if `num' == 1 {
  use "${TEMP}/patents1_$dataset.dta", clear 
}


if `num' == 3 {
  use "${TEMP}/patents3_$dataset.dta", clear 
}



* Only keep multi state firms 
bysort assignee_id app_year: gen count =_N 
bysort assignee_id: egen max_count = max(count)

bysort fips_state assignee_id: egen total_patents = total(patents3)
keep if total_patents>=5  

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

merge m:1 assignee_id app_year using "${TEMP}/helper_dataset`num'_$dataset.dta"
keep if _merge ==3 
drop _merge 

/*
bysort assignee_id app_year fips_state: gen count=_N
sum count, detail

local b = `r(max)' +1
drop count 
*/
gen states_total = states_present if app_year == min_year_estab 

bysort assignee_id fips_state (app_year): replace states_total = states_total[_n-1] + new_states if app_year!=min_year_estab
split states_total, parse(,) generate(other_fips_state)
drop other_fips_state1 

foreach var of varlist other_fips_state* {
   replace `var' ="" if app_year!=max_year_estab 
   destring `var', replace 
   
   bysort fips_state assignee_id: egen max_`var' = max(`var')
}
  

egen id = group(fips_state assignee_id app_year)

gen count = _n
drop other_fips_state*

save "${TEMP}/helper_other_v`num'_$dataset.dta", replace 


	
use "${TEMP}/helper_other_v`num'_$dataset.dta", clear 

drop count
reshape long max_other_fips_state, i(id) j(count)
drop if missing(max_other_fips_state)
drop if fips_state==max_other_fips_state

rename max_other_fips_state other_fips_state 

merge m:1 other_fips_state app_year using "${TEMP}/state_data_cleaned.dta", keepusing(rd_credit gdp cit pit unemployment)
drop if _merge!=3 
drop _merge 

merge m:1 other_fips_state assignee_id app_year using `patents'
drop if _merge==2
drop _merge 


/*
merge m:1 other_fips_state assignee_id year using `inventors', keepusing(n_inventors3)
drop if _merge==2 
drop _merge 
*/
rename app_year year

save "${TEMP}/helper_other_cleaned`num'_${dataset}.dta", replace 


* Generate the different variables weighted by the patenters respective inventors 
foreach var of varlist rd_credit gdp cit pit unemployment {
	bysort assignee_id year fips_state: egen total_`var' = total(`var')
}

if `num' == 0 {
	bysort assignee_id fips_state other_fips_state: egen other_patents = total(patents3) 
}

if `num'== 1 {
	bysort assignee_id fips_state other_fips_state: egen other_patents = total(patents1) 
}

if `num' == 3 {
	bysort assignee_id fips_state other_fips_state: egen other_patents = total(patents3) 
}

* Generate the different variables weighted by the patenters respective inventors 
bysort assignee_id year fips_state: gen nstates =_N 
bysort assignee_id fips_state year: egen sum_other_patents = total(other_patents)

*bysort assignee_id fips_state other_fips_state: egen other_inventors = total(n_inventors3) 
*bysort assignee_id fips_state: egen sum_other_inventors = total(other_inventors)

gen weight_patents = other_patents/sum_other_patents

foreach var of varlist rd_credit gdp cit pit unemployment {
gen `var'_weighted = weight_patents * `var'
*gen weight_inventors = other_inventors/sum_other_inventors 
*gen rd_credit_weighted2 = weight_inventors * rd_credit 

bysort assignee_id year fips_state: egen total_`var'_weighted = total(`var'_weighted)
*bysort assignee_id year fips_state: egen total_credits_weighted2 = total(rd_credit_weighted2)

gen other_`var'_all= total_`var'/nstates 
rename total_`var'_weighted other_`var'_weighted 
* Do not need to divide by state since we already weight the observations
}

label var other_rd_credit_all "RD Credits, all locations"
label var other_rd_credit_weighted "RD Credit, weighted by patents" 
label var other_pit_all "PIT, all locations"
label var other_pit_weighted "PIT, weighted by patents" 
label var other_cit_all "CIT, all locations"
label var other_cit_weighted "CIT, weighted by patents" 
label var other_unemployment_all "Unemployment, all locations"
label var other_unemployment_weighted "Unemployment, weighted by patents" 



*gen other_weighted2 = total_credits_weighted2/nstates 
*label var other_weighted1 "RD Credit, weighted by Inventors" 

duplicates drop fips_state assignee_id year, force 


keep fips_state assignee_id year other* 
save "${TEMP}/other_all_`num'_${dataset}_gvkey.dta", replace 




********************************************************************************
* RD Credit at other locations based on presence during the time period in which we  
* observe patenting activity at this establishment, only three largest estabs
********************************************************************************

use "${TEMP}/helper_other_cleaned`num'_$dataset.dta", clear 
duplicates drop fips_state assignee_id year other_fips_state, force
* This should not delete anything
* assignee_id=="10b96cde-e590-4dfb-ba21-127c1c54214e"
* assignee_id =="09a18b39-a0e7-4b18-aa79-2d28ed1bd4ba"
* br if assignee_id=="031b0c9c-b4c2-4322-b3d5-bf23db86d18a" 
drop count_obs count 
drop if missing(assignee_id)

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
drop if rank>=3
drop if missing(rank)
drop if rank>=3 


* For few observations there might be more than 3 observations per assignee, year, state this can be caused if e.g. four other establishments have the same importance 


bysort assignee_id year fips_state: gen nstates =_N 

foreach var of varlist rd_credit gdp cit pit unemployment {
	
bysort assignee_id year fips_state: egen total_`var' = total(`var')
gen other_`var'_threelargest = total_`var'/ nstates

}

label var other_rd_credit_threelargest "RD Credit, three largest locations"
label var other_cit_threelargest "CIT, three largest locations"
label var other_pit_threelargest "PIT, three largest locations"
label var other_gdp_threelargest "GDP, three largest locations"
label var other_unemployment_threelargest "Unemployment, three largest locations"


bysort fips_state assignee_id year: gen count = _n 
keep if count ==1 
save "${TEMP}/other_threelargest_`num'_${dataset}_gvkey.dta", replace 


* Erasing all the helper files I created along the way to keep storage space clean
*erase "${TEMP}/other_all`i'_`num'_$dataset.dta"
erase "${TEMP}/helper_dataset`num'_$dataset.dta"
erase  "${TEMP}/helper_other_v`num'_$dataset.dta"
erase   "${TEMP}/helper_other_cleaned`num'_$dataset.dta"

	}








