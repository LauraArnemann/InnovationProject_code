/// PROJECT: CEO Project
/// GOAL: Stacked regression 
/// AUTHOR: Laura Arnemann
/// CREATION:
/// LAST UPDATE: 29-06-2023
/// SOURCE: cleaned data 

use "$TEMP/tax_rates_bearbeitet.dta", clear 

drop L?_taxincrease_l1 F?_taxincrease_l1 

local fmax 4 // maximum lead		
local lmax 4 // minimum lead 

* Only look at  tax changes above 0.5 percentage point 
*gen ln_statetax=log(1-statetax/100)
*xtset state_id year 
*gen d_ln_statetax=ln_statetax-l.ln_statetax


gen taxintensity=taxchange
replace taxintensity=0 if taxchange<0.5 & taxchange>-0.5

replace taxchange = 0 if taxchange<0.5 & taxchange>-0.5
*xtset state_id year
/*
foreach x in taxincrease_l1 taxintensity {
	* Binary would be an indicator for a change in x var in a certain year
	* Intensity would an indicator for a change in xvar scaled with the size of the change
	forval f = `fmax'(-1)1 {
		gen F`f'_`x' = F`f'.`x'				
	} // f
	forval l = 0(1)`lmax' {		
		gen L`l'_`x' = L`l'.`x'
	} // l
}
/*
foreach x in taxincrease_l1 taxintensity {
	* Generate binned endpoints 
	bysort state_id (year): gen binned_`x'_L`lmax' = sum(L`lmax'_`x')
	replace L`lmax'_`x' = binned_`x'_L`lmax'
	}
	
foreach x in taxincrease_l1 taxintensity {	
	gsort state_id  -year
	by state_id: gen binned_F`fmax'_`x' = sum(F`fmax'_`x')
	replace F`fmax'_`x' = binned_F`fmax'_`x'
	
} // x
*/	*/	

gen treat_year = year if taxintensity!=0 
replace treat_year=. if missing(taxintensity)

* I want to drop all states which had a tax change in the eight periods surrounding their events so I generate an indicator to hknow when the repective state was last treated 

gen lasttreatment = 0
replace lasttreatment=treat_year if treat_year!=.
 
sort state year
bysort state: replace lasttreatment=lasttreatment[_n-1] if missing(treat_year)
replace lasttreatment=0 if missing(lasttreatment)

*Generate an indicator for treatment magnitude 
gen lastmagnitude = 0 
replace lastmagnitude=taxchange if taxchange!=0 

sort state year 
bysort state: replace lastmagnitude=lastmagnitude[_n-1] if missing(treat_year)
replace lastmagnitude=0 if missing(lastmagnitude)
				
save "$TEMP/tax_rates_stacked.dta", replace 

********************************************************************************
*** Implement Approach Similar to Tester and Cengiz et al. Paper (see also Baker code)
********************************************************************************

use "$OUT/final_dataset.dta", clear 
duplicates drop gvkey year, force 

drop L?_taxincrease_l1 F?_taxincrease_l1
**# Bookmark #1
drop if hq_change_sum2!=0
drop if state=="AZ" | state=="CT" | state=="HI" | state=="MD" | state=="ND" | state=="RI" | state=="VT"

merge m:1 state year using "$TEMP/tax_rates_stacked.dta", keep(match)
drop _merge 

save "$OUT/final_stacked.dta", replace 



********************************************************************************
* Only Tax Increases 
********************************************************************************
use "$OUT/final_stacked.dta", clear

local fmax 4 // maximum lead		
local lmax 4 // minimum lead 

