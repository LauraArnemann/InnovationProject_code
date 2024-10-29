// Project: Inventor Relocation
// Creation Date: 05/08/2024
// Last Update: 05/08/2024
// Author: Laura Arnemann 
// Goal: Regression Analysis for Inventor Productivity 



use "${TEMP}/inventor_productivity_cz_assignee.dta", replace 

egen estab_id = group(assignee_id fips_state)
egen inventor_firm = group(assignee_id inventor_id czone)

bysort estab_id year: egen total_patents = sum(n_patents)

xtset inventor_firm year 


forvalues i =1/6 {
gen change_otherstates`i' = cz_treated_change_w`i' 
gen byte incr_otherstates`i'  = change_otherstates`i'  >0
replace incr_otherstates`i'  = . if change_otherstates`i' <0 
gen byte decr_otherstates`i'  = change_otherstates`i'  <0
replace decr_otherstates`i'  = . if change_otherstates`i' >0 

		
foreach x in change_otherstates`i'  {
	
	forval f = 4(-1)1 {
		gen F`f'_`x' = F`f'.`x'		
		label var F`f'_`x' "- `f'"
		} // f

	forval l = 0(1)4{		
		gen L`l'_`x' = L`l'.`x'
		label var L`l'_`x' " `l'"
		} // l
			
	* Binning off of the event studies: 
	capture drop sum_F4_`x'
	gsort estab_id -year
	bysort estab_id: gen sum_F4_`x'=sum(F4_`x')

	sort estab_id year
	capture drop sum_L4_`x'
	bysort estab_id: gen sum_L4_`x'=sum(L4_`x')	
}
}

	drop F1* 
	gen zero_1=1
	label var zero_1 "-1"

local sample1 if inrange(year, 1988, 2018) 

forvalues  i =1/1 {	
ppmlhdfe n_patents  F?_change_otherstates6 zero_1 L?_change_otherstates6 `sample`i'', absorb(inventor_firm year#i.fips_state) cl(czone)
est sto regres1
coefplot regres1, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
keep(F?_change_otherstates6 zero_1 L?_change_otherstates6) yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))

capture noisily graph export"$RESULTS/eventstudies/inventor_productivity/productivity_czone_balanced.png", replace
}	



********************************************************************************
* Generating the Leads and Lags on firm level 
********************************************************************************

use "${TEMP}/final_cz_corp_assignee.dta", clear 

forvalues i =1/6 {
gen change_otherstates`i' = cz_treated_change_w`i' 
gen byte incr_otherstates`i'  = change_otherstates`i'  >0
replace incr_otherstates`i'  = . if change_otherstates`i' <0 
gen byte decr_otherstates`i'  = change_otherstates`i'  <0
replace decr_otherstates`i'  = . if change_otherstates`i' >0 

		
foreach x in change_otherstates`i'  {
	
	forval f = 4(-1)1 {
		gen F`f'_`x' = F`f'.`x'		
		label var F`f'_`x' "- `f'"
		} // f

	forval l = 0(1)4{		
		gen L`l'_`x' = L`l'.`x'
		label var L`l'_`x' " `l'"
		} // l
			
	* Binning off of the event studies: 
	capture drop sum_F4_`x'
	gsort estab_id -year
	bysort estab_id: gen sum_F4_`x'=sum(F4_`x')

	sort estab_id year
	capture drop sum_L4_`x'
	bysort estab_id: gen sum_L4_`x'=sum(L4_`x')	
}
}
drop F1* 
gen zero_1=1
label var zero_1 "-1"
	
	tempfile leadslags 
	save `leadslags', replace 

********************************************************************************
* Generating Leads and Lags on Establishment Level 
********************************************************************************
	
use "${TEMP}/inventor_productivity_state_assignee.dta", replace 
merge m:1 assignee_id year fips_state using `leadslags', keepusing(F* L* zero_1 treated change_other_threelargest)
keep if _merge ==3 
drop _merge 

egen inventor_firm = group(assignee_id inventor_id)

local sample1 if inrange(year, 1988, 2018) 

forvalues  i =1/1 {	
ppmlhdfe n_patents F?_change_`explaining' zero_1 L?_change_`explaining' `sample`i'', absorb(inventor_firm year#i.fips_state) cl(estab_id)
est sto regres1
coefplot regres1, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
keep(F?_change_`explaining' zero_1 L?_change_`explaining') yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))

capture noisily graph export"$RESULTS/eventstudies/inventor_productivity/productivity_unbalanced.png", replace
}	
