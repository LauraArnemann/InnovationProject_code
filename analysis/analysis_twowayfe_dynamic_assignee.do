// Project: Inventor Relocation
// Creation Date: 15/06/2024
// Last Update: 15/06/2024
// Author: Laura Arnemann 
// Goal: Regular two-way fixed effects analysis with event studies 

* Information on Assigee Type e.g. if assignee is governmental entity 
use "${TEMP}/patents_helper_${dataset}.dta", clear
bysort assignee_id: gen count = _n 
keep if count ==1  
tempfile patentshelper
save `patentshelper'

local sample1 if inrange(year, 1988, 2018)
local sample2 if inrange(year, 1988, 2018) & total_patents>10 
local sample3 if inrange(year, 1988, 2018) & estab_patents>10 
local sample4 if inrange(year, 1988, 2018) & patents3>10 
local sample5 if inrange(year, 1988, 2018) & noncorp_asg 
local sample6 if inrange(year, 1988, 2018) & noncorp_asg==0 
local sample7 if inrange(year, 1988, 2018) & noncorp_asg==0 & patents3>10
local sample8 if inrange(year, 1988, 2018) & asg_corp==1
local sample9 if inrange(year, 1988, 2018) & asg_corp==1 & patents3>10
local sample10 if inrange(year, 1988, 2018) & asg_corp==1 & total_patents>20


foreach type in assignee {
	
	use "${TEMP}/final_state_zeros_new_${dataset}_`type'.dta", clear 
	merge m:1 assignee_id using `patentshelper', keepusing(noncorp_asg asg_corp pub_assg)
	drop if _merge ==2 
	drop _merge 

	foreach var of varlist patents1 patents2 patents3 n_inventors1 n_inventors2 n_inventors3 n_newinventors1 n_newinventors3 {
		gstats winsor `var', cut(1 99) gen(`var'_w1)
		gstats winsor `var', cut(1 95) gen(`var'_w2)
		gen ln_`var'=log(`var')
}

	gen ln_gdp=log(gdp)

	foreach var of varlist other_gdp_weighted3 other_gdp_all3 other_gdp_threelargest3 {
		replace `var'=log(`var')
	}

	bysort assignee_id year: egen total_patents=total(patents3)

	********************************************************************************
	* Regular Regressions: Based on Assignee  Id 
	********************************************************************************
	egen estab_id = group(assignee_id fips_state)
	bysort estab_id: egen estab_patents = total(patents3)

	label var pit "PIT"
	label var cit "CIT"
	label var rd_credit "R\&D Credit"

	xtset estab_id year 
	foreach explaining in $weighting_strategy {
		gen change_`explaining' = other_rd_credit_`explaining'3 - l.other_rd_credit_`explaining'3
		gen byte increase_`explaining' = change_`explaining'>0
		gen byte decrease_`explaining' = change_`explaining'<0
	}

	foreach explaining in $weighting_strategy {
		
		foreach x in change_`explaining' increase_`explaining' decrease_`explaining' {

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

	
********************************************************************************
* Regular event studies: No binning off 
********************************************************************************
	/*
	forvalues i = 8/9 {
		
		** Poisson Regression 
		foreach var of varlist $outcome  {
			foreach explaining in $weighting_strategy  {

				* Generating the local which contains control variables 	
				local other_controls other_cit_`explaining' other_pit_`explaining'
					
				ppmlhdfe `var'  F?_change_`explaining' zero_1 L?_change_`explaining' `sample`i'', absorb(estab_id year#i.fips_state) cl(estab_id)
				est sto regres1
				coefplot regres1, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
					keep(F?_change_`explaining' zero_1 L?_change_`explaining') yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))
				capture noisily graph export "$RESULTS/eventstudies/new_`type'_${dataset}/var`var'_`explaining'_sample`i'_c1_balancednobin_`type'.png", replace

				ppmlhdfe `var' F?_change_`explaining' zero_1 L?_change_`explaining' `other_controls' `sample`i'', absorb(estab_id year#i.fips_state) cl(estab_id)
				est sto regres2
				coefplot regres2, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
					keep(F?_change_`explaining' zero_1 L?_change_`explaining') yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))
				capture noisily graph export "$RESULTS/eventstudies/new_`type'_${dataset}/var`var'_`explaining'_sample`i'_c2_balancednobin_`type'.png", replace
			} 
		}	
		
		** Regular Regression
		foreach var of varlist $outcome_log  {
			foreach explaining in $weighting_strategy  {

				reghdfe `var' F?_change_`explaining' zero_1 L?_change_`explaining' `sample`i'', absorb(estab_id year#i.fips_state) cl(estab_id)
				est sto regres3
				coefplot regres3, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
					keep(F?_change_`explaining' zero_1 L?_change_`explaining') yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))
				capture noisily graph export "$RESULTS/eventstudies/new_`type'_$dataset/var`var'_`explaining'_sample`i'_c3_balancednobin_`type'.png", replace

				reghdfe `var' F?_change_`explaining' zero_1 L?_change_`explaining' `other_controls' `sample`i'', absorb(estab_id year#i.fips_state) cl(estab_id)
				est sto regres4
				coefplot regres4, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
					keep(F?_change_`explaining' zero_1 L?_change_`explaining') yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))
				capture noisily graph export "$RESULTS/eventstudies/new_`type'_${dataset}/var`var'_`explaining'_sample`i'_c4_balancednobin_`type'.png", replace
			}
		}
	}

	*/
********************************************************************************
* Regular Event Studies: Binning Off 
********************************************************************************

	foreach explaining in $weighting_strategy {
		foreach x in change_`explaining' increase_`explaining' decrease_`explaining' {

			replace F4_`x'=sum_F4_`x'
			replace L4_`x'=sum_L4_`x'
		}
	} 

	forvalues i = 10/10 {
		
		** Poisson Regression
		foreach var of varlist $outcome {
			foreach explaining in $weighting_strategy {
				
				* Generating the local which contains control variables 	
				local other_controls other_cit_`explaining'  other_pit_`explaining' 
					
				ppmlhdfe `var'  F?_change_`explaining' zero_1 L?_change_`explaining' `sample`i'' , absorb(estab_id year#i.fips_state) cl(estab_id)
				est sto regres1
				coefplot regres1, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black))  ///
					keep(F?_change_`explaining' zero_1 L?_change_`explaining') yline(0,  lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))
				capture noisily graph export "$RESULTS/eventstudies/new_`type'_$dataset/var`var'_`explaining'_sample`i'_c1_balancedbinning_`type'.png", replace

				ppmlhdfe `var' F?_change_`explaining' zero_1 L?_change_`explaining' `other_controls' `sample`i'', absorb(estab_id year#i.fips_state) cl(estab_id)
				est sto regres2
				coefplot regres2, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
					keep(F?_change_`explaining' zero_1 L?_change_`explaining') yline(0,  lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))
				capture noisily graph export "$RESULTS/eventstudies/new_`type'_$dataset/var`var'_`explaining'_sample`i'_c2_balancedbinning_`type'.png", replace
			}
		}
		
		** Regular Regression		
		foreach var of varlist $outcome_log   {
			foreach explaining in $weighting_strategy  {
				
				reghdfe `var' F?_change_`explaining' zero_1 L?_change_`explaining' `sample`i'', absorb(estab_id year#i.fips_state) cl(estab_id)
				est sto regres3
				coefplot regres3, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
					keep(F?_change_`explaining' zero_1 L?_change_`explaining') yline(0,  lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))
				capture noisily graph export "$RESULTS/eventstudies/new_`type'_$dataset/var`var'_`explaining'_sample`i'_c3_balancedbinning_`type'.png", replace

				reghdfe `var' F?_change_`explaining' zero_1 L?_change_`explaining' `other_controls' `sample`i'', absorb(estab_id year#i.fips_state) cl(estab_id)
				est sto regres4
				coefplot regres4, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
					keep(F?_change_`explaining' zero_1 L?_change_`explaining') yline(0,  lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))
				capture noisily graph export "$RESULTS/eventstudies/new_`type'_$dataset/var`var'_`explaining'_sample`i'_c4_balancedbinning_`type'.png", replace
			}
		}	
	}
}

