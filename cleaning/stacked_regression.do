// Project: Inventor Relocation
// Creation Date: 19/03/2024
// Last Update: 21/03/2024
// Author: Laura Arnemann 
// Goal: Creating stacked event studies for changes in other states 


global lead=4 	// set leads
global lag=4	// set lags

********************************************************************************
* Stacked Regression for tax changes at establishment location
********************************************************************************

use  "${TEMP}/final_state_zeros.dta", clear 
drop if assignee_id == .

egen estab = group(assignee_id fips_state)

xtset estab year 

* Changes in R&D credits
gen change_rd_credit = rd_credit - l.rd_credit
// Keep only if at least 1% change
replace change_rd_credit = 0 if inrange(change_rd_credit, -1, 1)
// keep only obs with at least two consecutive years
*drop if missing(change_credit)	// let's leave this out for now; also need changes in other main variables
// 14,875 positive changes;  3,394  negative changes 

* Changes in PIT
gen change_pit = pit - l.pit
replace change_pit = 0 if inrange(change_pit, -1, 1)
// 11,063 positive changes;  6,204  negative changes 

* Changes in CIT
gen change_cit = cit - l.cit
replace change_cit = 0 if inrange(change_cit, -1, 1)
// 11,063 positive changes;  6,204  negative changes 

drop if missing(change_rd_credit) & missing(change_pit) & missing(change_cit)

drop max_year min_year nstates multistatefirm_temp multistatefirm_max
drop unemployment_l* state_rd_exp_l* gdp_l*

compress
save  "${TEMP}/final_state_stacked_zeros.dta", replace 

