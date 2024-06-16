// Project: Inventor Relocation
// Creation Date: 15/06/2024
// Last Update: 15/06/2024
// Author: Laura Arnemann 
// Goal: Regular two-way fixed effects analysis  


*use "${TEMP}/final_state.dta", clear


foreach type in assignee gvkey {
	
use "${TEMP}/final_state_zeros_new_${dataset}_`type'.dta", clear 


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

* Sample Restrictions 

		local sample1 if year>=1988 
		local sample2 if inrange(year, 1988, 2018)  & total_patents>5 
		local sample3 if inrange(year, 1988, 2018)  & total_patents!=0
		local sample4 if inrange(year, 1988, 2018) & estab_patents>5
	

forvalues i = 1/4 {
	
foreach var of varlist patents3 patents3_w1 n_inventors3 n_inventors3_w1 n_newinventors3 n_newinventors3_w1 {

foreach explaining in all weighted threelargest {
	
	local other_controls other_cit_`explaining'3  other_pit_`explaining'3 other_unemployment_`explaining'3 other_gdp_`explaining'3  
	
ppmlhdfe `var' other_rd_credit_`explaining'3 rd_credit `sample`i'' , absorb(estab_id year) cl(estab_id)
est sto reg1
estadd local yearfe "\checkmark", replace
estadd local estabfe "\checkmark", replace


ppmlhdfe `var' other_rd_credit_`explaining'3 rd_credit pit cit ln_gdp unemployment `sample`i'', absorb(estab_id year) cl(estab_id)
est sto reg2
estadd local yearfe "\checkmark", replace
estadd local estabfe "\checkmark", replace
estadd local statecontrols "\checkmark", replace


ppmlhdfe `var' other_rd_credit_`explaining'3 rd_credit pit cit ln_gdp unemployment `other_controls' `sample`i'', absorb(estab_id year) cl(estab_id)
est sto reg3
estadd local yearfe "\checkmark", replace
estadd local estabfe "\checkmark", replace
estadd local statecontrols "\checkmark", replace
estadd local othercontrols "\checkmark", replace

ppmlhdfe `var' other_rd_credit_`explaining'3 `sample`i'', absorb(estab_id year#i.fips_state) cl(estab_id)
est sto reg4
estadd local stateyearfe "\checkmark", replace
estadd local estabfe "\checkmark", replace


ppmlhdfe `var' other_rd_credit_`explaining'3 `other_controls' `sample`i'', absorb(estab_id year#i.fips_state) cl(estab_id)
est sto reg5
estadd local stateyearfe "\checkmark", replace
estadd local estabfe "\checkmark", replace
estadd local othercontrols "\checkmark", replace

* Exporting the Results in a log file, since no excel and tex available

log using "$RESULTS/tables/new_`type'_${dataset}/var`var'_`explaining'_sample`i'_`type'.log", replace 

esttab reg1 reg2 reg3 reg4 reg5, replace noconstant nomtitles drop(`other_controls' pit cit ln_gdp unemployment _cons) cells(b(star fmt(%9.3f)) se(par)) stats(yearfe estabfe stateyearfe statecontrols othercontrols N, fmt(%9.0g %9.0g %9.0g %9.0g %9.0g %9.0g ) label("Year FE" "Firm FE" "State-Year FE" "State Controls" "Other Controls" "Observations")) collabels(none) starl(* .10 ** .05 *** .01) label 


capture log close 


}
}
}
}


