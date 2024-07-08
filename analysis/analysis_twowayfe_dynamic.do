// Project: Inventor Relocation
// Creation Date: 15/06/2024
// Last Update: 15/06/2024
// Author: Laura Arnemann 
// Goal: Regular two-way fixed effects analysis with event studies 

local sample1 if inrange(year, 1988, 2018)
local sample2 if inrange(year, 1988, 2018)  & total_patents>10 
local sample3  if inrange(year, 1988, 2018)  & balanced_panel==1
local sample4  if inrange(year, 1988, 2018)  & balanced_panel==1 & total_patents>10 

foreach type in gvkey {

* Analysis on Commuting Zone Level 
use "${TEMP}/patentcount_czone_`type'.dta", clear 
merge 1:1 czone app_year assignee_id using "${TEMP}/inventorcount_czone_`type'.dta"
drop _merge 



* Merging in the state data for each commuting zone
merge m:1 czone using "${IN}/var_CommutingZones/cw_czone_state.dta"
keep if _merge ==3 
drop _merge 


rename statefip fips_state


merge m:1 fips_state app_year using "${TEMP}/state_data_cleaned.dta", keepusing(rd_credit gdp cit pit unemployment)
drop if _merge!=3
drop _merge


rename app_year year 

foreach num of numlist 3 {
* Merging in the variables at other locations

merge m:1 fips_state year assignee_id using "${TEMP}/other_all_`num'_${dataset}_gvkey.dta", keepusing(other*)
drop if _merge==2
drop _merge  

foreach var in rd_credit cit gdp unemployment pit {
	rename other_`var'_all other_`var'_all`num' 
	rename other_`var'_weighted other_`var'_weighted`num'
}


merge m:1 fips_state year assignee_id using "${TEMP}/other_threelargest_`num'_$dataset_gvkey.dta", keepusing(other*)
drop if _merge==2 
drop _merge 

foreach var in rd_credit cit gdp unemployment pit {
	rename other_`var'_threelargest other_`var'_threelargest`num' 
}
 
}


foreach var of varlist patents1 patents2 patents3 n_inventors1 n_inventors2 n_inventors3  n_newinventors1 n_newinventors3 {
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
egen estab_id = group(assignee_id czone)
bysort estab_id: egen estab_patents = total(patents3)

label var pit "PIT"
label var cit "CIT"
label var rd_credit "R\&D Credit"



xtset estab_id year 
foreach explaining in all weighted threelargest {
    gen change_`explaining' = other_rd_credit_`explaining'3 - l.other_rd_credit_`explaining'3
    gen byte increase_`explaining' = change_`explaining'>0
    gen byte decrease_`explaining' = change_`explaining'<0
}



foreach explaining in all weighted threelargest {
foreach x in change_`explaining' increase_`explaining' decrease_`explaining' {

	forval f = 4(-1)1 {
		gen F`f'_`x' = F`f'.`x'		
		label var F`f'_`x' "- `f'"
	} // f

	forval l = 0(1)4{		
		gen L`l'_`x' = L`l'.`x'
		label var L`l'_`x' " `l'"
	} // l

foreach type in assignee gvkey {

	
	use "${TEMP}/final_state_zeros_new_${dataset}_`type'.dta", clear 

	foreach var of varlist patents1 patents2 patents3 n_inventors1 n_inventors2 n_inventors3  n_newinventors1 n_newinventors3 {
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


* Sample Restrictions 

	local sample1 if inrange(year, 1988, 2018)
	local sample2 if inrange(year, 1988, 2018)  & total_patents>10 
	local sample3  if inrange(year, 1988, 2018)  & balanced_panel==1
	local sample4  if inrange(year, 1988, 2018)  & balanced_panel==1 & total_patents>10 
	
	forvalues i = 1/2 {
		
		** Poisson Regression 
		foreach var of varlist $outcome  {
			foreach explaining in $weighting_strategy  {

				* Generating the local which contains control variables 	
				local other_controls other_cit_`explaining' other_pit_`explaining' other_unemployment_`explaining' other_gdp_`explaining' 
					
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

				reghdfe `var' F?_change_`explaining' zero_1 L?_change_`explaining' $sample`i', absorb(estab_id year#i.fips_state) cl(estab_id)
				est sto regres3
				coefplot regres3, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
					keep(F?_change_`explaining' zero_1 L?_change_`explaining') yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))
				capture noisily graph export "$RESULTS/eventstudies/new_`type'_$dataset/var`var'_`explaining'_sample`i'_c3_balancednobin_`type'.png", replace

				reghdfe `var' F?_change_`explaining' zero_1 L?_change_`explaining' `other_controls' `sample`i'', absorb(estab_id year#i.fips_state) cl(estab_id)
				est sto regres4
				coefplot regres4, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
					keep(F?_change_`explaining' zero_1 L?_change_`explaining') yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))
				capture noisily graph export "$RESULTS/eventstudies/new_`type'_${dataset}/var`var'_`explaining'_sample`i'_c4_balancednobin_`type'.png", replac
			}
		}
	}


	
********************************************************************************
* Regular Event Studies: Binning Off 
********************************************************************************

	foreach explaining in $weighting_strategy {
		foreach x in change_`explaining' increase_`explaining' decrease_`explaining' {
			replace F4_`x'=sum_F4_`x'
			replace L4_`x'=sum_L4_`x'
		}
	} 

	forvalues i = 1/2 {
		
		** Poisson Regression
		foreach var of varlist $outcome {
			foreach explaining in $weighting_strategy {
				
				* Generating the local which contains control variables 	
				local other_controls other_cit_`explaining'  other_pit_`explaining' other_unemployment_`explaining' other_gdp_`explaining'  
					
				ppmlhdfe `var'  F?_change_`explaining' zero_1 L?_change_`explaining' `sample`i'' , absorb(estab_id year#i.fips_state) cl(estab_id)
				est sto regres1
				coefplot regres1, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black))  ///
					keep(F?_change_`explaining' zero_1 L?_change_`explaining') yline(0,  lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))
				capture noisily graph export "$RESULTS/eventstudies/new_`type'_$dataset/var`var'_`explaining'_sample`i'_c1_balancedbinning_`type'.png", replace


forvalues i = 1/2 {
	
foreach var of varlist patents3 patents3_w1 n_inventors3 n_inventors3_w1 n_newinventors3 n_newinventors3_w1 {

foreach explaining in all weighted threelargest {
	
* Generating the local which contains control variables 	
	local other_controls other_cit_`explaining'3  other_pit_`explaining'3 other_unemployment_`explaining'3 other_gdp_`explaining'3  
	
ppmlhdfe `var'  F?_change_`explaining' zero_1 L?_change_`explaining' `sample`i'' , absorb(estab_id year) cl(estab_id)
est sto reg1
coefplot reg1, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black))  keep(F?_change_`explaining' zero_1 L?_change_`explaining') yline(0,  lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))
capture noisily graph export "$RESULTS/eventstudies/new_`type'_$dataset/var`var'_`explaining'_sample`i'_c1_balancedbinning_`type'.png", replace


ppmlhdfe `var' F?_change_`explaining' zero_1 L?_change_`explaining' rd_credit pit cit ln_gdp unemployment `sample`i'', absorb(estab_id year) cl(estab_id)
est sto reg2
coefplot reg2, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black))  keep(F?_change_`explaining' zero_1 L?_change_`explaining') yline(0,  lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))
capture noisily graph export "$RESULTS/eventstudies/new_`type'_$dataset/var`var'_`explaining'_sample`i'_c2_balancedbinning_`type'.png", replace

ppmlhdfe `var' F?_change_`explaining' zero_1 L?_change_`explaining' rd_credit pit cit ln_gdp unemployment `other_controls' `sample`i'', absorb(estab_id year) cl(estab_id)
est sto reg3
coefplot reg3, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black))  keep(F?_change_`explaining' zero_1 L?_change_`explaining') yline(0,  lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))
capture noisily graph export "$RESULTS/eventstudies/new_`type'_$dataset/var`var'_`explaining'_sample`i'_c3_balancedbinning_`type'.png", replace

ppmlhdfe `var' F?_change_`explaining' zero_1 L?_change_`explaining' `sample`i'', absorb(estab_id year#i.fips_state) cl(estab_id)
est sto reg4
coefplot reg4, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black))  keep(F?_change_`explaining' zero_1 L?_change_`explaining') yline(0,  lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))
capture noisily graph export "$RESULTS/eventstudies/new_`type'_$dataset/var`var'_`explaining'_sample`i'_c4_balancedbinning_`type'.png", replace

ppmlhdfe `var' F?_change_`explaining' zero_1 L?_change_`explaining' `other_controls' `sample`i'', absorb(estab_id year#i.fips_state) cl(estab_id)
est sto reg5
coefplot reg5, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black))  keep(F?_change_`explaining' zero_1 L?_change_`explaining') yline(0,  lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))
capture noisily graph export "$RESULTS/eventstudies/new_`type'_$dataset/var`var'_`explaining'_sample`i'_c5_balancedbinning_`type'.png", replace

}
}
	** Regular Regression
	
	foreach var of varlist ln_patents3 ln_n_inventors3  {

foreach explaining in all weighted threelargest  {
	
	
reghdfe `var' F?_change_`explaining' zero_1 L?_change_`explaining' `sample`i'', absorb(estab_id year#i.fips_state) cl(estab_id)
est sto reg4
coefplot reg4, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black))  keep(F?_change_`explaining' zero_1 L?_change_`explaining') yline(0,  lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))
capture noisily graph export "$RESULTS/eventstudies/new_`type'_$dataset/czone/var`var'_`explaining'_sample`i'_c4_balancedbinning_`type'.png", replace

reghdfe `var' F?_change_`explaining' zero_1 L?_change_`explaining' `other_controls' `sample`i'', absorb(estab_id year#i.fips_state) cl(estab_id)
est sto reg5
coefplot reg5, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black))  keep(F?_change_`explaining' zero_1 L?_change_`explaining') yline(0,  lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))
capture noisily graph export "$RESULTS/eventstudies/new_`type'_$dataset/czone/var`var'_`explaining'_sample`i'_c5_balancedbinning_`type'.png", replace

}
	}	

}

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


