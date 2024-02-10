// Project: Inventor Relocation
// Creation Date: 06/12/2023
// Last Update: 06/12/2023
// Author: Laura Arnemann 
// Goal Similar analysis as in Giroud and Rauh 2019 paper 


use "${TEMP}/final_state.dta", clear
*use "${TEMP}/final_state_withzeros.dta", clear 

foreach var of varlist patents1 patents2 patents3 n_inventors1 n_inventors2 n_inventors3 {
	gstats winsor `var', cut(1 99) gen(`var'_w1)
	gstats winsor `var', cut(1 95) gen(`var'_w2)
	gen ln_`var'=log(`var')
}

gen ln_gdp=log(gdp)
gen ln_total_gdp=log(total_gdp)

bysort assignee_id year: egen total_patents=total(patents3)

********************************************************************************
* Main Regression Analysis: Giroud Rauh, Table 4  
********************************************************************************
tostring fips_state, gen(str_state)
gen estab_id = assignee_id + str_state

label var pit "PIT"
label var cit "CIT"
label var rd_credit "R\&D Credit"
label var total_rd_credit "R\&D Credit, other"


foreach var of varlist patents3_w1 n_inventors3_w1 {


ppmlhdfe `var' rd_credit  if year>=1992 , absorb(assignee_id year) cl(fips_state)
est sto reg1
estadd local yearfe "\checkmark", replace
estadd local firmfe "\checkmark", replace

ppmlhdfe  `var' rd_credit total_rd_credit if year>=1992, absorb(assignee_id year) cl(fips_state)
est sto reg2
estadd local yearfe "\checkmark", replace
estadd local firmfe "\checkmark", replace

ppmlhdfe  `var' rd_credit total_rd_credit pit cit ln_gdp if year>=1992 , absorb(assignee_id year) cl(fips_state)
est sto reg3
estadd local yearfe "\checkmark", replace
estadd local firmfe "\checkmark", replace

ppmlhdfe  `var' rd_credit total_rd_credit pit cit total_pit total_cit ln_total_gdp if year>=1992, absorb(assignee_id year) cl(fips_state)
est sto reg4
estadd local yearfe "\checkmark", replace
estadd local firmfe "\checkmark", replace
estadd local otherfe "\checkmark", replace


*esttab reg1 reg2 reg3 reg4 using "${RESULTS}/tables/poissonreg_`var'.tex", replace noconstant nomtitles drop(total_pit total_cit _cons) cells(b(star fmt(%9.3f)) se(par)) stats(yearfe firmfe otherfe N, fmt(%9.0g %9.0g %9.0g %9.0g %9.3f ) label("Year FE" "Firm FE" "Other Controls" "Observations")) collabels(none) starl(* .10 ** .05 *** .01) label 
}


********************************************************************************
* Assignee State Fixed Effects 
********************************************************************************



foreach var of varlist patents3_w1 n_inventors3_w1 {

ppmlhdfe `var' rd_credit if year>=1992 , absorb(estab_id year) cl(fips_state)
est sto reg1
estadd local yearfe "\checkmark", replace
estadd local firmfe "\checkmark", replace

ppmlhdfe  `var' rd_credit total_rd_credit if year>=1992, absorb(estab_id year) cl(fips_state)
est sto reg2
estadd local yearfe "\checkmark", replace
estadd local firmfe "\checkmark", replace

ppmlhdfe  `var' rd_credit total_rd_credit pit cit if year>=1992 , absorb(estab_id year) cl(fips_state)
est sto reg3
estadd local yearfe "\checkmark", replace
estadd local firmfe "\checkmark", replace

ppmlhdfe  `var' rd_credit total_rd_credit pit cit total_pit total_cit if year>=1992 , absorb(estab_id year) cl(fips_state)
est sto reg4
estadd local yearfe "\checkmark", replace
estadd local firmfe "\checkmark", replace
estadd local estabfe "\checkmark", replace

ppmlhdfe  `var' rd_credit total_rd_credit pit cit total_pit total_cit if year>=1992 , absorb(estab_id year#fips_state) cl(fips_state)
est sto reg5
estadd local stateyearfe "\checkmark", replace
estadd local firmfe "\checkmark", replace
estadd local otherfe "\checkmark", replace


esttab reg1 reg2 reg3 reg4 reg5 using "${RESULTS}/tables/poissonreg_`var'_statefe.tex", replace noconstant nomtitles drop(total_pit total_cit _cons) cells(b(star fmt(%9.3f)) se(par)) stats(yearfe stateyearfe firmfe otherfe N, fmt(%9.0g %9.0g %9.0g %9.0g %9.0g %9.3f ) label("Year FE" "State$\times$ Year FE" "Firm $\times$ StateFE" "Other Controls" "Observations")) collabels(none) starl(* .10 ** .05 *** .01) label 

}















