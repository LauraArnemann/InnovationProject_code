////////////////////////////////////////////////////////////////////////////////
// Project:        	Moving innovation
// Creation Date:  	04/07/2024
// Last Update:    	05/07/2024
// Authors:         Laura Arnemann
//					Theresa Bührle
// Goal: 			Calculating spillover with two-way fixed effects analysis
////////////////////////////////////////////////////////////////////////////////
	*https://github.com/sergiocorreia/ppmlhdfe/blob/master/guides/separation_primer.md
	

********************************************************************************
* Analysis on assignee level 
********************************************************************************	

use "${TEMP}/final_cz_${dataset}.dta", clear 

	foreach var of varlist patents3 n_inventors3 n_newinventors3 {
		gstats winsor `var', cut(1 99) gen(`var'_w1)
		gstats winsor `var', cut(1 95) gen(`var'_w2)
		gen ln_`var'=log(`var')
}


bysort estab_id: egen estab_patents = total(patents3)

	label var pit "PIT"
	label var cit "CIT"
	label var rd_credit "R\&D Credit"

xtset estab_id year 


forvalues i =1/6 {
gen change_otherstates`i' = cz_treated_change_w`i' 
gen byte incr_otherstates`i'  = change_otherstates`i'  >0
replace incr_otherstates`i'  = . if change_otherstates`i' <0 
gen byte decr_otherstates`i'  = change_otherstates`i'  <0
replace decr_otherstates`i'  = . if change_otherstates`i' >0 

		
foreach x in change_otherstates`i'  {
	
	forval f = 4(-1)1 {
		gen F`f'_`x' = F`f'.`x'		
		label var F`f'_`x' "- `f'"
		} // f

	forval l = 0(1)4{		
		gen L`l'_`x' = L`l'.`x'
		label var L`l'_`x' " `l'"
		} // l
			
	* Binning off of the event studies: 
	capture drop sum_F4_`x'
	gsort estab_id -year
	bysort estab_id: gen sum_F4_`x'=sum(F4_`x')

	sort estab_id year
	capture drop sum_L4_`x'
	bysort estab_id: gen sum_L4_`x'=sum(L4_`x')	
}
}
drop F1* 
gen zero_1=1
label var zero_1 "-1"

bysort assignee_id: egen total_patents = total(patents3)
replace change_other_threelargest = 0 if missing(change_other_threelargest)


*SAMPLE SLECTION:: ROBUSTNESS CHECK
*keep if tag_local == 1

*CHANGES -----------------------------------------------------------------------

* Outcome Variables 
local outcome n_inventors3_w1 patents3_w1 n_newinventors3_w1 
local outcome_log ln_n_inventors3 ln_patents3 ln_n_newinventors3 

local direction change

		
local sample1 if inrange(year, 1988, 2018)
local sample2 if inrange(year, 1988, 2018) & total_patents>10 
local sample3 if inrange(year, 1988, 2018) & total_patents<10 
local sample4 if inrange(year, 1988, 2018) & pub_assg==1 
local sample5 if inrange(year, 1988, 2018) & asg_corp==1
local sample6 if inrange(year, 1988, 2018) & noncorp_asg==0
local sample7 if inrange(year, 1988, 2018) & max_tr_other_threelargest!=1 
local sample8 if inrange(year, 1988, 2018) & tag_local==1
local sample9 if inrange(year, 1988, 2018) & treated!=1  	
local sample10 if inrange(year, 1988, 2018) & multistate_cz ==0 

			

