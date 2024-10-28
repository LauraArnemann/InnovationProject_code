////////////////////////////////////////////////////////////////////////////////
// Project:        	Moving innovation
// Creation Date:  	19/03/2024
// Last Update:    	24/04/2024
// Authors:         Laura Arnemann
//					Theresa Bührle
// Goal: 			Trying to see if we can replicate the results from the Giroud Spillover Paper to create similar control groups  
////////////////////////////////////////////////////////////////////////////////

********************************************************************************
* Running the analysis on commuting zone level 
********************************************************************************

foreach type in gvkey {

* Analysis on Commuting Zone Level 
use "${TEMP}/patentcount_czone_`type'.dta", clear 
merge 1:1 czone app_year assignee_id using "${TEMP}/inventorcount_czone_`type'.dta"
drop _merge 



* Merging in the state data for each commuting zone
merge m:1 czone using "${IN}/var_CommutingZones/cw_czone_state.dta"
keep if _merge ==3 
drop _merge 


rename statefip fips_state


merge m:1 fips_state app_year using "${TEMP}/state_data_cleaned.dta", keepusing(rd_credit gdp cit pit unemployment)
drop if _merge!=3
drop _merge


rename app_year year 

foreach num of numlist 3 {
* Merging in the variables at other locations

merge m:1 fips_state year assignee_id using "${TEMP}/other_all_`num'_${dataset}_gvkey.dta", keepusing(other*)
drop if _merge==2
drop _merge  

foreach var in rd_credit cit gdp unemployment pit {
	rename other_`var'_all other_`var'_all`num' 
	rename other_`var'_weighted other_`var'_weighted`num'
}


merge m:1 fips_state year assignee_id using "${TEMP}/other_threelargest_`num'_$dataset_gvkey.dta", keepusing(other*)
drop if _merge==2 
drop _merge 

foreach var in rd_credit cit gdp unemployment pit {
	rename other_`var'_threelargest other_`var'_threelargest`num' 
}
 
}

********************************************************************************
* Running Regressions 
********************************************************************************


*Different conditions for Balanced Panel 
     gen balanced_panel = 1 if min_year<=1988 & max_year>=2018
	 * Only 206 unique gvkey observations


foreach var of varlist patents1 patents2 patents3 n_inventors1 n_inventors2 n_inventors3  n_newinventors1 n_newinventors3 {
	gstats winsor `var', cut(1 99) gen(`var'_w1)
	gstats winsor `var', cut(1 95) gen(`var'_w2)
	gen ln_`var'=log(`var')
}



foreach var of varlist  other_gdp_weighted3 other_gdp_all3 other_gdp_threelargest3 {
    replace `var'=log(`var')
}

bysort assignee_id year: egen total_patents=total(patents3)

********************************************************************************
* Regular Regressions: Based on Assignee  Id 
********************************************************************************
egen estab_id = group(assignee_id czone)
bysort estab_id: egen estab_patents = total(patents3)

label var pit "PIT"
label var cit "CIT"
label var rd_credit "R\&D Credit"

gen ln_gdp = log(gdp)

* Sample Restrictions 

		local sample1 if year>=1988 
		local sample2 if inrange(year, 1988, 2018)  & total_patents>10	
		*local sample3 if inrange(year, 1988, 2018)  & total_patents>5 
		*local sample4 if inrange(year, 1988, 2018)  & total_patents!=0
		*local sample5 if inrange(year, 1988, 2018) & estab_patents>5
		*local sample6 if inrange(year, 1988, 2018) & balanced_panel ==1 

forvalues i = 1/2 {
	
foreach var of varlist patents3_w1 n_inventors3_w1 n_newinventors3_w1 {

foreach explaining in all weighted threelargest {
	
	local other_controls other_cit_`explaining'3  other_pit_`explaining'3 other_unemployment_`explaining'3 other_gdp_`explaining'3  
	
ppmlhdfe `var' other_rd_credit_`explaining'3 rd_credit `sample`i'' , absorb(estab_id year) cl(estab_id)
est sto reg1
estadd local yearfe "\checkmark", replace
estadd local estabfe "\checkmark", replace


ppmlhdfe `var' other_rd_credit_`explaining'3 rd_credit pit cit ln_gdp unemployment `sample`i'', absorb(estab_id year) cl(estab_id)
est sto reg2
estadd local yearfe "\checkmark", replace
estadd local estabfe "\checkmark", replace
estadd local statecontrols "\checkmark", replace


ppmlhdfe `var' other_rd_credit_`explaining'3 rd_credit pit cit ln_gdp unemployment `other_controls' `sample`i'', absorb(estab_id year) cl(estab_id)
est sto reg3
estadd local yearfe "\checkmark", replace
estadd local estabfe "\checkmark", replace
estadd local statecontrols "\checkmark", replace
estadd local othercontrols "\checkmark", replace

ppmlhdfe `var' other_rd_credit_`explaining'3 `sample`i'', absorb(estab_id year#i.fips_state) cl(estab_id)
est sto reg4
estadd local stateyearfe "\checkmark", replace
estadd local estabfe "\checkmark", replace


ppmlhdfe `var' other_rd_credit_`explaining'3 `other_controls' `sample`i'', absorb(estab_id year#i.fips_state) cl(estab_id)
est sto reg5
estadd local stateyearfe "\checkmark", replace
estadd local estabfe "\checkmark", replace
estadd local othercontrols "\checkmark", replace

* Exporting the Results in a log file, since no excel and tex available

log using "$RESULTS/tables/new_`type'_${dataset}/czone/var`var'_`explaining'_sample`i'_`type'.log", replace 

esttab reg1 reg2 reg3 reg4 reg5, replace noconstant nomtitles drop(`other_controls' pit cit ln_gdp unemployment _cons) cells(b(star fmt(%9.3f)) se(par)) stats(yearfe estabfe stateyearfe statecontrols othercontrols N, fmt(%9.0g %9.0g %9.0g %9.0g %9.0g %9.0g ) label("Year FE" "Firm FE" "State-Year FE" "State Controls" "Other Controls" "Observations")) collabels(none) starl(* .10 ** .05 *** .01) label 

capture log close 
}
}
}


********************************************************************************
* Also running the logarithm 
********************************************************************************
	forvalues i = 1/2  {
		
foreach var of varlist ln_patents3 ln_n_inventors3  {

foreach explaining in all weighted threelargest {

		
reghdfe `var' other_rd_credit_`explaining'3 rd_credit `sample`i'' , absorb(estab_id year) cl(estab_id)
est sto reg6
estadd local yearfe "\checkmark", replace
estadd local estabfe "\checkmark", replace


reghdfe  `var' other_rd_credit_`explaining'3 rd_credit pit cit ln_gdp unemployment `sample`i'', absorb(estab_id year) cl(estab_id)
est sto reg7
estadd local yearfe "\checkmark", replace
estadd local estabfe "\checkmark", replace
estadd local statecontrols "\checkmark", replace


reghdfe  `var' other_rd_credit_`explaining'3 rd_credit pit cit ln_gdp unemployment `other_controls' `sample`i'', absorb(estab_id year) cl(estab_id)
est sto reg8
estadd local yearfe "\checkmark", replace
estadd local estabfe "\checkmark", replace
estadd local statecontrols "\checkmark", replace
estadd local othercontrols "\checkmark", replace

reghdfe `var' other_rd_credit_`explaining'3 `sample`i'', absorb(estab_id year#i.fips_state) cl(estab_id)
est sto reg9
estadd local stateyearfe "\checkmark", replace
estadd local estabfe "\checkmark", replace


reghdfe `var' other_rd_credit_`explaining'3 `other_controls' `sample`i'', absorb(estab_id year#i.fips_state) cl(estab_id)
est sto reg10
estadd local stateyearfe "\checkmark", replace
estadd local estabfe "\checkmark", replace
estadd local othercontrols "\checkmark", replace


log using "$RESULTS/tables/new_`type'_${dataset}/czone/var`var'_`explaining'_sample`i'_`type'_log.log", replace 

esttab reg6 reg7 reg8 reg9 reg10, replace noconstant nomtitles drop(`other_controls' pit cit ln_gdp unemployment _cons) cells(b(star fmt(%9.3f)) se(par)) stats(yearfe estabfe stateyearfe statecontrols othercontrols N, fmt(%9.0g %9.0g %9.0g %9.0g %9.0g %9.0g ) label("Year FE" "Firm FE" "State-Year FE" "State Controls" "Other Controls" "Observations")) collabels(none) starl(* .10 ** .05 *** .01) label 

capture log close 


}
}
}
}



********************************************************************************
* Exclude commuting zones which experienced a treatment
********************************************************************************
*use "${TEMP}/patentcount_czone_`type'.dta", clear 


*merge 1:1 czone assignee_id app_year using "${TEMP}/inventorcount_cz.dta"
*drop _merge 



* Analysis on Commuting Zone Level, excluding 

* Control Group II: Only compare with treated units in the same state (Think more about whether this is the same thing as including state times year fixed effects)

* Control Group III: For each treated group counties with a similar geographic dispersion (present in similar states)