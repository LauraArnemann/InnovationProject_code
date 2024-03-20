// Project: Inventor Relocation
// Creation Date: 19/03/2024
// Last Update: 20/03/2024
// Author: Laura Arnemann 
// Goal: Creating stacked event studies for changes in other states 

********************************************************************************
* Stacked Regression for tax changes at establishment location
********************************************************************************

global lead=4 	// set leads
global lag=4	// set lags

use  "${TEMP}/final_state.dta", clear 

drop if assignee_id == ""

tostring fips_state, gen(str_state)
gen estab_id = assignee_id + str_state
egen estab = group(estab_id)

xtset estab year 

* Changes in R&D credits
gen change_credit = rd_credit - l.rd_credit
// Keep only if at least 1% change
replace change_credit = 0 if inrange(change_credit, -1, 1)
// keep only obs with at least two consecutive years
*drop if missing(change_credit)	// let's leave this out for now; also need changes in other main variables
// 14,875 positive changes;  3,394  negative changes 

* Changes in PIT
gen change_pit = pit - l.pit
replace change_pit = 0 if inrange(change_pit, -1, 1)
// 11,063 positive changes;  6,204  negative changes 

* Changes in CIT
replace cit = cit * 100
gen change_cit = cit - l.cit
replace change_cit = 0 if inrange(change_cit, -1, 1)
// 11,063 positive changes;  6,204  negative changes 

drop if missing(change_credit) & missing(change_pit) & missing(change_cit)

save  "${TEMP}/final_state_stacked.dta", replace 

