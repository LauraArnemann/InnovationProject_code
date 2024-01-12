// Project: Inventor Relocation
// Creation Date: 06/12/2023
// Last Update: 06/12/2023
// Author: Laura Arnemann 
// Goal: Merging the data set using the number of inventors in a state employed by the respective firm as outcome variable 

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


use "$IN/Stata/inventor_all.dta", clear 
tostring patnum, replace 
gen patent="0"+patnum 
merge m:1 patent using "$IN/cw_patent_compustat_adhps/cw_patent_compustat_adhps.dta"
keep if _merge==3
drop _merge 

* Drop all duplicate observations with same inventorid but different patent number 
duplicates drop inventor_id patnum, force 

bysort gvkey inventor_id appyear: gen patents=_N 
bysort state_fips_inventor gvkey inventor_id appyear: gen statepatents=_N 


gen share_statepatents=statepatents/patents 
bysort gvkey inventor_id appyear: egen max_stateshare=max(share_statepatents)

* (23,843 observations deleted)

drop patents 

bysort inventor_id appyear: gen patents=_N 
bysort gvkey inventor_id appyear: gen firmpatents=_N
gen share_firmpatents=firmpatents/patents 

bysort inventor_id appyear: egen max_firmshare=max(share_firmpatents)
keep if share_firmpatents==max_firmshare

duplicates drop inventor_id appyear gvkey state_fips_inventor, force 
duplicates tag inventor_id appyear gvkey, gen(dup)

gen state_weight=1
replace state_weight = share_statepatents if dup>0 
drop dup

duplicates tag inventor_id state_fips_inventor appyear, gen(dup)

gen firm_weight=1 
replace firm_weight = share_firmpatents if dup>0 
drop dup 

gen weight=firm_weight*state_weight 

gen inventors=1 

collapse (sum) n_inventors=inventors n_patents=firmpatents [pw=weight], by(gvkey appyear state_fips_inventor)

* Only keep companies with inventors present in multiple states 
bysort gvkey appyear: gen count=_N 
keep if count >1 

rename state_fips_inventor fips_state 
rename appyear year 



********************************************************************************
* Merging the data set with the RD Tax Credits 
********************************************************************************


merge m:1 fips_state year using `rd_credit_long'
keep if _merge==3 
drop _merge 

rename count n_labs

* Generate the average credit rate at other states
gen weighted_labs = rd_credit/(n_labs-1) 
bysort gvkey: egen avg_credit_rate = total(weighted_labs)
replace avg_credit_rate=avg_credit_rate-weighted_labs/(n_labs-1) 

label var avg_credit_rate "Average credit rate in other states in which the firm is active"

drop n_labs 
drop weighted_labs

* Credit rate weighted by number of inventors

bysort appyear gvkey: egen total_inventors=total(inventors)

gen rd_credit_w1=n_inventors*rd_credit_rate 

bysort appyear gvkey: gen avg_credit_rate_w=total(rd_credit_w1)
replace avg_credit_rate_w1 = (avg_credit_rate_w1 - rd_credit_w1)/(total_inventors -n_inventors)



* Credit rate weighted by share of patents in the respective state 

bysort appyear gvkey: egen total_patents=total(patents)

gen rd_credit_w2=n_patents*rd_credit_rate 

bysort appyear gvkey: gen avg_credit_rate_w=total(rd_credit_w1)
replace avg_credit_rate_w2 = (avg_credit_rate_w2 - rd_credit_w2)/(total_patents -n_patents)


save "${TEMP}/"





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