levelsof lasttreatment if lasttreatment > 1992 & lastmagnitude>0, local(taxincreases)
di `taxincreases'
levelsof lasttreatment if lasttreatment > 1992 & lastmagnitude>0, local(taxincreases_final)

*only keep clean controls 
foreach v in `taxincreases' {
	use "$OUT/final_stacked.dta", clear
	
	keep if year>=`v' -`fmax' & year<= `v'+ `lmax'
	
	*Generate an indicator for being treated in that year
	gen treated=0
	replace treated=1 if lasttreatment==`v' & taxchange>=0.5

	*Indicator for being in the treatment group
	sort state year
	by state: egen max_treated=max(treated)

	*Generate clean controls
	bysort state: egen max_event=max(lasttreatment)
	drop if max_event>= `v'-`fmax' & max_treated==0

	*Drop treated units if they experienced a tax change in the four years prior to the reform
	
	generate helper=0 
	replace helper=1 if lasttreatment>=`v'-`fmax' & lasttreatment <`v'
	bysort state: egen max_helper=max(helper)
	drop if max_helper==1 
	drop helper max_helper 

	
	*Drop treatment units if they experienced a reversal of the taxchange in the periods following the tax change
	gen taxreversal = 0 
	replace taxreversal = 1 if max_treated == 1 & lastmagnitude<0 & lastmagnitude[_n-1]>0 & year>`v'
	bysort state: egen max_taxreversal=max(taxreversal)
	drop if max_taxreversal==1
	drop max_taxreversal taxreversal
	

	*Indicator for the event being a taxdecrease
	generate helper=0 
	replace helper=1 if taxchange<0 & year==`v'
	bysort state: egen max_helper=max(helper)
	drop if max_helper==1
	drop max_helper helper


	*Generate a variable indicating that there were multiple tax changes following the first event
	sort state year
	by state: gen event=1 if lasttreatment!=lasttreatment[_n-1] & lasttreatment!=. & year!=`v'-`fmax'
	by state: egen sum_event=total(event)
	gen multiple_events=1 if sum_event>1 
	drop event sum_event 
	
	
	gen ry_increase= year - max_event if max_treated==1
	gen size=taxintensity if year==`v'
	bysort state: egen event_size=max(size)
	
	*Generate an event indicator which we can later use for the fixed effects estimator
	gen event= `v'
	*Make sure to have at least ten treated units in the last year
	sum roa3 if ry_increase == `lmax' & max_treated==1
	local count=r(N)
	di `count'
	if `count' >0 {
	tempfile stacked_`v'_increase
	save "$TEMP/stacked_`v'increase", replace
	  }
	
		else if `count' ==0  {
		local not `v'
		local taxincreases_final: list taxincreases_final - not
		di "`taxincreases_final'"
	}
}



*Combine all the datasets together 
local firstcohort = word("`taxincreases_final'", 1)
local cohorts_final: list taxincreases_final - firstcohort
di `cohorts_final'
*2004 2005 2008 2009 2012 2013
use "$TEMP/stacked_`firstcohort'increase.dta", clear
foreach v in `cohorts_final' {
	append using "$TEMP/stacked_`v'increase.dta", force
}

*Generate the event indicators

forvalues i=1/`fmax' {
	gen f`i'_binary = ry_increase==-`i'
	label var f`i'_binary "- `i'"
}

forvalues i=0/`lmax' {
	gen l`i'_binary = ry_increase==`i'
	label var l`i'_binary "`i'"
}
gen zero_1=0
label var zero_1 "-1"

forvalues i=1/`fmax' {
    gen f`i'_intensity=event_size*f`i'_binary
	label var f`i'_intensity "- `i'"
}

forvalues i=0/`lmax' {
    gen l`i'_intensity=event_size*l`i'_binary
	label var l`i'_intensity "`i'"
}


save "${TEMP}/stacked_increases.dta", replace 

********************************************************************************
* Both Tax Increases and Tax Decreases 
********************************************************************************

use "$OUT/final_stacked.dta", clear

local fmax 4 // maximum lead		
local lmax 4 // minimum lead 

