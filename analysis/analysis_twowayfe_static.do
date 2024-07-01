// Project: Inventor Relocation
// Creation Date: 15/06/2024
// Last Update: 15/06/2024
// Author: Laura Arnemann 
// Goal: Regular two-way fixed effects analysis  


foreach type in assignee gvkey {
	
	use "${TEMP}/final_state_zeros_new_${dataset}_`type'.dta", clear 

	*Different conditions for Balanced Panel 
     if ${dataset} == 2 {
     gen balanced_panel = 1 if min_year<=1988 & max_year>=2006 
      }
	  
	 else {
     gen balanced_panel = 1 if min_year<=1988 & max_year>=2018
	 * Only 206 unique gvkey observations
      }

	foreach var of varlist patents1 patents2 patents3 n_inventors1 n_inventors2 n_inventors3  n_newinventors1 n_newinventors3 {
		gstats winsor `var', cut(1 99) gen(`var'_w1)
		gstats winsor `var', cut(1 95) gen(`var'_w2)
		gen ln_`var'=log(`var')
	}

	gen ln_gdp=log(gdp)

	foreach var of varlist  other_gdp_weighted3 other_gdp_all3 other_gdp_threelargest3 {
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

	forvalues i = 1/2 {
		
		foreach var of $outcome {

			foreach explaining in $weighting_strategy {
				
			local other_controls other_cit_`explaining'  other_pit_`explaining' other_unemployment_`explaining' other_gdp_`explaining'  
				
			ppmlhdfe `var' other_rd_credit_`explaining' rd_credit $sample`i' , absorb(estab_id year#i.fips_state) cl(estab_id)
			est sto regres1
			estadd local yearfe "\checkmark", replace
			estadd local estabfe "\checkmark", replace

			ppmlhdfe `var' other_rd_credit_`explaining' `other_controls' $sample`i', absorb(estab_id year#i.fips_state) cl(estab_id)
			est sto regres2
			estadd local stateyearfe "\checkmark", replace
			estadd local estabfe "\checkmark", replace
			estadd local othercontrols "\checkmark", replace

			* Exporting the Results in a log file, since no excel and tex available
			log using "$RESULTS/tables/new_`type'_${dataset}/var`var'_`explaining'_sample`i'_`type'.log", replace 

			esttab regres1 regres2, replace noconstant nomtitles drop(`other_controls' pit cit ln_gdp unemployment _cons) ///
				cells(b(star fmt(%9.3f)) se(par)) stats(yearfe estabfe stateyearfe statecontrols othercontrols N, ///
				fmt(%9.0g %9.0g %9.0g %9.0g %9.0g %9.0g ) label("Year FE" "Firm FE" "State-Year FE" "State Controls" "Other Controls" "Observations")) ///
				collabels(none) starl(* .10 ** .05 *** .01) label 

			capture log close 
			}
		}
	}


	********************************************************************************
	* Also running the logarithm 
	********************************************************************************
	forvalues i = 1/2  {
		
		foreach var of varlist $outcome_log  {

			foreach explaining in $weighting_strategy {
				
			reghdfe `var' other_rd_credit_`explaining' $sample`i' , absorb(estab_id year#i.fips_state) cl(estab_id)
			est sto regres3
			estadd local yearfe "\checkmark", replace
			estadd local estabfe "\checkmark", replace

			reghdfe `var' other_rd_credit_`explaining' `other_controls' $sample`i', absorb(estab_id year#i.fips_state) cl(estab_id)
			est sto regres4
			estadd local stateyearfe "\checkmark", replace
			estadd local estabfe "\checkmark", replace
			estadd local othercontrols "\checkmark", replace

			* Exporting the Results in a log file, since no excel and tex available
			log using "$RESULTS/tables/new_`type'_${dataset}/var`var'_`explaining'_sample`i'_`type'_log.log", replace 

			esttab regres3 regres4, replace noconstant nomtitles drop(`other_controls' pit cit ln_gdp unemployment _cons) ///
				cells(b(star fmt(%9.3f)) se(par)) stats(yearfe estabfe stateyearfe statecontrols othercontrols N, ///
				fmt(%9.0g %9.0g %9.0g %9.0g %9.0g %9.0g ) label("Year FE" "Firm FE" "State-Year FE" "State Controls" "Other Controls" "Observations")) ///
				collabels(none) starl(* .10 ** .05 *** .01) label 

			capture log close 

			}
		}
	}
}

