////////////////////////////////////////////////////////////////////////////////
// Project:        	Moving innovation
// Creation Date:  	15/04/2024
// Last Update:    	15/04/2024
// Authors:         Laura Arnemann
//					Theresa Bührle
// Goal: 			Running Standard Regression
////////////////////////////////////////////////////////////////////////////////

global lead=4 	// set leads
global lag=4	// set lags

global controls pit cit 
global controls_other rd_credit_other pit_other cit_other

global controls2 $controls ln_gdp unemployment 
global controls_other2 $controls_other ln_gdp_other unemployment_other 

* Prepare dataset --------------------------------------------------------------

use  "${TEMP}/final_state_zeros.dta", clear 
drop if missing(assignee_id)

egen estab = group(assignee_id fips_state)
xtset estab year 

* Generate event study variables
xtset estab year 
sort estab year

foreach var in rd_credit pit cit {
	
	* Change at current location x	x	x	x	x	x	x	x	x	x	x	x	x
	
	* Generate change variable
	gen change_`var' = `var' - l.`var'
	replace change_`var' = 0 if inrange(change_`var', -1, 1)
		
	* Generate event dummy
	gen incr_`var' = 1 if change_`var' > 0 & change_`var' != .
	replace incr_`var' =  0 if change_`var' == 0 
	
	gen decr_`var' = 1 if change_`var' < 0 & change_`var' != .
	replace decr_`var' =  0 if change_`var' == 0 
	
	foreach y in "incr_`var'" "decr_`var'" {
		sort estab year

		* Generate lead dummies
		forval f=${lead}(-1)1{
			capture drop F`f'_`y'
			gen F`f'_`y'=F`f'.`y'
			label var  F`f'_`y' "- `f'"
		}
			
		* Generate lag dummies
		forval l=0/${lag}{
			capture drop L`l'_`y'
			gen L`l'_`y'=L`l'.`y'
			label var  L`l'_`y' "`l'"
		}
		

		gen zero_`y'=1
		label var zero_`y' "-1" 
			
		* Filling up
		foreach x in F L{
			forvalues i=0/${lag}{
				capture replace `x'`i'_`y'=0 if `x'`i'_`y'==.
			}
		}
		
		* Bin up ends of the event window
		capture drop sum_F${lead}_`y'
		gsort estab -year
		bysort estab: gen sum_F${lead}_`y'=sum(F${lead}_`y')
		replace F${lead}_`y'=sum_F${lead}_`y'

		sort estab year
		capture drop sum_L${lag}_`y'
		bysort estab: gen sum_L${lag}_`y'=sum(L${lag}_`y')
		replace L${lag}_`y'=sum_L${lag}_`y' 

		drop sum_L${lag}_`y' 
		drop sum_F${lead}_`y'
		
		*drop F1_`y'
		
		* Post dummy for DiD
		gen post_`y'  = 0
		forval l=0/${lag}{
			replace post_`y' = 1 if L`l'_`y' == 1
		}
		
		* Generate an indicator for being treated
		bysort estab: egen max_tr_`y' = max(`y')
		
		gen treat_after_`y'=post_`y'*max_tr_`y'
				
		* Drop treated units if they experienced a tax change four years prior to the reform
		sort estab year
		generate helper = 0 
		forval n=${lead}(-1)1{
			replace helper = 1 if change_`var'[_n-`n'] == 1 & estab == estab[_n-`n']
		}
		
		bysort estab: egen max_helper = max(helper)
		drop if max_helper ==1 
		drop helper max_helper
	}
	
	* Drop treated units if they experienced a reversal of the tax change in the the periods following the initial tax change 
	bysort estab: egen max_change_`var' = max(change_`var')
	bysort estab: egen min_change_`var' = min(change_`var')	
	
	gen taxreversal = 0 
	replace taxreversal = 1 if max_tr_incr_`var' ==1 & min_change_`var' < 0 
	replace taxreversal = 1 if max_tr_decr_`var' ==1 & max_change_`var' > 0 
	bysort estab: egen max_taxreversal = max(taxreversal)
	drop if max_taxreversal==1 
	drop max_taxreversal taxreversal 
	
	
	* Change at other locations x	x	x	x	x	x	x	x	x	x	x	x	x
		
	* Generate change variable
	gen change_oth_`var' = total_`var' - l.total_`var'
	replace change_oth_`var' = 0 if inrange(change_oth_`var', -1, 1)
		
	* Generate event dummy
	gen incr_oth_`var' = 1 if change_oth_`var' > 0 & change_oth_`var' != .
	replace incr_oth_`var' =  0 if change_oth_`var' == 0 
	
	gen decr_oth_`var' = 1 if change_oth_`var' < 0 & change_oth_`var' != .
	replace decr_oth_`var' =  0 if change_oth_`var' == 0 
	
	foreach y in incr_oth_`var' decr_oth_`var' {
		sort estab year

		* Generate lead dummies
		forval f=${lead}(-1)1{
			capture drop F`f'_`y'
			gen F`f'_`y'=F`f'.`y'
			label var  F`f'_`y' "- `f'"
		}
			
		* Generate lag dummies
		forval l=0/${lag}{
			capture drop L`l'_`y'
			gen L`l'_`y'=L`l'.`y'
			label var L`l'_`y' "`l'"
		}
		
		gen zero_`y'=1
		label var zero_`y' "-1" 
			
		* Filling up
		foreach x in F L{
			forvalues i=0/${lag}{
				capture replace `x'`i'_`y'=0 if `x'`i'_`y'==.
			}
		}
		
		* Bin up ends of the event window
		capture drop sum_F${lead}_`y'
		gsort estab -year
		bysort estab: gen sum_F${lead}_`y'=sum(F${lead}_`y')
		replace F${lead}_`y'=sum_F${lead}_`y'

		sort estab year
		capture drop sum_L${lag}_`y'
		bysort estab: gen sum_L${lag}_`y'=sum(L${lag}_`y')
		replace L${lag}_`y'=sum_L${lag}_`y' 

		drop sum_L${lag}_`y' 
		drop sum_F${lead}_`y'
		
		*drop F1_`y'
		
		* Post dummy for DiD
		gen post_`y'  = 0
		forval l=0/${lag}{
			replace post_`y' = 1 if L`l'_`y' == 1
		}
		
		* Generate an indicator for being treated
		bysort estab: egen max_tr_`y' = max(`y')
		
		gen treat_after_`y'=post_`y'*max_tr_`y'
		
		* Drop treated units if they experienced a tax change four years prior to the reform
		sort estab year
		generate helper = 0 
		forval n=${lead}(-1)1{
			replace helper = 1 if change_oth_`var'[_n-`n'] == 1 & estab == estab[_n-`n']
		}
		
		bysort estab: egen max_helper = max(helper)
		drop if max_helper ==1 
		drop helper max_helper
	}
	
	* Drop treated units if they experienced a reversal of the tax change in the the periods following the initial tax change 
	bysort estab: egen max_change_oth_`var' = max(change_oth_`var')
	bysort estab: egen min_change_oth_`var' = min(change_oth_`var')	
	
	gen taxreversal = 0 
	replace taxreversal = 1 if max_tr_incr_oth_`var' ==1 & min_change_oth_`var' < 0 
	replace taxreversal = 1 if max_tr_decr_oth_`var' ==1 & max_change_oth_`var' > 0 
	bysort estab: egen max_taxreversal = max(taxreversal)
	drop if max_taxreversal==1 
	drop max_taxreversal taxreversal 
}		
	
