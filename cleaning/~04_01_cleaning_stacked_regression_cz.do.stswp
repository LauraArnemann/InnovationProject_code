////////////////////////////////////////////////////////////////////////////////
// Project:        	Moving innovation
// Creation Date:  	27/11/2024
// Last Update:    	27/11/2024
// Authors:         Laura Arnemann
//					Theresa Bührle
// Goal: 			Creating stacked event studies for changes in the same state, cz level
////////////////////////////////////////////////////////////////////////////////

global lead=4 	// set leads
global lag=4	// set lags

********************************************************************************
* Stacked Regression for tax changes at establishment location
********************************************************************************

local weighting_strategy threelargest

use  "${TEMP}/final_cz_corp_assignee.dta", clear 
drop if missing(assignee_id)

xtset estab_id year 
	
foreach explaining in `weighting_strategy' {
	
	rename change_other_`explaining' change_`explaining'
	// Keep only if at least 1% change
	replace change_`explaining' = 0 if inrange(change_`explaining', -1, 1)
	
	gen byte increase_`explaining' = change_`explaining'>0
	gen byte decrease_`explaining' = change_`explaining'<0
	
	*Year of change
	gen change_`explaining'_year = year if change_`explaining' != 0 & change_`explaining' != .
	
	*Last change
	gen change_`explaining'_lastchange = change_`explaining'_year
	replace change_`explaining'_lastchange = l.change_`explaining'_lastchange if l.change_`explaining'_lastchange != . & change_`explaining'_lastchange == . 
		
	*Next change
	gen change_`explaining'_nextchange = change_`explaining'_year
	
	forvalues f = 1(1)11 {	// no more changes after f = 9, 11 should generate two zeros to be sure
		replace change_`explaining'_nextchange = f`f'.change_`explaining'_nextchange if f`f'.change_`explaining'_nextchange != . & change_`explaining'_nextchange == .
	}
	
	drop if missing(change_`explaining')
}

drop max_year min_year nstates weighted*

compress
save  "${TEMP}/final_cz_stacked_zeros.dta", replace 


********************************************************************************
*Increases	
********************************************************************************

use "${TEMP}/final_cz_stacked_zeros.dta", clear 

foreach explaining in `weighting_strategy' {

	levelsof year if change_`weighting_strategy' > 0 & year>=1992 & change_`weighting_strategy'!=. , local(change)
	di `change'

	levelsof year if change_`weighting_strategy' > 0 & year>=1992 & change_`weighting_strategy'!=. , local(change_final)
	di `change_final'

	foreach v in `change' {
		use  "${TEMP}/final_cz_stacked_zeros.dta", clear 
		local a = `v' - ${lead} 
		local b = `v' + ${lag}
		
		keep if inrange(year, `a', `b')
		 
		cap drop treated helper 
		 
		* Generate an indicator for being treated
		gen treated = 0 
		replace treated = 1 if year == `v' & change_`weighting_strategy' > 0 
		 
		bysort estab_id: egen max_treated = max(treated)
		bysort estab_id: egen max_change = max(change_`weighting_strategy')
		bysort estab_id: egen min_change = min(change_`weighting_strategy')
		
		* Drop all observations which were not treated and experienced a tax change in any other year 
		drop if max_change!=0 & max_treated==0 
		drop if min_change!=0 & max_treated==0 // NEW: We also have to drop controls with decreases!
		 
		* Drop all observations which were not treated and experienced a tax change +/-1 out side event window
		bysort estab_id: egen latest_lastchange = max(change_`weighting_strategy'_lastchange)
		drop if latest_lastchange >= `a' -1 & latest_lastchange <= `b' & max_treated==0 	
				
		bysort estab_id: egen earlist_nextchange = min(change_`weighting_strategy'_nextchange)
		drop if earlist_nextchange <= `b' + 1 & earlist_nextchange >= `a' & max_treated==0 		
				
		drop latest_lastchange earlist_nextchange
		 
		* Drop treated units if they experienced a tax change four years prior to the reform
		generate helper = 0 
		replace helper = 1 if change_`weighting_strategy'!=0 & change_`weighting_strategy'!=. & year>=`a' & year<`v'
		bysort estab_id: egen max_helper = max(helper)
		drop if max_helper ==1 
		drop helper max_helper
		
		* Drop treated units if they experienced a reversal of the tax change in the the periods following the initial tax change 
		gen taxreversal = 0 
		replace taxreversal = 1 if max_treated==1 & min_change < 0 
		bysort estab_id: egen max_taxreversal = max(taxreversal)
		drop if max_taxreversal==1 
		drop max_taxreversal taxreversal 
		
		* Generate a variable that indicates that the observed change was the first in a series of tax changes 
		gen indicator = 1 if change_`weighting_strategy'!=0  & change_`weighting_strategy'!= .
		bysort estab_id : egen total_change = total(indicator)
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
	
	keep fips_state czone estab_id year assignee_id treated max_treated max_change min_change multiple_events ry_increase event 
	compress
	save "${TEMP}/final_cz_stacked_`weighting_strategy'_incr.dta", replace 
}



********************************************************************************
*Decreases
********************************************************************************

use "${TEMP}/final_cz_stacked_zeros.dta", clear 

foreach weighting_strategy in `weighting_strategy' {

	levelsof year if change_`weighting_strategy' < 0 & year>=1992 & change_`weighting_strategy'!=. , local(change)
	di `change'

	levelsof year if change_`weighting_strategy' < 0 & year>=1992 & change_`weighting_strategy'!=. , local(change_final)
	di `change_final'
	
	
	foreach v in `change' {
		use  "${TEMP}/final_cz_stacked_zeros.dta", clear 
		local a = `v' - ${lead} 
		local b = `v' + ${lag}
		
		keep if inrange(year, `a', `b')
		 
		cap drop treated helper  
		 
		* Generate an indicator for being treated
		gen treated = 0 
		replace treated = 1 if year == `v' & change_`weighting_strategy' < 0 
		 
		bysort estab_id: egen max_treated = max(treated)
		bysort estab_id: egen max_change = max(change_`weighting_strategy')
		bysort estab_id: egen min_change = min(change_`weighting_strategy')
		
		* Drop all observations which were not treated and experienced a tax change in any other year 
		drop if max_change!=0 & max_treated==0 
		drop if min_change!=0 & max_treated==0 // NEW: We also have to drop controls with decreases!
		 
		* Drop treated units if they experienced a tax change four years prior to the reform
		generate helper = 0 
		replace helper = 1 if change_`weighting_strategy'!=0 & change_`weighting_strategy'!=. & year>=`a' & year<`v'
		bysort estab_id: egen max_helper = max(helper)
		drop if max_helper ==1 
		drop helper max_helper
		
		* Drop treated units if they experienced a reversal of the tax change in the the periods following the initial tax change 
		gen taxreversal = 0 
		replace taxreversal = 1 if max_treated==1 & max_change > 0 
		bysort estab_id: egen max_taxreversal = max(taxreversal)
		drop if max_taxreversal==1 
		drop max_taxreversal taxreversal 
		
		* Generate a variable that indicates that the observed change was the first in a series of tax changes 
		gen indicator = 1 if change_`weighting_strategy'!=0 & change_`weighting_strategy'!=.
		bysort estab_id : egen total_change = total(indicator)
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
	
	keep fips_state czone estab_id year assignee_id treated max_treated max_change min_change multiple_events ry_decrease event 
	compress
	save "${TEMP}/final_cz_stacked_`weighting_strategy'_decr.dta", replace 
}	 