********************************************************************************
* Regular Event Studies: Binning Off + Balanced Panel
********************************************************************************

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

	    local sample1 if year>=1988 
		local sample2 if inrange(year, 1988, 2018)  & total_patents>10 


forvalues i = 1/2 {
	
foreach var of varlist patents3 patents3_w1 n_inventors3 n_inventors3_w1 n_newinventors3 n_newinventors3_w1 {

foreach explaining in all weighted threelargest {
	
* Generating the local which contains control variables 	
	local other_controls other_cit_`explaining'3  other_pit_`explaining'3 other_unemployment_`explaining'3 other_gdp_`explaining'3  
	
ppmlhdfe `var'  F?_change_`explaining' zero_1 L?_change_`explaining' `sample`i'' , absorb(estab_id year) cl(estab_id)
est sto reg1
coefplot reg1, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black))  keep(F?_change_`explaining' zero_1 L?_change_`explaining') yline(0,  lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))
capture noisily graph export "$RESULTS/eventstudies/new_`type'_$dataset/var`var'_`explaining'_sample`i'_c1_unbalancedbinning_`type'.png", replace


ppmlhdfe `var' F?_change_`explaining' zero_1 L?_change_`explaining' rd_credit pit cit ln_gdp unemployment `sample`i'', absorb(estab_id year) cl(estab_id)
est sto reg2
coefplot reg2, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black))  keep(F?_change_`explaining' zero_1 L?_change_`explaining') yline(0,  lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))
capture noisily graph export "$RESULTS/eventstudies/new_`type'_$dataset/var`var'_`explaining'_sample`i'_c2_unbalancedbinning_`type'.png", replace

ppmlhdfe `var' F?_change_`explaining' zero_1 L?_change_`explaining' rd_credit pit cit ln_gdp unemployment `other_controls' `sample`i'', absorb(estab_id year) cl(estab_id)
est sto reg3
coefplot reg3, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black))  keep(F?_change_`explaining' zero_1 L?_change_`explaining') yline(0,  lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))
capture noisily graph export "$RESULTS/eventstudies/new_`type'_$dataset/var`var'_`explaining'_sample`i'_c3_unbalancedbinning_`type'.png", replace