capture log close 
log using "${RESULTS}/log_24_02_08_nocontrols.log", replace
forvalues i = 1/3 {
	di "Using Definition `i'"
	
reghdfe patents`i' rd_credit, absorb(assignee_id year) cl(state)
reghdfe patents`i'_w1 rd_credit, absorb(assignee_id year) cl(state)
reghdfe patents`i'_w2 rd_credit, absorb(assignee_id year) cl(state)
reghdfe ln_patents`i' rd_credit, absorb(assignee_id year) cl(state)


reghdfe patents`i' rd_credit if multistatefirm_max==1, absorb(assignee_id year)
reghdfe patents`i'_w1 rd_credit if multistatefirm_max==1, absorb(assignee_id year)
reghdfe patents`i'_w2 rd_credit if multistatefirm_max==1, absorb(assignee_id year)
reghdfe ln_patents`i' rd_credit if multistatefirm_max==1, absorb(assignee_id year)

ppmlhdfe patents`i' rd_credit, absorb(assignee_id year)
ppmlhdfe patents`i'_w1 rd_credit, absorb(assignee_id year)
ppmlhdfe patents`i'_w2 rd_credit, absorb(assignee_id year)

ppmlhdfe patents`i' rd_credit if multistatefirm_max==1, absorb(assignee_id year)
ppmlhdfe patents`i'_w1 rd_credit if multistatefirm_max==1, absorb(assignee_id year)
ppmlhdfe patents`i'_w2 rd_credit if multistatefirm_max==1, absorb(assignee_id year)


reghdfe n_inventors`i' rd_credit, absorb(assignee_id year)
reghdfe n_inventors`i'_w1 rd_credit, absorb(assignee_id year)
reghdfe n_inventors`i'_w2 rd_credit, absorb(assignee_id year)
reghdfe ln_n_inventors`i' rd_credit, absorb(assignee_id year)

reghdfe n_inventors`i' rd_credit if multistatefirm_max==1, absorb(assignee_id year)
reghdfe n_inventors`i'_w1 rd_credit if multistatefirm_max==1, absorb(assignee_id year)
reghdfe n_inventors`i'_w2 rd_credit if multistatefirm_max==1, absorb(assignee_id year)
reghdfe ln_n_inventors`i' rd_credit if multistatefirm_max==1, absorb(assignee_id year)

ppmlhdfe n_inventors`i' rd_credit, absorb(assignee_id year)
ppmlhdfe n_inventors`i'_w1 rd_credit, absorb(assignee_id year)
ppmlhdfe n_inventors`i'_w2 rd_credit, absorb(assignee_id year)

ppmlhdfe n_inventors`i' rd_credit if multistatefirm_max==1, absorb(assignee_id year)
ppmlhdfe n_inventors`i'_w1 rd_credit if multistatefirm_max==1, absorb(assignee_id year)
ppmlhdfe n_inventors`i'_w2 rd_credit if multistatefirm_max==1, absorb(assignee_id year)

}




********************************************************************************
* Analysis with controls and without controlling for tax rates in other states 
********************************************************************************
capture log close 
log using "${RESULTS}/log_24_02_07_controls.log", replace

local controls corprate_orig t_pinc_rate_orig ITC_rate_orig GDP_orig avg_credit_rate

