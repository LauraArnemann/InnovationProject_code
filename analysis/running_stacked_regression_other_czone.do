////////////////////////////////////////////////////////////////////////////////
// Project:        	Moving innovation
// Creation Date:  	19/03/2024
// Last Update:    	01/07/2024
// Authors:         Laura Arnemann
//					Theresa Bührle
// Goal: 			Running Stacked Regression: Change in credits at other locations 
////////////////////////////////////////////////////////////////////////////////

local sample1 if inrange(year, 1988, 2018)
local sample2 if inrange(year, 1988, 2018)  & total_patents>10 
local sample3  if inrange(year, 1988, 2018)  & balanced_panel==1
local sample4  if inrange(year, 1988, 2018)  & balanced_panel==1 & total_patents>10 


local outcome patents3_w1 n_inventors3_w1 n_newinventors3_w1
local outcome_log patents3_w1 n_inventors3_w1 n_newinventors3_w1


	foreach direction in incr {
		
********************************************************************************
* Events indicator on state-year level: Change at other locations  
********************************************************************************		
	
			use "${TEMP}/final_state_stacked_incr_${dataset}_cz_year.dta", replace 
			merge m:1 assignee_id fips_state czone year using "${TEMP}/final_state_stacked_other_zeros_${dataset}_cz.dta", nogen keep(3)
			drop min_year max_year 
				
			bysort assignee_id year event: egen total_patents = total(patents3)
			
			egen assignee = group(assignee_id)

			foreach var of varlist patents1 patents2 patents3 n_inventors1 n_inventors2 n_inventors3 n_newinventors3 {
				gstats winsor `var', cut(1 99) gen(`var'_w1)
				gstats winsor `var', cut(1 95) gen(`var'_w2)
				gen ln_`var'=log(`var')
			}
			
			
		    * Balanced Panel: Only observations present four years before and four years after event
		    bysort estab_id: egen min_year = min(year)
		    bysort estab_id: egen max_year = max(year)
			bysort estab_id: egen estab_patents = total(patents3)
                 
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
				
			forvalues i =1/1 {
				
				*Event studies
				foreach outc in `outcome' {
									
					ppmlhdfe `outc' f4_binary f3_binary f2_binary zero_1 l?_binary `sample`i'', absorb(estab#event year#event#fips_state) cl(estab#event)
					 est sto inventorreg1
					coefplot inventorreg1, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
					xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) keep(f?_binary zero_1 l?_binary) ///
					yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
					title("Spillovers, `direction' - no controls") xtitle("Years since Change") graphregion(color(white))
						capture noisily graph export "${RESULTS}/stackedregression/spillovers/stacked_other_`direction'_sample`i'_stateyear.png", replace  

				}
				
		* Also run the logarithm to give comparability with chaisemartin estimator 
				foreach outc in `outcome_log' {					
				
					reghdfe `outc' f4_binary f3_binary f2_binary zero_1 l?_binary `sample`i'', absorb(estab#event year#event#fips_state) cl(estab#event)
					 est sto inventorreg3
					coefplot inventorreg3, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
					xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) keep(f?_binary zero_1 l?_binary) ///
					yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
					title("Spillovers, `direction' - controls ") xtitle("Years since Change") graphregion(color(white))
						capture noisily graph export "${RESULTS}/stackedregression/spillovers/stacked_other_`direction'_c2_sample`i'_stateyear.png", replace  
			}
		}			
	}

