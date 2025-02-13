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
	
use "${TEMP}/final_cz_corp.dta", clear 
drop if missing(assignee_id)

collapse (max) cz_treated_change_w1 cz_treated_change_w2 cz_treated_change_w3, by(czone fips_state year)
 
egen czone_id = group(czone fips_state)

xtset czone_id year 	

* Changes are usually too small, so that we cannot impose this restriction
*replace  change_cz = 0 if inrange(change_cz, -1, 1)
compress	

forvalues i =1/3 {
gen change_cz`i' = cz_treated_change_w`i' 

}
drop if missing(czone_id)
save "${TEMP}/final_state_stacked_other_zeros_cz.dta", replace
	
********************************************************************************
* Increases 
********************************************************************************
*other_all0 other_all1 other_all3 other_weighted0 other_weighted1 other_weighted3 other_threelargest0 other_threelargest1 other_threelargest3 other_first0 other_first1 other_first3


forvalues y = 1/3 {
		
	    use  "${TEMP}/final_state_stacked_other_zeros_cz.dta", clear
	    levelsof year if year>= 1992 & year<=2018, local(years_final)
		di `years_final'	

		forvalues i = 1992/2018 { 
			use  "${TEMP}/final_state_stacked_other_zeros_cz.dta", clear
			
			* We want to have values without any tax changes 9 years before and 9 years after the tax change 
			local a = `i' - ${lead} - ${lead}
			local b = `i' + ${lag} + ${lag}
			
			keep if inrange(year, `a', `b')
			 
			* Generate an indicator for being treated
			gen treated = 0 
			replace treated = 1 if year == `i' & change_cz`y' > 0  & change_cz`y'!=. 
			bysort czone_id: egen max_treated = max(treated)
			bysort czone_id: egen max_change = max(change_cz`y')
			bysort czone_id: egen min_change = min(change_cz`y')
	
			
			* Drop all observations which were not treated and experienced a tax change in any other year 
			drop if max_change!=0 & max_treated==0 
			drop if min_change<0 // Drop all establishments that experienced a decrease over that time period
			 
			* Drop treated units if they experienced a tax change four years prior to the reform
			generate helper = 0 
			replace helper = 1 if change_cz`y'!=0 & change_cz`y'!=. & year>=`a' & year<`i'
			
			bysort czone_id: egen max_helper = max(helper)
			drop if max_helper ==1 
			drop helper max_helper

		
			* Generate a variable that indicates that the observed change was the first in a series of tax changes 
			gen indicator = 1 if change_cz`y'!=0  & change_cz`y'!= .
			bysort czone_id : egen total_change = total(indicator)
			*gen multiple_events = 1 if total_change >1
			drop indicator total_change 
	
			* Now only keep the period in time around the treatment that we actually want to assess 
			local a = `i' - ${lead} 
			local b = `i' + ${lag} 
			
			keep if inrange(year, `a', `b')

			gen indicator = 1 if change_cz`y'!=.
			bysort czone_id: egen count = total(indicator)
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
		


compress
local direction incr


egen czone_event = group(czone_id fips_state event)
xtset czone_event year 
forvalues i=1/4 {
				gen f`i'_binary = ry_`direction'ease==-`i'
				label var f`i'_binary "- `i'"
				gen f`i'_change = f`i'.change_cz`y'
				*replace f`i'_change  =0 if missing(f`i'_change )
				label var f`i'_change "- `i'"
			}

			forvalues i=0/4 {
				gen l`i'_binary = ry_`direction'ease==`i'
				label var l`i'_binary "`i'"
				gen l`i'_change = l`i'.change_cz`y'
				*replace l`i'_change  =0 if missing(l`i'_change )
				label var l`i'_change "`i'"
			}
			


* 697.350 observations
save "${TEMP}/final_state_stacked_incr_cz_year_w`y'.dta", replace 
}


/*
*if `aggregate' == 1 {
********************************************************************************
* Stacked Regression for tax changes at other establishment location
********************************************************************************
	
use "${TEMP}/final_cz_zeros_assignee.dta", clear 
*drop if missing(assignee_id)

* Changes in R&D credits
gen change_cz  = cz_treated_change_w 

egen czone_id = group(czone fips_state )

xtset czone_id year 

local x change_cz
forval f = 8(-1)1 {
		gen F`f'_`x' = F`f'.`x'		
		label var F`f'_`x' "- `f'"
		} // f

	forval l = 0(1)8{		
		gen L`l'_`x' = L`l'.`x'
		label var L`l'_`x' " `l'"
		} // l

gen sum_leadslags = F1_change_cz + F2_change_cz + F3_change_cz + F4_change_cz + F5_change_cz + F6_change_cz + F7_change_cz + F8_change_cz + L1_change_cz + L2_change_cz + L3_change_cz + L4_change_cz + L5_change_cz + L6_change_cz + L7_change_cz + L8_change_cz 	

* Changes are usually too small, so that we cannot impose this restriction
*replace  change_cz = 0 if inrange(change_cz, -1, 1)
compress	
save  "${TEMP}/final_state_stacked_other_zeros_cz_aggregate.dta", replace 


********************************************************************************
* Increases 
********************************************************************************
*other_all0 other_all1 other_all3 other_weighted0 other_weighted1 other_weighted3 other_threelargest0 other_threelargest1 other_threelargest3 other_first0 other_first1 other_first3
		
	    use  "${TEMP}/final_state_stacked_other_zeros_cz_aggregate.dta", clear 
	    levelsof year if year>= 1992 & year<=2018, local(years_final)
		di `years_final'	

		forvalues i = 1992/2018 { 
			use  "${TEMP}/final_state_stacked_other_zeros_cz_aggregate.dta", clear
			
			* We want to have values without any tax changes 9 years before and 9 years after the tax change 
			local a = `i' - ${lead} - ${lead}
			local b = `i' + ${lag} + ${lag}
			
			keep if inrange(year, `a', `b')
			 
			 egen czone_id = group(czone fips_state)
			* Generate an indicator for being treated
			gen treated = 0 
			replace treated = 1 if year == `i' & change_cz > 0  & change_cz !=. 
			bysort czone_id: egen max_treated = max(treated)
			bysort czone_id: egen max_change = max(change_cz)
			bysort czone_id: egen min_change = min(change_cz)
	
			
			* Drop all observations which were not treated and experienced a tax change in any other year 
			drop if max_change!=0 & max_treated==0 
			drop if min_change<0 // Drop all establishments that experienced a decrease over that time period
			 
			* Drop treated units if they experienced a tax change four years prior to the reform
			generate helper = 0 
			replace helper = 1 if change_cz!=0 & change_cz!=. & year>=`a' & year<`i'
			
			bysort czone_id: egen max_helper = max(helper)
			drop if max_helper ==1 
			drop helper max_helper

		
			* Generate a variable that indicates that the observed change was the first in a series of tax changes 
			gen indicator = 1 if change_cz!=0  & change_cz!= .
			bysort czone_id : egen total_change = total(indicator)
			*gen multiple_events = 1 if total_change >1
			drop indicator total_change 
				
	
			* Now only keep the period in time around the treatment that we actually want to assess 
			local a = `i' - ${lead} 
			local b = `i' + ${lag} 
			
			keep if inrange(year, `a', `b')

			drop count
			gen indicator = 1 if change_cz!=.
			bysort czone_id: egen count = total(indicator)
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
		

keep fips_state czone year treated max_treated max_change min_change ry_increase event balanced_panel
compress

* 697.350 observations
save "${TEMP}/final_state_stacked_incr_cz_year_aggregate.dta", replace 
		 
*}
	