levelsof lasttreatment if lasttreatment > 1992, local(cohorts)
di `cohorts'
levelsof lasttreatment if lasttreatment > 1992, local(cohorts_final)

*only keep clean controls 
foreach v in `cohorts' {
	use "$OUT/final_stacked.dta", clear
	
	keep if year>=`v' -`fmax' & year<=`v'+ `lmax'
	
	*Generate an indicator for being treated in that year
	gen treated=0
	replace treated=1 if lasttreatment==`v'
	
	*Indicator for being in the treatment group
	sort state year
	by state: egen max_treated=max(treated)
	
	*Generate clean controls
	bysort state: egen max_event=max(lasttreatment)
	drop if max_event>=`v'-`fmax' & max_treated==0
	
	*Drop treated units if they experienced a tax change in the four years prior to the reform
	generate helper=0 
	replace helper=1 if lasttreatment>= `v'-`fmax' & lasttreatment <`v'
	bysort state: egen max_helper=max(helper)
	drop if max_helper==1 
	drop helper max_helper 

	*Do this on state level
	*Drop treatment units if they experienced a reversal of the taxchange in the periods following the tax change
	gen taxreversal = 0 
	sort state year
	by state: replace taxreversal = 1 if max_treated == 1 &  lastmagnitude<0 & lastmagnitude[_n-1]>0 & year>`v'
	by state: replace taxreversal = 1 if max_treated == 1 &  lastmagnitude>0 & lastmagnitude[_n-1]<0 & year>`v'
	by state: egen max_taxreversal=max(taxreversal)
	drop if max_taxreversal==1
	drop max_taxreversal taxreversal
	
	*Indicator for the event being a taxdecrease
	generate helper=0 
	replace helper=1 if lastmagnitude<0 & year==`v'
	by state: egen max_helper=max(helper)
	drop helper
	
	*Indicator for multiple events happening
	sort state year
	by state: gen event=1 if lasttreatment!=lasttreatment[_n-1] & lasttreatment!=. & year!=`v'-`fmax'
	by state: egen sum_event=total(event)
	gen multiple_events=1 if sum_event>1 
	drop event sum_event 
	
	*Generate different indicators for tax increases and decreases {

	gen ry_increase = year - max_event if max_event==`v' & max_helper==0
	
	gen ry_decrease = year - max_event if max_event==`v' & max_helper==1
	
	gen event = `v'
	gen size=taxintensity if year==`v'
	bysort gvkey: egen event_size=max(size)
	


	*Make sure to have at least ten treated units in the last year
	sum roa3 if (ry_increase == `fmax' | ry_decrease==`lmax') & max_treated==1
	local count=r(N)
	di `count'
	if `count' >0 {
	tempfile stacked_`v'_increase
	save "$TEMP/stacked_`v'", replace
	  }
	
		else if `count' ==0  {
		local not `v'
		local cohorts_final: list cohorts_final - not
		di "`cohorts_final'"
	}
	
	
	tempfile stacked_`v'_increase
	save "$TEMP/stacked_`v'", replace
}



*Combine all the datasets together 
local firstcohort = word("`cohorts_final'", 1)
local cohorts_final: list cohorts_final - firstcohort

use "$TEMP/stacked_`firstcohort'", clear
foreach v in `cohorts_final' {
	append using "$TEMP/stacked_`v'", force
}


*Generate the event indicators, also allowing for missings 

forvalues i=1/`fmax' {
	gen f`i'_binary = ry_increase==-`i'
	replace f`i'_binary = -1  if ry_decrease== -`i'
	label var f`i'_binary "- `i'"
}

forvalues i=0/`lmax' {
	gen l`i'_binary = ry_increase==`i'
	replace l`i'_binary = -1  if ry_decrease== `i'
	label var l`i'_binary "`i'"
}
gen zero_1=0
label var zero_1 "-1"

forvalues i=1/`fmax' {
    gen f`i'_intensity=event_size*f`i'_binary
	replace f`i'_intensity= - event_size*f`i'_binary if f`i'_binary==-1
	label var f`i'_intensity "- `i'"
}

forvalues i=0/`lmax' {
    gen l`i'_intensity=event_size*l`i'_binary
	replace l`i'_intensity= - event_size*l`i'_binary if l`i'_binary==-1
	label var l`i'_intensity "`i'"
}

save "$OUT/stacked_final_both.dta", replace 




