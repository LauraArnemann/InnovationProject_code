// Project: Inventor Relocation
// Creation Date: 08/02/2024
// Last Update: 08/02/2024
// Author: Laura Arnemann 
// Goal: Descriptive Statistics and Heat Maps

use "${TEMP}/final_state.dta", clear



********************************************************************************
* Table with Descriptive Statistics: State Level 
********************************************************************************

foreach var of varlist patents1 patents2 patents3 n_inventors1 n_inventors2 n_inventors3 {
	gstats winsor `var', cut(1 99) gen(`var'_w1)
	gstats winsor `var', cut(1 95) gen(`var'_w2)
	gen ln_`var'=log(`var')
}



reg patents3 unemployment gdp pit cit multistatefirm_temp 
gen in_sample=1 if e(sample)==1
replace n_inventors3=0 if missing(n_inventors3)

replace gdp=gdp/1000000000
replace gdp_other=gdp_other/1000000000


label var patents3_w1 "Patents"
label var n_inventors3_w1 "Inventors"
label var nstates "Active States"
label var multistatefirm_temp "Share Multi State Firms"
label var unemployment "Unemployment Rate"
label var rd_credit "R\&D tax credit"
label var gdp "Total GDP"
label var cit "CIT"
label var pit "PIT"
label var total_rd_credit "Average R\&D"
label var total_pit "Average PIT"
label var total_cit "Average CIT"
label var patents3 "Patents"
label var n_inventors3 "Inventors"

estpost sum patents3_w1 n_inventors3_w1 multistatefirm_temp nstates rd_credit pit cit total_rd_credit total_pit cit_other if in_sample==1, detail
est sto firmvars
esttab firmvars using "${RESULTS}/tables/descriptives1.tex", replace cells("mean(fmt(%9.2f)) sd(fmt(%9.2f)) p25(fmt(%9.2f))  p50(fmt(%9.2f))  p75(fmt(%9.2f)) count(fmt(%9.0g))") nonum label noobs collabels(\multicolumn{1}{c}{{Mean}} \multicolumn{1}{c}{{Std.Dev.}} \multicolumn{1}{l}{{25thPerc.}} \multicolumn{1}{l}{{Median}} \multicolumn{1}{l}{{75thPerc.}} \multicolumn{1}{l}{{Obs}}) refcat(patents3 "\textbf{\emph{Firm Variables}}" rd_credit "\textbf{\emph{State Variables}}" total_rd_credit "\textbf{\emph{Other State Variables}}", nolabel)


********************************************************************************
* Table with Descriptive Statistics: CZ Level 
********************************************************************************

use "${TEMP}/final_cz.dta", clear


foreach var of varlist patents_cz3 inventors_cz3 total_labs {
	gstats winsor `var', cut(1 99) gen(`var'_w1)
	gstats winsor `var', cut(1 95) gen(`var'_w2)
	gen ln_`var'=log(`var')
}

label var patents_cz3_w1 "Patents Commuting Zone"
label var inventors_cz3_w1 "Inventors Commuting Zone"
label var rd_credit "R\&D Credit"
label var rd_credit_other_w1 "R\&D Credit, other"
label var pit "PIT"
label var cit "CIT"
label var pit_other_w1 "PIT, other"
label var cit_other_w1 "CIT, other"


reg patents_cz3_w1 rd_credit rd_credit_other_w1 pit cit  if year>=1992 & multistatefirm_temp==0
gen in_sample=1 if e(sample)==1
*replace inventors_cz3_w1 =0 if missing(inventors_cz3_w1)


estpost sum patents_cz3_w1 inventors_cz3_w1 rd_credit pit cit rd_credit_other_w1 pit_other_w1 cit_other_w1 if in_sample==1, detail
est sto firmvars
esttab firmvars using "${RESULTS}/tables/descriptives2.tex", replace cells("mean(fmt(%9.2f)) sd(fmt(%9.2f)) p25(fmt(%9.2f))  p50(fmt(%9.2f))  p75(fmt(%9.2f)) count(fmt(%9.0g))") nonum label noobs collabels(\multicolumn{1}{c}{{Mean}} \multicolumn{1}{c}{{Std.Dev.}} \multicolumn{1}{l}{{25thPerc.}} \multicolumn{1}{l}{{Median}} \multicolumn{1}{l}{{75thPerc.}} \multicolumn{1}{l}{{Obs}}) refcat(patents3_cz_w1 "\textbf{\emph{Firm Variables}}" rd_credit "\textbf{\emph{State Variables}}" rd_credit_other_w1 "\textbf{\emph{Other State Variables}}", nolabel)





