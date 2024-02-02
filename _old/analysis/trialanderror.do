/// PROJECT: Spillover Effects 
/// GOAL: Finding out why there are so little moves  
/// AUTHOR: Laura Arnemann, Theresa Bührle
/// CREATION: 27-12-2022
/// LAST UPDATE: 25-04-2023
/// SOURCE: Raw Data 


use "${mw_datadir}/star_migration_rates.dta", clear
keep if year>1996
keep if year<2007

*List of states kept:
local keepstates "6,25,34,36,48,27,42,17,26,39"
local statelist "CA IL MA MI MN NJ NY OH PA TX"
		
keep if inlist(fips,`keepstates')
keep if inlist(F_fips,`keepstates')

*Generate average annual outflow matrix
foreach st in `statelist' {
	egen `st' = sum(outflow95) if F_state=="`st'", by(fips)
	replace `st' = round(`st'/10,1)
	}
	
duplicates drop
collapse (max) `statelist', by(state)




use "${OUT}/moretti_sample.dta", replace 

keep if app_year>1996
keep if app_year<2007

local keepstates "6,25,34,36,48,27,42,17,26,39"

keep if inlist(destination_state,`keepstates')
keep if inlist(residence_state,`keepstates')

foreach num of numlist 6 25 34 36 48 27 42 17 26 39 {
	egen mig`num' = sum(outflow95) if destination_state==`num', by(residence_state)
	*replace mig`num' = round(`st'/10,1)
	}

duplicates drop
collapse (max) mig*, by(residence_state)	

*********************************************************************************
*use "${OUT}/moretti_sample1.dta", replace 
use "C:/Users/laura/Dropbox/spillover_effects_inventor_relocation/2_Empirical/2_1_Data/moretti_sample1.dta", clear 

gen destination_state=""
bysort inventor_id: replace destination_state =residence_state[_n+1] 
bysort inventor_id: replace destination_state="" if app_year[_n+1]!=app_year+1

gen origin_state=""
bysort inventor_id: replace origin_state=residence_state[_n-1] 
bysort inventor_id: replace origin_state="" if app_year[_n-1]!=app_year-1

keep if superstar==1

gen migration = 0 if residence_state!="" & origin_state!=""
replace migration=1 if residence_state!=origin_state & origin_state!="" & origin_state!=""

bysort residence_state origin_state app_year: egen outflow95=count(inventor_id)
bysort residence_state app_year: egen overall_pop = count(inventor_id)

gen helper=outflow95 if residence_state==destination_state
bysort residence_state: egen pop_stayer95=max(helper)

collapse (max) outflow95, by(residence_state destination_state app_year)

foreach var of varlist _all {

rename `var' trial`var'

}

rename trialapp_year year 
rename trialresidence_state state 
rename trialdestination_state F_state 


use "C:/Users/laura/Dropbox/spillover_effects_inventor_relocation/2_Empirical/2_1_Data/moretti_sample.dta", clear 
collapse (max) outflow95, by(residence_state destination_state app_year)
rename outflow95 trialoutflow95
rename residence_state state 
rename destination_state F_state
rename app_year year 

merge 1:1 state F_state year using "${mw_datadir}/star_migration_rates.dta" , keepusing(outflow95)

bysort year: egen sum_outflow95=sum(outflow95)
bysort year: gen count=_n 
replace sum_outflow95=. if count!=1
egen overall_outflow=sum(sum_outflow95)
*444101: This is way higher than the number of superstar year observations that they indicate 

	