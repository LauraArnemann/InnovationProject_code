////////////////////////////////////////////////////////////////////////////////
// Project:        	Moving innovation
// Creation Date:  	19/03/2024
// Last Update:    	24/04/2024
// Authors:         Laura Arnemann
//					Theresa Bührle
// Goal: 			Running Stacked Regression: Changes at current location 
////////////////////////////////////////////////////////////////////////////////

local sample1 if inrange(year, 1988, 2018)
local sample2 if inrange(year, 1988, 2018)  & total_patents>10 
local sample3  if inrange(year, 1988, 2018)  & balanced_panel==1
local sample4  if inrange(year, 1988, 2018)  & balanced_panel==1 & total_patents>10 

foreach direction in $direction  {

	foreach var in "other_$weighting_strategy"  {

		*Change in location
		*-----------------------------------------------------------------------

	    use "${TEMP}/final_state_stacked_`var'_`direction'.dta", clear 
		
		merge m:1 estab year using "${TEMP}/final_state_stacked_zeros.dta", nogen keep(3)
		
		bysort assignee_id year event: egen n_patents = total(patents3)
		
		* Balanced Panel: Only observations present four years before and four years after event
		bysort assignee_id fips_state: egen min_year = min(year)
		bysort assignee_id fips_state: egen max_year = max(year)
		
		gen balanced_panel = 0 
		replace balanced_panel = 1 if min_year + 4 == event & max_year + 4 == event 
		
		egen assignee = group(assignee_id)

		foreach var of varlist patents1 patents2 patents3 n_inventors1 n_inventors2 n_inventors3 {
			gstats winsor `var', cut(1 99) gen(`var'_w1)
			gstats winsor `var', cut(1 95) gen(`var'_w2)
			gen ln_`var'=log(`var')
		}

		gen ln_gdp=log(gdp)
		gen ln_gdp_other=log(total_gdp)
		gen ln_state_rd_exp=log(state_rd_exp)
		gen ln_state_rd_exp_other=log(state_rd_exp_other)
		
		*Generate the event indicators
		forvalues i=1/4  {
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
		
		
		*Post dummy for DiD
		gen byte post_tr = (year>=event)
		
		forvalues i =1/2 {

			foreach outc in $outcome {
	
			*Event studies
			capture noisily ppmlhdfe `outc' f4_binary f3_binary f2_binary zero_1 l?_binary `sample`i'', absorb(estab#event year#event#fips_stat) cl(estab#event)
			capture noisily est sto inventorreg1
			capture noisily coefplot inventorreg1, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
			xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) keep(f?_binary zero_1 l?_binary) ///
			yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
			title("`indepvar', `direction' - no controls") xtitle("Years since Change") graphregion(color(white))
				capture noisily graph export "${RESULTS}/graphs/`outc'/stacked_`indepvar'_`direction'_sample`i'.png", replace  

			capture noisily ppmlhdfe `outc' f4_binary f3_binary f2_binary zero_1 l?_binary $controls_other `sample`i'', absorb(estab#event year#event#fips_stat) cl(estab#event)
			capture noisily est sto inventorreg2
			capture noisily coefplot inventorreg2, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
			xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) keep(f?_binary zero_1 l?_binary) ///
			yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
			title("`indepvar', `direction' - controls") xtitle("Years since Change") graphregion(color(white))
				capture noisily graph export "${RESULTS}/graphs/`outc'/stacked_`indepvar'_`direction'_c1_sample`i'.png", replace  
		
			*DiD
			capture noisily ppmlhdfe `outc' 1.max_treated#1.post_tr `sample`i'', absorb(estab#event year#event#fips_stat) cl(estab#event)
				capture noisily outreg2 using "$RESULTS/tables/`outc'/change_stack_zero_`indepvar'_`direction'_sample`i'", ///
				replace dec(3) stats(coef se) addstat(Pseudo R2, e(r2_p)) noni nodepvar tex(frag) ///
				ctitle("`outc'") lab
		
			capture noisily ppmlhdfe `outc' 1.max_treated#1.post_tr $controls_other `sample`i'', absorb(estab#event year#event#fips_stat) cl(estab#event)
				capture noisily outreg2 using "$RESULTS/tables/`outc'/change_stack_zero_`indepvar'_`direction'_sample`i'", ///
				append dec(3) stats(coef se) addstat(Pseudo R2, e(r2_p)) noni nodepvar tex(frag) ///
				ctitle("`outc'") lab
			}
		}
	}
}