foreach var in "credit" "pit" "cit" {

*Increases	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x

preserve

	levelsof year if change_`var' > 0 & year>=1992 & change_`var'!=. , local(change)
	di `change'

	levelsof year if change_`var' > 0 & year>=1992 & change_`var'!=. , local(change_final)
	di `change_final'

	foreach v in `change' {
		use  "${TEMP}/final_state_stacked.dta", clear 
		local a = `v' - ${lead} 
		local b = `v' + ${lag}
		
		keep if inrange(year, `a', `b')
		 
		* Generate an indicator for being treated
		gen treated = 0 
		replace treated = 1 if year == `v' & change_`var' > 0 
		 
		bysort estab_id: egen max_treated = max(treated)
		bysort estab_id: egen max_change = max(change_`var')
		bysort estab_id: egen min_change = min(change_`var')
		
		* Drop all observations which were not treated and experienced a tax change in any other year 
		drop if max_change!=0 & max_treated==0 
		 
		* Drop treated units if they experienced a tax change four years prior to the reform
		generate helper = 0 
		replace helper = 1 if change_`var'!=0 & change_`var'!=. & year>=`a' & year<`v'
		bysort estab_id: egen max_helper = max(helper)
		drop if max_helper ==1 
		drop helper max_helper
		
		* Drop treated units if they experienced a reversal of the tax change in the the periods following the initial tax change 
		gen taxreversal = 0 
		replace taxreversal = 1 if max_treated==1 & min_change < 0 
		bysort estab_id: egen max_taxreversal = max(taxreversal)
		drop if max_taxreversal==1 
		drop max_taxreversal taxreversal 
		
		* Generate a variable that indicates that the observed change was the first in a series of tax changes 
		gen indicator = 1 if change_`var'!=0  & change_`var'!= .
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

	save "${TEMP}/final_state_stacked_`var'_incr.dta", replace 
	 
restore	

*Decreases	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x

preserve

	levelsof year if change_`var' < 0 & year>=1992 & change_`var'!=. , local(change)
	di `change'

	levelsof year if change_`var' < 0 & year>=1992 & change_`var'!=. , local(change_final)
	di `change_final'

	foreach v in `change' {
		use  "${TEMP}/final_state_stacked.dta", clear 
		local a = `v' - ${lead} 
		local b = `v' + ${lag}
		
		keep if inrange(year, `a', `b')
		 
		* Generate an indicator for being treated
		gen treated = 0 
		replace treated = 1 if year == `v' & change_`var' < 0 
		 
		bysort estab_id: egen max_treated = max(treated)
		bysort estab_id: egen max_change = max(change_`var')
		bysort estab_id: egen min_change = min(change_`var')
		
		* Drop all observations which were not treated and experienced a tax change in any other year 
		drop if max_change!=0 & max_treated==0 
		 
		* Drop treated units if they experienced a tax change four years prior to the reform
		generate helper = 0 
		replace helper = 1 if change_`var'!=0 & change_`var'!=. & year>=`a' & year<`v'
		bysort estab_id: egen max_helper = max(helper)
		drop if max_helper ==1 
		drop helper max_helper
		
		* Drop treated units if they experienced a reversal of the tax change in the the periods following the initial tax change 
		gen taxreversal = 0 
		replace taxreversal = 1 if max_treated==1 & max_change > 0 
		bysort estab_id: egen max_taxreversal = max(taxreversal)
		drop if max_taxreversal==1 
		drop max_taxreversal taxreversal 
		
		* Generate a variable that indicates that the observed change was the first in a series of tax changes 
		gen indicator = 1 if change_`var'!=0 & change_`var'!= .
		bysort estab_id : egen total_change = total(indicator)
		gen multiple_events = 1 if total_change >1
		drop indicator total_change 
			
		gen ry_decrease = year - `v' if max_treated ==1 
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

	save "${TEMP}/final_state_stacked_`var'_decr.dta", replace 
	 
restore	

}

********************************************************************************
* Stacked Regression for tax changes at other establishment location
********************************************************************************

use  "${TEMP}/final_state.dta", clear 

tostring fips_state, gen(str_state)
gen estab_id = assignee_id + str_state
egen estab = group(estab_id)

xtset estab year 

* Changes in R&D credits
gen change_other_credit = total_rd_credit - l.total_rd_credit
replace change_other_credit = 0 if inrange(change_other_credit, -1, 1)

* Changes in PIT
gen change_other_pit = total_pit - l.total_pit
replace change_other_pit = 0 if inrange(change_other_pit, -1, 1)

* Changes in CIT
replace total_cit = total_cit * 100
gen change_other_cit = total_cit - l.total_cit
replace change_other_cit = 0 if inrange(change_other_cit, -1, 1)

drop if missing(change_other_credit) & missing(change_other_pit) & missing(change_other_cit)

save  "${TEMP}/final_state_stacked_other.dta", replace 

foreach var in "credit" "pit" "cit"  {

*Increases	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x

preserve

	levelsof year if year>= 1992 & year<=2018, local(years_final)
	di `years_final'

	forvalues i = 1992/2018 { 
		use  "${TEMP}/final_state_stacked_other.dta", clear 
		local a = `i' - ${lead} 
		local b = `i' + ${lag}
		
		keep if inrange(year, `a', `b')
		 
		* Generate an indicator for being treated
		gen treated = 0 
		replace treated = 1 if year == `i' & change_other_`var' > 0 
		 
		bysort estab_id: egen max_treated = max(treated)
		bysort estab_id: egen max_change = max(change_other_`var')
		bysort estab_id: egen min_change = min(change_other_`var')
		
		* Drop all observations which were not treated and experienced a tax change in any other year 
		drop if max_change!=0 & max_treated==0 
		 
		* Drop treated units if they experienced a tax change four years prior to the reform
		generate helper = 0 
		replace helper = 1 if change_other_`var'!=0 & change_other_`var'!=. & year>=`a' & year<`i'
		bysort estab_id: egen max_helper = max(helper)
		drop if max_helper ==1 
		drop helper max_helper
		
		* Drop treated units if they experienced a reversal of the tax change in the the periods following the initial tax change 
		gen taxreversal = 0 
		replace taxreversal = 1 if max_treated==1 & min_change < 0 
		bysort estab_id: egen max_taxreversal = max(taxreversal)
		drop if max_taxreversal==1 
		drop max_taxreversal taxreversal 
		
		* Generate a variable that indicates that the observed change was the first in a series of tax changes 
		gen indicator = 1 if change_other_`var'!=0  & change_other_`var'!= .
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

	save "${TEMP}/final_state_stacked_other_`var'_incr.dta", replace 
	 
restore	

*Decreases	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x

preserve

	levelsof year if year>= 1992 & year<=2018, local(years_final)
	di `years_final'

	forvalues i = 1992/2018 { 
		use  "${TEMP}/final_state_stacked_other.dta", clear 
		local a = `i' - ${lead} 
		local b = `i' + ${lag}
		
		keep if inrange(year, `a', `b')
		 
		* Generate an indicator for being treated
		gen treated = 0 
		replace treated = 1 if year == `i' & change_other_`var' < 0 
		 
		bysort estab_id: egen max_treated = max(treated)
		bysort estab_id: egen max_change = max(change_other_`var')
		bysort estab_id: egen min_change = min(change_other_`var')
		
		* Drop all observations which were not treated and experienced a tax change in any other year 
		drop if max_change!=0 & max_treated==0 
		 
		* Drop treated units if they experienced a tax change four years prior to the reform
		generate helper = 0 
		replace helper = 1 if change_other_`var'!=0 & change_other_`var'!=. & year>=`a' & year<`i'
		bysort estab_id: egen max_helper = max(helper)
		drop if max_helper ==1 
		drop helper max_helper
		
		* Drop treated units if they experienced a reversal of the tax change in the the periods following the initial tax change 
		gen taxreversal = 0 
		replace taxreversal = 1 if max_treated==1 & max_change > 0 
		bysort estab_id: egen max_taxreversal = max(taxreversal)
		drop if max_taxreversal==1 
		drop max_taxreversal taxreversal 
		
		* Generate a variable that indicates that the observed change was the first in a series of tax changes 
		gen indicator = 1 if change_other_`var'!=0 & change_other_`var'!= .
		bysort estab_id : egen total_change = total(indicator)
		gen multiple_events = 1 if total_change >1
		drop indicator total_change 
			
		gen ry_decrease = year - `i' if max_treated ==1 
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
			di "`change_final'"
			
		}
	}

	clear 
	foreach v in `years_final' {
		append using `stacked_`v''
	}

	save "${TEMP}/final_state_stacked_other_`var'_decr.dta", replace 
	 
restore	
}