forvalues i = 1/3 {
	di "Using Definition `i'"
	
reghdfe patents`i' rd_credit `controls', absorb(assignee_id year)
reghdfe patents`i'_w1 rd_credit `controls', absorb(assignee_id year)
reghdfe patents`i'_w2 rd_credit `controls', absorb(assignee_id year)
reghdfe ln_patents`i' rd_credit `controls', absorb(assignee_id year)


reghdfe patents`i' rd_credit `controls' if multistatefirm_max==1, absorb(assignee_id year)
reghdfe patents`i'_w1 rd_credit `controls' if multistatefirm_max==1, absorb(assignee_id year)
reghdfe patents`i'_w2 rd_credit `controls' if multistatefirm_max==1, absorb(assignee_id year)
reghdfe ln_patents`i' rd_credit `controls' if multistatefirm_max==1, absorb(assignee_id year)

ppmlhdfe patents`i' rd_credit `controls', absorb(assignee_id year)
ppmlhdfe patents`i'_w1 rd_credit `controls', absorb(assignee_id year)
ppmlhdfe patents`i'_w2 rd_credit `controls', absorb(assignee_id year)

ppmlhdfe patents`i' rd_credit `controls' if multistatefirm_max==1, absorb(assignee_id year)
ppmlhdfe patents`i'_w1 rd_credit `controls' if multistatefirm_max==1, absorb(assignee_id year)
ppmlhdfe patents`i'_w2 rd_credit `controls' if multistatefirm_max==1, absorb(assignee_id year)


reghdfe n_inventors`i' rd_credit `controls', absorb(assignee_id year)
reghdfe n_inventors`i'_w1 rd_credit `controls', absorb(assignee_id year)
reghdfe n_inventors`i'_w2 rd_credit `controls', absorb(assignee_id year)
reghdfe ln_n_inventors`i' rd_credit `controls', absorb(assignee_id year)

reghdfe n_inventors`i' rd_credit `controls' if multistatefirm_max==1, absorb(assignee_id year)
reghdfe n_inventors`i'_w1 rd_credit `controls' if multistatefirm_max==1, absorb(assignee_id year)
reghdfe n_inventors`i'_w2 rd_credit `controls' if multistatefirm_max==1, absorb(assignee_id year)
reghdfe ln_n_inventors`i' rd_credit `controls' if multistatefirm_max==1, absorb(assignee_id year)

ppmlhdfe n_inventors`i' rd_credit `controls', absorb(assignee_id year)
ppmlhdfe n_inventors`i'_w1 rd_credit `controls', absorb(assignee_id year)
ppmlhdfe n_inventors`i'_w2 rd_credit `controls', absorb(assignee_id year)

ppmlhdfe n_inventors`i' rd_credit `controls' if multistatefirm_max==1, absorb(assignee_id year)
ppmlhdfe n_inventors`i'_w1 rd_credit `controls' if multistatefirm_max==1, absorb(assignee_id year)
ppmlhdfe n_inventors`i'_w2 rd_credit `controls' if multistatefirm_max==1, absorb(assignee_id year)

}


********************************************************************************
* Analysis without controls and with controls for credit rates in other states 
********************************************************************************
capture log close 
log using "${RESULTS}/log_24_02_08_controls_rdcredit.log", replace

local controls1
local controls2 cit gdp pit 

forvalues y=2/2 {
forvalues i = 1/3 {
	di "Using Definition `i' and Controls `y'"

reghdfe patents`i' rd_credit total_credit_other `controls`y'', absorb(assignee_id year)
reghdfe patents`i'_w1 rd_credit total_credit_other `controls`y'' , absorb(assignee_id year)
reghdfe patents`i'_w2 rd_credit total_credit_other `controls`y'' , absorb(assignee_id year)
reghdfe ln_patents`i' rd_credit total_credit_other `controls`y''  , absorb(assignee_id year)

ppmlhdfe patents`i' rd_credit total_credit_other `controls`y'' , absorb(assignee_id year)
ppmlhdfe patents`i'_w1 rd_credit total_credit_other `controls`y'', absorb(assignee_id year)
ppmlhdfe patents`i'_w2 rd_credit total_credit_other `controls`y'', absorb(assignee_id year)

reghdfe n_inventors`i' rd_credit total_credit_other `controls`y'', absorb(assignee_id year)
reghdfe n_inventors`i'_w1 rd_credit total_credit_other `controls`y'', absorb(assignee_id year)
reghdfe n_inventors`i'_w2 rd_credit total_credit_other `controls`y'', absorb(assignee_id year)
reghdfe ln_n_inventors`i' rd_credit total_credit_other `controls`y'' , absorb(assignee_id year)

ppmlhdfe n_inventors`i' rd_credit total_credit_other `controls`y'' , absorb(assignee_id year)
ppmlhdfe n_inventors`i'_w1 rd_credit total_credit_other `controls`y'', absorb(assignee_id year)
ppmlhdfe n_inventors`i'_w2 rd_credit total_credit_other `controls`y'' , absorb(assignee_id year)

}
}
