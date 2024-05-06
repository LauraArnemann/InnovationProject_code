////////////////////////////////////////////////////////////////////////////////
// Project:        	Moving innovation
// Creation Date:  	19/03/2024
// Last Update:    	24/04/2024
// Authors:         Laura Arnemann
//					Theresa Bührle
// Goal: 			Creating stacked event studies for changes in the same state
////////////////////////////////////////////////////////////////////////////////

global lead=4 	// set leads
global lag=4	// set lags

********************************************************************************
* Stacked Regression for tax changes at establishment location
********************************************************************************

use  "${TEMP}/final_state_zeros_new.dta", clear 
drop if missing(assignee_id)

egen estab = group(assignee_id fips_state)

xtset estab year 

foreach var in rd_credit  {
	
	*Changes in tax variable
	gen change_`var' = `var' - l.`var'
	// Keep only if at least 1% change
	replace change_`var' = 0 if inrange(change_`var', -1, 1)

	*Year of change
	gen change_`var'_year = year if change_`var' != 0 & change_`var' != .
	
	*Last change
	gen change_`var'_lastchange = change_`var'_year
	replace change_`var'_lastchange = l.change_`var'_lastchange if l.change_`var'_lastchange != . & change_`var'_lastchange == . 
		
	*Next change
	gen change_`var'_nextchange = change_`var'_year
		forvalues f = 1(1)11 {	// no more changes after f = 9, 11 should generate two zeros to be sure
			replace change_`var'_nextchange = f`f'.change_`var'_nextchange if f`f'.change_`var'_nextchange != . & change_`var'_nextchange == . 
		}	
}

// keep only obs with at least two consecutive years
*drop if missing(change_credit)	// let's leave this out for now; also need changes in other main variables

drop if missing(change_rd_credit)

drop max_year min_year nstates multistatefirm_temp multistatefirm_max

compress
save  "${TEMP}/final_state_stacked_zeros.dta", replace 


********************************************************************************
*Increases	
********************************************************************************

use "${TEMP}/final_state_stacked_zeros.dta", clear 

