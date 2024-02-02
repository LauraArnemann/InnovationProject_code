/// PROJECT: Spillover Effects 
/// GOAL: DATA PREP
/// AUTHOR: Laura Arnemann, Theresa Bührle
/// CREATION: 19-07-2023
/// LAST UPDATE: 19-07-2023

//Note: Running time 10-15 Min

*PREP RAW FILES PREP -----------------------------------------------------------

*Serrato/Zidar data
use "${basedir}/2_1_Data/suarez_serrato_zidar_data.dta", clear
	
	rename corporate_rate corprate
	rename taxshare_rev_indinctax revsh_indinctax
	rename taxshare_rev_corptax revsh_corptax
	rename FedIncomeTaxDeductible fed_deduction
	rename FederalIncomeasStateTaxBase fed_taxbase
	rename FederalBonusDepreciation fed_bonusdepr
	rename investment_credit inv_cred
	
	drop if state_abbr == ""
	drop State
	
save "${basedir}/2_1_Data/suarez_serrato_zidar_data_clean.dta", replace


*DATA MERGE --------------------------------------------------------------------

use "${basedir}/2_1_Data/raw_states.dta", clear
	
	rename state state_abbr
	merge m:1 year state_abbr using "${basedir}/2_1_Data/suarez_serrato_zidar_data_clean.dta"
	drop if _merge == 2
		drop _merge
	rename state_abbr state

save "${basedir}/2_1_Data/data_raw.dta", replace
	
	use "${basedir}/2_1_Data/data_raw.dta", clear	
		rename * *_orig
		rename year_orig year

	tempfile orig
	save `orig'
	
	use "${basedir}/2_1_Data/data_raw.dta", clear	
		rename * *_dest
		rename year_dest year

	tempfile dest
	save `dest'
	
use "${basedir}/2_1_Data/raw_statepairs.dta", clear	
	
	merge m:1 year state_orig using `orig', nogen
	merge m:1 year state_dest using `dest', nogen
	
save "${basedir}/2_1_Data/data_statepairs.dta", replace	


*VARIABLE GENERATION FOR ES ----------------------------------------------------

use "${basedir}/2_1_Data/data_statepairs.dta", clear

local taxvariables "corprate rec_val inv_cred t_pinc_rate"
local indicator "changeD incrD decrD changeV"

egen statepairs = group(state_orig state_dest) 
xtset statepairs year

capture drop L?_*
capture drop F?_*
capture drop L??_*
capture drop bin_*