/*

use "$OUT/final_stacked.dta", clear

local fmax 4 // maximum lead		
local lmax 4 // minimum lead 

levelsof lasttreatment if lasttreatment > 1992, local(cohorts)
di `cohorts'
levelsof lasttreatment if lasttreatment > 1992, local(cohorts_final)

*only keep clean controls 
foreach v in `cohorts' {
	use "$OUT/final_stacked.dta", clear
	
	keep if year>=`v' -`fmax' & year<=`v'+ `lmax'
	
	*Generate an indicator for being treated in that year
	gen treated=0
	replace treated=1 if lasttreatment==`v' & taxchange<=-0.5
	
	*Indicator for being in the treatment group
	sort state year
	by state: egen max_treated=max(treated)
	
	*Generate clean controls
	bysort state: egen max_event=max(lasttreatment)
	drop if max_event>=`v'-`fmax' & max_treated==0
	
	*Drop treated units if they experienced a tax change in the four years prior to the reform
	generate helper=0 
	replace helper=1 if lasttreatment>= `v'-`fmax' & lasttreatment <`v'
	bysort state: egen max_helper=max(helper)
	drop if max_helper==1 
	drop helper max_helper 

	*Do this on state level
	*Drop treatment units if they experienced a reversal of the taxchange in the periods following the tax change
	gen taxreversal = 0 
	sort state year
	by state: replace taxreversal = 1 if max_treated == 1 &  lastmagnitude<0 & lastmagnitude[_n-1]>0 & year>`v'
	by state: replace taxreversal = 1 if max_treated == 1 &  lastmagnitude>0 & lastmagnitude[_n-1]<0 & year>`v'
	by state: egen max_taxreversal=max(taxreversal)
	drop if max_taxreversal==1
	drop max_taxreversal taxreversal
	
	*Indicator for the event being a taxdecrease
	generate helper=0 
	replace helper=1 if lastmagnitude<0 & year==`v'
	by state: egen max_helper=max(helper)
	drop helper
	
	*Indicator for multiple events happening
	sort state year
	by state: gen event=1 if lasttreatment!=lasttreatment[_n-1] & lasttreatment!=. & year!=`v'-`fmax'
	by state: egen sum_event=total(event)
	gen multiple_events=1 if sum_event>1 
	drop event sum_event 
	
	*Generate different indicators for tax increases and decreases {

	gen ry_increase = year - max_event if max_event==`v' & max_helper==0
	
	gen ry_decrease = year - max_event if max_event==`v' & max_helper==1
	
	gen event = `v'
	gen size=taxintensity if year==`v'
	bysort gvkey: egen event_size=max(size)
	


	*Make sure to have at least ten treated units in the last year
	sum roa3 if (ry_increase == `fmax' | ry_decrease==`lmax') & max_treated==1
	local count=r(N)
	di `count'
	if `count' >0 {
	tempfile stacked_`v'_increase
	save "$TEMP/stacked_`v'", replace
	  }
	
		else if `count' ==0  {
		local not `v'
		local cohorts_final: list cohorts_final - not
		di "`cohorts_final'"
	}
	
	
	tempfile stacked_`v'_increase
	save "$TEMP/stacked_`v'", replace
}



*Combine all the datasets together 
local firstcohort = word("`cohorts_final'", 1)
local cohorts_final: list cohorts_final - firstcohort

use "$TEMP/stacked_`firstcohort'", clear
foreach v in `cohorts_final' {
	append using "$TEMP/stacked_`v'", force
}


*Generate the event indicators, also allowing for missings 

forvalues i=1/`fmax' {
	gen f`i'_binary = ry_increase==-`i'
	replace f`i'_binary = -1  if ry_decrease== -`i'
	label var f`i'_binary "- `i'"
}

forvalues i=0/`lmax' {
	gen l`i'_binary = ry_increase==`i'
	replace l`i'_binary = -1  if ry_decrease== `i'
	label var l`i'_binary "`i'"
}
gen zero_1=0
label var zero_1 "-1"

forvalues i=1/`fmax' {
    gen f`i'_intensity=event_size*f`i'_binary
	replace f`i'_intensity= - event_size*f`i'_binary if f`i'_binary==-1
	label var f`i'_intensity "- `i'"
}

forvalues i=0/`lmax' {
    gen l`i'_intensity=event_size*l`i'_binary
	replace l`i'_intensity= - event_size*l`i'_binary if l`i'_binary==-1
	label var l`i'_intensity "`i'"
}

save "${TEMP}/stacked_both.dta", replace 

*/

