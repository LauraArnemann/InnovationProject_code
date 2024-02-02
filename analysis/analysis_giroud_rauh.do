// Project: Inventor Relocation
// Creation Date: 06/12/2023
// Last Update: 06/12/2023
// Author: Laura Arnemann 
// Goal Similar analysis as in Giroud and Rauh 2019 paper 


use "${TEMP}/final_state.dta", clear

capture log close 
log using "${RESULTS}/log_24_02_02.log", replace
********************************************************************************
* Analysis without controls and without controlling for tax rates in other states 
********************************************************************************
foreach var of varlist patents1 patents2 patents3 n_inventors1 n_inventors2 n_inventors3 {
	gstats winsor `var', cut(1 99) gen(`var'_w1)
	gstats winsor `var', cut(1 95) gen(`var'_w2)
}


forvalues i = 1/3 {
	di "Using Definition `i'"
	
reghdfe patents`i' rd_credit, absorb(assignee_id year)
reghdfe patents`i'_w1 rd_credit, absorb(assignee_id year)
reghdfe patents`i'_w2 rd_credit, absorb(assignee_id year)

reghdfe patents`i' rd_credit if multistatefirm==1, absorb(assignee_id year)
reghdfe patents`i'_w1 rd_credit if multistatefirm==1, absorb(assignee_id year)
reghdfe patents`i'_w2 rd_credit if multistatefirm==1, absorb(assignee_id year)


ppmlhdfe patents`i' rd_credit, absorb(assignee_id year)
ppmlhdfe patents`i'_w1 rd_credit, absorb(assignee_id year)
ppmlhdfe patents`i'_w2 rd_credit, absorb(assignee_id year)

ppmlhdfe patents`i' rd_credit if multistatefirm==1, absorb(assignee_id year)
ppmlhdfe patents`i'_w1 rd_credit if multistatefirm==1, absorb(assignee_id year)
ppmlhdfe patents`i'_w2 rd_credit if multistatefirm==1, absorb(assignee_id year)


reghdfe n_inventors`i' rd_credit, absorb(assignee_id year)
reghdfe n_inventors`i'_w1 rd_credit, absorb(assignee_id year)
reghdfe n_inventors`i'_w2 rd_credit, absorb(assignee_id year)

reghdfe n_inventors`i' rd_credit if multistatefirm==1, absorb(assignee_id year)
reghdfe n_inventors`i'_w1 rd_credit if multistatefirm==1, absorb(assignee_id year)
reghdfe n_inventors`i'_w2 rd_credit if multistatefirm==1, absorb(assignee_id year)


ppmlhdfe n_inventors`i' rd_credit, absorb(assignee_id year)
ppmlhdfe n_inventors`i'_w1 rd_credit, absorb(assignee_id year)
ppmlhdfe n_inventors`i'_w2 rd_credit, absorb(assignee_id year)

ppmlhdfe n_inventors`i' rd_credit if multistatefirm==1, absorb(assignee_id year)
ppmlhdfe n_inventors`i'_w1 rd_credit if multistatefirm==1, absorb(assignee_id year)
ppmlhdfe n_inventors`i'_w2 rd_credit if multistatefirm==1, absorb(assignee_id year)


}


********************************************************************************
* Analysis without controls and with controls for credit rates in other states 
********************************************************************************


reghdfe patents1 rd_credit avg_credit_rate if multistatefirm==1, absorb(assignee_id year)
reghdfe patents2 rd_credit avg_credit_rate if multistatefirm==1, absorb(assignee_id year)
reghdfe patents3 rd_credit avg_credit_rate if multistatefirm==1, absorb(assignee_id year)


reghdfe n_inventors1 rd_credit avg_credit_rate if multistatefirm==1, absorb(assignee_id year)
reghdfe n_inventors2 rd_credit avg_credit_rate if multistatefirm==1, absorb(assignee_id year)
reghdfe n_inventors3 rd_credit avg_credit_rate if multistatefirm==1, absorb(assignee_id year)

* This finding is very weird for some reason there is also a positive effect on the number of patents in one state of the average credit rate in other states 


********************************************************************************
* Analysis without controls and controlling for tax rates in other states 
********************************************************************************




********************************************************************************
* Analysis without controls and with controls for credit rates in other states 
********************************************************************************