* Winsorize and log variables			
foreach var of varlist patents1 patents2 patents3 n_inventors1 n_inventors2 n_inventors3 {
	gstats winsor `var', cut(1 99) gen(`var'_w1)
	gstats winsor `var', cut(1 95) gen(`var'_w2)
	gen ln_`var'=log(`var')
}

gen ln_gdp=log(gdp)
gen ln_gdp_other=log(total_gdp)
gen ln_state_rd_exp=log(state_rd_exp)
gen ln_state_rd_exp_other=log(state_rd_exp_other)

save  "${TEMP}/final_state_standard_regfile.dta", replace 

* Regression -------------------------------------------------------------------

use  "${TEMP}/final_state_standard_regfile.dta", clear 
keep if inrange(year, 1988, 2018)

local outcome patents3
// patents3 share_patents3_multistate n_inventors3 n_newinventors3

local sample1 if inrange(year, 1988, 2018)
local sample2 if inrange(year, 1988, 2014) 
local sample3 if inrange(year, 1988, 2005)

forvalues i =1/3 {

	foreach var in rd_credit oth_rd_credit  {
	// rd_credit pit cit oth_rd_credit oth_pit oth_cit
		foreach direct in incr {
		// incr decr 
			foreach outc in `outcome' {

				* Event studies
				capture noisily ppmlhdfe `outc' (F4_`direct'_`var' - F2_`direct'_`var') L*_`direct'_`var' F1_`direct'_`var' ///
					`sample`i'', absorb(estab year) cl(fips_state)
				capture noisily est sto inventorreg1
				capture noisily coefplot inventorreg1, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
					xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
					keep(F?_`direct'_`var' F1_`direct'_`var' L?_`direct'_`var') order(F4_`direct'_`var' F3_`direct'_`var' F2_`direct'_`var' F1_`direct'_`var') ///
					yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ytitle("`outc'")  ///
					title("`var', `direct' - no controls") xtitle("Years since Change") graphregion(color(white))
					capture noisily graph export "${RESULTS}/graphs/`outc'/standard_`direct'_`var'_sample`i'.png", replace 
					
				capture noisily ppmlhdfe `outc' (F4_`direct'_`var' - F2_`direct'_`var') L*_`direct'_`var' F1_`direct'_`var' ///
					$controls `sample`i'', absorb(estab year) cl(fips_state)
				capture noisily est sto inventorreg2
				capture noisily coefplot inventorreg2, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
					xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
					keep(F?_`direct'_`var' F1_`direct'_`var' L?_`direct'_`var') order(F4_`direct'_`var' F3_`direct'_`var' F2_`direct'_`var' F1_`direct'_`var') ///
					yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ytitle("`outc'")  ///
					title("`var', `direct' - controls") xtitle("Years since Change") graphregion(color(white))
					capture noisily graph export "${RESULTS}/graphs/`outc'/standard_`direct'_`var'_c1_sample`i'.png", replace 

				capture noisily ppmlhdfe `outc' (F4_`direct'_`var' - F2_`direct'_`var') L*_`direct'_`var' F1_`direct'_`var' ///
					$controls $controls_other `sample`i'', absorb(estab year) cl(fips_state)
				capture noisily est sto inventorreg2
				capture noisily coefplot inventorreg2, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
					xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
					keep(F?_`direct'_`var' F1_`direct'_`var' L?_`direct'_`var') order(F4_`direct'_`var' F3_`direct'_`var' F2_`direct'_`var' F1_`direct'_`var') ///
					yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ytitle("`outc'")  ///
					title("`var', `direct' - controls (incl other)") xtitle("Years since Change") graphregion(color(white))
					capture noisily graph export "${RESULTS}/graphs/`outc'/standard_`direct'_`var'c2_sample`i'.png", replace 	
					
				capture noisily ppmlhdfe `outc' (F4_`direct'_`var' - F2_`direct'_`var') L*_`direct'_`var' F1_`direct'_`var' ///
					 $controls2 $controls_other2 `sample`i'', absorb(estab year) cl(fips_state)
				capture noisily est sto inventorreg2
				capture noisily coefplot inventorreg2, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
					xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
					keep(F?_`direct'_`var' F1_`direct'_`var' L?_`direct'_`var') order(F4_`direct'_`var' F3_`direct'_`var' F2_`direct'_`var' F1_`direct'_`var') ///
					yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ytitle("`outc'")  ///
					title("`var', `direct' - controls (incl other, gdp, unempl)") xtitle("Years since Change") graphregion(color(white))
					capture noisily graph export "${RESULTS}/graphs/`outc'/standard_`direct'_`var'_c3_sample`i'.png", replace 
					
				* DiD
				// capture noisily ppmlhdfe `outc' c.post_`direct'_`var'#c.max_tr_`direct'_`var', absorb(estab year) cl(fips_state)
				capture noisily ppmlhdfe `outc' treat_after_`direct'_`var' `sample`i'', absorb(estab year) cl(fips_state)
					capture noisily outreg2 using "$RESULTS/tables/`outc'/change_stand_`direct'_`var'_sample`i'", ///
					replace dec(3) stats(coef se) addstat(Pseudo R2, e(r2_p)) noni nodepvar tex(frag) ///
					ctitle("`outc'") lab
					
				capture noisily ppmlhdfe `outc' treat_after_`direct'_`var' $controls `sample`i'', absorb(estab year) cl(fips_state)
					capture noisily outreg2 using "$RESULTS/tables/`outc'/change_stand_`direct'_`var'_sample`i'", ///
					append dec(3) stats(coef se) addstat(Pseudo R2, e(r2_p)) noni nodepvar tex(frag) ///
					ctitle("`outc'") lab
				
				capture noisily ppmlhdfe `outc' treat_after_`direct'_`var' $controls $controls_other `sample`i'', absorb(estab year) cl(fips_state)
					capture noisily outreg2 using "$RESULTS/tables/`outc'/change_stand_`direct'_`var'_sample`i'", ///
					append dec(3) stats(coef se) addstat(Pseudo R2, e(r2_p)) noni nodepvar tex(frag) ///
					ctitle("`outc'") lab
				
				capture noisily ppmlhdfe `outc' treat_after_`direct'_`var' $controls2 $controls_other2 `sample`i'', absorb(estab year) cl(fips_state)
					capture noisily outreg2 using "$RESULTS/tables/`outc'/change_stand_`direct'_`var'_sample`i'", ///
					append dec(3) stats(coef se) addstat(Pseudo R2, e(r2_p)) noni nodepvar tex(frag) ///
					ctitle("`outc'") lab	
			}
		}
	}
}
