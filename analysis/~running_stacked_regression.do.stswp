// Project: Inventor Relocation
// Creation Date: 19/03/2024
// Last Update: 20/03/2024
// Author: Laura Arnemann 
// Goal: Running Stacked Regression

global controls gdp unemployment
global controls_other gdp_other unemployment_other

foreach direction in "incr" "decr" {

	foreach indepvar in "credit" "pit" "cit" {

		* Stacked Regression for a change in RD Tax Credits 

		use "${TEMP}/final_state_stacked_`indepvar'_`direction'.dta", clear 

		egen assignee = group(assignee_id)

		foreach var of varlist patents1 patents2 patents3 n_inventors1 n_inventors2 n_inventors3 {
			gstats winsor `var', cut(1 99) gen(`var'_w1)
			gstats winsor `var', cut(1 95) gen(`var'_w2)
			gen ln_`var'=log(`var')
		}

		gen ln_gdp=log(gdp)
		gen ln_total_gdp=log(total_gdp)

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


		reghdfe patents3_w1 f4_binary f3_binary f2_binary zero_1 l?_binary, absorb(estab#event year#event) cl(fips_state#event)
		est sto inventorreg
		coefplot inventorreg, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
		xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) keep(f?_binary zero_1 l?_binary) ///
		yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
		title("`indepvar', `direction' - no controls") xtitle("Years since Change") graphregion(color(white))
			graph export "$RESULTS\graphs\stacked_`indepvar'_`direction'.png", replace  
		
		reghdfe patents3_w1 f4_binary f3_binary f2_binary zero_1 l?_binary $controls, absorb(estab#event year#event) cl(fips_state#event)
		est sto inventorreg
		coefplot inventorreg, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
		xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) keep(f?_binary zero_1 l?_binary) ///
		yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
		title("`indepvar', `direction' - controls") xtitle("Years since Change") graphregion(color(white))
			graph export "$RESULTS\graphs\stacked_`indepvar'_`direction'_c1.png", replace  
			
		reghdfe patents3_w1 f4_binary f3_binary f2_binary zero_1 l?_binary $controls $controls_other, absorb(estab#event year#event) cl(fips_state#event)
		est sto inventorreg
		coefplot inventorreg, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
		xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) keep(f?_binary zero_1 l?_binary) ///
		yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
		title("`indepvar', `direction' - controls (incl other)") xtitle("Years since Change") graphregion(color(white))
			graph export "$RESULTS\graphs\stacked_`indepvar'_`direction'_c2.png", replace  

		********************************************************************************
		* Credit Changes at other locations 
		********************************************************************************

		use "${TEMP}/final_state_stacked_other_`indepvar'_`direction'.dta", replace 
		egen assignee = group(assignee_id)

		foreach var of varlist patents1 patents2 patents3 n_inventors1 n_inventors2 n_inventors3 {
			gstats winsor `var', cut(1 99) gen(`var'_w1)
			gstats winsor `var', cut(1 95) gen(`var'_w2)
			gen ln_`var'=log(`var')
		}

		gen ln_gdp=log(gdp)
		gen ln_total_gdp=log(total_gdp)

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

		reghdfe patents3_w1 f4_binary f3_binary f2_binary zero_1 l?_binary, absorb(estab#event year#event) cl(fips_state#event)
		est sto inventorreg
		coefplot inventorreg, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
		xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) keep(f?_binary zero_1 l?_binary) ///
		yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
		title("`indepvar', other, `direction' - no controls") xtitle("Years since Change") graphregion(color(white))
			graph export "$RESULTS\graphs\stacked_other_`indepvar'_`direction'.png", replace  
		
		reghdfe patents3_w1 f4_binary f3_binary f2_binary zero_1 l?_binary $controls, absorb(estab#event year#event) cl(fips_state#event)
		est sto inventorreg
		coefplot inventorreg, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
		xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) keep(f?_binary zero_1 l?_binary) ///
		yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
		title("`indepvar', other, `direction' - controls") xtitle("Years since Change") graphregion(color(white))
			graph export "$RESULTS\graphs\stacked_other_`indepvar'_`direction'_c1.png", replace  
			
		reghdfe patents3_w1 f4_binary f3_binary f2_binary zero_1 l?_binary $controls $controls_other, absorb(estab#event year#event) cl(fips_state#event)
		est sto inventorreg
		coefplot inventorreg, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
		xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) keep(f?_binary zero_1 l?_binary) ///
		yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
		title("`indepvar', other, `direction' - controls (incl other)") xtitle("Years since Change") graphregion(color(white))
			graph export "$RESULTS\graphs\stacked_other_`indepvar'_`direction'_c2.png", replace  

	}
}