ppmlhdfe `var' F?_change_`explaining' zero_1 L?_change_`explaining' `sample`i'', absorb(estab_id year#i.fips_state) cl(estab_id)
est sto reg4
coefplot reg4, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black))  keep(F?_change_`explaining' zero_1 L?_change_`explaining') yline(0,  lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))
capture noisily graph export "$RESULTS/eventstudies/new_`type'_$dataset/var`var'_`explaining'_sample`i'_c4_unbalancedbinning_`type'.png", replace

ppmlhdfe `var' F?_change_`explaining' zero_1 L?_change_`explaining' `other_controls' `sample`i'', absorb(estab_id year#i.fips_state) cl(estab_id)
est sto reg5
coefplot reg5, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black))  keep(F?_change_`explaining' zero_1 L?_change_`explaining') yline(0,  lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))
capture noisily graph export "$RESULTS/eventstudies/new_`type'_$dataset/var`var'_`explaining'_sample`i'_c5_unbalancedbinning_`type'.png", replace
} 
}

	** Regular Regression
	
	
foreach var of varlist ln_patents3 ln_n_inventors3 {

foreach explaining in all weighted threelargest {
	
	
reghdfe `var' F?_change_`explaining' zero_1 L?_change_`explaining' `sample`i'', absorb(estab_id year#i.fips_state) cl(estab_id)
est sto reg4
coefplot reg4, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black))  keep(F?_change_`explaining' zero_1 L?_change_`explaining') yline(0,  lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))
capture noisily graph export "$RESULTS/eventstudies/new_`type'_$dataset/var`var'_`explaining'_sample`i'_c4_unbalancedbinning_`type'.png", replace

reghdfe `var' F?_change_`explaining' zero_1 L?_change_`explaining' `other_controls' `sample`i'', absorb(estab_id year#i.fips_state) cl(estab_id)
est sto reg5
coefplot reg5, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black))  keep(F?_change_`explaining' zero_1 L?_change_`explaining') yline(0,  lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))
capture noisily graph export "$RESULTS/eventstudies/new_`type'_$dataset/var`var'_`explaining'_sample`i'_c5_unbalancedbinning_`type'.png", replace

}
}
}

	}

	forvalues i = 3/4 {
		
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
}
