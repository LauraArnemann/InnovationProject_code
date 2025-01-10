////////////////////////////////////////////////////////////////////////////////
// Project:        	Moving innovation
// Creation Date:  	27/11/2024
// Last Update:    	27/11/2024
// Authors:         Laura Arnemann
//					Theresa Bührle
// Goal: 			Creating stacked event studies for changes in other states, cz level 
////////////////////////////////////////////////////////////////////////////////

global lead=4 	// set leads
global lag=4	// set lags

local weighting_strategy threelargest

********************************************************************************
* Stacked Regression for tax changes at other establishment location
********************************************************************************
	
use "${TEMP}/final_cz_corp_assignee.dta", clear 
drop if missing(assignee_id)

* Only keep multistate firms for all others the values for the other variables will be zero 
merge m:m assignee_id using "${TEMP}/final_state_zeros_assignee.dta", keepusing(multistatefirm_max) nogen keep(3)
duplicates drop

keep if multistatefirm_max==1 

xtset estab_id year 

foreach explaining in `weighting_strategy' {
	
	rename change_other_`explaining' change_`explaining'
	// Keep only if at least 1% change
	replace change_`explaining' = 0 if inrange(change_`explaining', -1, 1)
}

drop max_year min_year nstates weighted* multistatefirm_max

compress	
save  "${TEMP}/final_cz_stacked_other_zeros.dta", replace 


********************************************************************************
* Increases 
********************************************************************************

foreach explaining in `weighting_strategy'  {
		
	use "${TEMP}/final_cz_stacked_other_zeros.dta", clear 
	    levelsof year if year>= 1992 & year<=2018, local(years_final)
		di `years_final'	

		forvalues i = 1992/2018 { 
			use  "${TEMP}/final_cz_stacked_other_zeros.dta", clear
			
			* We want to have values without any tax changes 9 years before and 9 years after the tax change 
			local a = `i' - ${lead} - ${lead}
			local b = `i' + ${lag} + ${lag}
			
			keep if inrange(year, `a', `b')
			 
			cap drop treated helper  
			 
			* Generate an indicator for being treated
			gen treated = 0 
			replace treated = 1 if year == `i' & change_`explaining' > 0  & change_`explaining' !=. 
			 
			bysort estab_id: egen max_treated = max(treated)
			bysort estab_id: egen max_change = max(change_`explaining')
			bysort estab_id: egen min_change = min(change_`explaining')
			
			* Drop all observations which were not treated and experienced a tax change in any other year 
			drop if max_change!=0 & max_treated==0 
			drop if min_change<0 // Drop all establishments that experienced a decrease over that time period
			 
			* Drop treated units if they experienced a tax change four years prior to the reform
			generate helper = 0 
			replace helper = 1 if change_`explaining'!=0 & change_`explaining'!=. & year>=`a' & year<`i'
			
			bysort estab_id: egen max_helper = max(helper)
			drop if max_helper ==1 
			drop helper max_helper
					
			* Generate a variable that indicates that the observed change was the first in a series of tax changes 
			gen indicator = 1 if change_`explaining'!=0  & change_`explaining'!= .
			bysort estab_id : egen total_change = total(indicator)
			gen multiple_events = 1 if total_change >1
			drop indicator total_change 
			
			* Now only keep the period in time around the treatment that we actually want to assess 
			local a = `i' - ${lead} 
			local b = `i' + ${lag} 
			
			keep if inrange(year, `a', `b')
			
			gen indicator = 1 if other_credit_`explaining'!=.
			bysort estab_id: egen count = total(indicator)
			gen balanced_panel = 1 if count == 9 
			drop indicator count 
			
			gen ry_increase = year - `i' if max_treated ==1
			
			gen event = `i'
			sum event if max_treated==1 
			local count =r(N)
			di `count'
			
			if `count' >0 {
				tempfile stacked_`i'
				save `stacked_`i''
				
			}
			else {
				local not `i'
				local years_final: list years_final - not
				di "`years_final'"		
			}
		}

		clear 
		foreach v in `years_final' {
			append using `stacked_`v''
		}
		
		keep fips_state czone estab_id year assignee_id treated max_treated max_change min_change multiple_events ry_increase event balanced_panel
		compress
		save "${TEMP}/final_cz_stacked_other_total_`explaining'_incr.dta", replace 
		 
	}


********************************************************************************
* Decreases 
********************************************************************************

*other_all0 other_all1 other_all3 other_weighted0 other_weighted1 other_weighted3 other_threelargest0 other_threelargest1 other_threelargest3 other_first0 other_first1 other_first3 

foreach explaining in `weighting_strategy'  {
	
        use  "${TEMP}/final_cz_stacked_other_zeros.dta", clear 
		levelsof year if year>= 1992 & year<=2018, local(years_final)
		di `years_final'

		forvalues i = 1992/2018 { 
			use  "${TEMP}/final_cz_stacked_other_zeros.dta", clear 
			local a = `i' - ${lead} 
			local b = `i' + ${lag}
			
			keep if inrange(year, `a', `b')
			 
			cap drop treated helper  
			 
			* Generate an indicator for being treated
			gen treated = 0 
			replace treated = 1 if year == `i' & change_`explaining' < 0 
			 
			bysort estab_id: egen max_treated = max(treated)
			bysort estab_id: egen max_change = max(change_`explaining')
			bysort estab_id: egen min_change = min(change_`explaining')
			
			* Drop all observations which were not treated and experienced a tax change in any other year 
			drop if max_change!=0 & max_treated==0 
			drop if min_change!=0 & max_treated==0 // NEW: We also have to drop controls with decreases!
			 
			* Drop treated units if they experienced a tax change four years prior to the reform
			generate helper = 0 
			replace helper = 1 if change_`explaining'!=0 & change_`explaining'!=. & year>=`a' & year<`i'
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
			gen indicator = 1 if change_`explaining'!=0 & change_`explaining'!= .
			bysort estab_id : egen total_change = total(indicator)
			gen multiple_events = 1 if total_change >1
			drop indicator total_change 
			
			gen indicator = 1 if other_credit_`explaining'!=.
			bysort estab_id: egen count = total(indicator)
			gen balanced_panel = 1 if count == 9 
			drop indicator count 
				
			gen ry_decrease = year - `i' if max_treated ==1 
			gen event = `i'
			sum event if max_treated==1 
			local count =r(N)
			di `count'
			
			if `count' >0 {
				tempfile stacked_`i'
				save `stacked_`i''
				
			}
			else {
				local not `i'
				local years_final: list years_final - not
				di "`change_final'"	
			}
		}

		clear 
		foreach v in `years_final' {
			append using `stacked_`v''
		}
		
		keep fips_state czone estab_id year assignee_id treated max_treated max_change min_change multiple_events ry_decrease event balanced_panel
		compress
		save "${TEMP}/final_cz_stacked_other_total_`explaining'_decr.dta", replace 
		 
	}


