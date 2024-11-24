////////////////////////////////////////////////////////////////////////////////
// Project: 		Moving innovation
// Creation Date: 	15/06/2024
// Last Update: 	21/11/2024
// Author: 			Laura Arnemann 
//					Theresa Bührle
// Goal: 			Regular two-way fixed effects analysis  
////////////////////////////////////////////////////////////////////////////////

local sample2 if inrange(year, 1988, 2018) & asg_corp==1
local sample3 if inrange(year, 1988, 2018) & asg_corp==1 & total_patents>20 
local sample4 if inrange(year, 1988, 2018) & asg_corp==1 & patents3>=10 & patents3!=. 
local sample5 if inrange(year, 1988, 2018)  & asg_corp==0
local sample6 if inrange(year, 1988, 2018)  & asg_corp==0 & total_patents>20 

foreach type in assignee  {
    // gvkey

	use "${TEMP}/patentdata_clean_`type'.dta", clear 

	bysort assignee_id: gen count = _n 
	keep if count ==1  
	tempfile patentshelper
	save `patentshelper'

	use "${TEMP}/final_state_zeros_`type'.dta", clear 

	merge m:1 assignee_id using `patentshelper', keepusing(noncorp_asg asg_corp pub_assg)
		drop if _merge ==2 
		drop _merge 

	egen estab_id = group(assignee_id fips_state)

	bysort assignee_id year: egen total_patents=total(patents3)

	foreach var of varlist patents1 patents2 patents3 n_inventors1 n_inventors2 n_inventors3 n_newinventors1 n_newinventors3  n_relocatinginventors n_lasttimeinventor {
			gstats winsor `var', cut(1 99) gen(`var'_w1)
			gstats winsor `var', cut(1 95) gen(`var'_w2)
			gen ln_`var'=log(`var')
	}

	label var other_rd_credit_threelargest3 "Other RD Credit"
	label var other_rd_credit_weighted3 "Other RD Credit"

	gen inventor_productivity = patents3/n_inventors3 
	replace inventor_productivity = 0 if missing(patents3)
		
********************************************************************************
* Regular Poisson regression
********************************************************************************		
		
	foreach var of varlist $outcome  {

		foreach explaining in $weighting_strategy {
			
			local other_controls other_cit_`explaining'  other_pit_`explaining'
					
			forvalues i =2/6  {

				ppmlhdfe `var' other_rd_credit_`explaining' `sample`i'', absorb(estab_id year#i.fips_state) cl(estab_id)
				est sto regres1`i'
				estadd local yearfe "\checkmark", replace
				estadd local estabfe "\checkmark", replace

				ppmlhdfe `var' other_rd_credit_`explaining' `other_controls' `sample`i'', absorb(estab_id year#i.fips_state) cl(estab_id)
				est sto regres2`i'
				estadd local stateyearfe "\checkmark", replace
				estadd local estabfe "\checkmark", replace
				estadd local othercontrols "\checkmark", replace
			}
		 
			esttab regres12 regres22 regres13 regres23 using "${RESULTS}/tables/stage1/`var'_`explaining'_`type'.tex", replace noconstant mtitles drop(`other_controls' _cons) ///
				cells(b(star fmt(%9.3f)) se(par)) stats(yearfe estabfe stateyearfe othercontrols N, ///
				fmt(%9.0g %9.0g %9.0g %9.0g %9.0g %9.0g ) label("Firm FE" "State-Year FE"  "Other Controls" "Observations")) ///
				mgroups("Corporate Assignees" "Large Corporate Assignees", pattern(1 0 1 0) prefix(\multicolumn{@span}{c}{) suffix(}) span) ///
				collabels(none) starl(* .10 ** .05 *** .01) label 
				
			esttab regres15 regres25 regres16 regres26 using "${RESULTS}/tables/stage1/`var'_`explaining'_`type'_noncorporate.tex", replace noconstant mtitles drop(`other_controls' _cons) ///
				cells(b(star fmt(%9.3f)) se(par)) stats(yearfe estabfe stateyearfe othercontrols N, ///
				fmt(%9.0g %9.0g %9.0g %9.0g %9.0g %9.0g ) label("Firm FE" "State-Year FE"  "Other Controls" "Observations")) ///
				mgroups("Corporate Assignees" "Large Corporate Assignees", pattern(1 0 1 0) prefix(\multicolumn{@span}{c}{) suffix(}) span) ///
				collabels(none) starl(* .10 ** .05 *** .01) label 
		
		}
	}

	/*
********************************************************************************
* Log as outcome and linear regression 
********************************************************************************

	foreach var of varlist $outcome_log {
	
		foreach explaining in $weighting_strategy {
			
			local other_controls other_cit_`explaining'  other_pit_`explaining'
				
			forvalues i =2/3  {
				
				reghdfe `var' other_rd_credit_`explaining' `sample`i'', absorb(estab_id year#i.fips_state) cl(estab_id)
				est sto regres1`i'
				estadd local yearfe "\checkmark", replace
				estadd local estabfe "\checkmark", replace

				reghdfe `var' other_rd_credit_`explaining' `other_controls' `sample`i'', absorb(estab_id year#i.fips_state) cl(estab_id)
				est sto regres2`i'
				estadd local stateyearfe "\checkmark", replace
				estadd local estabfe "\checkmark", replace
				estadd local othercontrols "\checkmark", replace
			}
		
			esttab regres12 regres22 regres13 regres23 using "${RESULTS}/tables/stage1/`var'_`explaining'_`type'.tex", replace noconstant mtitles drop(`other_controls'  _cons) ///
				cells(b(star fmt(%9.3f)) se(par)) stats(yearfe estabfe stateyearfe othercontrols N, ///
				fmt(%9.0g %9.0g %9.0g %9.0g %9.0g %9.0g ) label("Firm FE" "State-Year FE"  "Other Controls" "Observations")) ///
				mgroups("Corporate Assigness" "Large Corporate Assignees", pattern(1 0 1 0) prefix(\multicolumn{@span}{c}{) suffix(}) span) ///
				collabels(none) starl(* .10 ** .05 *** .01) label 	
				
			/*
			esttab regres15 regres25 regres16 regres26 using "${RESULTS}/tables/stage1/`var'_`explaining'_`type'_noncorporate.tex", replace noconstant mtitles drop(`other_controls'  _cons) ///
				cells(b(star fmt(%9.3f)) se(par)) stats(yearfe estabfe stateyearfe othercontrols N, ///
				fmt(%9.0g %9.0g %9.0g %9.0g %9.0g %9.0g ) label("Firm FE" "State-Year FE"  "Other Controls" "Observations")) ///
				mgroups("Corporate Assigness" "Large Corporate Assignees", pattern(1 0 1 0) prefix(\multicolumn{@span}{c}{) suffix(}) span) ///
				collabels(none) starl(* .10 ** .05 *** .01) label 
			*/		
		}
	}
	*/
}

