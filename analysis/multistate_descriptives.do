// Project: Inventor Relocation
// Creation Date: 05/04/2024
// Last Update: 05/04/2024
// Author: Laura Arnemann 
// Goal: Descriptive Stats: Explaining why we find positive effects   




use "${TEMP}/final_state_zeros.dta", clear


********************************************************************************
* Number of States in which firm is present/ Share of firms active in more than one state
********************************************************************************

egen estab = group(assignee_id fips_state)

duplicates drop estab year assignee_id, force 

preserve 
bysort assignee_id year: gen total_labs = _N 
 
collapse (mean) total_labs, by(year)
 
twoway (bar total_labs year if year>=1992, yaxis(2) ylabel(0(2)6, axis(2)) color(gs10%50) barw(0.85) ytitle("Average number of states", axis(2))) , ///
legend(off) xlabel(1992[4]2018) graphregion(style(none) color(white)) 
graph export "${RESULTS}/graph_number_states.png", replace

restore 

bysort assignee_id year: gen total_labs = _N 
gen multi_statefirm = 0 
replace multi_statefirm = 1 if total_labs>1 

duplicates drop assignee_id year, force 
collapse (mean) multi_statefirm, by(year)

twoway (bar multi_statefirm year if year>=1992, yaxis(2) ylabel(0(0.2)1, axis(2)) color(gs10%50) barw(0.85) ytitle("Share of Multi-State firms", axis(2))) , ///
legend(off) xlabel(1992[4]2018) graphregion(style(none) color(white)) 
graph export "${RESULTS}/graph_multistatefirms.png", replace



********************************************************************************
* Share of Multi-State Patents 
********************************************************************************

use patnum citation_count withdrawn date_filing date_grant app_year ///
	inventor_id first_name last_name male location_id state_fips_inventor county_fips_inventor ///
	assignee_id state_fips_assignee county_fips_assignee  ///
	using "${PATENTDTA}/inventor_applications.dta", clear
	
drop if withdrawn==1 
drop withdrawn

*-Drop if missings in important variables
drop if app_year == .
drop if county_fips_inventor == .


*-Drop duplicates (we only want to count inventors once per recorded patent)
duplicates drop patnum inventor_id county_fips_inventor assignee_id, force 
* (132 observations deleted)
duplicates report patnum inventor_id assignee_id // differences in geocoding (missings or two different locations recorded); 190 cases
duplicates drop patnum inventor_id assignee_id, force 
*preserve 

duplicates drop patnum state_fips_inventor, force 
* I don't enforce that patents need to be from the same 
preserve 
   bysort patnum assignee_id: gen count = _N 
   gen multistatepatent = 0 
   replace multistatepatent = 1 if count >1 

   duplicates drop patnum assignee_id, force 
   collapse (mean) multistatepatent, by(app_year)
   rename app_year year 
   label var year "Year"
   
twoway (bar multistatepatent year if inrange(year, 1992, 2018), yaxis(2) ylabel(0(0.05)0.2, axis(2)) color(gs10%50) barw(0.85) ytitle("Share of Multi-State Patents", axis(2))) , ///
legend(off) xlabel(1992[4]2018) graphregion(style(none) color(white)) 
graph export "${RESULTS}/graph_multistatepatents.png", replace

* Dropping all Research Labs which are in multi-state CZ  
restore 

rename county_fips_inventor county_fips
* Merging in the Commuting Zone level data 
   merge m:1 county_fips using "$IN\var_CommutingZones\CZ_combined.dta", keepusing(CZ_depagri_1990)
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
   
twoway (bar multistatepatent year if inrange(year, 1992, 2018), yaxis(2) ylabel(0(0.05)0.2, axis(2)) color(gs10%50) barw(0.85) ytitle("Share of Multi-State Patents", axis(2))) , ///
legend(off) xlabel(1992[4]2018) graphregion(style(none) color(white)) 
graph export "${RESULTS}/graph_multistatepatents_corrected_cz.png", replace