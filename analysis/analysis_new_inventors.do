// Project: Inventor Relocation
// Creation Date: 19/03/2024
// Last Update: 19/03/2024
// Author: Laura Arnemann 
// Goal: New Inventors 

use "${TEMP}/final_state_stacked_credit_incr.dta", replace 

egen assignee = group(assignee_id)

foreach var of varlist patents1 patents2 patents3 n_inventors1 n_inventors2 n_inventors3 {
	gstats winsor `var', cut(1 99) gen(`var'_w1)
	gstats winsor `var', cut(1 95) gen(`var'_w2)
	gen ln_`var'=log(`var')
}

gen patenting_activity = 0 
replace patenting_activity = 1 if patents3>0


gen ln_gdp=log(gdp)
gen ln_total_gdp=log(total_gdp)

*Generate the event indicators

forvalues i=1/4 {
	gen f`i'_binary = ry_increase==-`i'
	label var f`i'_binary "- `i'"
}

forvalues i=0/4 {
	gen l`i'_binary = ry_increase==`i'
	label var l`i'_binary "`i'"
}

drop f1_binary 
gen zero_1=1
label var zero_1 "-1" 

bysort assignee_id year event: egen n_patents = total(patents3)

ppmlhdfe n_newinventors3 f4_binary f3_binary f2_binary zero_1 l?_binary if inrange(year, 1988, 2013), absorb(estab#event year#event) cl(fips_state#event)
est sto inventorreg
coefplot inventorreg, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black))  keep(f?_binary zero_1 l?_binary) yline(0,  lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))

********************************************************************************
* Loop: Stacked regressions for changes at (other) locations
********************************************************************************

use  "${TEMP}/final_state_stacked_other_credit_incr.dta", replace 
egen assignee = group(assignee_id)

foreach var of varlist patents1 patents2 patents3 n_inventors1 n_inventors2 n_inventors3 {
	gstats winsor `var', cut(1 99) gen(`var'_w1)
	gstats winsor `var', cut(1 95) gen(`var'_w2)
	gen ln_`var'=log(`var')
}

gen ln_gdp=log(gdp)
gen ln_total_gdp=log(total_gdp)


*Generate the event indicators

forvalues i=1/4{
	gen f`i'_binary = ry_increase==-`i'
	label var f`i'_binary "- `i'"
}

forvalues i=0/4 {
	gen l`i'_binary = ry_increase==`i'
	label var l`i'_binary "`i'"
}

drop f1_binary 
gen zero_1=1
label var zero_1 "-1" 

bysort assignee_id year event: egen n_patents = total(patents3)

ppmlhdfe n_newinventors3 f4_binary f3_binary f2_binary zero_1 l?_binary rd_credit if inrange(year, 1988, 2013), absorb(estab#event year#event) cl(fips_state#event)
est sto inventorreg
coefplot inventorreg, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black))  keep(f?_binary zero_1 l?_binary) yline(0,  lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) xtitle("Years since Change") graphregion(color(white))