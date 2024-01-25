/// PROJECT: Spillover Effects 
/// GOAL: Inventor dataset - Mobility at county/commuting zone level
/// AUTHOR: Theresa Bührle, tbuehrle@diw.de
/// CREATION: 06-10-2023
/// LAST UPDATE: 11-01-2024
/// DATA: Woeppel patent data

if user ==2 {
*Set environment
global PATENTDTA "C:\Users\tbuehrle\OneDrive - DIW Berlin\3_Forschung\Data\Patent Data US_Woeppel"
global REGDTA "C:\Users\tbuehrle\OneDrive - DIW Berlin\3_Forschung\Topics\Spillover migration\2_Empirical\2_1_Data"
} 

*A. ****************************************************************************
*Generate dataset with inventor movements **************************************

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
duplicates drop patnum inventor_id county_fips_inventor, force 
duplicates report patnum inventor_id // differences in geocoding (missings or two different locations recorded); 190 cases
duplicates drop patnum inventor_id , force 

*Define destination and origin county for every inventor
egen tag = tag(inventor_id county_fips_inventor app_year)
egen ndistinct = total(tag), by(inventor_id app_year)
drop tag
tab ndistinct // keep ndistinct as tag for multiple loction changes within a year

	//If multiple states are observed, 
	//A. use mode of state-fips (most frequent location in data)
	bysort inventor_id app_year: egen county_inv = mode(county_fips_inventor)	
	bysort inventor_id app_year: egen state_inv = mode(state_fips_inventor)
	
	bysort inventor_id app_year: egen firm_id = mode(assignee_id)
	bysort inventor_id app_year: egen county_firm= mode(county_fips_assignee)
	bysort inventor_id app_year: egen state_firm = mode(state_fips_assignee)
	
	//B. drop observations with multiple loction changes within a year
	*drop if ndistinct > 2
	

*Calculate patent share (count) per inventor
bysort patnum: egen number_inv = count(inventor_id)
gen patent_share = 1/number_inv

collapse (first) county_inv state_inv ndistinct firm_id state_firm county_firm ///
		 (sum) patent_share ///
		 (mean) citation_count, ///
		 by(inventor_id app_year)
rename patent_share n_patents

label var app_year "Application year"
label var ndistinct "Number of moves within a year"
label var county_inv "County of Residence in t"
label var state_inv "State of Residence in t"
label var n_patents "Number of Patents"

save "$PATENTDTA\Temp\inventor_applic_collapse.dta", replace

*B. ****************************************************************************
*Calculate migration flows *****************************************************

use "$PATENTDTA\Temp\inventor_applic_collapse.dta", clear

/*
drop if ndistinct > 2	//see note above
*/

*Add commuting zones data
rename county_inv county_fips
	merge m:1 county_fips using "Temp\CZ_combined.dta"
drop if _merge == 2
rename county_fips county_inv
drop county_name_UScensus county_name_depagri _merge

*# observations per inventor
bysort inventor_id: egen inv_obs = count(inventor_id)
label var inv_obs "# observations per inventor in sample"
	
*Migration flows 
drop if county_inv == .

sort inventor_id app_year
duplicates report inventor_id app_year	// interim check; has to be unique!

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
	
	gen migration_`geo' = 0 if `geo'!= . & origin_`geo'!= .
	replace migration_`geo' = 1 if `geo'!=origin_`geo' & `geo'!= . & origin_`geo'!= .
		label var migration_`geo' "Dummy migration, `geo'"
	tab migration_`geo'
	
	*Moving within the company
	sort inventor_id app_year
	gen firm_move_`geo' = . 
		label var firm_move_`geo' "Dummy within firm migration, `geo'"
	replace firm_move_`geo'=0 if migration_`geo' == 1
	replace firm_move_`geo'=1 if migration_`geo' == 1 & firm_id==firm_id[_n-1]	
	tab firm_move_`geo'
	//state: 30% of 73,613 move within firms
		//if ndistinct =max(1): 30% of 72,008 move within firms
	//depagri: 35% of 93,472 move within firm
		//if ndistinct =max(1): 36% of 91,250 move within firms
	//UScensus: 43% of 114,139 move within firms
		//if ndistinct =max(1): 43% of 111,674 move within firms
}

foreach geo in "state" "CZ_depagri_2000" "CZ_UScensus"{
	bysort inventor_id: egen n_moves_`geo'=total(migration_`geo')
	
	gen ever_migrated_`geo'=0 if n_moves_`geo'==0 
	replace ever_migrated_`geo'=1 if n_moves_`geo'>0	
	tab ever_migrated_`geo'
	//10%-14% of inventors move at least once
		//if ndistinct =max(1): 9%-14% of inventors move at least once
}

save "$PATENTDTA\Stata\woeppel_inventor_moves.dta", replace

*C. ****************************************************************************
*Generate reg sample *******************************************************************

*Combine RHS variables
use "$REGDTA\raw\var_other\data_statepairs.dta", clear
	drop *_dest
	duplicates drop year fips_state_orig, force
	rename fips_state_orig fip_state
merge 1:1 year fip_state using "$REGDTA\raw\indep var\var_ITC\ITC_final.dta", nogen
	rename fip_state fips_state
merge 1:1 year fips_state using "$REGDTA\raw\indep var\var_R&Dcredits\R&D_credits_final.dta", nogen

rename ITC_rate ITC_rate_orig
rename rd_credit rd_credit_orig
rename fips_state state_fips

drop state_orig state F State 

save "$REGDTA\final\controls_orig.dta", replace

rename *_orig *
save "$REGDTA\final\controls.dta", replace

*Merge movement data set with controls
use "$PATENTDTA\Stata\woeppel_inventor_moves.dta", clear
	rename app_year year
	rename state_inv state_fips
merge m:1 year state_fips using "$REGDTA\final\controls.dta"
	drop if _merge == 2
	drop _merge
	rename state_fips state_inv
	rename origin_state_inv state_fips
merge m:1 year state_fips using "$REGDTA\final\controls_orig.dta"
	drop if _merge == 2
	drop _merge
	rename state_fips origin_state_inv
	rename state_inv state_fips 
merge m:1 state_fips using "$REGDTA\raw\var_other\raw_states_abbr.dta"	
	// The missing matches are 72 (Puerto Rico; 1058 obs) and 78 (Virgin Islands; 40 obs)
	keep if _merge == 3
	drop _merge
	rename state_fips state_inv

*Calculate difference in controls
foreach var in "corprate" "t_pinc_rate" "ITC_rate" "rd_credit" {
	gen diff_`var' = `var' - `var'_orig
}
	
label var year "Year"

save "$REGDTA\final\reg_data_patent_invmoves.dta", replace	



