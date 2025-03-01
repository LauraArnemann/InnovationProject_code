////////////////////////////////////////////////////////////////////////////////
// Project: 		Moving innovation
// Creation Date: 	27/11/2024
// Last Update: 	03/12/2024
// Author: 			Laura Arnemann 
//					Theresa Bührle
// Goal: 			Regular two-way fixed effects analysis with event studies, CZ level 
////////////////////////////////////////////////////////////////////////////////

local sample1 if inrange(year, 1988, 2018)
local sample2 if inrange(year, 1988, 2018) & total_patents>10 
local sample3 if inrange(year, 1988, 2018) & estab_patents>10 
local sample4 if inrange(year, 1988, 2018) & patents3>10 
local sample5 if inrange(year, 1988, 2018) & noncorp_asg==1
local sample6 if inrange(year, 1988, 2018) & noncorp_asg==0 
local sample7 if inrange(year, 1988, 2018) & noncorp_asg==0 & patents3>10
local sample8 if inrange(year, 1988, 2018) & asg_corp==1
local sample9 if inrange(year, 1988, 2018) & asg_corp==1 & patents3>10
local sample10 if inrange(year, 1988, 2018) & asg_corp==1 & total_patents>20

local weighting_strategy threelargest weighted 

foreach type in assignee {
    // gvkey
    use "${TEMP}/final_cz_corp_`type'.dta", clear 
	
	gen inventor_productivity = patents3/n_inventors3 
	replace inventor_productivity = 0 if missing(patents3)

	foreach var of varlist patents1 patents2 patents3 ///
		n_inventors1 n_inventors2 n_inventors3 ///
		n_newinventors1 n_newinventors3  {
		    
		gstats winsor `var', cut(1 99) gen(`var'_w1)
		gstats winsor `var', cut(1 95) gen(`var'_w2)
		gen ln_`var'=log(`var')
	}
	
	*State-level controls
	gen ln_gdp=log(gdp)

	foreach var of varlist other_gdp_threelargest {
		replace `var'=log(`var')
	}

	bysort assignee_id year: egen total_patents=total(patents3)
	
	egen estab_id_state = group(assignee_id fips_state) 

	********************************************************************************
	* Regular Regressions: Based on Assignee ID
	********************************************************************************
	*egen estab_id = group(assignee_id fips_state czone)	// already did that in data file
	bysort estab_id: egen estab_patents = total(patents3)

	label var pit "PIT"
	label var cit "CIT"
	label var rd_credit "R\&D Credit"
				
	xtset estab_id year 
	foreach explaining in `weighting_strategy' {
		rename change_other_`explaining' change_`explaining'
		gen byte increase_`explaining' = change_`explaining'>0
		gen byte decrease_`explaining' = change_`explaining'<0
	}

	foreach explaining in `weighting_strategy' {
		
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
* Regular Event Studies: Binning Off 
********************************************************************************

	foreach explaining in `weighting_strategy' {
		foreach x in change_`explaining' increase_`explaining' decrease_`explaining' {

			replace F4_`x'=sum_F4_`x'
			replace L4_`x'=sum_L4_`x'
		}
	} 
	
	* Generating the local which contains control variables 	
	forvalues i = 10/10 {
		
		** Poisson Regression
		foreach var of varlist $outcome {
			foreach explaining in `weighting_strategy' {
				
				local other_controls other_cit_`explaining'  other_pit_`explaining'
					
				ppmlhdfe `var'  F?_change_`explaining' zero_1 L?_change_`explaining' `sample`i'' , absorb(estab_id year#i.fips_state) cl(estab_id)
				est sto regres1
				coefplot regres1, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(3.5, lpattern(dash) lwidth(thin) lcolor(black))  ///
					keep(F3_change_`explaining' F2_change_`explaining' F1_change_`explaining' zero_1 L0_change_`explaining' L1_change_`explaining' L2_change_`explaining' L3_change_`explaining') ///
					yline(0,  lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))
				capture noisily graph export "$RESULTS/eventstudies/stage1/czone/`var'_`explaining'_sample`i'_c1_balancedbinning_`type'_cz.png", replace
				
				ppmlhdfe `var'  F?_change_`explaining' zero_1 L?_change_`explaining' `sample`i'' , absorb(estab_id year#i.czone) cl(estab_id)
				est sto regres1
				coefplot regres1, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(3.5, lpattern(dash) lwidth(thin) lcolor(black))  ///
					keep(F3_change_`explaining' F2_change_`explaining' F1_change_`explaining' zero_1 L0_change_`explaining' L1_change_`explaining' L2_change_`explaining' L3_change_`explaining') ///
					yline(0,  lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))
				capture noisily graph export "$RESULTS/eventstudies/stage1/czone/`var'_`explaining'_sample`i'_c1b_balancedbinning_`type'_cz.png", replace
				
				ppmlhdfe `var'  F?_change_`explaining' zero_1 L?_change_`explaining' `sample`i'' , absorb(estab_id year#i.czone) cl(estab_id_state)
				est sto regres1
				coefplot regres1, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(3.5, lpattern(dash) lwidth(thin) lcolor(black))  ///
					keep(F3_change_`explaining' F2_change_`explaining' F1_change_`explaining' zero_1 L0_change_`explaining' L1_change_`explaining' L2_change_`explaining' L3_change_`explaining') ///
					yline(0,  lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))
				capture noisily graph export "$RESULTS/eventstudies/stage1/czone/`var'_`explaining'_sample`i'_c1c_balancedbinning_`type'_cz.png", replace
				
				ppmlhdfe `var' F?_change_`explaining' zero_1 L?_change_`explaining' `other_controls' `sample`i'', absorb(estab_id year#i.fips_state) cl(estab_id)
				est sto regres2
				coefplot regres2, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(3.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
					keep(F3_change_`explaining' F2_change_`explaining' F1_change_`explaining' zero_1 L0_change_`explaining' L1_change_`explaining' L2_change_`explaining' L3_change_`explaining') ///
					yline(0,  lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))
				capture noisily graph export "$RESULTS/eventstudies/stage1/czone/`var'_`explaining'_sample`i'_c2_balancedbinning_`type'_cz.png", replace
				
				ppmlhdfe `var' F?_change_`explaining' zero_1 L?_change_`explaining' `other_controls' `sample`i'', absorb(estab_id year#i.czone) cl(estab_id)
				est sto regres2
				coefplot regres2, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(3.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
					keep(F3_change_`explaining' F2_change_`explaining' F1_change_`explaining' zero_1 L0_change_`explaining' L1_change_`explaining' L2_change_`explaining' L3_change_`explaining') ///
					yline(0,  lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))
				capture noisily graph export "$RESULTS/eventstudies/stage1/czone/`var'_`explaining'_sample`i'_c2b_balancedbinning_`type'_cz.png", replace
				
				ppmlhdfe `var' F?_change_`explaining' zero_1 L?_change_`explaining' `other_controls' `sample`i'', absorb(estab_id year#i.czone) cl(estab_id_state)
				est sto regres2
				coefplot regres2, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(3.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
					keep(F3_change_`explaining' F2_change_`explaining' F1_change_`explaining' zero_1 L0_change_`explaining' L1_change_`explaining' L2_change_`explaining' L3_change_`explaining') ///
					yline(0,  lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))
				capture noisily graph export "$RESULTS/eventstudies/stage1/czone/`var'_`explaining'_sample`i'_c2c_balancedbinning_`type'_cz.png", replace
			}
		}
		
		** Regular Regression		
		foreach var of varlist $outcome_log   {
			foreach explaining in `weighting_strategy'  {
				
				local other_controls other_cit_`explaining'  other_pit_`explaining'
				
				reghdfe `var' F?_change_`explaining' zero_1 L?_change_`explaining' `sample`i'', absorb(estab_id year#i.fips_state) cl(estab_id)
				est sto regres3
				coefplot regres3, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(3.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
					keep(F3_change_`explaining' F2_change_`explaining' F1_change_`explaining' zero_1 L0_change_`explaining' L1_change_`explaining' L2_change_`explaining' L3_change_`explaining') ///
					yline(0,  lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))
				capture noisily graph export "$RESULTS/eventstudies/stage1/czone/`var'_`explaining'_sample`i'_c3_balancedbinning_`type'_cz.png", replace
				
				reghdfe `var' F?_change_`explaining' zero_1 L?_change_`explaining' `sample`i'', absorb(estab_id year#i.czone) cl(estab_id)
				est sto regres3
				coefplot regres3, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(3.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
					keep(F3_change_`explaining' F2_change_`explaining' F1_change_`explaining' zero_1 L0_change_`explaining' L1_change_`explaining' L2_change_`explaining' L3_change_`explaining') ///
					yline(0,  lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))
				capture noisily graph export "$RESULTS/eventstudies/stage1/czone/`var'_`explaining'_sample`i'_c3b_balancedbinning_`type'_cz.png", replace

				reghdfe `var' F?_change_`explaining' zero_1 L?_change_`explaining' `other_controls' `sample`i'', absorb(estab_id year#i.fips_state) cl(estab_id)
				est sto regres4
				coefplot regres4, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(3.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
					keep(F3_change_`explaining' F2_change_`explaining' F1_change_`explaining' zero_1 L0_change_`explaining' L1_change_`explaining' L2_change_`explaining' L3_change_`explaining') ///
					yline(0,  lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))
				capture noisily graph export "$RESULTS/eventstudies/stage1/czone/`var'_`explaining'_sample`i'_c4_balancedbinning_`type'_cz.png", replace
				
				reghdfe `var' F?_change_`explaining' zero_1 L?_change_`explaining' `other_controls' `sample`i'', absorb(estab_id year#i.czone) cl(estab_id)
				est sto regres4
				coefplot regres4, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(3.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
					keep(F3_change_`explaining' F2_change_`explaining' F1_change_`explaining' zero_1 L0_change_`explaining' L1_change_`explaining' L2_change_`explaining' L3_change_`explaining') ///
					yline(0,  lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))
				capture noisily graph export "$RESULTS/eventstudies/stage1/czone/`var'_`explaining'_sample`i'_c4b_balancedbinning_`type'_cz.png", replace
			}
		}	
	}


}