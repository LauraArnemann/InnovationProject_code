// Project: Inventor Relocation
// Creation Date: 10/02/2024
// Last Update: 10/02/2024
// Author: Laura Arnemann 
// Goal: Merging the data set with the number of inventors 


use "${TEMP}/final_cz.dta", clear 


foreach var of varlist patents_cz3 inventors_cz3 total_labs {
	gstats winsor `var', cut(1 99) gen(`var'_w1)
	gstats winsor `var', cut(1 95) gen(`var'_w2)
	gen ln_`var'=log(`var')
}

gen ln_gdp=log(gdp)

label var rd_credit "R\&D Credit"
label var rd_credit_other_w1 "R\&D Credit, other"
label var pit "PIT"
label var cit "CIT"

reghdfe ln_inventors_cz3 rd_credit rd_credit_other_w1 if year>=1992 & multistatefirm_temp==0, absorb(czone year) cl(czone)
est sto reg1
estadd local yearfe "\checkmark", replace
estadd local czonefe "\checkmark", replace

ppmlhdfe ln_inventors_cz3 rd_credit rd_credit_other_w1 pit cit  if year>=1992 & multistatefirm_temp==0, absorb(czone year) cl(czone)
est sto reg2
estadd local yearfe "\checkmark", replace
estadd local czonefe "\checkmark", replace

ppmlhdfe ln_inventors_cz3 rd_credit rd_credit_other_w1 pit cit pit_other_w1 cit_other_w1 if year>=1992 & multistatefirm_temp==0, absorb(czone year) cl(czone)
est sto reg3
estadd local yearfe "\checkmark", replace
estadd local czonefe "\checkmark", replace
estadd local otherfe "\checkmark", replace

esttab reg1 reg2 reg3 using "${RESULTS}/tables/poissonreg_inventors_cz.tex", replace noconstant nomtitles drop(pit_other_w1 cit_other_w1 _cons) cells(b(star fmt(%9.3f)) se(par)) stats(yearfe czonefe otherfe N, fmt(%9.0g %9.0g %9.0g %9.0g %9.0g %9.3f ) label("Year FE" "Czone FE" "Other Controls" "Observations")) collabels(none) starl(* .10 ** .05 *** .01) label 



ppmlhdfe ln_patents_cz3 rd_credit rd_credit_other_w1 if year>=1992 & multistatefirm_max==0, absorb(assignee_id year) cl(czone)
est sto reg1
estadd local yearfe "\checkmark", replace
estadd local czonefe "\checkmark", replace

ppmlhdfe ln_patents_cz3 rd_credit rd_credit_other_w1 pit cit if year>=1992 & multistatefirm_temp==0 , absorb(czone year) cl(czone)
est sto reg2
estadd local yearfe "\checkmark", replace
estadd local czonefe "\checkmark", replace

ppmlhdfe ln_patents_cz3 rd_credit rd_credit_other_w1 pit cit pit_other_w1 cit_other_w1 if year>=1992 & multistatefirm_temp==0, absorb(czone year) cl(czone)
est sto reg3
estadd local yearfe "\checkmark", replace
estadd local czonefe "\checkmark", replace
estadd local otherfe "\checkmark", replace


esttab reg1 reg2 reg3 using "${RESULTS}/tables/poissonreg_patents_cz3.tex", replace noconstant nomtitles drop(pit_other_w1 cit_other_w1 _cons) cells(b(star fmt(%9.3f)) se(par)) stats(yearfe czonefe otherfe N, fmt(%9.0g %9.0g %9.0g %9.0g ) label("Year FE" "Czone FE" "Other Controls" "Observations")) collabels(none) starl(* .10 ** .05 *** .01) label 


*******************************************************************************
* Collapse on CZ Level and redo the analysis on czone level 
********************************************************************************

/*
use "${TEMP}/final_cz.dta", clear 

collapse (mean) total_labs rd_credit rd_credit_other_w1 pit cit pit_other_w1 cit_other_w1, by(czone year)


ppmlhdfe total_labs rd_credit rd_credit_other_w1 if year>=1992, absorb(czone year) cl(czone)
est sto reg2
estadd local yearfe "\checkmark", replace
estadd local firmfe "\checkmark", replace

ppmlhdfe total_labs rd_credit rd_credit_other_w1 pit cit if year>=1992 , absorb(czone year) cl(czone)
est sto reg3
estadd local yearfe "\checkmark", replace
estadd local firmfe "\checkmark", replace

ppmlhdfe total_labs rd_credit rd_credit_other_w1 pit cit pit_other_w1 cit_other_w1 if year>=1992, absorb(czone year) cl(czone)
est sto reg4
estadd local yearfe "\checkmark", replace
estadd local firmfe "\checkmark", replace
estadd local otherfe "\checkmark", replace


* This yields an increase in the number of labs, which is strongly significant (?) could this be a crowding out story 
*/ 