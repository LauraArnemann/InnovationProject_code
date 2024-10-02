// Project: Inventor Relocation
// Creation Date: 05/08/2024
// Last Update: 05/08/2024
// Author: Laura Arnemann 
// Goal: Regression Analysis for Inventor Productivity 



********************************************************************************
* Analysis on State Level 
********************************************************************************
/*
use "${TEMP}/inventor_productivity_state.dta", replace 

egen estab_id = group(assignee_id fips_state)
egen inventor_firm = group(assignee_id fips_state inventor_id)

bysort assignee_id year: egen total_patents = sum(n_patents)

local weighting_strategy threelargest weighted


xtset inventor_firm year 

foreach explaining in `weighting_strategy' {
		gen change_`explaining' = other_rd_credit_`explaining'3 - l.other_rd_credit_`explaining'3
		}
		
	foreach explaining in `weighting_strategy' {
		
		foreach x in change_`explaining' {

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
			   gsort inventor_firm -year
			   bysort inventor_firm: gen sum_F4_`x'=sum(F4_`x')

				sort inventor_firm year
				capture drop sum_L4_`x'
				bysort inventor_firm: gen sum_L4_`x'=sum(L4_`x')	
		}
	}

	drop F1* 
	gen zero_1=1
	label var zero_1 "-1"

local sample1 if inrange(year, 1988, 2018) & asg_corp==1 & total_patents>20
local weighting_strategy threelargest weighted

foreach explaining in `weighting_strategy' {
forvalues  i =1/1 {	
ppmlhdfe n_patents  F?_change_`explaining' zero_1 L?_change_`explaining' `sample`i'', absorb(inventor_firm year#i.fips_state) cl(estab_id)
est sto regres1
coefplot regres1, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
keep(F?_change_`explaining' zero_1 L?_change_`explaining') yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))

capture noisily graph export"${RESULTS}/eventstudies/inventor_productivity/productivity_balanced_`explaining'.png", replace
}	
}

*/
********************************************************************************
* Generating the Leads and Lags on firm level 
********************************************************************************

use "${TEMP}/final_state_zeros_new_4_assignee.dta", clear

egen estab_id = group(assignee_id fips_state)
bysort assignee_id year: egen total_patents = total(patents3)


local weighting_strategy threelargest weighted
xtset estab_id year 
	foreach explaining in `weighting_strategy' {
		gen change_`explaining' = other_rd_credit_`explaining'3 - l.other_rd_credit_`explaining'3
		gen byte increase_`explaining' = change_`explaining'>0
		gen byte decrease_`explaining' = change_`explaining'<0
	}

	foreach explaining in `weighting_strategy' {
		
		foreach x in change_`explaining' increase_`explaining' decrease_`explaining' {

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

	
use "${TEMP}/inventor_productivity_state.dta", clear 
merge m:1 assignee_id year fips_state using `leadslags', keepusing(F* L* zero_1 total_patents)
keep if _merge ==3 
drop _merge 


egen estab_id = group(assignee_id fips_state)
egen inventor_firm = group(estab_id inventor_id)

gstats winsor n_patents, cut(1 99) gen(patents_w1)


local sample1 if inrange(year, 1988, 2018) & asg_corp==1 & total_patents>20

foreach explaining in threelargest {
	
forvalues  i =1/1 {	
ppmlhdfe patents_w1 F?_change_`explaining' zero_1 L?_change_`explaining' `sample`i'', absorb(inventor_firm year#i.fips_state) cl(estab_id)
est sto regres1
coefplot regres1, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
keep(F?_change_`explaining' zero_1 L?_change_`explaining') yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))

capture noisily graph export "H:/InnovationProject/results/eventstudies/inventor_productivity/productivity_unbalanced.png", replace
}	
	}
