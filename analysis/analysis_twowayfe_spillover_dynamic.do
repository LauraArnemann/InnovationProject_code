////////////////////////////////////////////////////////////////////////////////
// Project:        	Moving innovation
// Creation Date:  	04/07/2024
// Last Update:    	05/07/2024
// Authors:         Laura Arnemann
//					Theresa Bührle
// Goal: 			Calculating regular and apillover effects with two-way fixed effects analysis 
////////////////////////////////////////////////////////////////////////////////

global dataset 4

use "${TEMP}/final_cz_${dataset}.dta", clear 

	foreach var of varlist patents3 n_inventors3 n_newinventors3 {
		gstats winsor `var', cut(1 99) gen(`var'_w1)
		gstats winsor `var', cut(1 95) gen(`var'_w2)
		gen ln_`var'=log(`var')
}


bysort estab_id: egen estab_patents = total(patents3)

	label var pit "PIT"
	label var cit "CIT"
	label var rd_credit "R\&D Credit"

xtset estab_id year 


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


		
foreach x in other_threelargest  {
	
	forval f = 4(-1)1 {
		gen F`f'_`x' = F`f'.change_`x'		
		label var F`f'_`x' "- `f'"
		} // f

	forval l = 0(1)4{		
		gen L`l'_`x' = L`l'.change_`x'
		label var L`l'_`x' " `l'"
		} // l

}

drop F1* 
gen zero_1=1
label var zero_1 "-1"

bysort assignee_id: egen total_patents = total(patents3)
replace change_other_threelargest = 0 if missing(change_other_threelargest)


local direction change 

local sample1 if inrange(year, 1988, 2018)
local sample2 if inrange(year, 1988, 2018) & total_patents>10 
local sample3 if inrange(year, 1988, 2018) & total_patents<10 
local sample4 if inrange(year, 1988, 2018) & pub_assg==1 
local sample5 if inrange(year, 1988, 2018) & asg_corp==1
local sample6 if inrange(year, 1988, 2018) & noncorp_asg==0
local sample7 if inrange(year, 1988, 2018) & max_tr_other_threelargest!=1 
local sample8 if inrange(year, 1988, 2018) & tag_local==1
local sample9 if inrange(year, 1988, 2018) & treated!=1  	
local sample10 if inrange(year, 1988, 2018) & multistate_cz ==0 
local sample11 if inrange(year, 1988, 2018) & tag_local==1 & multistate_cz ==0 

local expl 6
local i 2 


	ppmlhdfe n_inventors3_w1 F?_`direction'_otherstates`expl'  L?_`direction'_otherstates`expl'  F4_other_threelargest F3_other_threelargest F2_other_threelargest zero_1 L?_other_threelargest `sample`i'', absorb(estab_id year#i.fips_state) cl(estab_id)
			est sto regres1
			coefplot regres1, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
				keep(F?_other_threelargest zero_1 L?_other_threelargest ) yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
				xtitle("Years since `direction'") ytitle(`var') graphregion(color(white))
*capture noisily graph export "$RESULTS/eventstudies/estab/weight`expl'/`var'_spillover_sample`i'_c1_nobin_`direction'.png", replace