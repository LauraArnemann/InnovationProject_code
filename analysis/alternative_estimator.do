////////////////////////////////////////////////////////////////////////////////
// Project:        	Moving innovation
// Creation Date:  	06/12/2023
// Last Update:    	24/04/2024
// Authors:         Laura Arnemann
//					Theresa Bührle
// Goal: 			Using the Sun & Abraham and Chaisemartin approach 
////////////////////////////////////////////////////////////////////////////////


use "${TEMP}/final_state_zeros_new.dta", clear 
drop if missing(assignee_id)
merge m:1 assignee_id using "${TEMP}/corporate_assignees.dta"
drop if _merge!=3 
drop _merge 
drop if missing(assignee_id)

bysort assignee_id year : egen n_patents = total(patents3)

foreach var of varlist patents1 patents2 patents3 n_inventors1 n_inventors2 n_inventors3 {
	gstats winsor `var', cut(1 99) gen(`var'_w1)
	gstats winsor `var', cut(1 95) gen(`var'_w2)
	gen ln_`var'=log(`var')
}

gen ln_gdp =log(gdp)

egen estab = group(fips_state assignee_id)

xtset estab year 

* all 
foreach helper in weighted threelargest {
	
gen change_other_credit = other_rd_credit_`helper'3 - l.other_rd_credit_`helper'3
gen byte increase_credit = change_other_credit>0 & change_other_credit!=. 
gen byte decrease_credit = change_other_credit<0 & change_other_credit!=. 


bysort assignee_id fips_state: egen max_decrease = max(decrease_credit)
bysort assignee_id fips_state: egen max_increase = max(increase_credit)

replace other_gdp_`helper'3 = ln(other_gdp_`helper'3)
 *******************************************************************************
 * Chaisemartin Estimator 
 *******************************************************************************
 
		local sample1 if year>=1988 
		local sample2 if inrange(year, 1988, 2018)  & n_patents>5 
		local sample3 if inrange(year, 1988, 2018)  & n_patents!=0 
		local sample4 if inrange(year, 1988, 2005)
		local sample5 if inrange(year, 1988, 2018) & max_corp_assg==1
		
* No Controls 		
	forvalues i =1/5 {	
foreach var of varlist patents1 patents3 patents3_w1 patents1_w1 n_inventors3 n_newinventors3 ln_patents3 ln_n_inventors3 { 
 
* Both Changes 
did_multiplegt_dyn `var' estab year change_other_credit `sample`i'', effects(8) placebo(5) cluster(estab)
graph export "${RESULTS}/chaisemartin/graph`var'_sample`i'`helper'_c0_both.png", replace 

* Only Increases
did_multiplegt_dyn `var' estab year change_other_credit `sample`i'' & max_decrease == 0, effects(8) placebo(5) cluster(estab)
graph export "${RESULTS}/chaisemartin/graph`var'_sample`i'`helper'_c0_incr.png", replace 

*Only Decreases (Do not run through with sample2 )
if `i' !=2 {
did_multiplegt_dyn `var' estab year change_other_credit `sample`i'' & max_increase == 0, effects(8) placebo(5) cluster(estab)
graph export "${RESULTS}/chaisemartin/graph`var'_sample`i'`helper'_c0_decr.png", replace
}

}
}

drop change_other_credit
}

/*
* For some reason the code does not yet work with control variables 
foreach helper in all weighted threelargest {

    local controls1 rd_credit pit cit 
    local controls2 rd_credit pit cit ln_gdp
	local controls3 rd_credit pit cit other_cit_`helper'3 other_pit_`helper'3
	local controls4 rd_credit pit cit other_cit_`helper'3 other_pit_`helper'3 other_gdp_`helper'3 

	forvalues i =1/5 {	
		forvalues y =1/4 {
foreach var of varlist patents1 patents3 patents3_w1 patents1_w1 n_inventors3 n_newinventors3 { 
 
* Both Changes 
did_multiplegt_dyn `var' estab year change_other_credit `sample`i'', effects(8) placebo(5)  controls(`controls`y'') cluster(estab)
graph export "${RESULTS}/chaisemartin/graph`var'_sample`i'`helper'_c`y'_both.png", replace 

* Only Increases
did_multiplegt_dyn `var' estab year change_other_credit `sample`i'' & max_decrease == 0, effects(8) placebo(5)  controls(`controls`y'') cluster(estab)
graph export "${RESULTS}/chaisemartin/graph`var'_sample`i'`helper'_c`y'_incr.png", replace 

*Only Decreases
did_multiplegt_dyn `var' estab year change_other_credit `sample`i'' & max_increase == 0, effects(8) placebo(5)  controls(`controls`y'') cluster(estab)
graph export "${RESULTS}/chaisemartin/graph`var'_sample`i'`helper'_c`y'_decr.png", replace

}
		}
	}
}


********************************************************************************
* Sun & Abraham 
********************************************************************************







* Implementing all the necessary steps to run the eventstudyinteract estimator 
 gen change_year = year if increase_credit == 1 & change_other_credit >=1 
 bysort estab: egen first_change = min(change_year)

 gen ry = year - first_change
 
 gen never_change = (change_year == .) & max_decrease == 0
 
   forvalues k = 5(-1)2 {
           gen g_`k' = ry == -`k'
        }
        forvalues k = 0/5 {
             gen g`k' = ry == `k'
        }


 
 eventstudyinteract patents3 g_* g0-g5 if year>=1992 & max_corp_assg==1, cohort(first_change) covariates(rd_credit ln_gdp cit pit) control_cohort(never_change) absorb(i.estab i.year) vce(cluster estab)

 

graph export "${RESULTS}/chaisemartin/patents_all3.png", replace 

