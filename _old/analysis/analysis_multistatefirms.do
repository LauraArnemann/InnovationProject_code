






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