foreach var in `taxvariables' {
	
	*Tax differentials and change indicators (change in origin country)
	capture drop `var'_diff `var'_change
	gen `var'_diff = `var'_orig - `var'_dest
	replace `var'_diff = . if `var'_orig == . | `var'_dest == .
	
	sort statepairs year
	
		**Scaled values
		gen `var'_changeV = . // size of change
			replace `var'_changeV = `var'_diff - `var'_diff[_n-1] if `var'_diff[_n-1] != `var'_diff ///
							& `var'_diff[_n-1] != . & `var'_diff != . ///
							& statepairs[_n-1] == statepairs
			replace `var'_changeV = 0 if `var'_diff[_n-1] == `var'_diff ///
							& `var'_diff[_n-1] != . & `var'_diff != . ///
							& statepairs[_n-1] == statepairs
			// Set change to zero if caused by change in legislation in destination country	
			// REGRESSION: Control for changes in destination country (see Stantcheva paper -> WHICH PAPER?)
			replace `var'_changeV = 0 if `var'_orig == `var'_orig[_n-1] & `var'_dest != `var'_dest[_n-1] ///
							& `var'_orig != . & `var'_orig[_n-1] != . ///
							& `var'_dest != . & `var'_dest[_n-1] != . ///
							& statepairs[_n-1] == statepairs
							
		gen `var'_incrV = .	// size of increase
			replace `var'_incrV = `var'_changeV if `var'_changeV > 0 & `var'_changeV != .
			replace `var'_incrV = 0 if `var'_changeV == 0 & `var'_changeV != .
			replace `var'_incrV = 0 if `var'_changeV < 0 & `var'_changeV != .
		gen `var'_decrV = . // size of decrease
			replace `var'_decrV = `var'_changeV if `var'_changeV < 0 & `var'_changeV != .
			replace `var'_decrV = 0 if `var'_changeV == 0 & `var'_changeV != .
			replace `var'_decrV = 0 if `var'_changeV > 0 & `var'_changeV != .
			
		**Dummies					
		gen `var'_changeD = .	// -1/0/1 change dummies
			replace `var'_changeD = 1 if `var'_changeV > 0 & `var'_changeV != .
			replace `var'_changeD = -1 if `var'_changeV < 0	& `var'_changeV != .			
			replace `var'_changeD = 0 if `var'_changeV == 0 & `var'_changeV != .
			
		gen `var'_incrD = .	// increase dummy
			replace `var'_incrD = 1 if `var'_changeD > 0 & `var'_changeV != .
			replace `var'_incrD = 0 if `var'_changeD == 0 & `var'_changeV != .
			replace `var'_incrD = 0 if `var'_changeD < 0 & `var'_changeV != .
		gen `var'_decrD = . // decrease dummy
			replace `var'_decrD = 1 if `var'_changeD < 0 & `var'_changeV != .
			replace `var'_decrD = 0 if `var'_changeD == 0 & `var'_changeV != .
			replace `var'_decrD = 0 if `var'_changeD > 0 & `var'_changeV != .
	
	*Time indicators
	sort statepairs year
	
		**Treatment year
		gen `var'_treatyear = year if `var'_changeD != 0 & `var'_changeD != .
			replace `var'_treatyear = . if `var'_changeD == .
		
		**Year of last treatment
		gen `var'_lasttreat = 0
			replace `var'_lasttreat = `var'_treatyear if `var'_treatyear != .
			bysort statepairs: replace `var'_lasttreat = `var'_lasttreat[_n-1] if missing(`var'_treatyear)
			replace `var'_lasttreat  = 0 if missing(`var'_lasttreat)
			
		**Magnitude of last treatment
		gen `var'_lastmag = 0
			replace `var'_lastmag = `var'_changeV if `var'_changeV != 0 & `var'_changeV != .
			bysort statepairs: replace `var'_lastmag = `var'_lastmag[_n-1] if missing(`var'_treatyear)
			replace `var'_lastmag  = 0 if missing(`var'_lastmag)
				
local fmax 5 // lead	
local lmax 10 // lag

	foreach ind in `indicator' {
		*Generate leads and lags
		foreach x in `var'_`ind' {
			forval f = `fmax'(-1)1 {
				gen F`f'_`x' = F`f'.`x'				
			} // Leads
			forval l = 0(1)`lmax' {		
				gen L`l'_`x' = L`l'.`x'
			} // Lags
		}

		*Generate binned endpoints 
		foreach x in `var'_`ind' {
			bysort statepairs (year): gen bin_L`lmax'_`x' = sum(L`lmax'_`x')
			replace L`lmax'_`x' = bin_L`lmax'_`x'
			
		// Interpretation of end points doesn't really make sense for Dummies
		// e.g. for D, value could be 5 if there are 5 staggered increases in the years after
			}
		}
}

foreach var in `taxvariables' {		
	foreach ind in `indicator' {
		foreach x in `var'_`ind' {	
			gsort statepairs  -year
			by statepairs: gen bin_F`fmax'_`x' = sum(F`fmax'_`x')
			replace F`fmax'_`x' = bin_F`fmax'_`x'
		} 
	}
}	 
	
save "${basedir}/2_1_Data/data_state.dta", replace	

capture drop L?_*
capture drop F?_*
capture drop L??_*
capture drop bin_*

save "${basedir}/2_1_Data/data_prestacked.dta", replace	

