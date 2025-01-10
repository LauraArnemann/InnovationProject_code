////////////////////////////////////////////////////////////////////////////////
// Project: 		Moving innovation
// Creation Date: 	29/11/2024
// Last Update: 	29/11/2024
// Author: 			Laura Arnemann 
//					Theresa Bührle
// Goal: 			Regular two-way fixed effects analysis, CZ level  
////////////////////////////////////////////////////////////////////////////////

local sample2 if inrange(year, 1988, 2018) & asg_corp==1
local sample3 if inrange(year, 1988, 2018) & asg_corp==1 & total_patents>20 
local sample4 if inrange(year, 1988, 2018) & asg_corp==1 & patents3>=10 & patents3!=. 
local sample5 if inrange(year, 1988, 2018)  & asg_corp==0
local sample6 if inrange(year, 1988, 2018)  & asg_corp==0 & total_patents>20 

local outcome n_inventors3_w1 n_newinventors3_w1 patents3_w1
*   n_lasttimeinventor n_relocatinginventors n_inventors2_w1 n_inventors1_w1
local outcome_log ln_n_inventors3 
	*inventor_productivity 	ln_patents3 ln_n_newinventors3   	
local weighting_strategy threelargest weighted 


foreach type in assignee  {
    // gvkey

	use "${TEMP}/final_cz_corp_`type'.dta", clear 

	bysort assignee_id year: egen total_patents=total(patents3)

	foreach var of varlist patents1 patents2 patents3 n_inventors1 n_inventors2 n_inventors3 n_newinventors1 n_newinventors3  {
			gstats winsor `var', cut(1 99) gen(`var'_w1)
			gstats winsor `var', cut(1 95) gen(`var'_w2)
			gen ln_`var'=log(`var')
	}

	label var other_credit_threelargest "Other RD Credit"
	label var other_credit_weighted "Other RD Credit"

	gen inventor_productivity = patents3/n_inventors3 
	replace inventor_productivity = 0 if missing(patents3)
		
********************************************************************************
* Regular Poisson regression
********************************************************************************		
		
	foreach var of varlist `outcome'  {

		foreach explaining in `weighting_strategy' {
			
			local other_controls other_cit_`explaining'  other_pit_`explaining'
					
			forvalues i =2/6  {

				ppmlhdfe `var' other_credit_`explaining' `sample`i'', absorb(estab_id year#i.czone) cl(estab_id)
				est sto regres1`i'
				estadd local yearfe "\checkmark", replace
				estadd local estabfe "\checkmark", replace

				ppmlhdfe `var' other_credit_`explaining' `other_controls' `sample`i'', absorb(estab_id year#i.czone) cl(estab_id)
				est sto regres2`i'
				estadd local stateyearfe "\checkmark", replace
				estadd local estabfe "\checkmark", replace
				estadd local othercontrols "\checkmark", replace
			}
		 
			esttab regres12 regres22 regres13 regres23 using "${RESULTS}/tables/stage1/czone/`var'_`explaining'_`type'_cz.tex", replace noconstant mtitles drop(`other_controls' _cons) ///
				cells(b(star fmt(%9.3f)) se(par)) stats(yearfe estabfe stateyearfe othercontrols N, ///
				fmt(%9.0g %9.0g %9.0g %9.0g %9.0g %9.0g ) label("Firm FE" "State-Year FE"  "Other Controls" "Observations")) ///
				mgroups("Corporate Assignees" "Large Corporate Assignees", pattern(1 0 1 0) prefix(\multicolumn{@span}{c}{) suffix(}) span) ///
				collabels(none) starl(* .10 ** .05 *** .01) label 
				
			esttab regres15 regres25 regres16 regres26 using "${RESULTS}/tables/stage1/czone/`var'_`explaining'_`type'_noncorporate_cz.tex", replace noconstant mtitles drop(`other_controls' _cons) ///
				cells(b(star fmt(%9.3f)) se(par)) stats(yearfe estabfe stateyearfe othercontrols N, ///
				fmt(%9.0g %9.0g %9.0g %9.0g %9.0g %9.0g ) label("Firm FE" "State-Year FE"  "Other Controls" "Observations")) ///
				mgroups("Corporate Assignees" "Large Corporate Assignees", pattern(1 0 1 0) prefix(\multicolumn{@span}{c}{) suffix(}) span) ///
				collabels(none) starl(* .10 ** .05 *** .01) label 
		
		}
	}
	
********************************************************************************
* Log as outcome and linear regression 
********************************************************************************

	foreach var of varlist `outcome_log' {
	
		foreach explaining in `weighting_strategy' {
			
			local other_controls other_cit_`explaining'  other_pit_`explaining'
				
			forvalues i =2/3  {
				
				reghdfe `var' other_credit_`explaining' `sample`i'', absorb(estab_id year#i.czone) cl(estab_id)
				est sto regres1`i'
				estadd local yearfe "\checkmark", replace
				estadd local estabfe "\checkmark", replace

				reghdfe `var' other_credit_`explaining' `other_controls' `sample`i'', absorb(estab_id year#i.czone) cl(estab_id)
				est sto regres2`i'
				estadd local stateyearfe "\checkmark", replace
				estadd local estabfe "\checkmark", replace
				estadd local othercontrols "\checkmark", replace
			}
		
			esttab regres12 regres22 regres13 regres23 using "${RESULTS}/tables/stage1/czone/`var'_`explaining'_`type'_cz.tex", replace noconstant mtitles drop(`other_controls'  _cons) ///
				cells(b(star fmt(%9.3f)) se(par)) stats(yearfe estabfe stateyearfe othercontrols N, ///
				fmt(%9.0g %9.0g %9.0g %9.0g %9.0g %9.0g ) label("Firm FE" "State-Year FE"  "Other Controls" "Observations")) ///
				mgroups("Corporate Assigness" "Large Corporate Assignees", pattern(1 0 1 0) prefix(\multicolumn{@span}{c}{) suffix(}) span) ///
				collabels(none) starl(* .10 ** .05 *** .01) label 	
				
			/*
			esttab regres15 regres25 regres16 regres26 using "${RESULTS}/tables/stage1/czone/`var'_`explaining'_`type'_noncorporate.tex", replace noconstant mtitles drop(`other_controls'  _cons) ///
				cells(b(star fmt(%9.3f)) se(par)) stats(yearfe estabfe stateyearfe othercontrols N, ///
				fmt(%9.0g %9.0g %9.0g %9.0g %9.0g %9.0g ) label("Firm FE" "State-Year FE"  "Other Controls" "Observations")) ///
				mgroups("Corporate Assigness" "Large Corporate Assignees", pattern(1 0 1 0) prefix(\multicolumn{@span}{c}{) suffix(}) span) ///
				collabels(none) starl(* .10 ** .05 *** .01) label 
			*/		
		}
	}
	

}

