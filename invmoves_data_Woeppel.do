/// PROJECT: Spillover Effects 
/// GOAL: Inventor dataset - Mobility at county/commuting zone level
/// AUTHOR: Theresa Bührle, tbuehrle@diw.de
/// CREATION: 06-10-2023
/// LAST UPDATE: 01-02-2024
/// DATA: Woeppel patent data

*A. ****************************************************************************
*Inventor aggregation **********************************************************

*-------------------------------------------------------------------------------	
*Generation inventor panel
*-------------------------------------------------------------------------------

use patnum citation_count withdrawn date_filing date_grant app_year ///
	inventor_id first_name last_name male location_id state_fips_inventor county_fips_inventor ///
	assignee_id state_fips_assignee county_fips_assignee  ///
	using "$PATENTDTA\Temp\inventor_applications.dta", clear

*Cleaning	
drop if withdrawn==1 
drop withdrawn
*-Drop if missings in important variables
drop if app_year == .
drop if county_fips_inventor == .
*-Drop duplicates (we only want to count inventors once per recorded patent)
sort inventor_id patnum county_fips_inventor
duplicates drop patnum inventor_id county_fips_inventor, force 	// 132 obs
duplicates report patnum inventor_id // differences in geocoding (missings or two different locations recorded); 190 cases
duplicates drop patnum inventor_id, force 

*Define destination and origin county for every inventor
egen tag = tag(inventor_id county_fips_inventor app_year)
egen ndistinct = total(tag), by(inventor_id app_year)
drop tag
tab ndistinct // keep ndistinct as tag for multiple loction changes within a year

	//If multiple states are observed, 
	//A. use mode of state-fips (most frequent location in data)
		// USe maxmode if there are several nodes to avoid missings; could also use sth else (help egen -> mode)
	bysort inventor_id app_year: egen county_inv = mode(county_fips_inventor), maxmode	
	bysort inventor_id app_year: egen state_inv = mode(state_fips_inventor), maxmode	
	
	bysort inventor_id app_year: egen firm_id = mode(assignee_id), maxmode	
	bysort inventor_id app_year: egen county_firm= mode(county_fips_assignee), maxmode	
	bysort inventor_id app_year: egen state_firm = mode(state_fips_assignee), maxmode	
	
	//B. drop observations with multiple loction changes within a year
	*drop if ndistinct > 2	// 53,417 cases

*Calculate patent share (count) per inventor
bysort patnum: egen number_inv = count(inventor_id)
gen patent_share = 1/number_inv
gen citation_share_inv = patent_share * citation_count if citation_count != .

collapse (first) county_inv state_inv ndistinct firm_id state_firm county_firm ///
		 (sum) patent_share citation_share_inv citation_count, ///
		 by(inventor_id app_year)
rename patent_share n_patents_inv
rename citation_count n_cite_inv

gen av_cite_inv = n_cite_inv / n_patents_inv

*# observations per inventor
bysort inventor_id: egen inv_obs = count(inventor_id)
label var inv_obs "# observations per inventor in sample"

*Superstar inventors
rangestat (sum) n_patents_inv, by(inventor_id) int(app_year -10 0)
rename n_patents_inv_sum cum_10yrs

gen superstar=0 
forvalues i=1970/2021 {
	sum cum_10yrs if app_year== `i', detail 
	replace superstar = 1 if cum_10yrs>=r(p95) & cum_10yrs!=. & app_year==`i'
}

bysort inventor_id: egen max_superstar=max(superstar)
gen nonstar = 0
	replace nonstar = 1 if superstar == 0

sort inventor_id app_year
duplicates report inventor_id app_year	// interim check; has to be unique!

label var app_year "Application Year"
label var ndistinct "Number of Moves Within a Year"
label var county_inv "County of Residence in t, Inventor"
label var state_inv "State of Residence in t, Inventor"
label var n_patents_inv "Proportionate Number of Patents, Inventor"
label var county_firm "County of Residence in t, Firm"
label var state_firm "State of Residence in t, firm"

*Add commuting zones data
rename county_inv county_fips
	//Broomfild county in Colarado (8014) was part of Boulder County (8013) until 2001 and is recorded as such in old cenzus data
	replace county_fips = 8013 if county_fips == 8014
