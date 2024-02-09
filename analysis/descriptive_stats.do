// Project: Inventor Relocation
// Creation Date: 08/02/2024
// Last Update: 08/02/2024
// Author: Laura Arnemann 
// Goal: Descriptive Statistics and Heat Maps

use "${TEMP}/final_state.dta", clear


********************************************************************************
* Table with Descriptive Statistics
********************************************************************************

reg patents3 unemployment gdp pit cit multistatefirm_max 
gen in_sample=1 if e(sample)==1
replace n_inventors3=0 if missing(n_inventors3)

replace gdp=gdp/1000000000
replace gdp_other=gdp_other/1000000000
replace rd_credit=100*rd_credit
replace rd_credit_other=100*rd_credit_other

label var nstates "Active States"
label var multistatefirm_temp "Share Multi State Firms"
label var unemployment "Unemployment Rate"
label var rd_credit "R\&D tax credit"
label var gdp "Total GDP"
label var cit "CIT"
label var pit "PIT"
label var rd_credit_other "Average R\&D"
label var pit_other "Average PIT"
label var cit_other "Average CIT"
label var gdp_other "Average GDP"
label var unemployment_other "Average Unemployment"
label var patents3 "Patents"
label var n_inventors3 "Inventors"

estpost sum patents3 n_inventors3 multistatefirm_temp nstates rd_credit pit cit gdp unemployment rd_credit_other pit_other cit_other gdp_other unemployment_other if in_sample==1, detail
est sto firmvars
esttab firmvars using "${RESULTS}/tables/descriptives.tex", replace cells("mean(fmt(%9.2f)) sd(fmt(%9.2f)) p25(fmt(%9.2f))  p50(fmt(%9.2f))  p75(fmt(%9.2f)) count(fmt(%9.0g))") nonum label noobs collabels(\multicolumn{1}{c}{{Mean}} \multicolumn{1}{c}{{Std.Dev.}} \multicolumn{1}{l}{{25thPerc.}} \multicolumn{1}{l}{{Median}} \multicolumn{1}{l}{{75thPerc.}} \multicolumn{1}{l}{{Obs}}) refcat(patents3 "\textbf{\emph{Firm Variables}}" rd_credit "\textbf{\emph{State Variables}}" rd_credit_other "\textbf{\emph{State Variables}}", nolabel)



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

use "$OUT\woeppel_regsample_firm.dta", clear	
*gen cz=CZ_depagri_1990
drop if state_inv==2 | state_inv==15
keep if year == 1992 | year == 2009

gen helper=1

collapse (sum) n_patents helper, by(CZ_depagri_1990 year)


rename helper n_inventors  
reshape wide n_patents n_inventors, i(CZ_depagri_1990) j(year)
rename CZ_depagri_1990 cz

merge m:1 cz using "$IN/maps/cz/usdb_cz.dta"
drop if _merge ==1
drop _merge 

foreach var of varlist n_patents1992 n_inventors1992 n_patents2009 n_inventors2009 {
	replace `var'=0 if missing(`var')
}


spmap n_patents1992 using "$IN/maps/cz/uscoord_cz.dta", id(id) fcolor(Blues) clmethod(custom) clbreaks(0 1 10 40 10000) legend(position(5) size(medium))
graph export "$RESULTS\heatmap_n_patents1992_cz.png", replace

spmap n_patents2009 using "$IN/maps/cz/uscoord_cz.dta", id(id) fcolor(Blues) clmethod(custom) clbreaks(0 1 10 40 10000) legend(position(5) size(medium))
graph export "$RESULTS\heatmap_n_patents2009_cz.png", replace

spmap n_inventors1992 using "$IN/maps/cz/uscoord_cz.dta", id(id) fcolor(Blues) clmethod(custom) clbreaks(0 1 10 50 10000) legend(position(5) size(medium))
graph export "$RESULTS\heatmap_n_inventors1992_cz.png", replace

spmap n_inventors2009 using "$IN/maps/cz/uscoord_cz.dta", id(id) fcolor(Blues) clmethod(custom) clbreaks(0 1 10 50 10000) legend(position(5) size(medium))
graph export "$RESULTS\heatmap_n_inventors2009_cz.png", replace
	

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
drop if fips_state==2 | fips_state==15 
keep rd_credit fips_state year
keep if year==1992 | year==2009
replace rd_credit=rd_credit*100 

reshape wide rd_credit, i(fips_state) j(year)
merge 1:1 fips_state using "$IN\maps\states\state.dta", nogen keep(3)


spmap rd_credit2009 using "$IN\maps\states\us_coord.dta", id(id) fcolor(Blues) clmethod(custom) clbreaks(0 0.1 5 10 15 20) legend(position(5) size(medium)) 
graph export "$RESULTS\heatmap_rd_credit2009.png", replace

spmap rd_credit1992 using "$IN\maps\states\us_coord.dta", id(id) fcolor(Blues) clmethod(custom) clbreaks(0 0.1 5 10 15 20) legend(position(5) size(medium)) 
graph export "$RESULTS\heatmap_rd_credit1992.png", replace


