/// PROJECT: Spillover Effects 
/// GOAL: Trying to replicate some stats and results from the Moretti Paper 
/// AUTHOR: Laura Arnemann, Theresa Bührle
/// CREATION: 11-05-2023
/// LAST UPDATE: 11-05-2023
/// SOURCE: Comets Data

import delimited "${datadir}/comets/patent_inventors_v2.csv", clear 

gen appyear=substr(app_date, 1,4)
destring appyear, replace 
keep if inrange(appyear,1977,2010)
keep if country_code=="US"
* Maximum Jahr 2010

* deletes 4,441,865 observations
* There is no inventor id; check this in the paper is this also the case in that dat set? 

gen fullname=first_name + middle_name + last_name + suffix
unique(fullname appyear)
* Number of unique records, 2869491; upper 5 percent would be 143474
* This requires that the name is always recorded in a similar way 
bysort fullname: gen inventor_count1=_N
bysort fullname: gen inventor_count2=_n
bysort fullname appyear: gen move=1 if state!=state[_n-1] & inventor_count2!=1
bysort fullname appyear: egen total_moves=total(move)

bysort fullname appyear: egen residence_state = mode(state), missing


bysort patent_id: gen number_inventors=_N
gen patent_share = 1/number_inv
* Collapse to get the number of 
collapse (first) residence_state (count) patent_share, by(fullname appyear)

bysort fullname: gen destination_state=residence_state[_n+1] 

rangestat (sum) patent_share, by(fullname) int(appyear -10 0)
rename patent_share_sum cum_10yrs


bysort fullname (appyear): egen sum_pats=total(patent_share)
bysort fullname (appyear): gen count=_n 
gen n_sum_pats = sum_pats if count==1 
bysort fullname: gen cum_sum_pats=sum(n_sum_pats)

forvalues i=1/10 {
	local a=1976 + `i'
replace cum_10yrs=cum_sum_pats/`i' if appyear==`a'
}
*gen mean_10yrs=cum_10yrs/10 

* Generate an indicator for the number of superstar inventors 
gen superstar=0 

forvalues i=1977/2010 {
	local c=`i' - 10
	qui sum cum_10yrs if appyear<=`i' & appyear>=`c' , detail 
	replace superstar = 1 if cum_10yrs>=r(p95) & cum_10yrs!=. & appyear==`i' 
}


gen superstar_alternative=0

forvalues i=1977/2010 {
	local c=`i' - 10
	qui sum patent_share if appyear<=`i' & appyear>=`c' , detail 
	replace superstar_alternative = 1 if patent_share>=r(p95) & cum_10yrs!=. & appyear==`i' 
}

* Auch hier, viel weniger superstar Observationen als Moretti und Wilson, warum das denn? 

/* What did I try:
- I did not drop residence state beforehand, however this does not change results, actually made the number of superstar inventors smaller 
- Use mean over 10 yrs rather than sum; no change 
- Mean of number of patents over the last 10 years; superstars as those above that: makes this better 
- superstars: as inventors whose mean patent number is above the mean number of patents in the last 10 years: Makes this 218,317 
-  */
use "${mw_datadir}/star_migration_rates.dta", clear

egen sumall90=total(outflow90)
*595622
egen sumall95=total(outflow95)
*444101
egen sumall99=total(outflow99)
*170244

* How can this be? 