merge m:1 county_fips using "$IN\var_CommutingZones\CZ_combined.dta"
	//Non-matched master: Puerto Rico, Virgin Islands, Alaska
keep if _merge == 3
rename county_fips county_inv
drop county_name_UScensus county_name_depagri _merge
drop if county_inv == .	// interim check; should be zero

*Generate alternative firm_id that needs less disk space
egen firm_id2 = group(firm_id)
drop firm_id

save "$IN\main_data\data_patent\inventor_applic_collapse.dta", replace
//This is the inventor-level panel.

*-------------------------------------------------------------------------------	
*Generate variables aggregated at CZ-level 
*-------------------------------------------------------------------------------

use "$IN\main_data\data_patent\inventor_applic_collapse.dta", clear

/*
drop if ndistinct > 2	//see note above
*/

*Migration flows x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x

*Movements into commuting zone

/*
NOTE:
Not 100% clear how to define migration, but could also be defined as 
migration in next year, i.e. residence_state != destination_state
*/

foreach geo in "state_inv" "CZ_depagri_2000" "CZ_UScensus"{
	
	gen origin_`geo'= .
		label var origin_`geo' "Origin in t-1, `geo'"
	bysort inventor_id: replace origin_`geo'=`geo'[_n-1] 
	bysort inventor_id: replace origin_`geo'= . if app_year[_n-1]!=app_year-1
	replace origin_`geo'= . if inventor_id[_n-1] != inventor_id
	
	gen inmigr_`geo' = 0 if `geo'!= . & origin_`geo'!= .
	replace inmigr_`geo' = 1 if `geo'!=origin_`geo' & `geo'!= . & origin_`geo'!= .
		label var inmigr_`geo' "Dummy Inmigration, `geo'"
	tab inmigr_`geo'
	
	gen inmigr_super_`geo'= .
		replace inmigr_super_`geo'= 0 if inmigr_`geo' == 1 & superstar == 0
		replace inmigr_super_`geo'= 1 if inmigr_`geo' == 1 & superstar == 1
	
	*Moving within the company
	sort inventor_id app_year
	gen firm_move_`geo' = . 
		label var firm_move_`geo' "Dummy Within Firm Migration, `geo'"
	replace firm_move_`geo'=0 if inmigr_`geo' == 1
	replace firm_move_`geo'=1 if inmigr_`geo' == 1 & firm_id2==firm_id2[_n-1]
	tab firm_move_`geo'
	//state: 34% of 95,910 move within firms
	//depagri: 40% of 121,135 move within firm
	//UScensus: 46% of 146,904 move within firms
}

foreach geo in "state_inv" "CZ_depagri_2000" "CZ_UScensus"{
	bysort inventor_id: egen n_moves_`geo'=total(inmigr_`geo')
	
	gen ever_migrated_`geo'=0 if n_moves_`geo'==0 
	replace ever_migrated_`geo'=1 if n_moves_`geo'>0	
	tab ever_migrated_`geo'
	//10%-16% of inventors move at least once
}

*Movements out of commuting zone
foreach geo in "state_inv" "CZ_depagri_2000" "CZ_UScensus"{
	gen destin_`geo'= .
		label var destin_`geo' "Destination in t+1, `geo'"
	bysort inventor_id: replace destin_`geo'=`geo'[_n+1] 
	bysort inventor_id: replace destin_`geo'= . if app_year[_n+1]!=app_year+1
	replace destin_`geo'= . if inventor_id[_n+1] != inventor_id
	
	gen outmigr_`geo' = 0 if `geo'!= . & destin_`geo'!= .
	replace outmigr_`geo' = 1 if `geo'!=destin_`geo' & `geo'!= . & destin_`geo'!= .
		label var outmigr_`geo' "Dummy Outmigration, `geo'"
	tab outmigr_`geo'
	
	gen outmigr_super_`geo'= .
		replace outmigr_super_`geo'= 0 if outmigr_`geo' == 1 & superstar == 0
		replace outmigr_super_`geo'= 1 if outmigr_`geo' == 1 & superstar == 1
}

*Innovative activity	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x

