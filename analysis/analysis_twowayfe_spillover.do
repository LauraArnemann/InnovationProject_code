////////////////////////////////////////////////////////////////////////////////
// Project:        	Moving innovation
// Creation Date:  	04/07/2024
// Last Update:    	05/07/2024
// Authors:         Laura Arnemann
//					Theresa Bührle
// Goal: 			Calculating spillover with two-way fixed effects analysis
////////////////////////////////////////////////////////////////////////////////
	*https://github.com/sergiocorreia/ppmlhdfe/blob/master/guides/separation_primer.md
	
* Generate a local for the type of analysis you want to run 

local aggregate = 1	
	
********************************************************************************
* Analysis on assignee level 
********************************************************************************	

if `aggregate' == 0 {
local sample1 if inrange(year, 1988, 2018)
local sample2 if inrange(year, 1988, 2018)  & total_patents>10 
local sample3  if inrange(year, 1988, 2018)  & balanced_panel==1
local sample4  if inrange(year, 1988, 2018)  & balanced_panel==1 & total_patents>10 	

use "${TEMP}/final_cz_${dataset}.dta", clear 

	foreach var of varlist patents1 patents2 patents3 n_inventors1 n_inventors2 n_inventors3  n_newinventors1 n_newinventors3 {
		gstats winsor `var', cut(1 99) gen(`var'_w1)
		gstats winsor `var', cut(1 95) gen(`var'_w2)
		gen ln_`var'=log(`var')
}

egen estab_id = group(assignee_id fips_state czone)
bysort estab_id: egen estab_patents = total(patents3)

	label var pit "PIT"
	label var cit "CIT"
	label var rd_credit "R\&D Credit"

xtset estab_id year 

gen change_otherstates = cz_treated_change_w - l.cz_treated_change_w
gen byte incr_otherstates = change_otherstates >0
replace incr_otherstates = . if change_otherstates<0 
gen byte decr_otherstates = change_otherstates <0
replace decr_otherstates = . if change_otherstates>0 
		
