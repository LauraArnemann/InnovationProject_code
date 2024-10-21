////////////////////////////////////////////////////////////////////////////////
// Project:        	Moving innovation
// Creation Date:  	08/02/2024
// Last Update:    	21/10/2024
// Authors:         Laura Arnemann
//					Theresa Bührle
// Goal: 			Descriptive Statistics, Heat Maps, Development R&D Tax Incentives
////////////////////////////////////////////////////////////////////////////////

********************************************************************************
* Descriptive Statistics
********************************************************************************

* Table with Descriptive Statistics: State Level 
*-------------------------------------------------------------------------------

if $gvkey == 0 {
    use "${TEMP}/patentdata_clean.dta", clear 
}

if $gvkey == 1 {
    use "${TEMP}/patentdata_clean_gvkey.dta", clear 
}

bysort assignee_id: gen count = _n 
keep if count ==1  
tempfile patentshelper
save `patentshelper'

if $gvkey == 0 {
    use "${TEMP}/final_state_zeros_assignee.dta", clear 
}

if $gvkey == 1 {
    use "${TEMP}/final_state_zeros_assignee_gvkey.dta", clear 
}

merge m:1 assignee_id using `patentshelper', keepusing(noncorp_asg asg_corp pub_assg)
	drop if _merge ==2 
	drop _merge 

foreach var of varlist patents1 patents2 patents3 n_inventors1 n_inventors2 n_inventors3 n_newinventors3 {
	gstats winsor `var', cut(1 99) gen(`var'_w1)
	gstats winsor `var', cut(1 95) gen(`var'_w2)
	gen ln_`var'=log(`var')
}


egen estab_id= group(assignee_id fips_state)

