// Project: Inventor Relocation
// Creation Date: 06/12/2023
// Last Update: 06/12/2023
// Author: Laura Arnemann 
// Goal: Merge the data sets for innovators with the data set for patents 

global IN C:/Users/laura/Desktop/Data/Patent_Data
global IN2 C:/Users/laura/Desktop/InnovationProject/data/raw

********************************************************************************
* Merging the dataset 
********************************************************************************

import excel "${IN2}/indep_var/var_RDcredits/RD_credits_final.xlsx", sheet("rd_summary") firstrow clear 
drop if missing(fips_state)

rename DT1lowesttier rd_credit 
keep fips_state year rd_credit 

tempfile rd_credit_long 
save `rd_credit_long', replace


import excel "${IN2}/indep_var/var_RDcredits/RD_credits_final.xlsx", sheet("rd_summary") firstrow clear 
drop if missing(fips_state)

rename DT1lowesttier rd_credit 
keep fips_state year rd_credit 

reshape wide rd_credit, i(year) j(fips_state)

forvalues i=1/56 {
	gen weight`i'=. 
	gen indicator`i'=. 
} 

tempfile rd_credit_wide 
save `rd_credit_wide', replace  



use "$IN/Stata/inventor_all.dta", clear 
tostring patnum, replace 
gen patent="0"+patnum 
merge m:1 patent using "$IN/cw_patent_compustat_adhps/cw_patent_compustat_adhps.dta"
keep if _merge==3
drop _merge 

duplicates report patnum inventor_id
duplicates drop patnum inventor_id, force 

bysort patnum: gen weight=_N 
replace weight=1/weight 
bysort inventor_id: gen num_patents=_N

collapse (mean) num_patents [pw=weight], by(gvkey state_fips_inventor appyear) 


* Only keep companies with inventors present in multiple states 
bysort gvkey appyear: gen count=_N 
keep if count >1 

* Indicator Variable for the share of patents granted at the respective plant 

rename state_fips_inventor fips_state 
rename appyear year 

* Merging the data set with the RD Tax Credits 
merge m:1 fips_state year using `rd_credit_long'
keep if _merge==3 
drop _merge 

rename count n_labs

* Generate the average credit rate at other states
gen weighted_labs = rd_credit/(n_labs-1) 
bysort gvkey: egen avg_credit_rate = total(weighted_labs)
replace avg_credit_rate=avg_credit_rate-weighted_labs

label var avg_credit_rate "Average credit rate in other states in which the firm is active"

drop n_labs 
drop weighted_labs

***********************************************
* Creating the weighted credit rate 
***********************************************

* Merging the data set with all other RD Tax Credits in the same state 
merge m:1 year using `rd_credit_wide'
keep if _merge==3 
drop _merge 

forvalues i=1/56 {
	replace weight`i' = num_patents if fips_state==`i'
	replace weight`i' =0 if fips_state!=`i'
	
}


forvalues i=1/56 {
	bysort gvkey appyear: egen max_weight`i' = max(weight`i')
	replace weight`i' = max_weight`i'
	drop max_weight`i'
}

bysort gvkey appyear: gen total_patents=total(num_patents)
replace total_patents=total_patents-num_patents 

forvalues i=1/56 {
	replace weight`i'=weight`i'/total_patents
}



* Average tax rates weighted by number of patents in the respective state 

local c "(weight1 * rd_credit1)"

forvalues i =2/56 {
	if `i'==3 | `i'==7 | `i'==14 | `i'==43 | `i'==52 {
		local c `c'
	}
	else {
	local d " (weight`i' * rd_credit`i')"
	local c `c'+`d'
	}
}

di "`d'"

gen avg_rate_active_weight = "`d'"

forvalues i=1/56 {
	
	replace avg_rate_active_weight=avg_rate_active_weight- (weight`i'*rd_credit`i') if state_fips==`i'

}

rename rd_credit state_credit

drop weight* rd_credit* 

/* I actually think this is not necessary 









* Average tax rates in general 

gen avg_rate = rdcredit

* Average tax rates weighted by presence in the respective state 
local a "(indicator1 * rd_credit1)"

forvalues i =2/56 {
	if `i'==3 | `i'==7 | `i'==14 | `i'==43 | `i'==52 {
		local a `a'
	}
	else {
	local b " (indicator`i' * rd_credit`i')"
	local a `a'+`b'
	}
}

di "`a'"

bysort gvkey appyear: egen avg_rate_active = "`a'"














