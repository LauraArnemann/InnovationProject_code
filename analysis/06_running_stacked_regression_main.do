////////////////////////////////////////////////////////////////////////////////
// Project:        	Moving innovation
// Creation Date:  	19/03/2024
// Last Update:    	21/11/2024
// Authors:         Laura Arnemann
//					Theresa Bührle
// Goal: 			Running Stacked Regression: Change in credits at other locations 
////////////////////////////////////////////////////////////////////////////////

use "${TEMP}/patentdata_clean_assignee.dta", clear
bysort assignee_id: gen count = _n 
keep if count ==1  
tempfile patentshelper
save `patentshelper'

local sample1 if inrange(year, 1988, 2018)
local sample7 if inrange(year, 1988, 2018) & noncorp_asg==0 & patents3>10
local sample8 if inrange(year, 1988, 2018) & asg_corp==1
local sample9 if inrange(year, 1988, 2018) & asg_corp==1 & patents3>10
local sample10 if inrange(year, 1988, 2018) & asg_corp==1 & total_patents>20

foreach direction in $direction {
		
********************************************************************************
* Events indicator on state-year level: Change at other locations  
********************************************************************************		
	*other_weighted3 
	foreach var2 in other_$weighting_strategy {
			
		use "${TEMP}/final_state_stacked_other_total_`var2'_`direction'.dta", replace 
		merge m:1 estab year using "${TEMP}/final_state_stacked_other_zeros.dta", nogen keep(3)
			
		merge m:1 assignee_id using `patentshelper', keepusing(noncorp_asg asg_corp pub_assg)
			drop if _merge ==2 
			drop _merge 
			
		bysort assignee_id year event: egen total_patents = total(patents3)
			
		gen inventor_productivity = patents3/n_inventors3 
		replace inventor_productivity = 0 if missing(patents3)
			
		egen assignee = group(assignee_id)

		foreach var of varlist patents1 patents2 patents3 n_inventors1 n_inventors2 n_inventors3 n_newinventors3 n_relocatinginventors n_lasttimeinventor {
			gstats winsor `var', cut(1 99) gen(`var'_w1)
			gstats winsor `var', cut(1 95) gen(`var'_w2)
			gen ln_`var'=log(`var')
		}
			
		gen ln_gdp = log(`var2'_gdp)
			
		* Balanced Panel: Only observations present four years before and four years after event
		bysort estab: egen min_year = min(year)
		bysort estab: egen max_year = max(year)
		bysort estab: egen estab_patents = total(patents3)
                 
		*Generate the event indicators
		forvalues i=1/4 {
			gen f`i'_binary = ry_`direction'ease==-`i'
			label var f`i'_binary "- `i'"
		}

		forvalues i=0/4 {
			gen l`i'_binary = ry_`direction'ease==`i'
			label var l`i'_binary "`i'"
		}

		drop f1_binary 
		gen zero_1=1
		label var zero_1 "-1" 
				
		*
		foreach i of numlist 10 {
				
			*Event studies
			foreach outc in $outcome {
									
				ppmlhdfe `outc' f4_binary f3_binary f2_binary zero_1 l?_binary `sample`i'', absorb(estab#event year#event#fips_state) cl(estab#event)
					est sto inventorreg1
					coefplot inventorreg1, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
					xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) keep(f?_binary zero_1 l?_binary) ///
					yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
					xtitle("Years since Change") graphregion(color(white))
				capture noisily graph export "${RESULTS}/eventstudies/stackedregression/stacked_other_`outc'_`var2'_`direction'_c1_sample`i'_stateyear.png", replace  
									
				ppmlhdfe `outc' f4_binary f3_binary f2_binary zero_1 l?_binary `var2'_pit `var2'_cit `sample`i'', absorb(estab#event year#event#fips_state) cl(estab#event)
					est sto inventorreg3
					coefplot inventorreg3, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
					xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) keep(f?_binary zero_1 l?_binary) ///
					yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
					 xtitle("Years since Change") graphregion(color(white))
				capture noisily graph export "${RESULTS}/eventstudies/stackedregression/stacked_other_`outc'_`var2'_`direction'_c2_sample`i'_stateyear.png", replace  
				}
					
			* Also run the logarithm to give comparability with chaisemartin estimator 
			foreach outc in $outcome_log {	
			
				reghdfe `outc' f4_binary f3_binary f2_binary zero_1 l?_binary `sample`i'', absorb(estab#event year#event#fips_state) cl(estab#event)
					est sto inventorreg3
					coefplot inventorreg3, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
					xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) keep(f?_binary zero_1 l?_binary) ///
					yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
					xtitle("Years since Change") graphregion(color(white))
				capture noisily graph export "${RESULTS}/eventstudies/stackedregression/stacked_other_`outc'_`var2'_`direction'_c3_sample`i'_stateyear.png", replace 
				
				reghdfe `outc' f4_binary f3_binary f2_binary zero_1 l?_binary `var2'_pit `var2'_cit `sample`i'', absorb(estab#event year#event#fips_state) cl(estab#event)
					est sto inventorreg3
					coefplot inventorreg3, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
					xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) keep(f?_binary zero_1 l?_binary) ///
					yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
					xtitle("Years since Change") graphregion(color(white))
				capture noisily graph export "${RESULTS}/eventstudies/stackedregression/stacked_other_`outc'_`var2'_`direction'_c4_sample`i'_stateyear.png", replace  

			}
		}
	}			
}