foreach x in change_otherstates incr_otherstates decr_otherstates {
	
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


drop F1* 
gen zero_1=1
label var zero_1 "-1"

bysort assignee_id: egen total_patents = total(patents3)

*SAMPLE SLECTION:: ROBUSTNESS CHECK
*keep if tag_local == 1

*CHANGES -----------------------------------------------------------------------

local sample1 if inrange(year, 1988, 2018)
local sample2 if inrange(year, 1988, 2018)  & total_patents>10 
local sample3  if inrange(year, 1988, 2018)  & balanced_panel==1
local sample4  if inrange(year, 1988, 2018)  & balanced_panel==1 & total_patents>10 
	
	
foreach direction in change incr decr { 		
		
	********************************************************************************
	* Regular event studies: No binning off 
	********************************************************************************

	forvalues i = 1/2 {
			
		** Poisson Regression 
		foreach var of varlist $outcome  {

			ppmlhdfe `var' F?_`direction'_otherstates zero_1 L?_`direction'_otherstates `sample`i'', absorb(estab_id year#i.fips_state) cl(estab_id)
			est sto regres1
			coefplot regres1, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
				keep(F?_`direction'_otherstates zero_1 L?_`direction'_otherstates) yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
				xtitle("Years since `direction'") ytitle(`var') graphregion(color(white))
			capture noisily graph export "$RESULTS/eventstudies/`var'_spillover_sample`i'_c1_nobin_`direction'.png", replace
		} 
			
			
		** Regular Regression
		foreach var of varlist $outcome_log  {
			
			reghdfe `var' F?_`direction'_otherstates zero_1 L?_`direction'_otherstates `sample`i'', absorb(estab_id year#i.fips_state) cl(estab_id)
			est sto regres3
			coefplot regres3, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
				keep(F?_`direction'_otherstates zero_1 L?_`direction'_otherstates) yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
				xtitle("Years since `direction'") ytitle(`var') graphregion(color(white))
			capture noisily graph export "$RESULTS/eventstudies/var`var'_spillover_sample`i'_c3_nobin_`direction'.png", replace

		}
	}
		
		
	********************************************************************************
	* Regular Event Studies: Binning Off 
	********************************************************************************


	foreach x in change_otherstates incr_otherstates decr_otherstates {
		replace F4_`x'=sum_F4_`x'
		replace L4_`x'=sum_L4_`x'
	}
		 

	forvalues i = 1/2 {
			
		** Poisson Regression
		foreach var of varlist $outcome {

			ppmlhdfe `var' F?_`direction'_otherstates zero_1 L?_`direction'_otherstates `sample`i'', absorb(estab_id year#i.fips_state) cl(estab_id)
			est sto regres1
			coefplot regres1, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
				keep(F?_`direction'_otherstates zero_1 L?_`direction'_otherstates) yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
				xtitle("Years since `direction'") ytitle(`var') graphregion(color(white))
			capture noisily graph export "$RESULTS/eventstudies/var`var'_spillover_sample`i'_c1_binning_`direction'.png", replace

		}

			
		** Regular Regression
		foreach var of varlist $outcome_log  {
			
			reghdfe `var' F?_`direction'_otherstates zero_1 L?_`direction'_otherstates `sample`i'', absorb(estab_id year#i.fips_state) cl(estab_id)
			est sto regres3
			coefplot regres3, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
				keep(F?_`direction'_otherstates zero_1 L?_`direction'_otherstates) yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
				xtitle("Years since `direction'") ytitle(`var') graphregion(color(white))
			capture noisily graph export "$RESULTS/eventstudies/var`var'_spillover_sample`i'_c3_binning_`direction'.png", replace

		}
	}

}

}



********************************************************************************
* Analysis on aggregate level 
********************************************************************************	

*if `aggregate' == 1 {
	
use "${TEMP}/final_cz_${dataset}_aggregate.dta", clear

local outcome n_inventors3_w1 patents3_w1 n_newinventors3_w1 local_n_inventors3_w1 local_n_newinventors3_w1 local_patents3_w1 max_labs_w1
local outcome_log ln_n_inventors3 ln_patents3 ln_n_newinventors3 ln_local_n_inventors3 ln_local_n_newinventors3 ln_local_patents3

	foreach var of varlist n_inventors3 patents3 n_newinventors3 local_n_inventors3 local_n_newinventors3 local_patents3 max_labs {
		gstats winsor `var', cut(1 99) gen(`var'_w1)
		gstats winsor `var', cut(1 95) gen(`var'_w2)
		gen ln_`var'=log(`var')
}

	label var pit "PIT"
	label var cit "CIT"
	label var rd_credit "R\&D Credit"

xtset czone year 

gen change_otherstates = weighted_change - l.weighted_change
gen byte incr_otherstates = change_otherstates >0
replace incr_otherstates = . if change_otherstates<0 
gen byte decr_otherstates = change_otherstates <0
replace decr_otherstates = . if change_otherstates>0 
		
foreach x in change_otherstates incr_otherstates decr_otherstates {
	
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
	gsort czone -year
	bysort czone: gen sum_F4_`x'=sum(F4_`x')

	sort czone year
	capture drop sum_L4_`x'
	bysort czone: gen sum_L4_`x'=sum(L4_`x')	
}


drop F1* 
gen zero_1=1
label var zero_1 "-1"

*SAMPLE SLECTION:: ROBUSTNESS CHECK
*keep if tag_local == 1

*CHANGES -----------------------------------------------------------------------

local sample1 if inrange(year, 1988, 2018)
local sample2 if inrange(year, 1988, 2018)  & multistate_cz==0
	
	
foreach direction in change  { 		
		
	********************************************************************************
	* Regular event studies: No binning off 
	********************************************************************************

	forvalues i = 1/2 {
			
		** Poisson Regression 
		foreach var of varlist `outcome'  {
			
			local cl czone

			ppmlhdfe `var' F?_`direction'_otherstates zero_1 L?_`direction'_otherstates `sample`i'', absorb(czone year) cl(`cl')
			est sto regres1
			coefplot regres1, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
				keep(F?_`direction'_otherstates zero_1 L?_`direction'_otherstates) yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
				xtitle("Years since `direction'") ytitle(`var') graphregion(color(white))
			capture noisily graph export "$RESULTS/eventstudies/aggregate/`var'_spillover_sample`i'_c1_nobin_`direction'.png", replace
			
			ppmlhdfe `var' F?_`direction'_otherstates zero_1 L?_`direction'_otherstates pit rd_credit cit `sample`i'', absorb(czone year) cl(`cl')
			est sto regres1
			coefplot regres1, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
				keep(F?_`direction'_otherstates zero_1 L?_`direction'_otherstates) yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
				xtitle("Years since `direction'") ytitle(`var') graphregion(color(white))
			capture noisily graph export "$RESULTS/eventstudies/aggregate/`var'_spillover_sample`i'_c2_nobin_`direction'.png", replace
		} 
			
			
		** Regular Regression
		foreach var of varlist `outcome_log'  {
			
			reghdfe `var' F?_`direction'_otherstates zero_1 L?_`direction'_otherstates `sample`i'', absorb(czone year) cl(`cl')
			est sto regres3
			coefplot regres3, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
				keep(F?_`direction'_otherstates zero_1 L?_`direction'_otherstates) yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
				xtitle("Years since `direction'") ytitle(`var') graphregion(color(white))
			capture noisily graph export "$RESULTS/eventstudies/aggregate/var`var'_spillover_sample`i'_c1_nobin_`direction'.png", replace
			
						reghdfe `var' F?_`direction'_otherstates zero_1 L?_`direction'_otherstates pit rd_credit cit `sample`i'', absorb(czone year) cl(`cl')
			est sto regres3
			coefplot regres3, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
				keep(F?_`direction'_otherstates zero_1 L?_`direction'_otherstates) yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
				xtitle("Years since `direction'") ytitle(`var') graphregion(color(white))
			capture noisily graph export "$RESULTS/eventstudies/aggregate/var`var'_spillover_sample`i'_c2_nobin_`direction'.png", replace

		}
	}
		
	
	********************************************************************************
	* Regular Event Studies: Binning Off 
	********************************************************************************


	foreach x in change_otherstates incr_otherstates decr_otherstates {
		replace F4_`x'=sum_F4_`x'
		replace L4_`x'=sum_L4_`x'
	}
		 

	forvalues i = 1/2 {
			
		** Poisson Regression
		foreach var of varlist `outcome' {

			ppmlhdfe `var' F?_`direction'_otherstates zero_1 L?_`direction'_otherstates `sample`i'', absorb(czone year) cl(`cl')
			est sto regres1
			coefplot regres1, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
				keep(F?_`direction'_otherstates zero_1 L?_`direction'_otherstates) yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
				xtitle("Years since `direction'") ytitle(`var') graphregion(color(white))
			capture noisily graph export "$RESULTS/eventstudies/aggregate/var`var'_spillover_sample`i'_c1_binning_`direction'.png", replace
			
			
			ppmlhdfe `var' F?_`direction'_otherstates zero_1 L?_`direction'_otherstates pit rd_credit cit `sample`i'', absorb(czone year) cl(`cl')
			est sto regres1
			coefplot regres1, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
				keep(F?_`direction'_otherstates zero_1 L?_`direction'_otherstates) yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
				xtitle("Years since `direction'") ytitle(`var') graphregion(color(white))
			capture noisily graph export "$RESULTS/eventstudies/aggregate/var`var'_spillover_sample`i'_c2_binning_`direction'.png", replace

		}

			
		** Regular Regression
		foreach var of varlist `outcome_log'  {
			
			reghdfe `var' F?_`direction'_otherstates zero_1 L?_`direction'_otherstates `sample`i'', absorb(czone year) cl(`cl')
			est sto regres3
			coefplot regres3, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
				keep(F?_`direction'_otherstates zero_1 L?_`direction'_otherstates) yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
				xtitle("Years since `direction'") ytitle(`var') graphregion(color(white))
			capture noisily graph export "$RESULTS/eventstudies/aggregate/var`var'_spillover_sample`i'_c1_binning_`direction'.png", replace
			
					
			reghdfe `var' F?_`direction'_otherstates zero_1 L?_`direction'_otherstates pit rd_credit cit `sample`i'', absorb(czone year) cl(`cl')
			est sto regres3
			coefplot regres3, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
				keep(F?_`direction'_otherstates zero_1 L?_`direction'_otherstates) yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
				xtitle("Years since `direction'") ytitle(`var') graphregion(color(white))
			capture noisily graph export "$RESULTS/eventstudies/aggregate/var`var'_spillover_sample`i'_c2_binning_`direction'.png", replace

		}
	}

}


























