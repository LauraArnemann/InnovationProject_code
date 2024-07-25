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
* Analysis on aggregate level 
********************************************************************************	

local sample1 if inrange(year, 1988, 2018) & missing(change_other_threelargest)
local sample2 if inrange(year, 1988, 2018) & total_patents>10  & missing(change_other_threelargest)
local sample3 if inrange(year, 1988, 2018) & total_patents<10  & missing(change_other_threelargest)
local sample4 if inrange(year, 1988, 2018) & pub_assg==1 & missing(change_other_threelargest)
local sample5 if inrange(year, 1988, 2018) & noncorp_asg==0  & missing(change_other_threelargest)
local sample6 if inrange(year, 1988, 2018) & tag_local==1  & missing(change_other_threelargest)

forvalues i = 6/6 {
	
	use "${TEMP}/final_cz_${dataset}.dta", replace 
	bysort assignee_id: egen total_patents = total(patents3)
	
	keep `sample`i''


collapse (sum) n_inventors3 patents3 n_newinventors3 (max) total_change_w1 = cz_treated_change_w1 total_change_w2 = cz_treated_change_w2 total_change_w3 = cz_treated_change_w3  max_labs = n_labs max_multistate = multistate_cz , by(czone year fips_state)

rename max_multistate multistate_cz
* Outcome Variables 
local outcome n_inventors3_w1 patents3_w1 n_newinventors3_w1 
local outcome_log ln_n_inventors3 ln_patents3 ln_n_newinventors3 

	foreach var of varlist n_inventors3 patents3 n_newinventors3 {
		gstats winsor `var', cut(1 99) gen(`var'_w1)
		gstats winsor `var', cut(1 95) gen(`var'_w2)
		gen ln_`var'=log(`var')
}

* We don't need these variables since we are always including year state fixed effects anyways
	*label var pit "PIT"
	*label var cit "CIT"
	*label var rd_credit "R\&D Credit"

	egen czone_id = group(czone fips_state)
	
foreach expl in 1 2 3 {
xtset czone_id year 
gen change_otherstates`expl' = total_change_w`expl'
gen byte incr_otherstates`expl' = total_change_w`expl' >0
replace incr_otherstates`expl' = . if total_change_w`expl'<0 
gen byte decr_otherstates`expl' = total_change_w`expl'<0
replace decr_otherstates`expl' = . if total_change_w`expl'>0 
		
foreach x in change_otherstates`expl'  {
	
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
	gsort czone_id -year
	bysort czone_id: gen sum_F4_`x'=sum(F4_`x')

	sort czone_id year
	capture drop sum_L4_`x'
	bysort czone_id: gen sum_L4_`x'=sum(L4_`x')	
}

}
drop F1* 
gen zero_1=1
label var zero_1 "-1"
local direction change 

*SAMPLE SLECTION:: ROBUSTNESS CHECK
*keep if tag_local == 1

*CHANGES -----------------------------------------------------------------------