*Patent count in commuting zone
foreach geo in "state_inv" "CZ_depagri_2000" "CZ_UScensus"{
	
	*Patent count in commuting zone
	bysort `geo' app_year: egen n_patents_inv_`geo' = sum(n_patents_inv)
	label var n_patents_inv_`geo' "Number of Patents, `geo'"
		
	*Patent quality
	*-Total citations
	bysort `geo' app_year: egen n_cite_inv_`geo' = sum(n_cite_inv)
	label var n_cite_inv_`geo' "Weighted Citation Count, `geo'"

	*-Av citation per patent
	bysort `geo' app_year: egen av_cite_inv_`geo' = mean(av_cite_inv)
	label var av_cite_inv_`geo' "Average Citation Count, `geo'"     
}

*Inventor count in commuting zone
foreach geo in "state_inv" "CZ_depagri_2000" "CZ_UScensus"{
	*-Total
	bysort `geo' app_year: egen n_inv_total_`geo' = count(inventor_id)
		**Superstars
		bysort `geo' app_year: egen n_inv_totalsuper_`geo' = count(superstar)
	*-Thereof: New inventors
	bysort `geo' app_year: egen n_inv_new_`geo' = sum(inmigr_`geo')
		**Superstars
		bysort `geo' app_year: egen n_inv_newsuper_`geo' = sum(inmigr_super_`geo')
	*-Thereof: Old inventors
	gen nomigr_`geo' = 1 if inmigr_`geo' == 0
	bysort `geo' app_year: egen n_inv_old_`geo' = sum(nomigr_`geo')
	drop nomigr_`geo' 
		**Superstars
		gen nomigr_super_`geo' = 1 if  inmigr_super_`geo' == 0
		bysort `geo' app_year: egen n_inv_oldsuper_`geo' = sum(nomigr_super_`geo')
		drop nomigr_super_`geo' 
	
	// Total != old_inv + new_inv
	// There is an additional number of inventors we don't observe in the previous year	
}

save "$IN\main_data\data_patent\woeppel_inventor_moves.dta", replace
//This is the inventor-level panel with additional variables on CZ-level migration and activity.



*B. ****************************************************************************
*Company presence across CZs ***************************************************

use "$IN\main_data\data_patent\inventor_applic_collapse.dta", clear

*For now, we focus on US Cenzus CZ (highest # of moves)
drop  CZ_depagri_2000 CZ_depagri_1990 CZ_depagri_1980 
rename CZ_UScensus CZ_inv

*Drop if missing firm info
drop if firm_id2 == .
*drop if state_firm == .	// We assume subs at inventor locations, officially recorded firm location is irrelevant

*Define mode for firm location
// Around 5% of firms report multiple locations within one year
bysort firm_id2 app_year: egen county_firm_mode = mode(county_firm), maxmode	
bysort firm_id2 app_year: egen state_firm_mode = mode(state_firm), maxmode	

*Inventor and patent count per firm-year at CZ of inventor
bysort firm_id2 CZ_inv app_year: egen n_inv_firm = count(inventor_id)
bysort firm_id2 CZ_inv app_year: egen n_patent_firm = sum(n_patents_inv)
bysort firm_id2 CZ_inv app_year: egen n_cite_firm = sum(citation_share_inv)
gen av_cite_firm = n_cite_firm / n_patent_firm if n_cite_firm != . & n_patent_firm != .

label var CZ_inv "Inventor CZ"
label var n_inv_firm "Inventor Count, per Firm-year and Inv CZ"
label var n_patent_firm "Patent Count, per Firm-year and Inv CZ"
label var n_cite_firm "Citation Count, per Firm-year and Inv CZ"
label var av_cite_firm "Av Citation per Patent, per Firm-year and Inv CZ"
label var county_firm_mode "County of Residence in t, firm"

*Drop duplicates (we only need distinct firm_id-state_inv-year pairs)
sort firm_id2 app_year CZ_inv 
duplicates drop firm_id2 app_year CZ_inv , force
keep firm_id2 state_firm_mode county_firm_mode CZ_inv state_inv app_year n_inv_firm n_patent_firm n_cite_firm av_cite_firm
order app_year firm_id2 state_firm_mode county_firm_mode CZ_inv state_inv n_inv_firm n_patent_firm n_cite_firm av_cite_firm

save "$IN\main_data\data_patent\woeppel_firm_invCZ_aggr.dta", replace

*Generate data set with all states the firm was ever present in
use "$IN\main_data\data_patent\woeppel_firm_invCZ_aggr.dta", clear
/* COMMENTS
- Controls are state-level. Move to CZ level if controls at CZ level are added
- Difficult to appoint CZ to specific state! Might need to add CZ controls seperately.
- More refined measure: presence at least 2x, presence assumed +/-5 years around obs...	
*/

keep firm_id2 state_inv 
duplicates drop, force	

sort firm_id2 state_inv

*Add years
expand 51	// 1970 - 2021
bysort firm_id2 state_inv: gen count_obs = _n
gen app_year = 1969+count_obs
drop count_obs

save "$IN\main_data\data_patent\woeppel_firm_presence.dta", replace

*C. ****************************************************************************
*Generate reg sample ***********************************************************

*-------------------------------------------------------------------------------	
*RHS variables/ controls
*-------------------------------------------------------------------------------
use "$IN\var_other\data_statepairs.dta", clear
	// 1980-2012/2015

	drop *_dest
	duplicates drop year fips_state_orig, force
	rename fips_state_orig fip_state
merge 1:1 year fip_state using "$IN\indep_var\var_ITC\ITC_final.dta", nogen
	// 1963-2018
	rename fip_state fips_state
merge 1:1 year fips_state using "$IN\indep_var\var_R&Dcredits\R&D_credits_final.dta", nogen
	// 1963-2018

replace state_orig = state_abbr if state_orig == ""
drop state_abbr state F State 

rename *_orig * 

rename state residence_state
rename year app_year 

sort fips_state
duplicates drop app_year residence_state, force

merge 1:1 app_year residence_state using "$IN\var_other\moretti_controls_basic.dta", nogen	
// data covers only 1977-2009

rename residence_state state_abbr
drop if fips_state == .

compress
save "$OUT\controls_basic.dta", replace

use "$OUT\controls_basic.dta", clear
rename * *_inv
rename app_year_inv app_year
drop state_abbr_inv
save "$OUT\controls_basic_inv.dta", replace

use "$OUT\controls_basic.dta", clear
rename * *_net
rename app_year_net app_year
drop state_abbr_net
save "$OUT\controls_basic_network.dta", replace


*-------------------------------------------------------------------------------	
*Merge all
*-------------------------------------------------------------------------------

//For now, we focus on US Cenzus CZ (highest # of moves)

*First stage	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	

*Merge firm presence dataset with controls
use "$IN\main_data\data_patent\woeppel_firm_presence.dta", clear

rename state_inv fips_state_net
merge m:1 app_year fips_state_net using "$OUT\controls_basic_network.dta", nogen keep(3)

compress
save "$IN\main_data\data_patent\woeppel_firm_presence_controls.dta", replace

//Reduced version
keep firm_id2 app_year fips_state_net ///
	ITC_rate_net rd_credit_net GDP_net corprate_net t_pinc_rate_net RA_net
save "$IN\main_data\data_patent\woeppel_firm_presence_controls_red.dta", replace

*Merge firm dataset with inventor CZs with controls

use "$IN\main_data\data_patent\woeppel_firm_invCZ_aggr.dta", clear
//unique identifier: app_year firm_id2 CZ_inv

rename state_inv fips_state_inv
merge m:1 app_year fips_state_inv using "$OUT\controls_basic_inv.dta", nogen keep(3)
	// Nonmatched from using: years before 1974
	// Nonmatched from master: years after 2018	
	
merge m:m firm_id2 app_year using "$IN\main_data\data_patent\woeppel_firm_presence_controls_red.dta", nogen keep(3)
	
compress
save "$IN\main_data\data_patent\woeppel_finalsample.dta", replace
	
duplicates report app_year firm_id2 CZ_inv fips_state_net	
	
*Calculate averages in other locations of the firm
//Weighted by # inventors?

*- Set variables to missing in state of inventor	
foreach var in "ITC_rate_net" "rd_credit_net" "GDP_net" "corprate_net" "t_pinc_rate_net" "RA_net" {
	replace `var' = . if fips_state_inv == fips_state_net
}	
	
*- Calculate averages	
foreach var in "ITC_rate_net" "rd_credit_net" "GDP_net" "corprate_net" "t_pinc_rate_net" "RA_net" {
bysort app_year CZ_inv: egen `var'_other = mean(`var')
}

save "$OUT\woeppel_regsample.dta", replace	

	


*Second stage	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	
