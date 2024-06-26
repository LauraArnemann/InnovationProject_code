////////////////////////////////////////////////////////////////////////////////
// Project:        	Moving innovation
// Creation Date:  	19/03/2024
// Last Update:    	10/04/2024
// Authors:         Laura Arnemann
//					Theresa Bührle
// Goal: 			Running Stacked Regression
////////////////////////////////////////////////////////////////////////////////

* Stacked Regression for a change in RD Tax Credits 
*use "${TEMP}/final_state_stacked.dta", clear 


global controls pit cit 
global controls_other rd_credit_other pit_other cit_other

global controls2 $controls ln_gdp unemployment ln_state_rd_exp
global controls_other2 $controls_other ln_gdp_other unemployment_other ln_state_rd_exp_other

local direction incr decr
*incr decr 
local indepvar rd_credit 
*pit cit 
local outcome patents3 share_patents3_multistate n_inventors3 n_newinventors3

foreach var in `indepvar' {
local other_var  total_`indepvar'   
*total_`indepvar'  `indepvar'_other_b `indepvar'_l1_other `indepvar'_l2_other `indepvar'_l3_other `indepvar'_l4_other `indepvar'_l1_other_b `indepvar'_l2_other_b `indepvar'_l3_other_b `indepvar'_l4_other_b 
}

foreach direction in `direction'  {

	foreach indepvar in `indepvar' {

		*Change in location
		*-----------------------------------------------------------------------

		use "${TEMP}/final_state_stacked_`indepvar'_`direction'.dta", clear 
		
		merge m:1 estab year using "${TEMP}/final_state_stacked_zeros.dta", nogen keep(3)
		
		bysort assignee_id year event: egen n_patents = total(patents3)
		
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
		forvalues i=1/4{
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
		
		* Set different sample restrictions as well 
		local sample1 if inrange(year, 1988, 2014) 
		local sample2 if inrange(year, 1988, 2014) & n_patents>5 
		local sample3 if inrange(year, 1988, 2014) & n_patents!=0 
		local sample4 if inrange(year, 1988, 2014) & rd_credit_other!=. 
		local sample5 if inrange(year, 1988, 2014) & rd_credit_other==. 
		local sample6 if inrange(year, 1988, 2005)
		local sample7 if inrange(year, 1988, 2018)
		
		forvalues i =1/7 {

			foreach outc in `outcome' {
		/*
			*Event studies
			capture ppmlhdfe `outc' f4_binary f3_binary f2_binary zero_1 l?_binary `sample`i'', absorb(estab#event year#event) cl(fips_state#event)
			capture est sto inventorreg1
			capture coefplot inventorreg1, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
			xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) keep(f?_binary zero_1 l?_binary) ///
			yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
			title("`indepvar', `direction' - no controls") xtitle("Years since Change") graphregion(color(white))
				capture graph export "${RESULTS}/graphs/`outc'/stacked_`indepvar'_`direction'_sample`i'.png", replace  
		
			capture ppmlhdfe `outc' f4_binary f3_binary f2_binary zero_1 l?_binary $controls `sample`i'', absorb(estab#event year#event) cl(fips_state#event)
			capture est sto inventorreg2
			capture coefplot inventorreg2, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
			xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) keep(f?_binary zero_1 l?_binary) ///
			yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
			title("`indepvar', `direction' - controls") xtitle("Years since Change") graphregion(color(white))
				capture graph export "${RESULTS}/graphs/`outc'/stacked_`indepvar'_`direction'_c1_sample`i'.png", replace  
				
			capture ppmlhdfe `outc' f4_binary f3_binary f2_binary zero_1 l?_binary $controls $controls_other `sample`i'', absorb(estab#event year#event) cl(fips_state#event)
			capture est sto inventorreg3
			capture coefplot inventorreg3, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
			xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) keep(f?_binary zero_1 l?_binary) ///
			yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
			title("`indepvar', `direction' - controls (incl other)") xtitle("Years since Change") graphregion(color(white))
				capture graph export "${RESULTS}/graphs/`outc'/stacked_`indepvar'_`direction'_c2_sample`i'.png", replace  
			
			capture ppmlhdfe `outc' f4_binary f3_binary f2_binary zero_1 l?_binary $controls2 $controls_other2 `sample`i'', absorb(estab#event year#event) cl(fips_state#event)
			capture est sto inventorreg4
			coefplot inventorreg4, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
			xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) keep(f?_binary zero_1 l?_binary) ///
			yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
			title("`indepvar', `direction' - controls (incl other , incl gdp unemployment)") xtitle("Years since Change") graphregion(color(white))
				capture graph export "${RESULTS}/graphs/`outc'/stacked_`indepvar'_`direction'_c3_sample`i'.png", replace  
			*/
			*DiD
			capture ppmlhdfe `outc' max_treated#post_tr `sample`i'', absorb(estab#event year#event) cl(fips_state#event)
				capture outreg2 using "$RESULTS/tables/`outc'/change_stack_zero_`indepvar'_`direction'_sample`i'", ///
				replace dec(3) stats(coef se) addstat(Pseudo R2, e(r2_p)) noni nodepvar tex(frag) ///
				ctitle("`outc'") lab
		
			capture ppmlhdfe `outc' max_treated#post_tr $controls `sample`i'', absorb(estab#event year#event) cl(fips_state#event)
				capture outreg2 using "$RESULTS/tables/`outc'/change_stack_zero_`indepvar'_`direction'_sample`i'", ///
				append dec(3) stats(coef se) addstat(Pseudo R2, e(r2_p)) noni nodepvar tex(frag) ///
				ctitle("`outc'") lab
				
			capture ppmlhdfe `outc' max_treated#post_tr $controls $controls_other `sample`i'', absorb(estab#event year#event) cl(fips_state#event)
				capture outreg2 using "$RESULTS/tables/`outc'/change_stack_zero_`indepvar'_`direction'_sample`i'", ///
				append dec(3) stats(coef se) addstat(Pseudo R2, e(r2_p)) noni nodepvar tex(frag) ///
				ctitle("`outc'") lab
			
			capture ppmlhdfe `outc' max_treated#post_tr $controls2 $controls_other2 `sample`i'', absorb(estab#event year#event) cl(fips_state#event)
				capture outreg2 using "$RESULTS/tables/`outc'/change_stack_zero_`indepvar'_`direction'_sample`i'", ///
				append dec(3) stats(coef se) addstat(Pseudo R2, e(r2_p)) noni nodepvar tex(frag) ///
				ctitle("`outc'") lab

			}
		}
	}
}