foreach expl in 1 2 3 {		

		
	********************************************************************************
	* Regular event studies: No binning off 
	********************************************************************************

			
		** Poisson Regression 
		foreach var of varlist `outcome'  {
			
			local cl czone

			ppmlhdfe `var' F?_`direction'_otherstates`expl' zero_1 L?_`direction'_otherstates`expl', absorb(czone#fips_state year#fips_state) cl(`cl')
			est sto regres1
			coefplot regres1, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
				keep(F?_`direction'_otherstates`expl' zero_1 L?_`direction'_otherstates`expl') yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
				xtitle("Years since `direction'") ytitle(`var') graphregion(color(white))
			capture noisily graph export "$RESULTS/eventstudies/aggregate/weight`expl'/`var'_spillover_sample`i'_c1_nobin_`direction'.png", replace
			
			ppmlhdfe `var' F?_`direction'_otherstates`expl' zero_1 L?_`direction'_otherstates`expl' if multistate_cz==0 , absorb(czone#fips_state year#fips_state) cl(`cl')
			est sto regres1
			coefplot regres1, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
				keep(F?_`direction'_otherstates`expl' zero_1 L?_`direction'_otherstates`expl') yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
				xtitle("Years since `direction'") ytitle(`var') graphregion(color(white))
			capture noisily graph export "$RESULTS/eventstudies/aggregate/weight`expl'/`var'_spillover_sample`i'_c2_nobin_`direction'.png", replace
			
		} 
			
			
		** Regular Regression
		foreach var of varlist `outcome_log'  {
			
			reghdfe `var' F?_`direction'_otherstates`expl' zero_1 L?_`direction'_otherstates`expl', absorb(czone#fips_state year#fips_state) cl(`cl')
			est sto regres3
			coefplot regres3, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
				keep(F?_`direction'_otherstates`expl' zero_1 L?_`direction'_otherstates`expl') yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
				xtitle("Years since `direction'") ytitle(`var') graphregion(color(white))
			capture noisily graph export "$RESULTS/eventstudies/aggregate/weight`expl'/var`var'_spillover_sample`i'_c1_nobin_`direction'.png", replace
			
	reghdfe `var' F?_`direction'_otherstates`expl' zero_1 L?_`direction'_otherstates`expl' if multistate_cz==0 , absorb(czone#fips_state year#fips_state) cl(`cl')
			est sto regres3
			coefplot regres3, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
				keep(F?_`direction'_otherstates`expl' zero_1 L?_`direction'_otherstates`expl') yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
				xtitle("Years since `direction'") ytitle(`var') graphregion(color(white))
			capture noisily graph export "$RESULTS/eventstudies/aggregate/weight`expl'/var`var'_spillover_sample`i'_c2_nobin_`direction'.png", replace

		}
	
		
	
	********************************************************************************
	* Regular Event Studies: Binning Off 
	********************************************************************************


	foreach x in change_otherstates`expl' {
		replace F4_`x' =sum_F4_`x' 
		replace L4_`x' =sum_L4_`x' 
	}
		 

			
		** Poisson Regression
		foreach var of varlist `outcome' {

			ppmlhdfe `var' F?_`direction'_otherstates`expl' zero_1 L?_`direction'_otherstates`expl', absorb(czone#fips_state year#fips_state) cl(`cl')
			est sto regres1
			coefplot regres1, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
				keep(F?_`direction'_otherstates`expl' zero_1 L?_`direction'_otherstates`expl') yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
				xtitle("Years since `direction'") ytitle(`var') graphregion(color(white))
			capture noisily graph export "$RESULTS/eventstudies/aggregate/weight`expl'/var`var'_spillover_sample`i'_c1_binning_`direction'.png", replace
			
				ppmlhdfe `var' F?_`direction'_otherstates`expl' zero_1 L?_`direction'_otherstates`expl' if multistate_cz==0 , absorb(czone#fips_state year#fips_state) cl(`cl')
			est sto regres1
			coefplot regres1, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
				keep(F?_`direction'_otherstates`expl' zero_1 L?_`direction'_otherstates`expl') yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
				xtitle("Years since `direction'") ytitle(`var') graphregion(color(white))
			capture noisily graph export "$RESULTS/eventstudies/aggregate/weight`expl'/var`var'_spillover_sample`i'_c2_binning_`direction'.png", replace
			
			
		}

			
		** Regular Regression
		foreach var of varlist `outcome_log'  {
			
			reghdfe `var' F?_`direction'_otherstates`expl' zero_1 L?_`direction'_otherstates`expl' , absorb(czone#fips_state year#fips_state) cl(`cl')
			est sto regres3
			coefplot regres3, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
				keep(F?_`direction'_otherstates`expl' zero_1 L?_`direction'_otherstates`expl') yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
				xtitle("Years since `direction'") ytitle(`var') graphregion(color(white))
			capture noisily graph export "$RESULTS/eventstudies/aggregate/weight`expl'/var`var'_spillover_sample`i'_c1_binning_`direction'.png", replace
			
			
			reghdfe `var' F?_`direction'_otherstates`expl' zero_1 L?_`direction'_otherstates`expl' if multistate_cz==0 , absorb(czone#fips_state year#fips_state) cl(`cl')
			est sto regres3
			coefplot regres3, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
				keep(F?_`direction'_otherstates`expl' zero_1 L?_`direction'_otherstates`expl') yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
				xtitle("Years since `direction'") ytitle(`var') graphregion(color(white))
			capture noisily graph export "$RESULTS/eventstudies/aggregate/weight`expl'/var`var'_spillover_sample`i'_c2_binning_`direction'.png", replace
			

		}
	}
}





