*STACKED COHORT DiD SET-UP -----------------------------------------------------
/// Cengiz et al. (2019), Baker et al. (2022)

use "${basedir}/2_1_Data/data_prestacked.dta", clear	

local fmax 5 // lead	
local lmax 5 // lag

local taxvariables "corprate rec_val inv_cred t_pinc_rate"
local indicator "changeD incrD decrD changeV"

foreach var in `taxvariables'{

*Identify years with treatment and define them as cohorts (with sufficient pre-periods)
	**Increases
	levelsof `var'_lasttreat if `var'_lasttreat > 1980 + `fmax' & `var'_changeD == 1, local(`var'_coh_incr)
		di ``var'_coh_incr'
	**Decreases
	levelsof `var'_lasttreat if `var'_lasttreat > 1980 + `fmax' & `var'_changeD == -1, local(`var'_coh_decr)
		di ``var'_coh_decr'
		
*Generate cohorts for increases	
	foreach t in ``var'_coh_incr' {
		
	preserve
	
	*Limit sample to observations within ES window
	keep if year>=`t' -`fmax' & year<=`t'+ `lmax'
	
	*Generate an indicator for being treated in that year
	gen `var'_treat=0
	replace `var'_treat=1 if `var'_lasttreat==`t' & `var'_changeD == 1
	
	*Indicator for being in the treatment group
	sort statepairs year
	by statepairs: egen max_`var'_treat=max(`var'_treat)
	
	*Drop controls with change within already defined time window (treatment +/- t)
	bysort statepairs: egen max_`var'_event=max(`var'_lasttreat)
	drop if max_`var'_event>=`t'-`fmax' & max_`var'_treat==0
	
	*Drop treatment units if they experienced a change in the years prior to the reform
	generate helper=0 
	replace helper=1 if `var'_lasttreat>= `t'-`fmax' & `var'_lasttreat <`t'
	bysort statepairs: egen max_helper=max(helper)
	drop if max_helper==1 
	drop helper max_helper 

	*Drop treatment units if they experienced a reversal of the taxchange in the periods following the tax change
	gen taxreversal = 0 
	sort statepairs year
	by statepairs: replace taxreversal = 1 if max_`var'_treat == 1 &  `var'_lastmag<0 & `var'_lastmag[_n-1]>0 & year>`t'
	by statepairs: replace taxreversal = 1 if max_`var'_treat == 1 &  `var'_lastmag>0 & `var'_lastmag[_n-1]<0 & year>`t'
	by statepairs: egen max_taxreversal=max(taxreversal)
	drop if max_taxreversal==1
	drop max_taxreversal taxreversal
	
	*Indicator for multiple events happening
	//Do we event want the multiple treatment units?
	sort statepairs year
	by statepairs: gen event=1 if `var'_lasttreat!=`var'_lasttreat[_n-1] & `var'_lasttreat!=. & year!=`t'-`fmax'
	by statepairs: egen sum_event=total(event)
	gen `var'_multiple_events=1 if sum_event>1 
	drop event sum_event 
	
	*Generate different indicators for tax increases and decreases 
	gen ry_`var'_incr = 1 if year == max_`var'_event & max_`var'_event==`t' & `var'_incrD==1
		
	gen `var'_event = `t'
	gen `var'_size=`var'_changeV if year==`t'
	bysort statepairs: egen `var'_event_size=max(`var'_size)
		//REPLACE WITH COUNTY-LEVEL INDICATOR ONCE WE HAVE THE DATA
	
	gen `var'_StackID = `t'*1000
	gen `var'_incr_Stack=1
	
	*Generate event indicators	
	egen `var'_cohortstatepairs = group(statepairs `var'_StackID) 

	foreach ind in `indicator' {
		
		sort `var'_cohortstatepairs year
		xtset `var'_cohortstatepairs year
		
		**Making sure only for current treatment
		replace `var'_`ind' = 0 if `var'_treat!=1
		
		**Generate leads and lags
		foreach x in `var'_`ind' {
			forval f = `fmax'(-1)1 {
				gen F`f'_`x' = F`f'.`x'				
				} // Leads
			forval l = 0(1)`lmax' {		
				gen L`l'_`x' = L`l'.`x'
				} // Lags
			}

		**Generate binned endpoints 
		foreach x in `var'_`ind' {
			bysort statepairs (year): gen bin_L`lmax'_`x' = sum(L`lmax'_`x')
			replace L`lmax'_`x' = bin_L`lmax'_`x'
			}
		}
	
			foreach ind in `indicator' {
			foreach x in `var'_`ind' {	
				gsort statepairs  -year
				by statepairs: gen bin_F`fmax'_`x' = sum(F`fmax'_`x')
				replace F`fmax'_`x' = bin_F`fmax'_`x'
			} 
		}
		
	*Save datafile
	tempfile `var'_StackIncr`t'
	save `"``var'_StackIncr`t'''"', replace
	
	di "incr_`t' done"
			
	restore
	}


*Generate cohorts for decreases	
	foreach t in ``var'_coh_decr' {
		
	preserve
	
	*Limit sample to observations within ES window
	keep if year>=`t' -`fmax' & year<=`t'+ `lmax'
	
	*Generate an indicator for being treated in that year
	gen `var'_treat=0
	replace `var'_treat=1 if `var'_lasttreat==`t' & `var'_changeD == -1
	
	*Indicator for being in the treatment group
	sort statepairs year
	by statepairs: egen max_`var'_treat=max(`var'_treat)
	
	*Drop controls with change within already defined time window (treatment +/- t)
	bysort statepairs: egen max_`var'_event=max(`var'_lasttreat)
	drop if max_`var'_event>=`t'-`fmax' & max_`var'_treat==0
	
	*Drop treatment units if they experienced a change in the years prior to the reform
	generate helper=0 
	replace helper=1 if `var'_lasttreat>= `t'-`fmax' & `var'_lasttreat <`t'
	bysort statepairs: egen max_helper=max(helper)
	drop if max_helper==1 
	drop helper max_helper 

	*Drop treatment units if they experienced a reversal of the taxchange in the periods following the tax change
	gen taxreversal = 0 
	sort statepairs year
	by statepairs: replace taxreversal = 1 if max_`var'_treat == 1 &  `var'_lastmag<0 & `var'_lastmag[_n-1]>0 & year>`t'
	by statepairs: replace taxreversal = 1 if max_`var'_treat == 1 &  `var'_lastmag>0 & `var'_lastmag[_n-1]<0 & year>`t'
	by statepairs: egen max_taxreversal=max(taxreversal)
	drop if max_taxreversal==1
	drop max_taxreversal taxreversal
	
	*Indicator for multiple events happening
	//Do we event want the multiple treatment units?
	sort statepairs year
	by statepairs: gen event=1 if `var'_lasttreat!=`var'_lasttreat[_n-1] & `var'_lasttreat!=. & year!=`t'-`fmax'
	by statepairs: egen sum_event=total(event)
	gen `var'_multiple_events=1 if sum_event>1 
	drop event sum_event 
	
	*Generate different indicators for tax increases and decreases 
	gen ry_`var'_decr = 1 if year == max_`var'_event & max_`var'_event==`t' & `var'_decrD==1
	
	gen `var'_event = `t'
	gen `var'_size=`var'_changeV if year==`t'
	bysort statepairs: egen `var'_event_size=max(`var'_size)
		//REPLACE WITH COUNTY-LEVEL INDICATOR ONCE WE HAVE THE DATA
	
	gen `var'_StackID = `t'
	gen `var'_incr_Stack=0
		
	*Generate event indicators	
	egen `var'_cohortstatepairs = group(statepairs `var'_StackID) 
	
	foreach ind in `indicator' {
		
		sort `var'_cohortstatepairs year
		xtset `var'_cohortstatepairs year
			
		**Making sure only for current treatment
		replace `var'_`ind' = 0 if `var'_treat!=1
		
		**Generate leads and lags
		foreach x in `var'_`ind' {
			forval f = `fmax'(-1)1 {
				gen F`f'_`x' = F`f'.`x'				
				} // Leads
			forval l = 0(1)`lmax' {		
				gen L`l'_`x' = L`l'.`x'
				} // Lags
			}

		**Generate binned endpoints 
		foreach x in `var'_`ind' {
			bysort statepairs (year): gen bin_L`lmax'_`x' = sum(L`lmax'_`x')
			replace L`lmax'_`x' = bin_L`lmax'_`x'
			}
		}

		foreach ind in `indicator' {
			foreach x in `var'_`ind' {	
				gsort statepairs  -year
				by statepairs: gen bin_F`fmax'_`x' = sum(F`fmax'_`x')
				replace F`fmax'_`x' = bin_F`fmax'_`x'
			} 
		}
	
	*Save datafile
	tempfile `var'_StackDecr`t'
	save `"``var'_StackDecr`t'''"', replace
	
	di "decr_`t' done"
	
	restore
	}
}
		
	
*Combine all the datasets together 	
	
