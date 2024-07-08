////////////////////////////////////////////////////////////////////////////////
// Project:        	Moving innovation
// Creation Date:  	19/03/2024
// Last Update:    	24/04/2024
// Authors:         Laura Arnemann
//					Theresa Bührle
// Goal: 			Creating stacked event studies for changes in other states 
////////////////////////////////////////////////////////////////////////////////

global lead=4 	// set leads
global lag=4	// set lags


********************************************************************************
* Stacked Regression for tax changes at other establishment location
********************************************************************************

foreach type in assignee gvkey {
	
use "${TEMP}/final_state_zeros_new_${dataset}_`type'.dta", clear 
drop if missing(assignee_id)

* Only keep multistate firms for all others the values for the other variables will be zero 
keep if multistatefirm_max==1 

egen estab = group(assignee_id fips_state)
xtset estab year 


* Renaming all the variables because otherwise we can't generate the change variable 
*rename other_rd_credit_all0 other_all0
*rename other_rd_credit_all1 other_all1 
rename other_rd_credit_all3 other_all3

*rename other_rd_credit_weighted0 other_weighted0
*rename other_rd_credit_weighted1 other_weighted1 
rename other_rd_credit_weighted3 other_weighted3

*rename other_rd_credit_threelargest0 other_threelargest0
*rename other_rd_credit_threelargest1 other_threelargest1 
rename other_rd_credit_threelargest3 other_threelargest3
 
*rename other_rd_credit_first0 other_first0
*rename other_rd_credit_first1 other_first1 
rename other_rd_credit_first3 other_first3 

foreach num of numlist  3 {
foreach state_var in unemployment gdp cit pit {
	rename other_`state_var'_threelargest`num' other_threelargest`num'_`state_var'
	rename other_`state_var'_weighted`num' other_weighted`num'_`state_var'
	rename other_`state_var'_first`num' other_first`num'_`state_var'
	rename other_`state_var'_all`num' other_all`num'_`state_var'
}
}


foreach var in  other_all3 other_weighted3 other_threelargest3 {
	
		* Changes in R&D credits
		gen change_`var'  = `var' - l.`var'
		replace  change_`var' = 0 if inrange(change_`var', -1, 1)
		* We should probably check if this is a good size approximation
	
}
	
*drop if missing(change_oth_total_rd_credit) 
//& missing(change_oth_total_cit) & missing(change_oth_total_pit)

drop max_year min_year nstates multistatefirm_temp multistatefirm_max

compress	
save  "${TEMP}/final_state_stacked_other_zeros_${dataset}_`type'.dta", replace 




********************************************************************************
* Increases 
********************************************************************************
*other_all0 other_all1 other_all3 other_weighted0 other_weighted1 other_weighted3 other_threelargest0 other_threelargest1 other_threelargest3 other_first0 other_first1 other_first3


	foreach var in other_all3 other_weighted3 other_threelargest3  {
		
	    use  "${TEMP}/final_state_stacked_other_zeros_${dataset}_`type'.dta", clear 
	    levelsof year if year>= 1992 & year<=2018, local(years_final)
		di `years_final'	

		forvalues i = 1992/2018 { 
			use  "${TEMP}/final_state_stacked_other_zeros_${dataset}_`type'.dta", clear
			
			* We want to have values without any tax changes 9 years before and 9 years after the tax change 
			local a = `i' - ${lead} - ${lead}
			local b = `i' + ${lag} + ${lag}
			
			keep if inrange(year, `a', `b')
			 
			* Generate an indicator for being treated
			gen treated = 0 
			replace treated = 1 if year == `i' & change_`var' > 0  & change_`var' !=. 
			 
			bysort estab: egen max_treated = max(treated)
			bysort estab: egen max_change = max(change_`var')
			bysort estab: egen min_change = min(change_`var')
			
			* Drop all observations which were not treated and experienced a tax change in any other year 
			drop if max_change!=0 & max_treated==0 
			drop if min_change<0 // Drop all establishments that experienced a decrease over that time period
			 
			* Drop treated units if they experienced a tax change four years prior to the reform
			generate helper = 0 
			replace helper = 1 if change_`var'!=0 & change_`var'!=. & year>=`a' & year<`i'
			
			bysort estab: egen max_helper = max(helper)
			drop if max_helper ==1 
			drop helper max_helper
			
		
			* Generate a variable that indicates that the observed change was the first in a series of tax changes 
			gen indicator = 1 if change_`var'!=0  & change_`var'!= .
			bysort estab : egen total_change = total(indicator)
			gen multiple_events = 1 if total_change >1
			drop indicator total_change 
			
			* Now only keep the period in time around the treatment that we actually want to assess 
			local a = `i' - ${lead} 
			local b = `i' + ${lag} 
			
			keep if inrange(year, `a', `b')
			
			gen indicator = 1 if `var'!=.
			bysort estab: egen count = total(indicator)
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
		
		keep fips_state estab year assignee_id treated max_treated max_change min_change multiple_events ry_increase event balanced_panel
		compress
		save "${TEMP}/final_state_stacked_`var'_incr_${dataset}_`type'_year.dta", replace 
		 
}
}

/*
********************************************************************************
* Decreases 
********************************************************************************

*other_all0 other_all1 other_all3 other_weighted0 other_weighted1 other_weighted3 other_threelargest0 other_threelargest1 other_threelargest3 other_first0 other_first1 other_first3 

foreach var in other_all3 other_weighted3 other_threelargest3 {
	// pit cit 
	// Loop with `var'_other_b  `var'_l1_other_b `var'_l2_other_b `var'_l3_other_b `var'_l4_other_b 
	
        use  "${TEMP}/final_state_stacked_other_zeros_${dataset}_`type'.dta", clear 
		levelsof year if year>= 1992 & year<=2018, local(years_final)
		di `years_final'

		forvalues i = 1992/2018 { 
			use  "${TEMP}/final_state_stacked_other_zeros_${dataset}_`type'.dta", clear 
			local a = `i' - ${lead} 
			local b = `i' + ${lag}
			
			keep if inrange(year, `a', `b')
			 
			* Generate an indicator for being treated
			gen treated = 0 
			replace treated = 1 if year == `i' & change_`var' < 0 
			 
			bysort estab: egen max_treated = max(treated)
			bysort estab: egen max_change = max(change_`var')
			bysort estab: egen min_change = min(change_`var')
			
			* Drop all observations which were not treated and experienced a tax change in any other year 
			drop if max_change!=0 & max_treated==0 
			drop if min_change!=0 & max_treated==0 // NEW: We also have to drop controls with decreases!
			 
			* Drop treated units if they experienced a tax change four years prior to the reform
			generate helper = 0 
			replace helper = 1 if change_`var'!=0 & change_`var'!=. & year>=`a' & year<`i'
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
			gen indicator = 1 if change_`var'!=0 & change_`var'!= .
			bysort estab : egen total_change = total(indicator)
			gen multiple_events = 1 if total_change >1
			drop indicator total_change 
			
			gen indicator = 1 if `var'!=.
			bysort estab: egen count = total(indicator)
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
		
		keep fips_state estab year assignee_id treated max_treated max_change min_change multiple_events ry_decrease event balanced_panel
		compress
		save "${TEMP}/final_state_stacked_other_total_`var'_decr_${dataset}_`type'_year.dta", replace 
		 
}

}