foreach var in "rd_credit" {

	levelsof year if change_`var' > 0 & year>=1992 & change_`var'!=. , local(change)
	di `change'

	levelsof year if change_`var' > 0 & year>=1992 & change_`var'!=. , local(change_final)
	di `change_final'

	foreach v in `change' {
		use  "${TEMP}/final_state_stacked_zeros.dta", clear 
		local a = `v' - ${lead} 
		local b = `v' + ${lag}
		
		keep if inrange(year, `a', `b')
		 
		* Generate an indicator for being treated
		gen treated = 0 
		replace treated = 1 if year == `v' & change_`var' > 0 
		 
		bysort estab: egen max_treated = max(treated)
		bysort estab: egen max_change = max(change_`var')
		bysort estab: egen min_change = min(change_`var')
		
		* Drop all observations which were not treated and experienced a tax change in any other year 
		drop if max_change!=0 & max_treated==0 
		drop if min_change!=0 & max_treated==0 // NEW: We also have to drop controls with decreases!
		 
		* Drop all observations which were not treated and experienced a tax change +/-1 out side event window
		bysort estab: egen latest_lastchange = max(change_`var'_lastchange)
		drop if latest_lastchange >= `a' -1 & latest_lastchange <= `b' & max_treated==0 	
				
		bysort estab: egen earlist_nextchange = min(change_`var'_nextchange)
		drop if earlist_nextchange <= `b' + 1 & earlist_nextchange >= `a' & max_treated==0 		
				
		drop latest_lastchange earlist_nextchange
		 
		* Drop treated units if they experienced a tax change four years prior to the reform
		generate helper = 0 
		replace helper = 1 if change_`var'!=0 & change_`var'!=. & year>=`a' & year<`v'
		bysort estab: egen max_helper = max(helper)
		drop if max_helper ==1 
		drop helper max_helper
		
		* Drop treated units if they experienced a reversal of the tax change in the the periods following the initial tax change 
		gen taxreversal = 0 
		replace taxreversal = 1 if max_treated==1 & min_change < 0 
		bysort estab: egen max_taxreversal = max(taxreversal)
		drop if max_taxreversal==1 
		drop max_taxreversal taxreversal 
		
		* Generate a variable that indicates that the observed change was the first in a series of tax changes 
		gen indicator = 1 if change_`var'!=0  & change_`var'!= .
		bysort estab : egen total_change = total(indicator)
		gen multiple_events = 1 if total_change >1
		drop indicator total_change 
			
		gen ry_increase = year - `v' if max_treated ==1 
		gen event = `v'
		sum event if max_treated==1 
		local count =r(N)
		di `count'
		
		if `count' >0 {
			tempfile stacked_`v'
			save `stacked_`v''
			
		}
		else {
			local not `v'
			local change_final: list change_final - not
			di "`change_final'"
			
		}
	}

	clear 
	foreach v in `change_final' {
		append using `stacked_`v''
	}
	
	keep fips_state estab year assignee_id treated max_treated max_change min_change multiple_events ry_increase event 
	compress
	save "${TEMP}/final_state_stacked_`var'_incr.dta", replace 
}



********************************************************************************
*Decreases
********************************************************************************

use "${TEMP}/final_state_stacked_zeros.dta", clear 

	levelsof year if change_`var' < 0 & year>=1992 & change_`var'!=. , local(change)
	di `change'

	levelsof year if change_`var' < 0 & year>=1992 & change_`var'!=. , local(change_final)
	di `change_final'
	
foreach var in "rd_credit" {
	
	foreach v in `change' {
		use  "${TEMP}/final_state_stacked_zeros.dta", clear 
		local a = `v' - ${lead} 
		local b = `v' + ${lag}
		
		keep if inrange(year, `a', `b')
		 
		* Generate an indicator for being treated
		gen treated = 0 
		replace treated = 1 if year == `v' & change_`var' < 0 
		 
		bysort estab: egen max_treated = max(treated)
		bysort estab: egen max_change = max(change_`var')
		bysort estab: egen min_change = min(change_`var')
		
		* Drop all observations which were not treated and experienced a tax change in any other year 
		drop if max_change!=0 & max_treated==0 
		drop if min_change!=0 & max_treated==0 // NEW: We also have to drop controls with decreases!
		 
		* Drop treated units if they experienced a tax change four years prior to the reform
		generate helper = 0 
		replace helper = 1 if change_`var'!=0 & change_`var'!=. & year>=`a' & year<`v'
		bysort estab: egen max_helper = max(helper)
		drop if max_helper ==1 
		drop helper max_helper
		
		* Drop treated units if they experienced a reversal of the tax change in the the periods following the initial tax change 
		gen taxreversal = 0 
		replace taxreversal = 1 if max_treated==1 & max_change > 0 
		bysort estab: egen max_taxreversal = max(taxreversal)
		drop if max_taxreversal==1 
		drop max_taxreversal taxreversal 
		
		* Generate a variable that indicates that the observed change was the first in a series of tax changes 
		gen indicator = 1 if change_`var'!=0 & change_`var'!=.
		bysort estab : egen total_change = total(indicator)
		gen multiple_events = 1 if total_change >1
		drop indicator total_change 
			
		gen ry_decrease = year - `v' if max_treated ==1 
		gen event = `v'
		sum event if max_treated==1 
		local count =r(N)
		di `count'
		
		if `count' >0 {
			tempfile stacked_`v'
			save `stacked_`v''
			
		}
		else {
			local not `v'
			local change_final: list change_final - not
			di "`change_final'"
			
		}
	}

	clear 
	foreach v in `change_final' {
		append using `stacked_`v''
	}
	
	keep fips_state estab year assignee_id treated max_treated max_change min_change multiple_events ry_decrease event 
	compress
	save "${TEMP}/final_state_stacked_`var'_decr.dta", replace 
}	 