reghdfe n_inventors3_w1 other_rd_credit_threelargest if inrange(year, 1988, 2018) & asg_corp==1, absorb(estab_id year#i.fips_state) 
gen in_sample=1 if e(sample)==1


replace gdp=gdp/1000000000

label var patents3_w1 "Patents"
label var n_inventors3_w1 "Inventors"
label var nstates "Active States"
label var multistatefirm_max "Share Multi State Firms"
label var unemployment "Unemployment Rate"
label var rd_credit "R/&D tax credit"
label var gdp "Total GDP"
label var cit "CIT"
label var pit "PIT"
label var other_rd_credit_threelargest3 "Average R/&D"
label var other_pit_threelargest3 "Average PIT"
label var other_cit_threelargest3 "Average CIT"
label var patents3 "Patents"
label var n_inventors3 "Inventors"

estpost sum patents3_w1 n_inventors3_w1 n_newinventors3_w1 nstates rd_credit pit cit other_rd_credit_threelargest3 other_pit_threelargest3 other_cit_threelargest3 if in_sample==1, detail
	est sto firmvars
	esttab firmvars using "${RESULTS}/tables/descriptives1.tex", ///
		replace cells("mean(fmt(%9.2f)) sd(fmt(%9.2f)) p25(fmt(%9.2f)) p50(fmt(%9.2f)) p75(fmt(%9.2f)) count(fmt(%9.0g))") nonum label noobs ///
		collabels(/multicolumn{1}{c}{{Mean}} /multicolumn{1}{c}{{Std.Dev.}} /multicolumn{1}{l}{{25thPerc.}} /multicolumn{1}{l}{{Median}} /multicolumn{1}{l}{{75thPerc.}} /multicolumn{1}{l}{{Obs}}) ///
		refcat(patents3 "/textbf{/emph{Firm Variables}}" rd_credit "/textbf{/emph{State Variables}}" total_rd_credit "/textbf{/emph{Other State Variables}}", nolabel)

		
* Table with Descriptive Statistics: CZ Level 
*-------------------------------------------------------------------------------

if $gvkey == 0 {
    use "${TEMP}/final_cz_corp.dta", clear 
}

if $gvkey == 1 {
    use "${TEMP}/final_cz_corp_gvkey.dta", clear 
}

foreach var of varlist patents3 n_inventors3 n_newinventors3 {
	gstats winsor `var', cut(1 99) gen(`var'_w1)
	gstats winsor `var', cut(1 95) gen(`var'_w2)
	gen ln_`var'=log(`var')
}

label var patents3_w1 "Patents"
label var n_inventors3_w1 "Inventors"
label var n_newinventors3_w1 "New Inventors"
label var rd_credit "R/&D Credit"
label var pit "PIT"
label var cit "CIT"
label var cz_treated_levelcredit_w6 "Weighted Change"
replace patents3_w1 = 0 if missing(patents3_w1)

bysort assignee_id year: egen total_patents = total(patents3)

ppmlhdfe n_inventors3_w1 cz_treated_levelcredit_w6 if inrange(year, 1988, 2018), absorb(estab_id year#i.fips_state) 
gen in_sample=1 if e(sample)==1

estpost sum patents3_w1 n_inventors3_w1 n_newinventors3_w1 rd_credit pit cit cz_treated_levelcredit_w6 if in_sample==1, detail
	est sto firmvars
	esttab firmvars using "${RESULTS}/tables/descriptives2.tex", ///
		replace cells("mean(fmt(%9.2f)) sd(fmt(%9.2f)) p25(fmt(%9.2f)) p50(fmt(%9.2f)) p75(fmt(%9.2f)) count(fmt(%9.0g))") nonum label noobs ///
		collabels(/multicolumn{1}{c}{{Mean}} /multicolumn{1}{c}{{Std.Dev.}} /multicolumn{1}{l}{{25thPerc.}} /multicolumn{1}{l}{{Median}} /multicolumn{1}{l}{{75thPerc.}} /multicolumn{1}{l}{{Obs}}) ///
		refcat(patents3_cz_w1 "/textbf{/emph{Firm Variables}}" rd_credit "/textbf{/emph{State Variables}}" rd_credit_other_w1 "/textbf{/emph{Other State Variables}}", nolabel)


		
********************************************************************************
* Distributions
********************************************************************************

* Distribution changes in other variable 
*-------------------------------------------------------------------------------

if $gvkey == 0 {
    use "${TEMP}/final_state_stacked_other_zeros_assignee.dta", clear 
}

if $gvkey == 1 {
    use "${TEMP}/final_state_stacked_other_zeros_gvkey.dta", clear 
}

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

foreach var of varlist other_all3  {
gen indicator_largechange =1 if change_`var'!=.
replace indicator_largechange=0  if inrange(change_`var', -1, 1)

gen indicator_largeincrease =0
replace indicator_largeincrease=1  if change_`var'>=1 & change_`var'!=.

gen indicator_largedecrease =0
replace indicator_largedecrease=1  if change_`var'<=-1 & change_`var'!=.

* Bar Graph with the distribution of large changes  
graph bar (rawsum) indicator_largechange if year>=1992 , over(year, label(labsize(small) angle(forty_five))) graphregion(color(white)) bgcolor(white)  bar(1, color(dkgreen%50) ) ytitle("Number of Large Changes")
	graph export "${RESULTS}/graphs/`var'_largechanges.png", replace 
drop indicator_largechange 

* Bar Graph with the distribution of large increases 
graph bar (rawsum) indicator_largeincrease if year>=1992 , over(year, label(labsize(small) angle(forty_five))) graphregion(color(white)) bgcolor(white)  bar(1, color(dkgreen%50) ) ytitle("Number of Large Increases")
	graph export "${RESULTS}/graphs/`var'_largeincrease.png", replace 
drop indicator_largeincrease

* Bar Graph with the distribution of large decreases 
graph bar (rawsum) indicator_largedecrease if year>=1992 , over(year, label(labsize(small) angle(forty_five))) graphregion(color(white)) bgcolor(white)  bar(1, color(dkgreen%50) ) ytitle("Number of Large Decreases")
	graph export "${RESULTS}/graphs/`var'_largedecrease.png", replace 
drop indicator_largedecrease 
}

* Overview of the Variation in Treatment
*-------------------------------------------------------------------------------

if $gvkey == 0 {
    use "${TEMP}/patentdata_clean.dta", clear 
}

if $gvkey == 1 {
    use "${TEMP}/patentdata_clean_gvkey.dta", clear 
}

bysort assignee_id: gen count = _n 
keep if count ==1  
tempfile patentshelper
save `patentshelper'


if $gvkey == 0 {
    use "${TEMP}/final_state_zeros_assignee.dta", clear 
}

if $gvkey == 1 {
    use "${TEMP}/final_state_zeros_assignee_gvkey.dta", clear 
}
	
merge m:1 assignee_id using `patentshelper', keepusing(noncorp_asg asg_corp pub_assg)
	drop if _merge ==2 
	drop _merge 

egen estab_id = group(assignee_id fips_state)
xtset estab_id year 

gen change_threelargest = other_rd_credit_threelargest3 - l.other_rd_credit_threelargest3
gen change_weighted = other_rd_credit_weighted3 - l.other_rd_credit_weighted3

hist change_threelargest if change_threelargest!=0 & asg_corp==1, graphregion(color(white)) ytitle("Density") xtitle("Change in R&D Credit at three largest Establishments") color(blue%50) bin(100)
	graph export "$RESULTS/graphs/variation_threelargest.png", replace

hist change_weighted if change_weighted!=0 & asg_corp==1, graphregion(color(white)) ytitle("Density") xtitle("Change in R&D Credits at other Establishments") color(blue%50) bin(100)
	graph export "$RESULTS/graphs/variation_weighted.png", replace


if $gvkey == 0 {
    use "${TEMP}/final_cz_zeros_assignee.dta", clear 
}

if $gvkey == 1 {
    use "${TEMP}/final_cz_zeros_gvkey.dta", clear 
}

egen estab_id = group(fips_state czone)
xtset estab_id year 

gen change_weighted = cz_treated_levelcredit_w6 - l.cz_treated_levelcredit_w6

hist change_weighted if change_weighted>=0.1 | change_weighted<=-0.1, graphregion(color(white)) ytitle("Density") xtitle("Change in average credit in CZs") color(blue%50) bin(50)
	graph export "$RESULTS/graphs/variation_spillover.png", replace
	

*Mulsti-state firms
*-------------------------------------------------------------------------------

* Number of States in which firm is present/ 
* Share of firms active in more than one state	x	x	x	x	x	x	x	x	

if $gvkey == 0 {
    use "${TEMP}/final_state_zeros_assignee.dta", clear 
}

if $gvkey == 1 {
    use "${TEMP}/final_state_zeros_assignee_gvkey.dta", clear 
}

egen estab = group(assignee_id fips_state)

duplicates drop estab year assignee_id, force 

preserve 
bysort assignee_id year: gen total_labs = _N 
 
collapse (mean) total_labs, by(year)
 
twoway (bar total_labs year if year>=1992, yaxis(2) ylabel(0(2)6, axis(2)) color(gs10%50) barw(0.85) ///
	ytitle("Average number of states", axis(2))), legend(off) xlabel(1992[4]2018) graphregion(style(none) color(white)) 
	graph export "${RESULTS}/graphs/graph_number_states.png", replace

restore 

bysort assignee_id year: gen total_labs = _N 
gen multi_statefirm = 0 
replace multi_statefirm = 1 if total_labs>1 

duplicates drop assignee_id year, force 
collapse (mean) multi_statefirm, by(year)

twoway (bar multi_statefirm year if year>=1992, yaxis(2) ylabel(0(0.2)1, axis(2)) color(gs10%50) barw(0.85) ///
	ytitle("Share of Multi-State firms", axis(2))), legend(off) xlabel(1992[4]2018) graphregion(style(none) color(white)) 
	graph export "${RESULTS}/graphs/graph_multistatefirms.png", replace


* Share of Multi-State Patents	x	x	x	x	x	x	x	x	x	x	x	x 

if $gvkey == 0 {
    use "${TEMP}/patentdata_clean.dta", clear 
}

if $gvkey == 1 {
    use "${TEMP}/patentdata_clean_cz.dta", clear 
}

keep patnum assignee_id inventor_id county_fips_inventor state_fips_inventor app_year

bysort patnum assignee_id: gen count = _N 
gen multistatepatent = 0 
replace multistatepatent = 1 if count >1 

duplicates drop patnum assignee_id, force 
collapse (mean) multistatepatent, by(app_year)
rename app_year year 
label var year "Year"
   
twoway (bar multistatepatent year if inrange(year, 1992, 2018), ///
	yaxis(2) ylabel(0(0.05)0.2, axis(2)) color(gs10%50) barw(0.85) ytitle("Share of Multi-State Patents", axis(2))), ///
	legend(off) xlabel(1992[4]2018) graphregion(style(none) color(white)) 
	graph export "${RESULTS}/graphs/graph_multistatepatents.png", replace

* Dropping all Research Labs which are in multi-state CZ  

use "${TEMP}/patentdata_clean_cz.dta", clear

rename county_fips_inventor county_fips
replace county_fips = 8013 if county_fips == 8014 

* Merging in the Commuting Zone level data 
merge m:1 county_fips using "$IN/var_CommutingZones/CZ_combined.dta", keepusing(CZ_depagri_1990)

   drop if _merge!=3  
   drop _merge	
   
rename CZ_depagri_1990 cz
 
bysort patnum assignee_id cz: gen count1 = _N 
bysort patnum assignee_id cz state_fips_inventor: gen count2 =_N 

drop if count1 != count2 
  
duplicates drop patnum state_fips_inventor, force 
 
   bysort patnum assignee_id: gen count = _N 
   gen multistatepatent = 0 
   replace multistatepatent = 1 if count >1 

   duplicates drop patnum assignee_id, force 
   collapse (mean) multistatepatent, by(app_year)
   
   rename app_year year 
   label var year "Year"
   
twoway (bar multistatepatent year if inrange(year, 1992, 2018), ///
	yaxis(2) ylabel(0(0.05)0.2, axis(2)) color(gs10%50) barw(0.85) ytitle("Share of Multi-State Patents", axis(2))), ///
	legend(off) xlabel(1992[4]2018) graphregion(style(none) color(white)) 
	graph export "${RESULTS}/graphs/graph_multistatepatents_corrected_cz.png", replace

	

********************************************************************************
* Heatmaps
********************************************************************************

* State
*-------------------------------------------------------------------------------

**States
shp2dta using "$IN/maps/states/cb_2018_us_state_20m.shp", database("${IN}/maps/states/usdb.dta") coordinates( "$IN/maps/states/us_coord.dta") genid(id) replace 

use "${IN}/maps/states/usdb.dta", clear
rename STATEFP fips_state
rename NAME state_name
destring fips_state, replace
save "$IN/maps/states/state.dta", replace

if $gvkey == 0 {
    use "${TEMP}/final_state_zeros_assignee.dta", clear 
}

if $gvkey == 1 {
    use "${TEMP}/final_state_zeros_assignee_gvkey.dta", clear 
}

duplicates drop fips_state year, force  
replace rd_credit=0 if fips_state==36 & year>=2012

drop if fips_state==2 | fips_state==15 
keep rd_credit fips_state year
keep if year==1992 | year==2018

reshape wide rd_credit, i(fips_state) j(year)
merge 1:1 fips_state using "$IN/maps/states/state.dta", nogen keep(3)


spmap rd_credit2018 using "$IN/maps/states/us_coord.dta", id(id) fcolor(Blues) clmethod(custom) clbreaks(0 0.1 5 10 15 30) legend(position(5) size(medium)) 
	graph export "$RESULTS/graphs/heatmap_rd_credit2018.png", replace

spmap rd_credit1992 using "$IN/maps/states/us_coord.dta", id(id) fcolor(Blues) clmethod(custom) clbreaks(0 0.1 5 10 15 30) legend(position(5) size(medium)) 
	graph export "$RESULTS/graphs/heatmap_rd_credit1992.png", replace


* Commuting Zones 
*-------------------------------------------------------------------------------

shp2dta using "$IN/maps/cz/cz1990", database("$IN/maps/cz/usdb_cz.dta") coordinates("$IN/maps/cz/uscoord_cz.dta") genid(id)	replace 

use "$IN/maps/cz/usdb_cz.dta", clear 
drop if inrange(cz, 34101, 34115)
drop if inrange(cz, 34701, 34703)
drop if cz==35600
save "$IN/maps/cz/usdb_cz.dta", replace 

if $gvkey == 0 {
    use "${TEMP}/final_cz_zeros_assignee.dta", clear 
}

if $gvkey == 1 {
    use "${TEMP}/final_cz_zeros_gvkey.dta", clear 
}
	
*gen cz=CZ_depagri_1990
keep if year == 1992 | year == 2018

drop helper 
gen helper=1

collapse (sum) patents3 n_inventors3, by(czone year)
 
reshape wide patents3 n_inventors3, i(czone) j(year)
rename czone cz

merge m:1 cz using "$IN/maps/cz/usdb_cz.dta"
drop if _merge ==1
drop _merge 

foreach var of varlist patents31992 n_inventors31992 patents32018 n_inventors32018 {
	replace `var'=0 if missing(`var')
}

spmap patents31992 using "$IN/maps/cz/uscoord_cz.dta", id(id) fcolor(Blues) clmethod(custom) clbreaks(0 1 10 40 15000) legend(position(5) size(medium))
	graph export "$RESULTS/graphs/heatmap_n_patents1992_cz.png", replace

spmap patents32018 using "$IN/maps/cz/uscoord_cz.dta", id(id) fcolor(Blues) clmethod(custom) clbreaks(0 1 10 40 15000) legend(position(5) size(medium))
	graph export "$RESULTS/graphs/heatmap_n_patents2018_cz.png", replace

spmap n_inventors31992 using "$IN/maps/cz/uscoord_cz.dta", id(id) fcolor(Blues) clmethod(custom) clbreaks(0 1 10 50 25000) legend(position(5) size(medium))
	graph export "$RESULTS/graphs/heatmap_n_inventors1992_cz.png", replace

spmap n_inventors32018 using "$IN/maps/cz/uscoord_cz.dta", id(id) fcolor(Blues) clmethod(custom) clbreaks(0 1 10 50 25000) legend(position(5) size(medium))
	graph export "$RESULTS/graphs/heatmap_n_inventors2018_cz.png", replace
	
	
********************************************************************************
* Institutional: Graphs R&D incentives
********************************************************************************

*Graph development R&D incentives

use "$IN/indep_var/var_RDcredits/RD_credits_final.dta", clear

gen rd_credit_pos = 1 if rd_credit > 0

bysort year: egen rd_count = count(rd_credit_pos)
bysort year: egen rd_avrate = mean(rd_credit)

keep if year >= 1992 & year <= 2018

twoway (bar rd_avrate year, yaxis(2)  color(gs10%20) barw(0.85) ytitle("Average tax credit rate (line)", axis(2))) ///
		(line rd_count year, yaxis(1)  color(black) ytitle("Number of states with tax credit (bars)")), ///
		legend(off) xlabel(1992[4]2018) graphregion(style(none) color(white))
		graph export "$RESULTS/graphs/graph_dev_rdcredits.png", replace

*Graph changes R&D incentives		

use "$IN/indep_var/var_RDcredits/RD_credits_final.dta", clear

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
	graph export "$RESULTS/graphs/graph_changes_rdcredits.png", replace



