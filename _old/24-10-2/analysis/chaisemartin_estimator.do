////////////////////////////////////////////////////////////////////////////////
// Project:        	Moving innovation
// Creation Date:  	06/12/2023
// Last Update:    	24/04/2024
// Authors:         Laura Arnemann
//					Theresa Bührle
// Goal: 			Using the Sun & Abraham and Chaisemartin approach 
////////////////////////////////////////////////////////////////////////////////

local sample1 if inrange(year, 1988, 2018)
local sample2 if inrange(year, 1988, 2018)  & total_patents>10 
local sample3  if inrange(year, 1988, 2018)  & balanced_panel==1
local sample4  if inrange(year, 1988, 2018)  & balanced_panel==1 & total_patents>10 

foreach type in  gvkey {

use "${TEMP}/final_state_zeros_new_${dataset}_`type'.dta", clear 

drop if missing(assignee_id)

bysort assignee_id year : egen n_patents = total(patents3)

foreach var of varlist patents1 patents2 patents3 n_inventors1 n_inventors2 n_inventors3 {
	gstats winsor `var', cut(1 99) gen(`var'_w1)
	gstats winsor `var', cut(1 95) gen(`var'_w2)
	gen ln_`var'=log(`var')
}

gen ln_gdp =log(gdp)

bysort assignee_id fips_state: egen total_patents = total(patents3)
egen estab = group(fips_state assignee_id)
bysort estab: egen estab_patents = total(patents3)
egen state_year = group(fips_state year)



* all weighted threelargest
foreach helper in threelargest {
	xtset estab year 
gen change_other_credit = other_rd_credit_`helper'3 - l.other_rd_credit_`helper'3
gen byte increase_credit = change_other_credit>=1 & change_other_credit!=. 
gen byte decrease_credit = change_other_credit<=-1 & change_other_credit!=. 


bysort assignee_id fips_state: egen max_decrease = max(decrease_credit)
bysort assignee_id fips_state: egen max_increase = max(increase_credit)

replace other_gdp_`helper'3 = ln(other_gdp_`helper'3)

 *******************************************************************************
 * Chaisemartin Estimator 
 *******************************************************************************
	
****** Only Establishment and Year Fixed Effects 	
* No Controls 		
	forvalues i =5/5 {	
foreach var of varlist $outcome { 
 
* Both Changes 
did_multiplegt_dyn `var' estab year change_other_credit `sample`i'', effects(6) placebo(4) cluster(estab)
graph export "${RESULTS}/chaisemartin_new/new_`type'_${dataset}/graph`var'_sample`i'`helper'_c0_both_continuous_year.png", replace 

* Only Increases
did_multiplegt_dyn `var' estab year change_other_credit `sample`i'' & max_decrease == 0, effects(6) placebo(4) cluster(estab)
graph export "${RESULTS}/chaisemartin_new/new_`type'_${dataset}/graph`var'_sample`i'`helper'_incr_continuous_year.png", replace 

did_multiplegt_dyn `var' estab year increase_credit `sample`i'' & max_decrease == 0, effects(6) placebo(4) cluster(estab)
graph export "${RESULTS}/chaisemartin_new/new_`type'_${dataset}/graph`var'_sample`i'`helper'_incr_binary_year.png", replace 


***** Establishment and State-Year Fixed effects 
* Both Changes 
*did_multiplegt_dyn `var' estab state_year change_other_credit `sample`i'', effects(6) placebo(4) cluster(estab)
*graph export "${RESULTS}/chaisemartin_new/new_`type'_${dataset}/graph`var'_sample`i'`helper'_c0_both_continuous_stateyear.png", replace 

* Only Increases
*did_multiplegt_dyn `var' estab state_year change_other_credit `sample`i'' & max_decrease == 0, effects(6) placebo(4) cluster(estab)
*graph export "${RESULTS}/chaisemartin_new/new_`type'_${dataset}/graph`var'_sample`i'`helper'_incr_continuous_stateyear.png", replace 

*did_multiplegt_dyn `var' estab state_year increase_credit `sample`i'' & max_decrease == 0, effects(6) placebo(4) cluster(estab)
*graph export "${RESULTS}/chaisemartin_new/new_`type'_${dataset}/graph`var'_sample`i'`helper'_incr_binary_stateyear.png", replace 
}
}

drop change_other_credit
}
}



********************************************************************************
* This would be the analysis when using controls; However this does not converge yet  
********************************************************************************
	
/*
	local sample1 if year>=1988 
		local sample2 if inrange(year, 1988, 2018)  & n_patents>5 
		local sample3 if inrange(year, 1988, 2018)  & n_patents!=0 
		local sample4 if inrange(year, 1988, 2005)
		local sample5 if inrange(year, 1988, 2018) & max_corp_assg==1
		

did_multiplegt_dyn ln_n_inventors3 estab year increase_credit if year>=1988 &  max_decrease == 0, effects(5) placebo(3)  controls(rd_credit) cluster(estab)
graph export "${RESULTS}/chaisemartin/graph`var'_sample`i'`helper'_c`y'_incr.png", replace 

* With control variables the Chaisemartin estimator does not accomodate a continuous treatment alongside continuous control variables. Hence, I will only use the binary treatment indicator with the control variables 
foreach helper in all weighted threelargest {

    local controls1 rd_credit pit cit 
    local controls2 rd_credit pit cit ln_gdp
	local controls3 rd_credit pit cit other_cit_`helper'3 other_pit_`helper'3
	local controls4 rd_credit pit cit other_cit_`helper'3 other_pit_`helper'3 other_gdp_`helper'3 

	forvalues i =1/5 {	
		forvalues y =1/4 {
foreach var of varlist  ln_n_inventors3 { 

* patents1 patents3 patents3_w1 patents1_w1 n_inventors3 n_newinventors3

* Only Increases
did_multiplegt_dyn `var' estab year increase_credit `sample`i'' & max_decrease == 0, effects(8) placebo(5)  controls(rd_credit) cluster(estab)
graph export "${RESULTS}/chaisemartin/graph`var'_sample`i'`helper'_c`y'_incr.png", replace 

*Only Decreases
*did_multiplegt_dyn `var' estab year decrease_credit `sample`i'' & max_increase == 0, effects(8) placebo(5)  controls(`controls`y'') cluster(estab)
*graph export "${RESULTS}/chaisemartin/graph`var'_sample`i'`helper'_c`y'_decr.png", replace

}
		}
	}
}

*/
