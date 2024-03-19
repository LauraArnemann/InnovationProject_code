// Project: Inventor Relocation
// Creation Date: 19/03/2024
// Last Update: 19/03/2024
// Author: Laura Arnemann 
// Goal: Creating stacked event studies for changes in other states 

********************************************************************************
* Stacked Regression for Increases in R&D Tax Credits at other establishments 
********************************************************************************

use  "${TEMP}/final_state.dta", clear 

tostring fips_state, gen(str_state)
gen estab_id = assignee_id + str_state
egen estab = group(estab_id)

xtset estab year 

gen change_credit = rd_credit - l.rd_credit
replace change_credit = 0 if inrange(change_credit, -1, 1)
drop if missing(change_credit)
* 14,875 positive changes;  3,394  negative changes 

save  "${TEMP}/final_state_stacked.dta", replace 

levelsof year if change_credit>0 & year>=1992 & change_credit!=. , local(change)
di `change'


levelsof year if change_credit > 0 & year>=1992 & change_credit!=. , local(change_final)
di `change_final'

foreach v in `change' {
	 use  "${TEMP}/final_state_stacked.dta", clear 
	 local a = `v' -4 
	 local b = `v' + 4
	
	 keep if inrange(year, `a', `b')
	 
	 gen treated = 0 
	 replace treated = 1 if year == `v' & change_credit>0 
	 
	bysort estab_id: egen max_treated = max(treated)
	bysort estab_id: egen max_change = max(change_credit)
	bysort estab_id: egen min_change = min(change_credit)
	drop if max_change!=0 & max_treated==0 
	
	* Drop all observations which were not treated and experienced a tax change in any other year 
	drop if max_change!=0 & max_treated==0 
	 
	* Drop treated units if they experienced a tax change four years prior to the reform
	generate helper = 0 
	replace helper = 1 if change_credit!=0 & year>=`a' & year<`v'
	bysort estab_id: egen max_helper = max(helper)
	drop if max_helper ==1 
	drop helper max_helper
	
	* Drop treated units if they experienced a reversal of the tax change in the the periods following the initial tax change 
	gen taxreversal = 0 
	replace taxreversal = 1 if max_treated==1 & min_change<0 
	bysort estab_id: egen max_taxreversal = max(taxreversal)
	drop if max_taxreversal==1 
	drop max_taxreversal taxreversal 
	
* Generate a variable that indicates that the observed change was the first in a series of tax changes 
	gen indicator = 1 if change_credit!=0 
	bysort estab_id : egen total_change = total(indicator)
	gen multiple_events = 1 if total_change >1
	drop indicator total_change 
		
	gen ry_increase = year - `v' if max_treated ==1 
	gen event = `v'
	sum event if max_treated==1 
	local count =r(N)
	di `count'
	
	if `count' >0 {
		tempfile stacked_`v'
		save `stacked_`v''
		
	}
	else {
		local not `v'
		local change_final: list change_final - not
		di "`change_final'"
		
	}
}

clear 
foreach v in `change_final' {
	append using `stacked_`v''
}

save "${TEMP}/final_state_stacked.dta", replace 
	 
	

********************************************************************************
* Stacked Regression for Changes in R&D Tax Credits at other establishments 
********************************************************************************

use  "${TEMP}/final_state.dta", clear 

tostring fips_state, gen(str_state)
gen estab_id = assignee_id + str_state
egen estab = group(estab_id)

xtset estab year 

gen change_other_credit = total_rd_credit - l.total_rd_credit
replace change_other_credit = 0 if inrange(change_other_credit, -1, 1)
drop if missing(change_other_credit)
* 66,574 observations for which this is the case 

save  "${TEMP}/final_state_stacked_other.dta", replace 

levelsof year if year>= 1992 & year<=2018, local(years_final)
di `years_final'

* Stacked Regression for 
forvalues i = 1992/2018 { 
	
	 use  "${TEMP}/final_state_stacked_other.dta", clear 
	 local a = `i' -4 
	 local b = `i' + 4
	
	 keep if inrange(year, `a', `b')
	 
	* Generate an indicator for being treated 
	gen treated = 0 
	replace treated = 1 if year == `i' & change_other_credit>0 
	
	bysort estab_id: egen max_treated = max(treated)
	bysort estab_id: egen max_change = max(change_other_credit)
	bysort estab_id: egen min_change = min(change_other_credit)
	drop if max_change!=0 & max_treated==0 
	
	* Drop treated units if they experienced a tax change four years prior to the reform
	generate helper = 0 
	replace helper = 1 if change_other_credit!=0 & year>=`a' & year<`i'
	bysort estab_id: egen max_helper = max(helper)
	drop if max_helper ==1 
	drop helper max_helper 
	
	* Drop treated units if they experienced a reversal of the tax change in the the periods following the initial tax change 
	gen taxreversal = 0 
	replace taxreversal = 1 if max_treated==1 & min_change<0 
	bysort estab_id: egen max_taxreversal = max(taxreversal)
	drop if max_taxreversal==1 
	drop max_taxreversal taxreversal 
	
	* Generate a variable that indicates that the observed change was the first in a series of tax changes 
	gen indicator = 1 if change_other_credit!=0 
	bysort estab_id : egen total_change = total(indicator)
	gen multiple_events = 1 if total_change >1
	drop indicator total_change 
	
	gen ry_increase = year - `i' if max_treated ==1 
	gen event = `i'
	sum event if max_treated==1 
	local count =r(N)
	di `count'
	
	if `count' >0 {
		tempfile stacked_`i'
		save `stacked_`i''
		
	}
	else {
		local not `i'
		local years_final: list years_final - not
		di "`years_final'"
		
	}
}

clear 
foreach v in `years_final' {
	append using `stacked_`v''
}

save "${TEMP}/final_state_stacked_other.dta", replace 
