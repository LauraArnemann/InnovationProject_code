/// PROJECT: Spillover Effects 
/// GOAL: Trying to replicate some stats and results from the Moretti Paper 
/// AUTHOR: Laura Arnemann
/// CREATION: 27-12-2022
/// LAST UPDATE: 09-03-2023
/// SOURCE: Raw Data 

use "${TEMP}/inventor_applications.dta", clear 
drop if withdrawn==1 

* Moretti Sample Restrictions to check if we have more or less the same observations
keep if inrange(app_year,1977,2010)

duplicates drop patnum inventor_id, force 
* Where do these duplicates come from? Just deletes 748 observations

* Define destination and origin state for every inventor
* If multiple states observed, mode of state-fips 
bysort inventor_id app_year: egen origin_state = mode(state_fips_inventor)

*Patent share (count) per inventor
bysort patnum: egen number_inv = count(inventor_id)
gen patent_share = 1/number_inv



collapse (mean) origin_state (count) patnum, by(inventor_id app_year)
rename patnum n_patents

bysort inventor_id (app_year): gen ru_sum_pats=sum(n_patents)

/*
drop count

bysort inventor_id app_year: gen helper=_N
* Number of patents an inventor applied for in a year 
bysort inventor_id app_year: gen count=_n 
* Numerate the number of patents within a year 
gen num_pat=helper if count==1 
drop helper 

bysort inventor_id (app_year): gen ru_sum_pats=sum(num_pat)
*/ 


/* Definition of superstar inventors: We define star inventors,
in a given year, as those who are at or above the ninety-fifth percentile in
number of patents over the past ten years.

What does this mean? Are you a superstar inventor once you surpassed this threshold
or does superstar status change once you are not above the 95th percentile anymore? */ 


rangestat (sum) n_patents, by(inventor_id) int(app_year -10 0)
rename n_patents_sum cum_10yrs

/*
gen pat_10yrs=. 
replace pat_10yrs=ru_sum_pats if app_year<=1987

forvalues i=1988/2010 {
	local c=`i'-10
	display `c'
	gen helper = ru_sum_pats if app_year==`c'
	bysort inventor_id: egen max_helper=max(helper)
	replace pat_10yrs = ru_sum_pats - max_helper if app_year==`i'
	drop helper max_helper 
}
*/ 

gen superstar=0 

forvalues i=1987/2010 {
	qui sum cum_10yrs if app_year== `i', detail 
	replace superstar = 1 if cum_10yrs>=r(p95) & cum_10yrs!=. 
}

bysort inventor_id: egen max_superstar=max(superstar)


gen residence_state=. 
bysort inventor_id: replace destination_state=origin_state[_n+1] 
bysort inventor_id: replace destination_state=. if app_year[_n+1]!=app_year+1

gen migration = 0 if destination_state!=. & origin_state!=.
replace migration=1 if origin_state!=destination_state & destination_state!=. & destination_state!=.  

bysort inventor_id: egen number_moves=total(migration)

gen ever_migrated=0 if number_moves==0 
replace ever_migrated=1 if number_moves>0

label var cum_10yrs "Patents over last 10 years"
label var n_patents "Number of Patents"
label var superstar "Indicator for being a Superstar"
label var max_superstar "Ever Superstar"
label var origin_state "State of Origin"
label var residence_state "State of Residence"
label var migration "Residence State differs from Origin State "
label var ever_migrated "Inventor has ever migrated"


save "${OUT}/moretti_sample.dta", replace 
********************************************************************************
* Trying to replicate some of the Summary Statistics 
*******************************************************************************
use "${OUT}/moretti_sample.dta", clear 

sum superstar if superstar==1 
*Moretti Paper has 260.000 superstar x year observations; we have around 361.919 observations 
sum max_superstar if max_superstar==1
 * 751,996 
 
sum superstar if superstar==1 & residence_state!=. & origin_state!=. 
* This is more in the ballpark of the Moretti sample: 280,856 observations

sum max_superstar if max_superstar==1 & residence_state!=. & origin_state!=. 
* 472,159 observations  

sum cum_10yrs if app_year==2006 & superstar==1 , detail
* A lot higher that what they found in the Moretti sample, mean in Moretti 15.7, for us 26.10255

sum cum_10yrs if app_year==2006 & max_superstar==1 , detail

sum n_patents if superstar==1, detail
* 3,5 patents each year, mean inventor has 1.5 patents each year ?  

sum migration if app_year==2006 & superstar==1
* Slightly lower migration rate than in the Moretti sample with 4.54712   percent of superstar migrants; Moretti Paper (6 percent)

sum ever_migrated if superstar==1
* 20 percent of sample migrated 

sum number_moves if superstar==1, detail
* Average: .4185881

sum number_moves if superstar==1 & number_moves>=1, detail
* Mean: 2.00483 , smaller than 2.66 reported in Moretti paper