foreach var in `taxvariables'{
	
	clear 
	tempfile stackdata 
	save `stackdata', emptyok
		
	foreach x in ``var'_coh_incr' { 
		if(`x'>0){		
			append using `"``var'_StackIncr`x'''"'
			save `"`stackdata'"' , replace
		}
	}

	foreach x in ``var'_coh_decr' { 
		if(`x'>0){
			append using `"``var'_StackDecr`x'''"'
			save `"`stackdata'"' , replace
		}
	}	
	
			
	*Add size indicators for increases and decreases	
	**Increases
	forval f = `fmax'(-1)1 {
		gen F`f'_`var'_incrV = F`f'_`var'_changeV if F`f'_`var'_changeV >= 0 | F`f'_`var'_changeV == .
	}
	forval l = 0(1)`lmax' {		
		gen L`l'_`var'_incrV = L`l'_`var'_changeV if L`l'_`var'_changeV >= 0 | L`l'_`var'_changeV == .	
	}
	**Decreases
	forval f = `fmax'(-1)1 {
		gen F`f'_`var'_decrV = F`f'_`var'_changeV if F`f'_`var'_changeV <= 0 | F`f'_`var'_changeV == .
	}
	forval l = 0(1)`lmax' {		
		gen L`l'_`var'_decrV = L`l'_`var'_changeV if L`l'_`var'_changeV <= 0 | L`l'_`var'_changeV == .	
	}
	
	*Make sure to set indicators to missing in case of changes in the other direction
	// Otherwise treated countries could show up in control groups
	forval f = `fmax'(-1)1 {
		replace F`f'_`var'_incrD = . if `var'_event_size < 0 & `var'_event_size != . 
		replace F`f'_`var'_decrD = . if `var'_event_size > 0 & `var'_event_size != .
		replace F`f'_`var'_incrV = . if `var'_event_size < 0 & `var'_event_size != . 
		replace F`f'_`var'_decrV = . if `var'_event_size > 0 & `var'_event_size != .
	}	
	forval l = 0(1)`lmax' {	
		replace L`l'_`var'_incrD = . if `var'_event_size < 0 & `var'_event_size != . 
		replace L`l'_`var'_decrD = . if `var'_event_size > 0 & `var'_event_size != .
		replace L`l'_`var'_incrV = . if `var'_event_size < 0 & `var'_event_size != . 
		replace L`l'_`var'_decrV = . if `var'_event_size > 0 & `var'_event_size != . 
	}
	
save "${basedir}/2_1_Data/data_stacked_state_`var'.dta", replace
// We save separate files for each type of change to limit file size
// (could also create one big file by taking the first and last part out of the bracket)		
}



		


	




