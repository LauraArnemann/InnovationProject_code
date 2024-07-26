// Project: Inventor Relocation
// Creation Date: 15/06/2024
// Last Update: 15/06/2024
// Author: Laura Arnemann 
// Goal: Checking why there are so large differences when binning off and when not binning off 

global weighting_strategy threelargest

use "${TEMP}/final_state_zeros_new_4_gvkey.dta", clear 


	foreach var of varlist patents1 patents2 patents3 n_inventors1 n_inventors2 n_inventors3  n_newinventors1 n_newinventors3 {
		gstats winsor `var', cut(1 99) gen(`var'_w1)
		gstats winsor `var', cut(1 95) gen(`var'_w2)
		gen ln_`var'=log(`var')
}


egen estab_id = group(assignee_id fips_state)
bysort estab_id: egen estab_patents = total(patents3)

bysort assignee_id year: egen total_patents = total(patents3)

	label var pit "PIT"
	label var cit "CIT"
	label var rd_credit "R\&D Credit"

	xtset estab_id year 
	foreach explaining in $weighting_strategy {
		gen change_`explaining' = other_rd_credit_`explaining'3 - l.other_rd_credit_`explaining'3
		gen byte increase_`explaining' = change_`explaining'>0
		gen byte decrease_`explaining' = change_`explaining'<0
	}

	foreach explaining in $weighting_strategy {
		
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
	

	
local explaining threelargest

	
ppmlhdfe n_inventors3_w1 F?_change_`explaining' zero_1 L?_change_`explaining' if inrange(year, 1988, 2018) & total_patents>10 , absorb(estab_id year#i.fips_state) cl(estab_id)
est sto regres2
coefplot regres2, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
keep(F?_change_`explaining' zero_1 L?_change_`explaining') yline(0,  lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))
	
	foreach explaining in $weighting_strategy {
		foreach x in change_`explaining' {
			gen F4_change_old = F4_`x'
			gen L4_change_old = L4_`x'
			replace F4_`x'=sum_F4_`x'
			replace L4_`x'=sum_L4_`x'
		}
	} 

sort estab_id year 

br estab_id year F4_change_threelargest F4_change_old 

local explaining threelargest


ppmlhdfe n_inventors3_w1 F4_change_`explaining' F3_change_`explaining' F2_change_`explaining' zero_1 L?_change_`explaining' if inrange(year, 1988, 2018) & total_patents>10 & F4_change_`explaining'!=. , absorb(estab_id year#i.fips_state) cl(estab_id)
est sto regres3
coefplot regres3, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
keep(F?_change_`explaining' zero_1 L?_change_`explaining') yline(0,  lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))


reghdfe ln_n_inventors3 F?_change_`explaining' zero_1 L?_change_`explaining' if inrange(year, 1988, 2018) & total_patents>10, absorb(estab_id year#i.fips_state) cl(estab_id)
est sto regres3
coefplot regres3, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
keep(F?_change_`explaining' zero_1 L?_change_`explaining') yline(0,  lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))


local other_controls other_cit_`explaining'  other_pit_`explaining' other_gdp_`explaining'  
ppmlhdfe n_inventors3_w1 F?_change_`explaining' zero_1 L?_change_`explaining' `other_controls' if inrange(year, 1988, 2018) & total_patents>10, absorb(estab_id year#i.fips_state) cl(estab_id)
est sto regres4
coefplot regres4, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
keep(F?_change_`explaining' zero_1 L?_change_`explaining') yline(0,  lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))


********************************************************************************
* Checking binning with aggregate 
********************************************************************************
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
drop F1* 
gen zero_1=1
label var zero_1 "-1"

bysort assignee_id: egen total_patents = total(patents3)
replace change_other_threelargest = 0 if missing(change_other_threelargest)

		
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


local direction change 
local cl czone 
local i 1
local expl 1 

	ppmlhdfe n_inventors3_w1 change_other_threelargest F?_`direction'_otherstates`expl' zero_1 L?_`direction'_otherstates`expl' `sample`i'' , absorb(estab_id year#i.fips_state) cl(`cl')
	est sto regres1
	coefplot regres1, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
	keep(F?_`direction'_otherstates`expl' zero_1 L?_`direction'_otherstates`expl') yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
	xtitle("Years since `direction'") ytitle(`var') graphregion(color(white))

	
foreach expl of numlist 1 2 3 4 5 6 { 		
	foreach x in change_otherstates`expl' {
	gen L4_old_`x' = L4_`x'
	gen F4_old_`x' = F4_`x'
	replace F4_`x'=sum_F4_`x'
	replace L4_`x'=sum_L4_`x'
	}
	}
	
	
local direction change 
local cl czone 
local i 1
local expl 6

	ppmlhdfe n_inventors3_w1 F?_`direction'_otherstates`expl' zero_1 L?_`direction'_otherstates`expl' `sample`i'' if treated!=1, absorb(estab_id year#i.fips_state) cl(`cl')
	est sto regres2
	coefplot regres2, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
	keep(F?_`direction'_otherstates`expl' zero_1 L?_`direction'_otherstates`expl') yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
	xtitle("Years since `direction'") ytitle(`var') graphregion(color(white))