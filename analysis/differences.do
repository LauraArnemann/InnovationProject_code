// Project: Inventor Relocation
// Creation Date: 15/06/2024
// Last Update: 15/06/2024
// Author: Laura Arnemann 
// Goal: Figuring out difference between stacked and regular regression



use "${TEMP}/final_state_stacked_other_zeros_${dataset}_gvkey.dta", clear 

* Generating the "event identifiers"
drop change*

xtset estab year 
foreach explaining in all weighted threelargest {
    gen change_`explaining' = other_`explaining'3 - l.other_`explaining'3
    gen byte increase_`explaining' = change_`explaining'>0
    gen byte decrease_`explaining' = change_`explaining'<0
}



foreach explaining in all weighted threelargest {
foreach x in change_`explaining' increase_`explaining' decrease_`explaining' {

	forval f = 4(-1)1 {
		gen F`f'_`x' = F`f'.`x'		
		label var F`f'_`x' "- `f'"
		replace F`f'_`x' = 0 if inrange(F`f'_`x', -1, 1)
		replace F`f'_`x'=1 if F`f'_`x'>1 & F`f'_`x'!=.
		*replace F`f'_`x'=0 if F`f'_`x'<-1 & F`f'_`x'!=.
		
	} // f

	forval l = 0(1)4{		
		gen L`l'_`x' = L`l'.`x'
		label var L`l'_`x' " `l'"
		replace L`l'_`x' = 0 if inrange(L`l'_`x', -1, 1)
		replace L`l'_`x'=1 if L`l'_`x'>1 & L`l'_`x'!=.
		*replace L`l'_`x'=0 if L`l'_`x'<-1 & L`l'_`x'!=.
	} // l

}
}

drop F1* 
gen zero_1=1
label var zero_1 "-1"
tempfile helper 
save `helper'

*all weighted 
foreach explaining in threelargest {
*other_weighted3 other_threelargest3
use "${TEMP}/final_state_stacked_other_`explaining'3_incr_${dataset}_gvkey_year.dta", replace 
merge m:1 estab year using `helper'
keep if _merge==3 
drop _merge 



			foreach var of varlist patents1 patents2 patents3 n_inventors1 n_inventors2 n_inventors3 n_newinventors3 {
				gstats winsor `var', cut(1 99) gen(`var'_w1)
				gstats winsor `var', cut(1 95) gen(`var'_w2)
				gen ln_`var'=log(`var')
			}
			
			gen ln_gdp = log(other_`explaining'3_gdp)
			
			bysort assignee_id year event: egen total_patents = total(patents3)
			
			*Generate the event indicators
			forvalues i=1/4 {
				gen f`i'_binary = ry_increase==-`i'
				label var f`i'_binary "- `i'"
			}

			forvalues i=0/4 {
				gen l`i'_binary = ry_increase==`i'
				label var l`i'_binary "`i'"
			}


* Set different sample restrictions as well 
		 	local sample1 if inrange(year, 1988, 2014) 
		    local sample2 if inrange(year, 1988, 2014)  & n_patents>5 
		    local sample3 if inrange(year, 1988, 2014)  & n_patents!=0 
			local sample4 if inrange(year, 1988, 2018) & estab_patents>5
			 local sample5 if inrange(year, 1988, 2018)  & total_patents>10 
			 local sample6 if inrange(year, 1988, 2018)  & balanced_panel==1
			 local sample7 if inrange(year, 1988, 2018) & total_patents>10 
			 local sample8 if inrange(year, 1988, 2018) & total_patents>10 
			  
			local other_controls other_`explaining'3_cit  other_`explaining'3_pit  other_`explaining'3_unemployment other_`explaining'3_gdp
			

			
			forvalues i =1/1 {
				
				foreach outc in n_inventors3_w1 n_newinventors3_w1 {
				
				
				*Event studies
				ppmlhdfe `outc'   F?_change_`explaining' zero_1 L?_change_`explaining' `sample`i'', absorb(estab#event year#event#fips_state) cl(estab#event)
				 est sto inventorreg1
				coefplot inventorreg1, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
				xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) keep(F?_change_`explaining' zero_1 L?_change_`explaining' ) ///
				yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
				title("`var2', `direction' - no controls") xtitle("Years since Change") graphregion(color(white))
					*capture noisily graph export "${RESULTS}/stackedregression/new_`type'_${dataset}/`outc'/stacked_other_`var2'_`direction'_sample`i'_stateyear.png", replace  
					
				ppmlhdfe `outc'   f4_binary f3_binary f2_binary zero_1 l?_binary `sample`i'', absorb(estab#event year#event#fips_state) cl(estab#event)
				 est sto inventorreg1
				coefplot inventorreg1, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
				xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) keep(f4_binary f3_binary f2_binary zero_1 l?_binary ) ///
				yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
				title("`var2', `direction' - no controls") xtitle("Years since Change") graphregion(color(white))
					
				 ppmlhdfe `outc'  F?_change_`explaining' zero_1 L?_change_`explaining'  `other_controls' `sample`i'', absorb(estab#event year#event#fips_state) cl(estab#event)
				 est sto inventorreg3
				coefplot inventorreg3, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
				xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) keep(F?_change_`explaining' zero_1 L?_change_`explaining') ///
				yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
				title("`var2', `direction' - controls (incl other)") xtitle("Years since Change") graphregion(color(white))
					*capture noisily graph export "${RESULTS}/stackedregression/new_`type'_${dataset}/`outc'/stacked_other_`var2'_`direction'_c2_sample`i'_stateyear.png", replace  

				ppmlhdfe `outc' f4_binary f3_binary f2_binary zero_1 l?_binary  `other_controls' `sample`i'', absorb(estab#event year#event#fips_state) cl(estab#event)
				 est sto inventorreg3
				coefplot inventorreg3, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
				xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) keep(f4_binary f3_binary f2_binary zero_1 l?_binary) ///
				yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
				title("`var2', `direction' - controls (incl other)") xtitle("Years since Change") graphregion(color(white))
* Also run the logarithm to give comparability with chaisemartin estimator 
			

				}
					
					
					foreach outc in ln_n_inventors3 ln_n_newinventors3 {
				
		reghdfe `outc'  F?_change_`explaining' zero_1 L?_change_`explaining'  `other_controls' `sample`i'', absorb(estab#event year#event#fips_state) cl(estab#event)
				 est sto inventorreg3
				coefplot inventorreg3, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
				xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) keep(F?_change_`explaining' zero_1 L?_change_`explaining') ///
				yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
				title("`var2', `direction' - controls (incl other)") xtitle("Years since Change") graphregion(color(white))
			
							
		reghdfe `outc'  f4_binary f3_binary f2_binary zero_1 l?_binary `other_controls' `sample`i'', absorb(estab#event year#event#fips_state) cl(estab#event)
				 est sto inventorreg3
				coefplot inventorreg3, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
				xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) keep(f4_binary f3_binary f2_binary zero_1 l?_binary) ///
				yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
				title("`var2', `direction' - controls (incl other)") xtitle("Years since Change") graphregion(color(white))
					*capture noisily graph export "${RESULTS}/stackedregression/new_`type'_${dataset}/`outc'/stacked_other_`var2'_`direction'_c2_sample`i'_stateyear.png", replace  
			}
		}		
		
		
	}



