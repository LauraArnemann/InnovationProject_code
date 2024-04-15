////////////////////////////////////////////////////////////////////////////////
// Project:        	Moving innovation
// Creation Date:  	15/04/2024
// Last Update:    	15/04/2024
// Authors:         Laura Arnemann
//					Theresa Bührle
// Goal: 			Running Stacked Regression
////////////////////////////////////////////////////////////////////////////////


use "${TEMP}/final_state_stacked_rd_credit_incr.dta", clear 
merge m:1 estab  year using "${TEMP}/final_state_stacked_zeros.dta", nogen keep(3)

*Generate the event indicators
		forvalues i=1/4{
			gen f`i'_binary = ry_increase==-`i'
			label var f`i'_binary "- `i'"
		}

		forvalues i=0/4 {
			gen l`i'_binary = ry_increase==`i'
			label var l`i'_binary "`i'"
		}

		drop f1_binary 
		gen zero_1=1
		label var zero_1 "-1" 

		
		gen ln_gdp=log(gdp)
		gen ln_gdp_other=log(total_gdp)
		gen ln_state_rd_exp=log(state_rd_exp)
		gen ln_state_rd_exp_other=log(state_rd_exp_other)
		
		
foreach var of varlist patents3 n_inventors3 n_newinventors3 {
		
		
ppmlhdfe `var' f4_binary f3_binary f2_binary zero_1 l?_binary pit cit ln_gdp unemployment if inrange(year, 1988, 2018), absorb(estab#event year#event) cl(fips_state#event)
est sto `var'reg1

coefplot `var'reg1, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
			xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) keep(f?_binary zero_1 l?_binary) ///
			yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
		 xtitle("Years since Change") graphregion(color(white))
capture noisily graph export "${OVERLEAF}/graphs/eventstudies/stacked_rd_credit_incr_sample7_`var'.png", replace  
		
		 
ppmlhdfe `var' f4_binary f3_binary f2_binary zero_1 l?_binary pit cit ln_gdp unemployment if inrange(year, 1988, 2018) & rd_credit_other!=., absorb(estab#event year#event) cl(fips_state#event)
est sto `var'reg2

coefplot `var'reg2, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
			xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) keep(f?_binary zero_1 l?_binary) ///
			yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
		 xtitle("Years since Change") graphregion(color(white))
capture noisily graph export "${OVERLEAF}/graphs/eventstudies/stacked_rd_credit_incr_sample5_`var'.png", replace  
		
		}
		 
		 
********************************************************************************
* Changes at other R&D locations 
********************************************************************************		 


use "${TEMP}/final_state_stacked_other_total_rd_credit_incr.dta", replace 
merge m:1 estab year using "${TEMP}/final_state_stacked_other_zeros.dta", nogen keep(3)

*Generate the event indicators
			forvalues i=1/4{
				gen f`i'_binary = ry_increase==-`i'
				label var f`i'_binary "- `i'"
			}

			forvalues i=0/4 {
				gen l`i'_binary = ry_increase==`i'
				label var l`i'_binary "`i'"
			}

			drop f1_binary 
			gen zero_1=1
			label var zero_1 "-1" 
		 
		 gen ln_gdp=log(gdp)
		gen ln_gdp_other=log(total_gdp)
	
foreach var of varlist patents3 n_inventors3 n_newinventors3 {
		
		
ppmlhdfe `var' f4_binary f3_binary f2_binary zero_1 l?_binary rd_credit pit cit ln_gdp unemployment pit_other cit_other ln_gdp_other unemployment_other if inrange(year, 1988, 2018), absorb(estab#event year#event) cl(fips_state#event)
est sto `var'reg1

coefplot `var'reg1, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
			xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) keep(f?_binary zero_1 l?_binary) ///
			yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
		 xtitle("Years since Change") graphregion(color(white))
capture noisily graph export "${OVERLEAF}/graphs/eventstudies/stacked_rd_credit_incr_other_sample7_`var'.png", replace  
		
		  }		 
		 
		 
		 
		 
		 
		 
		 
		 
		 
* Making sense of the switch in the coefficient we observe 

use "${TEMP}/final_state_stacked_other_zeros.dta", clear
bysort assignee_id year : egen n_patents = total(patents3) 
bysort assignee_id year : gen n_states = _N 

merge 1:m assignee_id fips_state year using "${TEMP}/final_state_stacked_other_credit_incr.dta"
drop if _merge==2 

duplicates drop assignee_id year fips_state, force 

sum n_patents n_states patents3 n_inventors3 if _merge==1
sum n_patents n_states patents3 n_inventors3 if _merge==3