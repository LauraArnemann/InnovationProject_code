////////////////////////////////////////////////////////////////////////////////
// Project:        	Moving innovation
// Creation Date:  	19/03/2024
// Last Update:    	24/04/2024
// Authors:         Laura Arnemann
//					Theresa Bührle
// Goal: 			Alternative cleaning of stacked regressions
////////////////////////////////////////////////////////////////////////////////


use "${TEMP}/final_cz_${dataset}.dta", clear 
drop if missing(assignee_id)

egen estab_id = group(assignee_id fips_state czone)
xtset estab_id year 	
* Changes in R&D credits
gen change_cz  = cz_treated_change_w 

* Changes are usually too small, so that we cannot impose this restriction
*replace  change_cz = 0 if inrange(change_cz, -1, 1)
compress	

* Only keeping clean treatments: 
gen treat = 1 if change_cz!=0 
bysort estab_id : egen total_treatments = total(treat)
bysort estab_id: egen estab_patents = total(patents3)

xtset estab_id year 

local x change_cz
forval f = 8(-1)1 {
		gen F`f'_`x' = F`f'.`x'		
		label var F`f'_`x' "- `f'"
		} // f

	forval l = 0(1)8{		
		gen L`l'_`x' = L`l'.`x'
		label var L`l'_`x' " `l'"
		} // l

gen sum_leadslags = F1_change_cz + F2_change_cz + F3_change_cz + F4_change_cz + F5_change_cz + F6_change_cz + F7_change_cz + F8_change_cz + L1_change_cz + L2_change_cz + L3_change_cz + L4_change_cz + L5_change_cz + L6_change_cz + L7_change_cz + L8_change_cz 		
		
		
save  "${TEMP}/final_state_stacked_other_zeros_${dataset}_cz.dta", replace 


*********************************************************************************
* Cleaning 
*********************************************************************************
