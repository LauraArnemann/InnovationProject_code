// Project: Inventor Relocation
// Creation Date: 15/06/2024
// Last Update: 15/06/2024
// Author: Laura Arnemann 
// Goal: Regular two-way fixed effects analysis  

* Define Globals 

global weighting_strategy threelargest3 weighted3

use "${TEMP}/patents_helper_${dataset}.dta", clear
bysort assignee_id: gen count = _n 
keep if count ==1  
tempfile patentshelper
save `patentshelper'

*local sample1 if inrange(year, 1988, 2018)


use "${TEMP}/final_state_zeros_new_${dataset}_assignee.dta", clear 


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

	
local sample2 if inrange(year, 1988, 2018) & asg_corp==1
local sample3 if inrange(year, 1988, 2018) & asg_corp==1 & total_patents>20 
local sample4 if inrange(year, 1988, 2018) & asg_corp==1 & patents3>=10 & patents3!=. 
local sample5 if inrange(year, 1988, 2018)  & asg_corp==0
local sample6 if inrange(year, 1988, 2018)  & asg_corp==0 & total_patents>20 


* n_inventors1_w1 n_inventors2_w1 patents3_w1 n_newinventors3_w1
foreach var of varlist n_relocatinginventors_w1 n_lasttimeinventor_w1  {
	foreach explaining in $weighting_strategy {
	   local other_controls other_cit_`explaining'  other_pit_`explaining'
	   
	   forvalues i =2/3  {

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
	  * Exporting the Results in a log file, since no excel and tex available
			*log using "$RESULTS/tables/new_assignee_4/var`var'_`explaining'.log", replace 

			esttab regres12 regres22 regres13 regres23 using "${RESULTS}/tables/new_assignee_4/var`var'_`explaining'.tex", replace noconstant mtitles drop(`other_controls'  _cons) ///
				cells(b(star fmt(%9.3f)) se(par)) stats(yearfe estabfe stateyearfe othercontrols N, ///
				fmt(%9.0g %9.0g %9.0g %9.0g %9.0g %9.0g ) label("Firm FE" "State-Year FE"  "Other Controls" "Observations")) mgroups("Corporate Assigness" "Large Corporate Assignees", pattern(1 0 1 0) prefix(\multicolumn{@span}{c}{) suffix(}) span) ///
				collabels(none) starl(* .10 ** .05 *** .01) label 
			
/*			esttab regres15 regres25 regres16 regres26 using "${RESULTS}/tables/new_assignee_4/var`var'_`explaining'_noncorporate.tex", replace noconstant mtitles drop(`other_controls'  _cons) ///
				cells(b(star fmt(%9.3f)) se(par)) stats(yearfe estabfe stateyearfe othercontrols N, ///
				fmt(%9.0g %9.0g %9.0g %9.0g %9.0g %9.0g ) label("Firm FE" "State-Year FE"  "Other Controls" "Observations")) mgroups("Corporate Assigness" "Large Corporate Assignees", pattern(1 0 1 0) prefix(\multicolumn{@span}{c}{) suffix(}) span) ///
				collabels(none) starl(* .10 ** .05 *** .01) label 
*/	

			*capture log close 
}
}

********************************************************************************
* Log as Ouctome  
********************************************************************************
/*
*ln_n_inventors3 ln_patents3 ln_n_newinventors3
foreach var of varlist share_relocating share_lasttime  {
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
	
	/*
esttab regres15 regres25 regres16 regres26 using "${RESULTS}/tables/new_assignee_4/var`var'_`explaining'_noncorporate.tex", replace noconstant mtitles drop(`other_controls'  _cons) ///
				cells(b(star fmt(%9.3f)) se(par)) stats(yearfe estabfe stateyearfe othercontrols N, ///
				fmt(%9.0g %9.0g %9.0g %9.0g %9.0g %9.0g ) label("Firm FE" "State-Year FE"  "Other Controls" "Observations")) mgroups("Corporate Assigness" "Large Corporate Assignees", pattern(1 0 1 0) prefix(\multicolumn{@span}{c}{) suffix(}) span) ///
				collabels(none) starl(* .10 ** .05 *** .01) label 
*/
				
esttab regres12 regres22 regres13 regres23 using "${RESULTS}/tables/new_assignee_4/var`var'_`explaining'.tex", replace noconstant mtitles drop(`other_controls'  _cons) ///
				cells(b(star fmt(%9.3f)) se(par)) stats(yearfe estabfe stateyearfe othercontrols N, ///
				fmt(%9.0g %9.0g %9.0g %9.0g %9.0g %9.0g ) label("Firm FE" "State-Year FE"  "Other Controls" "Observations")) mgroups("Corporate Assigness" "Large Corporate Assignees", pattern(1 0 1 0) prefix(\multicolumn{@span}{c}{) suffix(}) span) ///
				collabels(none) starl(* .10 ** .05 *** .01) label 
				

}
}
*/

/*
********************************************************************************
* Robustness: Also using gvkey as identifier 
********************************************************************************



use "${TEMP}/final_state_zeros_new_${dataset}_gvkey.dta", clear 

egen estab_id = group(assignee_id fips_state)

bysort assignee_id year: egen total_patents=total(patents3)


foreach var of varlist patents1 patents2 patents3 n_inventors1 n_inventors2 n_inventors3 n_newinventors1 n_newinventors3 {
		gstats winsor `var', cut(1 99) gen(`var'_w1)
		gstats winsor `var', cut(1 95) gen(`var'_w2)
		gen ln_`var'=log(`var')
	}


local sample2 if inrange(year, 1988, 2018)  
local sample3  if inrange(year, 1988, 2018) & total_patents>20 
local sample4  if inrange(year, 1988, 2018) & patents3>10 

foreach var of varlist n_inventors1_w1 n_inventors2_w1 n_inventors3_w1 patents3_w1 n_newinventors3_w1  {
	foreach explaining in $weighting_strategy {
		forvalues i =2/3  {
	   local other_controls other_cit_`explaining'  other_pit_`explaining'
	
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
	  * Exporting the Results in a log file, since no excel and tex available

esttab regres12 regres22 regres13 regres23 using "${RESULTS}/tables/new_gvkey_4/var`var'_`explaining'_gvkey.tex", replace noconstant mtitles drop(`other_controls'  _cons) ///
				cells(b(star fmt(%9.3f)) se(par)) stats(yearfe estabfe stateyearfe othercontrols N, ///
				fmt(%9.0g %9.0g %9.0g %9.0g %9.0g %9.0g ) label("Firm FE" "State-Year FE"  "Other Controls" "Observations")) mgroups("Corporate Assigness" "Large Corporate Assignees", pattern(1 0 1 0) prefix(\multicolumn{@span}{c}{) suffix(}) span) ///
				collabels(none) starl(* .10 ** .05 *** .01) label 
}
}


