// Project: Inventor Relocation
// Creation Date: 08/02/2024
// Last Update: 18/03/2024
// Author: Laura Arnemann, Theresa Bührle 
// Goal: Overview of the Variation in Treatment 

global dataset 4 

use "${TEMP}/patents_helper_${dataset}.dta", clear
bysort assignee_id: gen count = _n 
keep if count ==1  
tempfile patentshelper
save `patentshelper'


use "${TEMP}/final_state_zeros_new_${dataset}_assignee.dta", clear 
	merge m:1 assignee_id using `patentshelper', keepusing(noncorp_asg asg_corp pub_assg)
	drop if _merge ==2 
	drop _merge 

egen estab_id = group(assignee_id fips_state)
xtset estab_id year 

gen change_threelargest = other_rd_credit_threelargest3 - l.other_rd_credit_threelargest3
gen change_weighted = other_rd_credit_weighted3 - l.other_rd_credit_weighted3

hist change_threelargest if change_threelargest!=0 & asg_corp==1, graphregion(color(white)) ytitle("Density") xtitle("Change in R&D Credit at three largest Establishments") color(blue%50) bin(100)
graph export "$RESULTS\variation_threelargest.png", replace

hist change_weighted if change_weighted!=0 & asg_corp==1, graphregion(color(white)) ytitle("Density") xtitle("Change in R&D Credits at other Establishments") color(blue%50) bin(100)
graph export "$RESULTS\variation_weighted.png", replace


use "${TEMP}/final_cz_${dataset}_corp.dta", clear 
hist cz_treated_change_w6 if cz_treated_change_w6>=0.1 | cz_treated_change_w6<=-0.1, graphregion(color(white)) ytitle("Density") xtitle("Change in average credit in CZs") color(blue%50) bin(50)
graph export "$RESULTS\variation_spillover.png", replace