********************************************************************************
* Regular Event Studies: Binning Off + Balanced Panel
********************************************************************************
/*
	foreach explaining in $weighting_strategy {
		foreach x in change_`explaining' increase_`explaining' decrease_`explaining' {

			* Filling up
			forvalues i =0/4 {
			replace L`i'_`x'=0 if L`i'_`x'==.
			}
			
			forvalues i =2/4 {
			replace F`i'_`x'=0 if F`i'_`x'==.
			}
		}
	}

	forvalues i = 10/10 {
		
		** Poisson Regression
		foreach var of varlist $outcome {
			foreach explaining in $weighting_strategy {
				
				* Generating the local which contains control variables 	
				local other_controls other_cit_`explaining'  other_pit_`explaining' other_unemployment_`explaining' other_gdp_`explaining'  
					
				ppmlhdfe `var'  F?_change_`explaining' zero_1 L?_change_`explaining' `sample`i'', absorb(estab_id year#i.fips_state) cl(estab_id)
				est sto regres1
				coefplot regres1, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
					keep(F?_change_`explaining' zero_1 L?_change_`explaining') yline(0,  lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))
				capture noisily graph export "$RESULTS/eventstudies/new_`type'_$dataset/var`var'_`explaining'_sample`i'_c1_unbalancedbinning_`type'.png", replace

				ppmlhdfe `var' F?_change_`explaining' zero_1 L?_change_`explaining' `other_controls' `sample`i'', absorb(estab_id year#i.fips_state) cl(estab_id)
				est sto regres2
				coefplot regres2, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
					keep(F?_change_`explaining' zero_1 L?_change_`explaining') yline(0,  lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))
				capture noisily graph export "$RESULTS/eventstudies/new_`type'_$dataset/var`var'_`explaining'_sample`i'_c2_unbalancedbinning_`type'.png", replace	
			} 
		}

		** Regular Regression		
		foreach var of varlist $outcome_log {
			foreach explaining in $weighting_strategy {
					
				reghdfe `var' F?_change_`explaining' zero_1 L?_change_`explaining' `sample`i'', absorb(estab_id year#i.fips_state) cl(estab_id)
				est sto regres3
				coefplot regres3, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
					keep(F?_change_`explaining' zero_1 L?_change_`explaining') yline(0,  lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))
				capture noisily graph export "$RESULTS/eventstudies/new_`type'_$dataset/var`var'_`explaining'_sample`i'_c3_unbalancedbinning_`type'.png", replace

				reghdfe `var' F?_change_`explaining' zero_1 L?_change_`explaining' `other_controls' `sample`i'', absorb(estab_id year#i.fips_state) cl(estab_id)
				est sto regres4
				coefplot regres4, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
					keep(F?_change_`explaining' zero_1 L?_change_`explaining') yline(0,  lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))
				capture noisily graph export "$RESULTS/eventstudies/new_`type'_$dataset/var`var'_`explaining'_sample`i'_c4_unbalancedbinning_`type'.png", replace
			}
		}
	}
}

