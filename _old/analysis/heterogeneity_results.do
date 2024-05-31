////////////////////////////////////////////////////////////////////////////////
// Project:        	Moving innovation
// Creation Date:  	15/04/2024
// Last Update:    	15/04/2024
// Authors:         Laura Arnemann
//					Theresa Bührle
// Goal: 			Understanding Heterogeneity
////////////////////////////////////////////////////////////////////////////////


use  "${TEMP}/final_state_stacked_other_zeros.dta", clear 

keep if inrange(year, 1988, 2018)
merge 1:m fips_state assignee_id year using "${TEMP}/final_state_stacked_other_total_rd_credit_incr.dta"
keep if _merge==1 

collapse (count)  obs_patents3 = patents3 (sum) s_patents3 = patents3, by(fips_state)

* Fraction of patents not matched by state, 
egen all_obs = total(obs_patents3)
egen all_patents = total(s_patents3)

gen frac_obs = obs_patents3 / all_obs
gen frac_patents = s_patents3/all_patents 
tempfile helper 
save `helper'


shp2dta using "$IN/maps/states/cb_2018_us_state_20m.shp", database("${IN}/maps/states/usdb.dta") coordinates( "$IN\maps\states\us_coord.dta") genid(id) replace 

use "${IN}/maps/states/usdb.dta", clear
rename STATEFP fips_state
rename NAME state_name
destring fips_state, replace
save "$IN\maps\states\state.dta", replace


use `helper'
drop if fips_state==2 | fips_state==15 
merge 1:1 fips_state using "$IN\maps\states\state.dta", nogen keep(3)


spmap frac_obs using "$IN\maps\states\us_coord.dta", id(id) fcolor(Blues)  clmethod(custom) clbreaks(0 0.01 0.02 0.10 0.20) legend(position(5) size(medium)) 
graph export "$RESULTS\heatmap_notmatched_obs.png", replace

spmap frac_patents using "$IN\maps\states\us_coord.dta", id(id) fcolor(Blues)  clmethod(custom) clbreaks(0 0.01 0.02 0.10 0.30) legend(position(5) size(medium)) 
graph export "$RESULTS\heatmap_notmatched_patents.png", replace



