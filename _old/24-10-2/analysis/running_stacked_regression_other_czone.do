////////////////////////////////////////////////////////////////////////////////
// Project:        	Moving innovation
// Creation Date:  	19/03/2024
// Last Update:    	01/07/2024
// Authors:         Laura Arnemann
//					Theresa Bührle
// Goal: 			Running Stacked Regression: Change in credits at other locations 
////////////////////////////////////////////////////////////////////////////////


local sample1 if inrange(year, 1988, 2018)
local sample2 if inrange(year, 1988, 2018)  & estab_patents>5 
*local sample3 if inrange(year, 1988, 2018)  & total_patents>5 
*local sample3  if inrange(year, 1988, 2018)  & balanced_panel==1
*local sample4  if inrange(year, 1988, 2018)  & balanced_panel==1 & total_patents>10 



* On Establishment Level 

local outcome patents3_w1 n_inventors3_w1 n_newinventors3_w1 
local outcome_log ln_patents3 ln_n_inventors3 ln_n_newinventors3

	
********************************************************************************
* Events indicator on state-year level: Change at other locations  
********************************************************************************
/*
forvalues y = 2/3 {	
use "${TEMP}/final_state_stacked_incr_${dataset}_cz_year_w`y'.dta", clear 
levelsof event, local(events_final)

clear 
use "${TEMP}/final_cz_${dataset}.dta"
* Just set some arbitrary value this will be dropped anyway when merging
gen event = 1992 

foreach l in `events_final' {
	append using "${TEMP}/final_cz_${dataset}.dta"
	replace event = `l'
}
compress
save "${TEMP}/final_cz_${dataset}_w`y'.dta", replace 
}
*/
	
forvalues y = 1/3 {	
	
			use "${TEMP}/final_cz_${dataset}_w`y'.dta", replace 
			merge m:1 czone fips_state year event using "${TEMP}/final_state_stacked_incr_${dataset}_cz_year_w`y'.dta", nogen keep(3)
			drop min_year max_year 
				
			bysort assignee_id year event: egen total_patents = total(patents3)
			
			drop if missing(estab_id)

			foreach var of varlist patents3 n_inventors3 n_newinventors3 {
				gstats winsor `var', cut(1 99) gen(`var'_w1)
				gstats winsor `var', cut(1 95) gen(`var'_w2)
				gen ln_`var'=log(`var')
			}
			
			
		    * Balanced Panel: Only observations present four years before and four years after event
		    bysort estab_id event: egen min_year = min(year)
		    bysort estab_id event: egen max_year = max(year)
			bysort estab_id event: egen estab_patents = total(patents3)
                 
			*Generate the event indicators
	
			
			drop f1*
			gen zero_1=1
			label var zero_1 "-1" 
				
			forvalues i =1/2 {
				
				*Event studies
				foreach outc in `outcome' {
									
					ppmlhdfe `outc' f4_binary f3_binary f2_binary zero_1 l?_binary `sample`i'', absorb(estab_id#event year#fips_state) cl(czone#fips_state#event)
					 est sto inventorreg1
					coefplot inventorreg1, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
					xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) keep(f?_binary zero_1 l?_binary) ///
					yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
					title("Spillovers, Increase - no controls") xtitle("Years since Change") graphregion(color(white))
						capture noisily graph export "${RESULTS}/stackedregression/spillovers/estab/stacked_other_increase_`outc'_sample`i'_stateyear_w`y'.png", replace 
						
						ppmlhdfe `outc' f4_change f3_change f2_change zero_1 l?_change `sample`i'', absorb(estab_id#event year#fips_state)cl(czone#fips_state#event)
					 est sto inventorreg2
					coefplot inventorreg3, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
					xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) keep(f?_binary zero_1 l?_binary) ///
					yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
					title("Spillovers, Increase - no controls") xtitle("Years since Change") graphregion(color(white))
						capture noisily graph export "${RESULTS}/stackedregression/spillovers/estab/stacked_other_change_`outc'_sample`i'_stateyear_w`y'.png", replace  
						

				}
				
		* Also run the logarithm to give comparability with chaisemartin estimator 
				foreach outc in `outcome_log' {					
				
					reghdfe `outc' f4_binary f3_binary f2_binary zero_1 l?_binary `sample`i'', absorb(estab_id#event year#event#fips_state) cl(czone#fips_state#event)
					 est sto inventorreg3
					coefplot inventorreg3, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
					xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) keep(f?_binary zero_1 l?_binary) ///
					yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
					title("Spillovers, `direction' - controls ") xtitle("Years since Change") graphregion(color(white))
						capture noisily graph export "${RESULTS}/stackedregression/spillovers/estab/stacked_other_increase_`outc'_c2_sample`i'_stateyear_w`y'.png", replace 
						
						
					reghdfe `outc' f4_change f3_change f2_change zero_1 l?_change `sample`i'', absorb(estab_id#event year#event#fips_state) cl(czone#fips_state#event)
					 est sto inventorreg4
					coefplot inventorreg4, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
					xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) keep(f?_binary zero_1 l?_binary) ///
					yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
					title("Spillovers, `direction' - controls ") xtitle("Years since Change") graphregion(color(white))
						capture noisily graph export "${RESULTS}/stackedregression/spillovers/estab/stacked_other_change_`outc'_c2_sample`i'_stateyear_w`y'.png", replace  
						
				

			}
		}			
}
*}