foreach var in "rd_credit" "pit" "cit" {

*Increases	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x

preserve

	levelsof year if change_`var' > 0 & year>=1992 & change_`var'!=. , local(change)
	di `change'

	levelsof year if change_`var' > 0 & year>=1992 & change_`var'!=. , local(change_final)
	di `change_final'

	foreach v in `change' {
		use  "${TEMP}/final_state_stacked_zeros.dta", clear 
		local a = `v' - ${lead} 
		local b = `v' + ${lag}
		
		keep if inrange(year, `a', `b')
		 
		* Generate an indicator for being treated
		gen treated = 0 
		replace treated = 1 if year == `v' & change_`var' > 0 
		 
		bysort estab: egen max_treated = max(treated)
		bysort estab: egen max_change = max(change_`var')
		bysort estab: egen min_change = min(change_`var')
		
		* Drop all observations which were not treated and experienced a tax change in any other year 
		drop if max_change!=0 & max_treated==0 
		 
		* Drop treated units if they experienced a tax change four years prior to the reform
		generate helper = 0 
		replace helper = 1 if change_`var'!=0 & change_`var'!=. & year>=`a' & year<`v'
		bysort estab: egen max_helper = max(helper)
		drop if max_helper ==1 
		drop helper max_helper
		
		* Drop treated units if they experienced a reversal of the tax change in the the periods following the initial tax change 
		gen taxreversal = 0 
		replace taxreversal = 1 if max_treated==1 & min_change < 0 
		bysort estab: egen max_taxreversal = max(taxreversal)
		drop if max_taxreversal==1 
		drop max_taxreversal taxreversal 
		
		* Generate a variable that indicates that the observed change was the first in a series of tax changes 
		gen indicator = 1 if change_`var'!=0  & change_`var'!= .
		bysort estab : egen total_change = total(indicator)
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
	
	keep fips_state estab year assignee_id treated max_treated max_change min_change multiple_events ry_increase event 
	compress
	save "${TEMP}/final_state_stacked_`var'_incr.dta", replace 
	 
restore	

*Decreases	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x

preserve

	levelsof year if change_`var' < 0 & year>=1992 & change_`var'!=. , local(change)
	di `change'

	levelsof year if change_`var' < 0 & year>=1992 & change_`var'!=. , local(change_final)
	di `change_final'

	foreach v in `change' {
		use  "${TEMP}/final_state_stacked_zeros.dta", clear 
		local a = `v' - ${lead} 
		local b = `v' + ${lag}
		
		keep if inrange(year, `a', `b')
		 
		* Generate an indicator for being treated
		gen treated = 0 
		replace treated = 1 if year == `v' & change_`var' < 0 
		 
		bysort estab: egen max_treated = max(treated)
		bysort estab: egen max_change = max(change_`var')
		bysort estab: egen min_change = min(change_`var')
		
		* Drop all observations which were not treated and experienced a tax change in any other year 
		drop if max_change!=0 & max_treated==0 
		 
		* Drop treated units if they experienced a tax change four years prior to the reform
		generate helper = 0 
		replace helper = 1 if change_`var'!=0 & change_`var'!=. & year>=`a' & year<`v'
		bysort estab: egen max_helper = max(helper)
		drop if max_helper ==1 
		drop helper max_helper
		
		* Drop treated units if they experienced a reversal of the tax change in the the periods following the initial tax change 
		gen taxreversal = 0 
		replace taxreversal = 1 if max_treated==1 & max_change > 0 
		bysort estab: egen max_taxreversal = max(taxreversal)
		drop if max_taxreversal==1 
		drop max_taxreversal taxreversal 
		
		* Generate a variable that indicates that the observed change was the first in a series of tax changes 
		gen indicator = 1 if change_`var'!=0 & change_`var'!= .
		bysort estab : egen total_change = total(indicator)
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
	
	keep fips_state estab year assignee_id treated max_treated max_change min_change multiple_events ry_decrease event 
	compress
	save "${TEMP}/final_state_stacked_`var'_decr.dta", replace 
	 
restore	
}


********************************************************************************
* Stacked Regression for tax changes at other establishment location
********************************************************************************

use  "${TEMP}/final_state_zeros.dta", clear 
drop if assignee_id == .

egen estab = group(assignee_id fips_state)
xtset estab year 

* (Weighted) levels at other locations:
foreach var in "rd_credit" "pit" "cit" {
	foreach var2 of varlist total_`var'  `var'_other `var'_other_b ///
		`var'_l1_other `var'_l2_other `var'_l3_other `var'_l4_other ///
		`var'_l1_other_b `var'_l2_other_b `var'_l3_other_b `var'_l4_other_b {

		* Changes in R&D credits
		gen change_oth_`var2' = `var2' - l.`var2'
		replace change_oth_`var2' = 0 if inrange(change_oth_`var2', -1, 1)
	}
}
	
drop if missing(change_oth_total_rd_credit) & missing(change_oth_total_cit) & missing(change_oth_total_pit)

drop max_year min_year nstates multistatefirm_temp multistatefirm_max
drop unemployment_l* state_rd_exp_l* gdp_l*

compress	
save  "${TEMP}/final_state_stacked_other_zeros.dta", replace 

use  "${TEMP}/final_state_stacked_other_zeros.dta", clear 

*Split incr and decr for other due to I/O error (too little space for tempfiles)

foreach var in "rd_credit" "pit" "cit"  {
	
	foreach var2 of varlist total_`var'  `var'_other `var'_other_b ///
		`var'_l1_other `var'_l2_other `var'_l3_other `var'_l4_other ///
		`var'_l1_other_b `var'_l2_other_b `var'_l3_other_b `var'_l4_other_b {

	*Increases	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x

	preserve
		
		levelsof year if year>= 1992 & year<=2018, local(years_final)
		di `years_final'

		forvalues i = 1992/2018 { 
			use  "${TEMP}/final_state_stacked_other_zeros.dta", clear 
			local a = `i' - ${lead} 
			local b = `i' + ${lag}
			
			keep if inrange(year, `a', `b')
			 
			* Generate an indicator for being treated
			gen treated = 0 
			replace treated = 1 if year == `i' & change_oth_`var2' > 0 
			 
			bysort estab: egen max_treated = max(treated)
			bysort estab: egen max_change = max(change_oth_`var2')
			bysort estab: egen min_change = min(change_oth_`var2')
			
			* Drop all observations which were not treated and experienced a tax change in any other year 
			drop if max_change!=0 & max_treated==0 
			 
			* Drop treated units if they experienced a tax change four years prior to the reform
			generate helper = 0 
			replace helper = 1 if change_oth_`var2'!=0 & change_oth_`var2'!=. & year>=`a' & year<`i'
			bysort estab: egen max_helper = max(helper)
			drop if max_helper ==1 
			drop helper max_helper
			
			* Drop treated units if they experienced a reversal of the tax change in the the periods following the initial tax change 
			gen taxreversal = 0 
			replace taxreversal = 1 if max_treated==1 & min_change < 0 
			bysort estab: egen max_taxreversal = max(taxreversal)
			drop if max_taxreversal==1 
			drop max_taxreversal taxreversal 
			
			* Generate a variable that indicates that the observed change was the first in a series of tax changes 
			gen indicator = 1 if change_oth_`var2'!=0  & change_oth_`var2'!= .
			bysort estab : egen total_change = total(indicator)
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
		
		keep fips_state estab year assignee_id treated max_treated max_change min_change multiple_events ry_increase event
		compress
		save "${TEMP}/final_state_stacked_other_`var2'_incr.dta", replace 
		 
	restore	
	}
}

use  "${TEMP}/final_state_stacked_other_zeros.dta", clear 

foreach var in "rd_credit" "pit" "cit"  {
	
	foreach var2 of varlist total_`var'  `var'_other `var'_other_b ///
		`var'_l1_other `var'_l2_other `var'_l3_other `var'_l4_other ///
		`var'_l1_other_b `var'_l2_other_b `var'_l3_other_b `var'_l4_other_b {

	*Decreases	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x

	preserve

		levelsof year if year>= 1992 & year<=2018, local(years_final)
		di `years_final'

		forvalues i = 1992/2018 { 
			use  "${TEMP}/final_state_stacked_other_zeros.dta", clear 
			local a = `i' - ${lead} 
			local b = `i' + ${lag}
			
			keep if inrange(year, `a', `b')
			 
			* Generate an indicator for being treated
			gen treated = 0 
			replace treated = 1 if year == `i' & change_oth_`var2' < 0 
			 
			bysort estab: egen max_treated = max(treated)
			bysort estab: egen max_change = max(change_oth_`var2')
			bysort estab: egen min_change = min(change_oth_`var2')
			
			* Drop all observations which were not treated and experienced a tax change in any other year 
			drop if max_change!=0 & max_treated==0 
			 
			* Drop treated units if they experienced a tax change four years prior to the reform
			generate helper = 0 
			replace helper = 1 if change_oth_`var2'!=0 & change_oth_`var2'!=. & year>=`a' & year<`i'
			bysort estab: egen max_helper = max(helper)
			drop if max_helper ==1 
			drop helper max_helper
			
			* Drop treated units if they experienced a reversal of the tax change in the the periods following the initial tax change 
			gen taxreversal = 0 
			replace taxreversal = 1 if max_treated==1 & max_change > 0 
			bysort estab: egen max_taxreversal = max(taxreversal)
			drop if max_taxreversal==1 
			drop max_taxreversal taxreversal 
			
			* Generate a variable that indicates that the observed change was the first in a series of tax changes 
			gen indicator = 1 if change_oth_`var2'!=0 & change_oth_`var2'!= .
			bysort estab : egen total_change = total(indicator)
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
		
		keep fips_state estab year assignee_id treated max_treated max_change min_change multiple_events ry_decrease event
		compress
		save "${TEMP}/final_state_stacked_other_`var2'_decr.dta", replace 
		 
	restore	
	}
}