macro drop controls controls_other 

global controls rd_credit pit cit 
global controls_other pit_other cit_other

foreach direction in `direction' {

	foreach indepvar in `indepvar' {
		
		*Change at other locations
		*-----------------------------------------------------------------------

		foreach var2 of varlist `other_var' {
		
			use "${TEMP}/final_state_stacked_other_`var2'_`direction'.dta", replace 
			
			merge m:1 estab year using "${TEMP}/final_state_stacked_other_zeros.dta", nogen keep(3)
			
			bysort assignee_id year event: egen n_patents = total(patents3)
			
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
			forvalues i=1/4{
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
			
			* Set different sample restrictions as well 
		 	local sample1 if inrange(year, 1988, 2014) 
		    local sample2 if inrange(year, 1988, 2014)  & n_patents>5 
		    local sample3 if inrange(year, 1988, 2014)  & n_patents!=0 
		    local sample4 if inrange(year, 1988, 2005)
			local sample5 if inrange(year, 1988, 2018)
			
			forvalues i =1/5 {
				
				foreach outc in `outcome'  {
				
				*Event studies
				capture ppmlhdfe `outc' f4_binary f3_binary f2_binary zero_1 l?_binary `sample`i'', absorb(estab#event year#event) cl(fips_state#event)
				capture est sto inventorreg1
				capture coefplot inventorreg1, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
				xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) keep(f?_binary zero_1 l?_binary) ///
				yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
				title("`indepvar', `var2', `direction' - no controls") xtitle("Years since Change") graphregion(color(white))
					capture graph export "${RESULTS}/graphs/`outc'/stacked_other_`var2'_`direction'_sample`i'.png", replace  
						
				capture ppmlhdfe `outc' f4_binary f3_binary f2_binary zero_1 l?_binary $controls `sample`i'', absorb(estab#event year#event) cl(fips_state#event)
				capture est sto inventorreg2
				capture coefplot inventorreg2, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
				xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) keep(f?_binary zero_1 l?_binary) ///
				yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
				title("`indepvar', `var2', `direction' - controls") xtitle("Years since Change") graphregion(color(white))
					capture graph export "${RESULTS}/graphs/`outc'/stacked_other_`var2'_`direction'_c1_sample`i'.png", replace  
					
				capture ppmlhdfe `outc' f4_binary f3_binary f2_binary zero_1 l?_binary $controls $controls_other `sample`i'', absorb(estab#event year#event) cl(fips_state#event)
				capture est sto inventorreg3
				capture coefplot inventorreg3, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
				xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) keep(f?_binary zero_1 l?_binary) ///
				yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
				title("`indepvar', `var2', `direction' - controls (incl other)") xtitle("Years since Change") graphregion(color(white))
					capture graph export "${RESULTS}/graphs/`outc'/stacked_other_`var2'_`direction'_c2_sample`i'.png", replace  
					
				capture ppmlhdfe `outc' f4_binary f3_binary f2_binary zero_1 l?_binary $controls2 $controls_other2 `sample`i'', absorb(estab#event year#event) cl(fips_state#event)
				capture est sto inventorreg4
				capture coefplot inventorreg4, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
				xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) keep(f?_binary zero_1 l?_binary) ///
				yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
				title("`indepvar', `var2', `direction' - controls (incl other, incl gdp unemployment)") xtitle("Years since Change") graphregion(color(white))
					capture graph export "${RESULTS}/graphs/`outc'/stacked_other_`var2'_`direction'_c3_sample`i'.png", replace 
						
				*DiD
				/*
				capture ppmlhdfe `outc' max_treated##post_tr `sample`i'', absorb(estab#event year#event) cl(fips_state#event)
					capture outreg2 using "$RESULTS/tables/`outc'/change_stack_other_zero_`var2'_`direction'_sample`i'", ///
					replace dec(3) stats(coef se) addstat(Pseudo R2, e(r2_p)) noni nodepvar tex(frag) ///
					ctitle("`outc'") lab
		
				capture ppmlhdfe `outc' max_treated##post_tr $controls `sample`i'' , absorb(estab#event year#event) cl(fips_state#event)
					capture outreg2 using "$RESULTS/tables/`outc'/change_stack_other_zero_`var2'_`direction'_sample`i'", ///
					append dec(4) stats(coef se) addstat(Pseudo R2, e(r2_p)) noni nodepvar tex(frag) ///
					ctitle("`outc'") lab
				
				capture ppmlhdfe `outc' max_treated##post_tr $controls $controls_other `sample`i'', absorb(estab#event year#event) cl(fips_state#event)
					capture outreg2 using "$RESULTS/tables/`outc'/change_stack_other_zero_`var2'_`direction'_sample`i'", ///
					append dec(3) stats(coef se) addstat(Pseudo R2, e(r2_p)) noni nodepvar tex(frag) ///
					ctitle("`outc'") lab
			
				capture ppmlhdfe `outc' max_treated##post_tr $controls2 $controls_other2 `sample`i'', absorb(estab#event year#event) cl(fips_state#event)
					capture outreg2 using "$RESULTS/tables/`outc'/change_stack_other_zero_`var2'_`direction'_sample`i'", ///
					append dec(3) stats(coef se) addstat(Pseudo R2, e(r2_p)) noni nodepvar tex(frag) ///
					ctitle("`outc'") lab
					*/

				}
			}
		}
	}
}