********************************************************************************
* Tax Decreases 
********************************************************************************

use "$OUT/final_stacked.dta", clear

local fmax 4 // maximum lead		
local lmax 4 // minimum lead 

levelsof lasttreatment if lasttreatment > 1992 & lastmagnitude<0, local(taxdecreases)
di `taxincreases'
levelsof lasttreatment if lasttreatment > 1992 & lastmagnitude<0, local(taxdecreases_final)

*only keep clean controls 
foreach v in `taxdecreases' {
	use "$OUT/final_stacked.dta", clear
	
	keep if year>=`v' -`fmax' & year<= `v'+ `lmax'
	
	*Generate an indicator for being treated in that year
	gen treated=0
	replace treated=1 if lasttreatment==`v' & taxchange<=0.5

	*Indicator for being in the treatment group
	sort state year
	by state: egen max_treated=max(treated)

	*Generate clean controls
	bysort state: egen max_event=max(lasttreatment)
	drop if max_event>= `v'-`fmax' & max_treated==0

	*Drop treated units if they experienced a tax change in the four years prior to the reform
	
	generate helper=0 
	replace helper=1 if lasttreatment>=`v'-`fmax' & lasttreatment <`v'
	bysort state: egen max_helper=max(helper)
	drop if max_helper==1 
	drop helper max_helper 

	
	*Drop treatment units if they experienced a reversal of the taxchange in the periods following the tax change
	gen taxreversal = 0 
	replace taxreversal = 1 if max_treated == 1 & lastmagnitude>0 & lastmagnitude[_n-1]<0 & year>`v'
	bysort state: egen max_taxreversal=max(taxreversal)
	drop if max_taxreversal==1
	drop max_taxreversal taxreversal
	

	*Indicator for the event being a taxdecrease
	generate helper=0 
	replace helper=1 if taxchange>0 & year==`v'
	bysort state: egen max_helper=max(helper)
	drop if max_helper==1
	drop max_helper helper


	*Generate a variable indicating that there were multiple tax changes following the first event
	sort state year
	by state: gen event=1 if lasttreatment!=lasttreatment[_n-1] & lasttreatment!=. & year!=`v'-`fmax'
	by state: egen sum_event=total(event)
	gen multiple_events=1 if sum_event>1 
	drop event sum_event 
	
	
	gen ry_decrease= year - max_event if max_treated==1
	gen size=taxintensity if year==`v'
	bysort state: egen event_size=max(size)
	
	*Generate an event indicator which we can later use for the fixed effects estimator
	gen event= `v'
	*Make sure to have at least ten treated units in the last year
	sum roa3 if ry_decrease == `lmax' & max_treated==1
	local count=r(N)
	di `count'
	if `count' >0 {
	tempfile stacked_`v'_decrease
	save "$TEMP/stacked_`v'decrease", replace
	  }
	
		else if `count' ==0  {
		local not `v'
		local taxdecreases_final: list taxdecreases_final - not
		di "`taxdecreases_final'"
	}
}



*Combine all the datasets together 
local firstcohort = word("`taxdecreases_final'", 1)
local cohorts_final: list taxdecreases_final - firstcohort
di `cohorts_final'


use "$TEMP/stacked_`firstcohort'decrease.dta", clear
foreach v in `cohorts_final' {
	append using "$TEMP/stacked_`v'decrease.dta", force
}

*Generate the event indicators

forvalues i=1/`fmax' {
	gen f`i'_binary = ry_decrease==-`i'
	label var f`i'_binary "- `i'"
}

forvalues i=0/`lmax' {
	gen l`i'_binary = ry_decrease==`i'
	label var l`i'_binary "`i'"
}
gen zero_1=0
label var zero_1 "-1"

forvalues i=1/`fmax' {
    gen f`i'_intensity=event_size*f`i'_binary
	label var f`i'_intensity "- `i'"
}

forvalues i=0/`lmax' {
    gen l`i'_intensity=event_size*l`i'_binary
	label var l`i'_intensity "`i'"
}


save "${TEMP}/stacked_decreases.dta", replace 
