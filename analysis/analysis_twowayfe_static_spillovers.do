// Project: Inventor Relocation
// Creation Date: 15/06/2024
// Last Update: 15/06/2024
// Author: Laura Arnemann 
// Goal: Regular two-way fixed effects analysis 



use "${TEMP}/final_cz_${dataset}_corp_new.dta", clear 

	foreach var of varlist patents3 n_inventors3 n_newinventors3 {
		gstats winsor `var', cut(1 99) gen(`var'_w1)
		gstats winsor `var', cut(1 95) gen(`var'_w2)
		gen ln_`var'=log(`var')
}
 
* Local with the type of explaining variation we want to use  

 
replace other_threelargest = 0 if missing(other_threelargest)
 
local sample1 if inrange(year, 1988, 2018)
local sample2 if inrange(year, 1988, 2018) & max_tr_other_threelargest!=1 
local sample3 if inrange(year, 1988, 2018) & total_patents>10 
local sample4 if inrange(year, 1988, 2018) & max_tr_other_threelargest!=1  & total_patents>10

/*
local sample2 if inrange(year, 1988, 2018) & total_patents>10 
local sample3 if inrange(year, 1988, 2018) & total_patents<10 
local sample4 if inrange(year, 1988, 2018) & pub_assg==1 
local sample5 if inrange(year, 1988, 2018) & asg_corp==1
local sample6 if inrange(year, 1988, 2018) & noncorp_asg==0
local sample7 if inrange(year, 1988, 2018) 
local sample8 if inrange(year, 1988, 2018) & tag_local==1
local sample9 if inrange(year, 1988, 2018) & treated!=1  	
local sample10 if inrange(year, 1988, 2018) & multistate_cz ==0 
local sample11 if inrange(year, 1988, 2018) & tag_local==1 & multistate_cz ==0 
local sample12 if inrange(year, 1988, 2018) & noncorp_asg==1 
*/

bysort assignee_id year: egen total_patents = total(patents3)

local sample1 if inrange(year, 1988, 2018)
local sample2 if inrange(year, 1988, 2018) & max_tr_other_threelargest!=1 
local sample3 if inrange(year, 1988, 2018) & total_patents>10 
local sample4 if inrange(year, 1988, 2018) & max_tr_other_threelargest!=1  & total_patents>10


local explaining cz_treated_level_w6
foreach var of varlist n_inventors3_w1 patents3_w1 n_newinventors3_w1  {
	
forvalues i =1/4 {
	
	 ppmlhdfe `var' `explaining' `sample`i'', absorb(estab_id year#i.fips_state) cl(czone)
       est sto regres1`i'
       estadd local yearfe "\checkmark", replace
       estadd local estabfe "\checkmark", replace

       ppmlhdfe `var' `explaining' other_threelargest `sample`i'', absorb(estab_id year#i.fips_state) cl(czone)
       est sto regres2`i'
       estadd local stateyearfe "\checkmark", replace
       estadd local estabfe "\checkmark", replace
       estadd local othercontrols "\checkmark", replace
	   

}

local explaining cz_treated_level_w6
	  * Exporting the Results in a log file, since no excel and tex available
esttab regres11 regres21 regres12 regres22 using "${RESULTS}/tables/spillovers/var`var'_spillovers1.tex", replace noconstant mtitles keep(`explaining') ///
				cells(b(star fmt(%9.3f)) se(par)) stats( estabfe stateyearfe othercontrols N, ///
				fmt(%9.0g %9.0g %9.0g %9.0g %9.0g %9.0g ) label("Firm FE" "State-Year FE"  "R\&D Credit, other" "Observations")) mgroups("All" "No Treatment", pattern(1 0 1 0) prefix(\multicolumn{@span}{c}{) suffix(}) span) ///
				collabels(none) starl(* .10 ** .05 *** .01) label 
				

esttab regres13 regres23 regres14 regres24 using "${RESULTS}/tables/spillovers/var`var'_spillovers2.tex", replace noconstant mtitles keep(`explaining') ///
				cells(b(star fmt(%9.3f)) se(par)) stats( estabfe stateyearfe othercontrols N, ///
				fmt(%9.0g %9.0g %9.0g %9.0g %9.0g %9.0g ) label("Firm FE" "State-Year FE"  "R\&D Credit, other" "Observations")) mgroups("All" "No Treatment", pattern(1 0 1 0) prefix(\multicolumn{@span}{c}{) suffix(}) span) ///
				collabels(none) starl(* .10 ** .05 *** .01) label 

	
}