foreach expl of numlist 1 2 3 4 5 6  { 		
		
	********************************************************************************
	* Regular event studies: No binning off 
	********************************************************************************

	forvalues i = 1/10 {
			local cl czone 
		** Poisson Regression 
		foreach var of varlist `outcome' {
 
	
				
			ppmlhdfe `var' F?_`direction'_otherstates`expl' zero_1 L?_`direction'_otherstates`expl' `sample`i'' & treated!=1, absorb(estab_id year#i.fips_state) cl(`cl')
			est sto regres1
			coefplot regres1, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
				keep(F?_`direction'_otherstates`expl' zero_1 L?_`direction'_otherstates`expl') yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
				xtitle("Years since `direction'") ytitle(`var') graphregion(color(white))
			capture noisily graph export "$RESULTS/eventstudies/estab/weight`expl'/`var'_spillover_sample`i'_c1_nobin_`direction'.png", replace
					
		
		* Also control for the change in other states 
		

			ppmlhdfe `var' change_other_threelargest F?_`direction'_otherstates`expl' zero_1 L?_`direction'_otherstates`expl' `sample`i'', absorb(estab_id year#i.fips_state) cl(`cl')
			est sto regres1
			coefplot regres1, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
				keep(F?_`direction'_otherstates`expl' zero_1 L?_`direction'_otherstates`expl') yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
				xtitle("Years since `direction'") ytitle(`var') graphregion(color(white))
			capture noisily graph export "$RESULTS/eventstudies/estab/weight`expl'/`var'_spillover_sample`i'_c2_nobin_`direction'.png", replace
		}
		


			
		** Regular Regression
		foreach var of varlist `outcome_log' {
			
				
			reghdfe `var' F?_`direction'_otherstates`expl' zero_1 L?_`direction'_otherstates`expl' `sample`i'' &  treated!=1, absorb(estab_id year#i.fips_state) cl(`cl')
			est sto regres3
			coefplot regres3, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
				keep(F?_`direction'_otherstates`expl' zero_1 L?_`direction'_otherstates`expl') yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
				xtitle("Years since `direction'") ytitle(`var') graphregion(color(white))
			capture noisily graph export "$RESULTS/eventstudies/estab/weight`expl'/var`var'_spillover_sample`i'_c1_nobin_`direction'.png", replace
				
				
		reghdfe `var' change_other_threelargest F?_`direction'_otherstates`expl' zero_1 L?_`direction'_otherstates`expl' `sample`i'', absorb(estab_id year#i.fips_state) cl(`cl')
			est sto regres3
			coefplot regres3, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
				keep(F?_`direction'_otherstates`expl' zero_1 L?_`direction'_otherstates`expl') yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
				xtitle("Years since `direction'") ytitle(`var') graphregion(color(white))
			capture noisily graph export "$RESULTS/eventstudies/estab/weight`expl'/var`var'_spillover_sample`i'_c2_nobin_`direction'.png", replace
				
				

		}
	
}
}	
	********************************************************************************
	* Regular Event Studies: Binning Off 
	********************************************************************************

foreach expl of numlist 1 2 3 4 5 6 { 		
	foreach x in change_otherstates`expl' {
		replace F4_`x'=sum_F4_`x'
		replace L4_`x'=sum_L4_`x'
	}
		 

	forvalues i = 1/10 {
			
		** Poisson Regression
		foreach var of varlist `outcome' {
			
			if `i'!=9 {

			ppmlhdfe `var' F?_`direction'_otherstates`expl' zero_1 L?_`direction'_otherstates`expl' `sample`i'', absorb(estab_id year#i.fips_state) cl(`cl')
			est sto regres1
			coefplot regres1, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
				keep(F?_`direction'_otherstates`expl' zero_1 L?_`direction'_otherstates`expl') yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
				xtitle("Years since `direction'") ytitle(`var') graphregion(color(white))
			capture noisily graph export "$RESULTS/eventstudies/estab/weight`expl'/var`var'_spillover_sample`i'_c1_binning_`direction'.png", replace
			}
			
			
			ppmlhdfe `var' change_other_threelargest F?_`direction'_otherstates`expl' zero_1 L?_`direction'_otherstates`expl' `sample`i'', absorb(estab_id year#i.fips_state) cl(`cl')
			est sto regres1
			coefplot regres1, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
				keep(F?_`direction'_otherstates`expl' zero_1 L?_`direction'_otherstates`expl') yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
				xtitle("Years since `direction'") ytitle(`var') graphregion(color(white))
			capture noisily graph export "$RESULTS/eventstudies/estab/weight`expl'/var`var'_spillover_sample`i'_c2_binning_`direction'.png", replace
				

		}

			
		** Regular Regression
		foreach var of varlist `outcome_log'  {
			
				if `i'!=9 {
			reghdfe `var' F?_`direction'_otherstates`expl' zero_1 L?_`direction'_otherstates`expl' `sample`i'', absorb(estab_id year#i.fips_state) cl(`cl')
			est sto regres3
			coefplot regres3, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
				keep(F?_`direction'_otherstates`expl' zero_1 L?_`direction'_otherstates`expl') yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
				xtitle("Years since `direction'") ytitle(`var') graphregion(color(white))
			capture noisily graph export "$RESULTS/eventstudies/estab/weight`expl'/var`var'_spillover_sample`i'_c1_binning_`direction'.png", replace
				}
			
		
			reghdfe `var' F?_`direction'_otherstates`expl' zero_1 L?_`direction'_otherstates`expl' `sample`i'', absorb(estab_id year#i.fips_state) cl(`cl')
			est sto regres3
			coefplot regres3, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
				keep(F?_`direction'_otherstates`expl' zero_1 L?_`direction'_otherstates`expl') yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
				xtitle("Years since `direction'") ytitle(`var') graphregion(color(white))
			capture noisily graph export "$RESULTS/eventstudies/estab/weight`expl'/var`var'_spillover_sample`i'_c2_binning_`direction'.png", replace
			

		}
	}

}












