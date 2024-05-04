////////////////////////////////////////////////////////////////////////////////
// Project:        	Moving innovation
// Creation Date:  	06/12/2023
// Last Update:    	24/04/2024
// Authors:         Laura Arnemann
//					Theresa Bührle
// Goal: 			Other Variable; Definition I 
////////////////////////////////////////////////////////////////////////////////

use "${TEMP}/patentcount_state.dta", clear 
merge 1:1 fips_state assignee_id app_year using "${TEMP}/inventorcount_state.dta"
drop if _merge==2 // locations with inventors where we do not assign patents
drop _merge 

* Min 10% of overall patenting across all years
bysort assignee_id fips_state: egen patentsum_state = sum(patents3)
bysort assignee_id: egen patentsum_assign = sum(patents3)
gen patenterloc10 = 1 if patentsum_state / patentsum_assign >= 0.1

* Three biggest locations: 
bysort assignee_id fips_state: egen n_inventors3_statemean = mean(-n_inventors3)
sort assignee_id n_inventors3_statemean 

bysort assignee_id (n_inventors3_statemean): gen rank = n_inventors3_statemean != n_inventors3_statemean[_n-1]
by assignee_id: replace rank = sum(rank)
replace rank = . if n_inventors3_statemean == .

*sort assignee_id fips_state app_year
*br assignee_id fips_state app_year n_inventors3_statemean rank_inv

bysort fips_state assignee_id: egen min_year_estab = min(app_year)
bysort fips_state assignee_id: egen max_year_estab = max(app_year)

bysort assignee_id: egen min_year_assignee = min(app_year)
bysort assignee_id: egen max_year_assignee = max(app_year)

keep fips_state assignee_id min_year_estab max_year_estab min_year_assignee max_year_assignee patenterloc10 rank 
duplicates drop, force 
expand 51 

bysort assignee_id fips_state: gen count_obs = _n
gen app_year = 1969+count_obs

keep if inrange(min_year_assignee, max_year_assignee)

rename app_year year 

merge m:1 fips_state app_year using "${IN}/indep_var/var_RDcredits/RD_credits_final.dta"
keep if _merge==3 

* Changes at all locations 
bysort assignee_id app_year: gen n_states = _N 

* First Location 
   gen firstlocation = 1 if min_year_assignee == app_year
   bysort assignee_id fips_state: egen firstlocation_max = max(firstlocation)

   bysort assignee_id app_year: egen nstates_first= count(firstlocation) 

   drop firstlocation

   foreach var of varlist rd_credit pit cit gdp unemployment {
	
    gen `var'_first = `var' if firstlocation_max == 1	// only consider firstlocation states
    bysort assignee_id app_year: egen total_`var'_first=total(`var'_first)
	replace total_`var'_first=(total_`var'_first)/(nstates_first) if firstlocation_max!=1
	replace total_`var'_first=(total_`var'_first -`var'_first)/(nstates_first - 1) if firstlocation_max==1
	replace total_`var'_first=0 if total_`var'_first<0
	label var total_`var'_first "`var', first"
}

* Minimum 10 percent of patents 
gen firstyear_10pat = min_year_assignee
	replace firstyear_10pat = . if  patenterloc10 != 1 
	
bysort assignee_id app_year: egen nstates_10pat= count(patenterloc10) 

foreach var of varlist rd_credit pit cit gdp unemployment {
	
gen `var'_10pat = `var' if patenterloc10 == 1	// only consider states with at least 10% patenting
bysort assignee_id app_year: egen total_`var'_10pat=total(`var'_10pat)
	replace total_`var'_10pat=(total_`var'_10pat -`var'_10pat)/(nstates_10pat-1)
	replace total_`var'_10pat=0 if total_`var'_10pat<0
	label var total_`var'_10pat "`var', 10 Pct"
}

* 3 biggest locations across all years 
// Ideally by employee count, we go by inventors for now
gen firstyear_rank = min_year_estab if rank_inv <=3
gen rank_counter = 1 if rank_inv<=3 & inrange(app_year, min_year_estab, max_year_estab)

bysort assignee_id app_year: egen nstates_rank = count(rank_counter) 

foreach var of varlist rd_credit pit cit gdp unemployment {
	
gen `var'_rank = `var' if rank <= 3	// only consider top 3 states
bysort assignee_id app_year: egen total_`var'_rank=total(`var'_rank)
	replace total_`var'_rank=(total_`var'_rank -`var'_rank)/(nstates_rank-1)
	replace total_`var'_rank=0 if total_`var'_rank<0
	label var total_`var'_rank "`var', rank"
}


save "${TEMP}/total_vars.dta", replace 

