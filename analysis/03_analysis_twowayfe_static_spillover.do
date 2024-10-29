////////////////////////////////////////////////////////////////////////////////
// Project:        	Moving innovation
// Creation Date: 	15/06/2024
// Last Update: 	29/10/2024
// Author: 			Laura Arnemann 
// Goal: 			Regular two-way fixed effects analysis 
////////////////////////////////////////////////////////////////////////////////

use "${TEMP}/final_cz_corp_assignee.dta", clear 

	foreach var of varlist patents3 n_inventors3 n_newinventors3 {
		gstats winsor `var', cut(1 99) gen(`var'_w1)
		gstats winsor `var', cut(1 95) gen(`var'_w2)
		gen ln_`var'=log(`var')
}
 
* Local with the type of explaining variation we want to use  

replace other_credit_threelargest = 0 if missing(other_credit_threelargest)
bysort assignee_id year: egen total_patents = total(patents3)

local sample1 if inrange(year, 1988, 2018)
local sample2 if inrange(year, 1988, 2018) & max_tr_other_threelargest!=1 
local sample3 if inrange(year, 1988, 2018) & total_patents>10 
local sample4 if inrange(year, 1988, 2018) & max_tr_other_threelargest!=1  & total_patents>10
local sample5 if inrange(year, 1988, 2018) & total_patents>10 & multistate_cz==0
local sample6 if inrange(year, 1988, 2018) & max_tr_other_threelargest!=1  & total_patents>10 & multistate_cz==0

local explaining cz_treated_levelcredit_w6
foreach var of varlist n_inventors3_w1 patents3_w1 n_newinventors3_w1  {
	
forvalues i =5/6 {
	
	 ppmlhdfe `var' `explaining' `sample`i'', absorb(estab_id year#i.fips_state) cl(czone)
       est sto regres1`i'
       estadd local yearfe "\checkmark", replace
       estadd local estabfe "\checkmark", replace

       ppmlhdfe `var' `explaining' other_credit_threelargest `sample`i'', absorb(estab_id year#i.fips_state) cl(czone)
       est sto regres2`i'
       estadd local stateyearfe "\checkmark", replace
       estadd local estabfe "\checkmark", replace
       estadd local othercontrols "\checkmark", replace
}

local explaining cz_treated_levelcredit_w6
	/*
	esttab regres11 regres21 regres12 regres22 using "${RESULTS}/tables/spillovers/var`var'_spillovers1.tex", replace noconstant mtitles keep(`explaining') ///
		cells(b(star fmt(%9.3f)) se(par)) stats( estabfe stateyearfe othercontrols N, ///
		fmt(%9.0g %9.0g %9.0g %9.0g %9.0g %9.0g ) label("Firm FE" "State-Year FE"  "R\&D Credit, other" "Observations")) ///
		mgroups("All" "No Treatment", pattern(1 0 1 0) prefix(\multicolumn{@span}{c}{) suffix(}) span) ///
		collabels(none) starl(* .10 ** .05 *** .01) label 
				

	esttab regres13 regres23 regres14 regres24 using "${RESULTS}/tables/spillovers/var`var'_spillovers2.tex", replace noconstant mtitles keep(`explaining') ///
		cells(b(star fmt(%9.3f)) se(par)) stats( estabfe stateyearfe othercontrols N, ///
		fmt(%9.0g %9.0g %9.0g %9.0g %9.0g %9.0g ) label("Firm FE" "State-Year FE"  "R\&D Credit, other" "Observations")) ///
		mgroups("All" "No Treatment", pattern(1 0 1 0) prefix(\multicolumn{@span}{c}{) suffix(}) span) ///
		collabels(none) starl(* .10 ** .05 *** .01) label 
	*/ 
				
	esttab regres15 regres25 regres16 regres26 using "${RESULTS}/tables/spillovers/var`var'_spillovers2.tex", replace noconstant mtitles keep(`explaining') ///
		cells(b(star fmt(%9.3f)) se(par)) stats( estabfe stateyearfe othercontrols N, ///
		fmt(%9.0g %9.0g %9.0g %9.0g %9.0g %9.0g ) label("Firm FE" "State-Year FE"  "R\&D Credit, other" "Observations")) ///
		mgroups("All" "No Treatment", pattern(1 0 1 0) prefix(\multicolumn{@span}{c}{) suffix(}) span) ///
		collabels(none) starl(* .10 ** .05 *** .01) label 
}

