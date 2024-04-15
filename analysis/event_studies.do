// Project: Inventor Relocation
// Creation Date: 06/12/2023
// Last Update: 06/12/2023
// Author: Laura Arnemann 
// Goal: Merging the data set using the number of inventors in a state employed by the respective firm as outcome variable 


********************************************************************************
* Event Studies without Zeros 
********************************************************************************

use "${TEMP}/final_state_stacked_zeros.dta", clear 

foreach var of varlist patents1 patents2 patents3 n_inventors1 n_inventors2 n_inventors3 {
	gstats winsor `var', cut(1 99) gen(`var'_w1)
	gstats winsor `var', cut(1 95) gen(`var'_w2)
	gen ln_`var'=log(`var')
}

tostring fips_state, gen(strate_str) 
gen estab_id = assignee_id + strate_str
*egen estab = group(estab_id)

xtset estab year 

gen change_other_credit = total_rd_credit - l.total_rd_credit 
gen byte increase_credit = change_other_credit>0
gen byte decrease_credit = change_other_credit<0

foreach x in change_other_credit increase_credit decrease_credit {

	forval f = 4(-1)1 {
		gen F`f'_`x' = F`f'.`x'		
		label var F`f'_`x' "- `f'"
	} // f

	forval l = 0(1)4{		
		gen L`l'_`x' = L`l'.`x'
		label var L`l'_`x' " `l'"
	} // l
}


		gen ln_gdp=log(gdp)
		gen ln_gdp_other=log(total_gdp)

drop F1* 
gen zero_1=1
label var zero_1 "-1"

ppmlhdfe patents3 rd_credit F?_change_other_credit zero_1 L?_change_other_credit rd_credit ln_gdp ln_gdp_other unemployment unemployment_other pit cit total_pit total_cit if year>=1988, absorb(estab year) cl(fips_state)
est sto patreg
coefplot patreg, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black))  keep(F?_change_other_credit zero_1 L?_change_other_credit) yline(0,  lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))
capture noisily graph export "${OVERLEAF}/graphs/eventstudies/patents_heterogeneity1.png", replace

*graph export "${RESULTS}/figures/eventstudy_patents.pdf", replace


ppmlhdfe n_inventors3_w1 rd_credit F?_change_other_credit L?_change_other_credit pit cit total_pit total_cit if year>=1992 , absorb(assignee_id year) cl(fips_state)
est sto inventorreg
coefplot inventorreg, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black))  keep(F?_change_other_credit zero_1 L?_change_other_credit) yline(0,  lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))
graph export "${RESULTS}/figures/eventstudy_inventors.pdf", replace


********************************************************************************
* Event Study with Zeros
********************************************************************************
use "${TEMP}/final_state_zeros.dta", clear 

foreach var of varlist patents1 patents2 patents3 n_inventors1 n_inventors2 n_inventors3 {
	gstats winsor `var', cut(1 99) gen(`var'_w1)
	gstats winsor `var', cut(1 95) gen(`var'_w2)
	gen ln_`var'=log(`var')
}

tostring fips_state, gen(strate_str) 
gen estab_id = assignee_id + strate_str
egen estab = group(estab_id)

xtset estab year 



gen change_credit = rd_credit - l.rd_credit
gen neg=1 if change_credit<0 
bysort estab: egen max_neg=max(neg)

gen change_other_credit = total_rd_credit - l.total_rd_credit 
gen byte increase_credit = change_other_credit>0
gen byte decrease_credit = change_other_credit<0

foreach x in change_credit change_other_credit increase_credit decrease_credit {

	forval f = 4(-1)1 {
		gen F`f'_`x' = F`f'.`x'		
		label var F`f'_`x' "- `f'"
	} // f

	forval l = 0(1)4{		
		gen L`l'_`x' = L`l'.`x'
		label var L`l'_`x' " `l'"
	} // l
}

drop F1* 
gen zero_1=1
label var zero_1 "-1"


ppmlhdfe patents3_w1 rd_credit F?_change_other_credit zero_1 L?_change_other_credit pit cit total_pit total_cit if year>=1992 , absorb(assignee_id year) cl(fips_state)

ppmlhdfe n_inventors3_w1 rd_credit F?_change_other_credit L?_change_other_credit pit cit total_pit total_cit if year>=1992 , absorb(assignee_id year) cl(fips_state)





********************************************************************************
* Commuting Zone level Analysis 
********************************************************************************

use "${TEMP}/final_cz.dta", clear 

foreach var of varlist patents_cz3 inventors_cz3 total_labs {
	gstats winsor `var', cut(1 99) gen(`var'_w1)
	gstats winsor `var', cut(1 95) gen(`var'_w2)
	gen ln_`var'=log(`var')
}


tostring czone, gen(czone_str) 
gen estab_id = assignee_id + czone_str
egen estab = group(estab_id)

xtset estab year 

gen change_other_credit = rd_credit_other_w1 - l.rd_credit_other_w1 
gen byte increase_credit = change_other_credit>0
gen byte decrease_credit = change_other_credit<0

foreach x in change_other_credit increase_credit decrease_credit {

	forval f = 4(-1)1 {
		gen F`f'_`x' = F`f'.`x'		
		label var F`f'_`x' "- `f'"
	} // f

	forval l = 0(1)4{		
		gen L`l'_`x' = L`l'.`x'
		label var L`l'_`x' " `l'"
	} // l
}


drop F1* 
gen zero_1=1
label var zero_1 "-1"

ppmlhdfe patents_cz3 rd_credit F?_change_other_credit zero_1 L?_change_other_credit pit cit pit_other_w1 cit_other_w1 if year>=1992 & multistatefirm_temp==0 , absorb(czone year) cl(czone)
est sto patreg_cz

coefplot patreg_cz, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black))  keep(F?_change_other_credit zero_1 L?_change_other_credit) yline(0,  lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))
graph export "${RESULTS}/figures/eventstudy_patents_cz.pdf", replace


ppmlhdfe inventors_cz3 rd_credit F?_change_other_credit zero_1 L?_change_other_credit pit cit pit_other_w1 cit_other_w1 if year>=1992 & multistatefirm_temp==0 , absorb(czone year) cl(czone)
est sto inventors_cz

coefplot inventors_cz, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black))  keep(F?_change_other_credit zero_1 L?_change_other_credit) yline(0,  lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))
graph export "${RESULTS}/figures/eventstudy_inventors_cz.pdf", replace