********************************************************************************
* Heatmaps
********************************************************************************

* Commuting Zones 


shp2dta using "$IN/maps/cz/cz1990", database("$IN/maps/cz/usdb_cz.dta") coordinates("$IN/maps/cz/uscoord_cz.dta") genid(id)	replace 

use "$IN/maps/cz/usdb_cz.dta", clear 
drop if inrange(cz, 34101, 34115)
drop if inrange(cz, 34701, 34703)
drop if cz==35600
save "$IN/maps/cz/usdb_cz.dta", replace 

use "$OUT\reg_data_patent_invmoves.dta", clear	
*gen cz=CZ_depagri_1990
keep if year == 1992 | year == 2018

gen helper=1

collapse (sum) n_patents helper, by(CZ_depagri_1990 year)


rename helper n_inventors  
reshape wide n_patents n_inventors, i(CZ_depagri_1990) j(year)
rename CZ_depagri_1990 cz

merge m:1 cz using "$IN/maps/cz/usdb_cz.dta"
drop if _merge ==1
drop _merge 

foreach var of varlist n_patents1992 n_inventors1992 n_patents2018 n_inventors2018 {
	replace `var'=0 if missing(`var')
}

spmap n_patents1992 using "$IN/maps/cz/uscoord_cz.dta", id(id) fcolor(Blues) clmethod(custom) clbreaks(0 1 10 40 15000) legend(position(5) size(medium))
graph export "$RESULTS\heatmap_n_patents1992_cz.png", replace

spmap n_patents2018 using "$IN/maps/cz/uscoord_cz.dta", id(id) fcolor(Blues) clmethod(custom) clbreaks(0 1 10 40 15000) legend(position(5) size(medium))
graph export "$RESULTS\heatmap_n_patents2018_cz.png", replace

spmap n_inventors1992 using "$IN/maps/cz/uscoord_cz.dta", id(id) fcolor(Blues) clmethod(custom) clbreaks(0 1 10 50 25000) legend(position(5) size(medium))
graph export "$RESULTS\heatmap_n_inventors1992_cz.png", replace

spmap n_inventors2018 using "$IN/maps/cz/uscoord_cz.dta", id(id) fcolor(Blues) clmethod(custom) clbreaks(0 1 10 50 25000) legend(position(5) size(medium))
graph export "$RESULTS\heatmap_n_inventors2018_cz.png", replace
	

* State

**States
shp2dta using "$IN/maps/states/cb_2018_us_state_20m.shp", database("${IN}/maps/states/usdb.dta") coordinates( "$IN\maps\states\us_coord.dta") genid(id) replace 

use "${IN}/maps/states/usdb.dta", clear
rename STATEFP fips_state
rename NAME state_name
destring fips_state, replace
save "$IN\maps\states\state.dta", replace

use "${TEMP}/final_state.dta", clear
duplicates drop fips_state year, force  
replace rd_credit=0 if fips_state==36 & year>=2012


drop if fips_state==2 | fips_state==15 
keep rd_credit fips_state year
keep if year==1992 | year==2018


reshape wide rd_credit, i(fips_state) j(year)
merge 1:1 fips_state using "$IN\maps\states\state.dta", nogen keep(3)


spmap rd_credit2018 using "$IN\maps\states\us_coord.dta", id(id) fcolor(Blues) clmethod(custom) clbreaks(0 0.1 5 10 15 30) legend(position(5) size(medium)) 
graph export "$RESULTS\heatmap_rd_credit2018.png", replace

spmap rd_credit1992 using "$IN\maps\states\us_coord.dta", id(id) fcolor(Blues) clmethod(custom) clbreaks(0 0.1 5 10 15 30) legend(position(5) size(medium)) 
graph export "$RESULTS\heatmap_rd_credit1992.png", replace