********************************************************************************	
* On Aggregate level 
********************************************************************************
/*
local sample1 if inrange(year, 1988, 2018)
local sample2 if inrange(year, 1988, 2018)  & multistate_cz==0
 
* n_inventors3_w1 patents3_w1 n_newinventors3_w1 local_n_inventors3_w1 local_n_newinventors3_w1 local_patents3_w1 
local outcome  n_inventors3_w1 patents3_w1 n_newinventors3_w1 local_n_inventors3_w1 local_n_newinventors3_w1 local_patents3_w1  max_labs_w1
local outcome_log ln_patents3 ln_n_inventors3 ln_n_newinventors3
*if `aggregate' == 0 {
	
	foreach direction in incr {
		
		use "${TEMP}/final_state_stacked_incr_${dataset}_cz_year_aggregate.dta", replace 
			merge m:1 fips_state czone year using "${TEMP}/final_state_stacked_other_zeros_${dataset}_cz_aggregate.dta", nogen keep(3)
			

			foreach var of varlist  patents3 n_inventors3 n_newinventors3  local_patents3 local_n_inventors3 local_n_newinventors3 max_labs {
				gstats winsor `var', cut(1 99) gen(`var'_w1)
				gstats winsor `var', cut(1 95) gen(`var'_w2)
				gen ln_`var'=log(`var')
			}
			
                 
			*Generate the event indicators
			forvalues i=1/4 {
				gen f`i'_binary = ry_`direction'ease==-`i'
				label var f`i'_binary "- `i'"
			}

			forvalues i=0/4 {
				gen l`i'_binary = ry_`direction'ease==`i'
				label var l`i'_binary "`i'"
			}
	}
			drop f1_binary 
			gen zero_1=1
			label var zero_1 "-1" 
				
			forvalues i =1/2 {
				
				*Event studies
				foreach outc in `outcome' {
									
					ppmlhdfe `outc' f4_binary f3_binary f2_binary zero_1 l?_binary `sample`i'', absorb(czone#fips_state#event year#fips_state#event) cl(czone#event)
					 est sto inventorreg1
					coefplot inventorreg1, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
					xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) keep(f?_binary zero_1 l?_binary) ///
					yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
					title("Spillovers, `direction' - no controls") xtitle("Years since Change") graphregion(color(white))
						capture noisily graph export "${RESULTS}/stackedregression/spillovers/aggregate/stacked_other_`outc'_sample`i'_stateyear.png", replace  

				}
				
		* Also run the logarithm to give comparability with chaisemartin estimator 
				foreach outc in `outcome_log' {					
				
					reghdfe `outc' f4_binary f3_binary f2_binary zero_1 l?_binary `sample`i'', absorb(czone#fips_state#event year#event#fips_state) cl(czone#event)
					 est sto inventorreg3
					coefplot inventorreg3, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
					xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) keep(f?_binary zero_1 l?_binary) ///
					yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
					title("Spillovers, `direction' - controls ") xtitle("Years since Change") graphregion(color(white))
						capture noisily graph export "${RESULTS}/stackedregression/spillovers/aggregate/stacked_other_`outc'_c2_sample`i'_stateyear.png", replace  
			}
			}
*}
*/


