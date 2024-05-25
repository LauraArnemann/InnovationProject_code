// Project: Inventor Relocation
// Creation Date: 08/02/2024
// Last Update: 18/03/2024
// Author: Laura Arnemann, Theresa Bührle 
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


********************************************************************************
* R&D incentives
********************************************************************************

*Graph development R&D incentives

use "$IN\indep_var\var_RDcredits\RD_credits_final.dta", clear

gen rd_credit_pos = 1 if rd_credit > 0

bysort year: egen rd_count = count(rd_credit_pos)
bysort year: egen rd_avrate = mean(rd_credit)

keep if year >= 1992 & year <= 2018

twoway (bar rd_avrate year, yaxis(2)  color(gs10%20) barw(0.85) ytitle("Average tax credit rate (line)", axis(2))) ///
		(line rd_count year, yaxis(1)  color(black) ytitle("Number of states with tax credit (bars)")), ///
		legend(off) xlabel(1992[4]2018) graphregion(style(none) color(white))
		graph export "$RESULTS\graph_dev_rdcredits.png", replace

*Graph changes R&D incentives		

use "$IN\indep_var\var_RDcredits\RD_credits_final.dta", clear

sort fips_state year
by fips_state: gen change_rd = rd_credit - rd_credit[_n-1] if fips_state == fips_state[_n-1]

keep if year >= 1992 & year <= 2018

sum change_rd
gen change_rd_neg = change_rd if change_rd < 0 & change_rd != .
	gen change_rd_neg_d = 1 if change_rd_neg != .
gen change_rd_pos = change_rd if change_rd > 0 & change_rd != .
	gen change_rd_pos_d = 1 if change_rd_pos != .
	
bysort year: egen rd_neg_count = count(change_rd_neg_d)	
	replace rd_neg_count = -rd_neg_count
bysort year: egen rd_pos_count = count(change_rd_pos_d)	
bysort year: egen rd_neg_av = mean(change_rd_neg)	
bysort year: egen rd_pos_av = mean(change_rd_pos)	

duplicates drop year, force
	
twoway 	(bar rd_neg_count year, barw(0.85) color(gs10%50) yaxis(1) ytitle("Number of R&D credit changes (bars)")) ///
		(bar rd_pos_count year, barw(0.85) color(black%70) yaxis(1)) ///
		(line rd_neg_av year, yaxis(2) color(red) ytitle("Mean R&D credit change (lines)", axis(2))) ///
		(line rd_pos_av year, yaxis(2) color(green)) ///
		, xlabel(1992[2]2018) ylabel(-0.2(0.2)0.6, axis(2)) graphregion(style(none) color(white)) ///
		legend(pos(6) rows(2) order(1 "# decreases" 2 "# increases" 3 "av. decrease" 4 "av. increase"))
	graph export "$RESULTS\graph_changes_rdcredits.png", replace


********************************************************************************
* Distribution of changes in other variable 
********************************************************************************
use "${TEMP}/final_state_stacked_other_zeros.dta", clear 
drop if missing(assignee_id)




*  other_rd_credit_first other_rd_credit_threelargest other_rd_credit_all other_rd_credit_weighted  
/*
* Bar Graph with the overll distribution of changes
foreach var of varlist other_all0 other_all1 other_all3 other_weighted0 other_weighted1 other_weighted3 other_threelargest0 other_threelargest1 other_threelargest3 other_first0 other_first1 other_first3 {
	hist change_`var', graphregion(color(white)) xtitle("Change in RD Credit, other locations")
	sum change_`var', detail 
 
	hist change_`var' if inrange(change_`var', `r(p10)', `r(p90)'), graphregion(color(white)) xtitle("Change in RD Credit, other locations")
	hist change_`var' if change_`var'>0, graphregion(color(white)) xtitle("Change in RD Credit, other locations")
	hist change_`var' if change_`var'<0, graphregion(color(white)) xtitle("Change in RD Credit, other locations")

} 		
*/ 

* other_weighted3 other_threelargest3 other_first3

foreach var of varlist other_all3  {
gen indicator_largechange =1 if change_`var'!=.
replace indicator_largechange=0  if inrange(change_`var', -1, 1)

gen indicator_largeincrease =0
replace indicator_largeincrease=1  if change_`var'>=1 & change_`var'!=.

gen indicator_largedecrease =0
replace indicator_largedecrease=1  if change_`var'<=-1 & change_`var'!=.

}

* Bar Graph with the distribution of large changes  
graph bar (rawsum) indicator_largechange if year>=1992 , over(year, label(labsize(small) angle(forty_five))) graphregion(color(white)) bgcolor(white)  bar(1, color(dkgreen%50) ) ytitle("Number of Large Changes")
graph export "${RESULTS}/descriptives/`var'_largechanges.png", replace 
drop indicator_largechange 


* Bar Graph with the distribution of large increases 
graph bar (rawsum) indicator_largeincrease if year>=1992 , over(year, label(labsize(small) angle(forty_five))) graphregion(color(white)) bgcolor(white)  bar(1, color(dkgreen%50) ) ytitle("Number of Large Increases")
graph export "${RESULTS}/descriptives/`var'_largeincrease.png", replace 
drop indicator_largeincrease


* Bar Graph with the distribution of large decreases 
graph bar (rawsum) indicator_largedecrease if year>=1992 , over(year, label(labsize(small) angle(forty_five))) graphregion(color(white)) bgcolor(white)  bar(1, color(dkgreen%50) ) ytitle("Number of Large Decreases")
graph export "${RESULTS}/descriptives/`var'_largedecrease.png", replace 
drop indicator_largedecrease 
}




use "${TEMP}/other_all_3.dta", clear 

egen estab = group(assignee_id fips_state)
xtset estab year 

gen change_otherall3 = other_rd_credit_all - l.other_rd_credit_all
rename year app_year 

merge m:1 assignee_id app_year using "${TEMP}/helper_dataset3.dta" , keepusing(states_present new_states)
keep if _merge==3 
drop _merge 
* Also seems like other all variable was generated properly 


* 03bb96f2-0306-4608-a4fb-e21bb46c3dd9, year 2020
* 03ede0a1-cc92-4d76-88ed-d6a7a0101822, year 2019
