////////////////////////////////////////////////////////////////////////////////
// Project:        	Moving innovation
// Creation Date:  	06/12/2023
// Last Update:    	24/04/2024
// Authors:         Laura Arnemann
//					Theresa Bührle
// Goal: 			Merging the data set using the number of inventors in a state employed by the respective firm as outcome variable 
////////////////////////////////////////////////////////////////////////////////


********************************************************************************
*Reduce file size by assigning numerical IDs
********************************************************************************
/*
use "$PATENTDTA\inventor_applications.dta", clear
compress

egen inventor_id_num = group(inventor_id)
egen assignee_id_num = group(assignee_id)
egen location_id_num = group(location_id)

preserve
	keep inventor_id_num inventor_id 
	duplicates drop
	rename inventor_id inventor_id_string 
	rename inventor_id_num inventor_id
	save "${TEMP}/id_match_inventor.dta", replace 
restore

preserve
	keep assignee_id_num assignee_id
	rename assignee_id assignee_id_string
	rename assignee_id_num assignee_id
	duplicates drop
	save "${TEMP}/id_match_assignee.dta", replace 
restore

preserve
	keep location_id_num location_id
	rename location_id location_id_string
	rename location_id_num location_id
	duplicates drop
	save "${TEMP}/id_match_location.dta", replace 
restore

drop assignee_id
rename assignee_id_num assignee_id
drop inventor_id
rename inventor_id_num inventor_id
drop location_id
rename location_id_num location_id

save "${TEMP}/inventor_applications.dta", replace
*/

********************************************************************************
*File: Patent count at state level
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

* First step: Number of patents the firm records in a county and a state

*-Drop duplicates (we only want to count inventors once per recorded patent)
duplicates tag patnum inventor_id county_fips_inventor assignee_id, gen(dup)
drop if dup!=0
drop dup
* (132 observations deleted)
duplicates report patnum inventor_id assignee_id // differences in geocoding (missings or two different locations recorded); 190 cases
duplicates tag patnum inventor_id assignee_id, gen(dup)
drop if dup!=0 
drop dup

duplicates report patnum inventor_id

save "${TEMP}/patents_helper.dta", replace 

* No more duplicates in terms of patent numbers and inventor identification number
/* 
Every patent now only has one assignee_id
. unique(patnum)
Number of unique values of patnum is  3511455
Number of records is  7779753

. unique(patnum assignee_id)
Number of unique values of patnum assignee_id is  3511455
Number of records is  7779753

unique(patnum state_fips_inventor)
Number of unique values of patnum state_fips_inventor is  4110824
Number of records is  7779753

* Inventors of patents sometimes live in several states. I will assign the patent
to the state in which most inventors live 

*/ 
/* Here  I will try different things: 

1. Only keep patents in which all inventors live in one state 
2. Weight patents according to the number of inventors living in the respective state
3. Only keep patents in the state in which most inventors report to live. 

* For now choose option 3 and drop patents if they cannot be uniquely assigned to 
one state with this method. 
*/


*1 Only keep patents which can be uniquely assigned to one state during a year

    use "${TEMP}/patents_helper.dta", clear 
	bysort patnum state_fips_inventor app_year: gen state_count=_N 
	bysort patnum app_year: gen count=_N
	keep if count==state_count 
	* (1,847,032 observations deleted)
	duplicates tag patnum, gen(dup)
	drop if dup!=0
	* Drop patents which cannot be uniquely assigned 

	collapse (count) patnum, by(state_fips_inventor assignee_id app_year)

	rename patnum patents1 
	label var patents1 "Patent count, using Option 1"
	rename state_fips_inventor fips_state

	tempfile patents1 
	save `patents1'
	
	* Already include zeros in states inbetween activity 
	 bysort fips_state assignee_id: egen max_year = max(app_year)
     bysort fips_state assignee_id: egen min_year = min(app_year)
	 
	 duplicates drop fips_state assignee_id, force 
	 keep fips_state assignee_id min_year max_year 
	 
	 expand 51 
	 bysort assignee_id fips_state: gen count_obs = _n
	 gen app_year = 1969+count_obs
	 
	 keep if inrange(app_year, min_year, max_year)
	 drop count_obs 
	 
	 merge 1:1 fips_state assignee_id app_year using `patents1', keepusing(patents1)
	 replace patents1 = 0 if _merge ==1 
	 drop _merge 
	 * Not merged 2021 
	 
	 save "${TEMP}/patents1.dta", replace 
 
 
 
*2 Weight patents by number of patents recorded in each state
    use "${TEMP}/patents_helper.dta", clear 
	bysort patnum state_fips_inventor app_year: gen state_count=_N 
	bysort patnum app_year: gen count=_N
	gen weight=state_count/count 

	duplicates tag patnum state_fips_inventor, gen(dup)
	drop if dup!=0

	gen patent=1 
	replace patent = weight * patent 
	collapse (sum) patent, by(state_fips_inventor assignee_id app_year)

	rename patent patents2 
	label var patents2 "Patent count, using Option 2"
	rename state_fips_inventor fips_state

	tempfile patents2 
	save `patents2'
	
	* Already include zeros in states inbetween activity 
	 bysort fips_state assignee_id: egen max_year = max(app_year)
     bysort fips_state assignee_id: egen min_year = min(app_year)
	 
	 duplicates drop fips_state assignee_id, force 
	 keep fips_state assignee_id min_year max_year 
	 
	 expand 51 
	 bysort assignee_id fips_state: gen count_obs = _n
	 gen app_year = 1969+count_obs
	 
	 keep if inrange(app_year, min_year, max_year)
	 drop count_obs 
	 
	 merge 1:1 fips_state assignee_id app_year using `patents2', keepusing(patents2)
	 replace patents2 = 0 if _merge ==1 
	 drop _merge 
	 * Not merged 2021 
	 save "${TEMP}/patents2.dta", replace

*3 Keep observation with the highest number of patents in one year  
    use "${TEMP}/patents_helper.dta", clear 
	bysort patnum state_fips_inventor app_year: gen state_count=_N 
	bysort patnum app_year: egen max_state=max(state_count)
	keep if max_state==state_count 
	* (405,003 observations deleted)

	bysort patnum: gen count=_N 
	drop if count!=state_count
	* (483,736 observations deleted)

	duplicates tag patnum, gen(dup)
	drop if dup!=0

	collapse (count) patnum, by(state_fips_inventor assignee_id app_year)
	rename patnum patents3 
	label var patents3 "Patent count, using Option 3"
	rename state_fips_inventor fips_state

	tempfile patents3 
	save `patents3'
	
	* Already include zeros in states inbetween activity 
	 bysort fips_state assignee_id: egen max_year = max(app_year)
     bysort fips_state assignee_id: egen min_year = min(app_year)
	 
	 duplicates drop fips_state assignee_id, force 
	 keep fips_state assignee_id min_year max_year 
	 
	 expand 51 
	 bysort assignee_id fips_state: gen count_obs = _n
	 gen app_year = 1969+count_obs
	 
	 keep if inrange(app_year, min_year, max_year)
	 drop count_obs 
	 
	 merge 1:1 fips_state assignee_id app_year using `patents3', keepusing(patents3)
	 replace patents3 = 0 if _merge ==1 
	 drop _merge 
	 * Not merged 2021 
	 save "${TEMP}/patents3.dta", replace
	
      
merge 1:1 state_fips_inventor assignee_id app_year using "${TEMP}/patents1.dta", keepusing(patents1)
drop _merge 

merge 1:1 state_fips_inventor assignee_id app_year using "${TEMP}/patents2.dta", keepusing(patents2)
drop _merge 

merge 1:1 state_fips_inventor assignee_id app_year using "${TEMP}/patents3.dta", keepusing(patents3)
drop _merge  

save "${TEMP}/patentcount_state.dta", replace 


********************************************************************************
*File: Inventor count at state level
******************************************************************************** 

* Helper data set for the inventors: balanced panel from 1970 - 2020 
*-------------------------------------------------------------------------------

use inventor_id state_fips_inventor assignee_id using "${PATENTDTA}/inventor_applications.dta", clear
duplicates drop state_fips_inventor assignee_id inventor_id, force
drop if state_fips == . 

expand 51 
bysort state_fips_inventor assignee_id inventor_id: gen count_obs = _n
gen app_year = 1969+count_obs
save "${TEMP}/helper.dta", replace 

* Helper data set for the inventors: patent count per firm, location and year 
*-------------------------------------------------------------------------------

use patnum withdrawn app_year ///
	inventor_id  state_fips_inventor county_fips_inventor ///
	assignee_id state_fips_assignee county_fips_assignee  ///
	using "${PATENTDTA}/inventor_applications.dta", clear
	
drop if withdrawn==1 
drop withdrawn

* Drop if missings in important variables
drop if app_year == .
drop if county_fips_inventor == .

* Drop duplicates (we only want to count inventors once per recorded patent)
duplicates tag patnum inventor_id county_fips_inventor assignee_id, gen(dup)
drop if dup!=0 
drop dup	// 132 observations deleted
duplicates report patnum inventor_id assignee_id // differences in geocoding (missings or two different locations recorded); 190 cases
duplicates tag patnum inventor_id assignee_id, force 
drop if dup!=0
drop dup
* Patent count by inventor - assignee - state - year
collapse (count) n_patents=patnum, by(inventor_id assignee_id state_fips_inventor app_year)

* Drop all inventors working in 3 or more firms and working in 3 or more states 
bysort inventor_id app_year: gen count=_N
drop if count>=3 	// 148,111 observations deleted
drop count 

save "${TEMP}/inventor_helper.dta", replace 

* Generate inventor count
*-------------------------------------------------------------------------------

* Generate similar options to above 
*1 Only keep inventors which can be uniquely assigned to one state during a year
    use "${TEMP}/inventor_helper.dta", clear 
	bysort inventor_id app_year: gen count_pats=_N 
	bysort inventor_id app_year state_fips_inventor: gen count_state=_N
	keep if count_state==count_pats
	drop count_state count_pats

	duplicates tag inventor_id state_fips_inventor assignee_id app_year, gen(dup)
	drop if dup!=0
	drop dup

	merge m:1 state_fips_inventor assignee_id inventor_id app_year using "${TEMP}/helper.dta"
	drop if _merge==1 // Observations from year 2021
	bysort state_fips_inventor assignee_id inventor_id: egen max_merge=max(_merge)
	
	*sum n_patents if max_merge!=3	// obs without any patents!
	keep if max_merge==3 // 22,233,705 observations deleted; why does this make such a difference? 
			//-> These relate to obs that have been dropped before (missing info, multi-state inv, ...)
			
	* Keep inventor obs between first and last patent 
	bysort state_fips_inventor assignee_id inventor_id _merge: egen max_helper = max(app_year)
	bysort state_fips_inventor assignee_id inventor_id _merge: egen min_helper = min(app_year)
	replace max_helper = . if _merge==2
	replace min_helper = . if _merge==2

	bysort state_fips_inventor assignee_id inventor_id: egen max_year = max(max_helper)
	bysort state_fips_inventor assignee_id inventor_id: egen min_year = min(min_helper)
	
	gen new_inventor = 1 if app_year==min_year 
	keep if inrange(app_year, min_year, max_year)

* Drop all observations which cannot unqiuely be assigned to a state in a given year
	duplicates tag inventor_id app_year, gen(dup)
	drop if dup>0
	drop dup 

bysort state_fips_inventor assignee_id app_year: gen count=_N
collapse (count) n_inventors1=count n_newinventors1=new_inventor, by(state_fips_inventor assignee_id app_year)

label var n_inventors1 "Number of Inventors, 1"
label var n_newinventors1 "Number of New Inventors, 1"
save "${TEMP}/inventor_1.dta", replace


*2 Weight inventors by number of patents recorded in each state
    use "${TEMP}/inventor_helper.dta", clear
	bysort inventor_id app_year: egen total_patents=total(n_patents)
	gen share_patents= n_patents/total_patents 

	gen inventor= 1 * share_patents 

	collapse (sum) n_inventors2=inventor, by(state_fips_inventor assignee_id app_year)

	label var n_inventors2 "Number of Inventors, 2"
	save "${TEMP}/inventor_2.dta", replace


*3 Keep observation with the highest number of patents in one year  
    use "${TEMP}/inventor_helper.dta", clear
	bysort inventor_id app_year: egen max_patents=max(n_patents)
	keep if max_patents==n_patents 

	* Drop all observations for which inventors could not be uniquely assigned to a firm or state this way 
	bysort inventor_id app_year: gen count=_N 
	drop if count>=2 
	drop count 
	
	duplicates tag inventor_id state_fips_inventor assignee_id app_year, gen(dup)
	drop if dup!=0
	bysort state_fips_inventor assignee_id app_year: gen count=_N

	merge m:1 state_fips_inventor assignee_id inventor_id app_year using "${TEMP}/helper.dta"
	drop if _merge==1	// Observations from year 2021
	bysort state_fips_inventor assignee_id inventor_id: egen max_merge=max(_merge)
	keep if max_merge==3 
	
	* Keep inventor obs between first and last patent 
	bysort state_fips_inventor assignee_id inventor_id _merge: egen max_helper = max(app_year)
	bysort state_fips_inventor assignee_id inventor_id _merge: egen min_helper = min(app_year)
	replace max_helper = . if _merge==2
	replace min_helper = . if _merge==2

	bysort state_fips_inventor assignee_id inventor_id: egen max_year = max(max_helper)
	bysort state_fips_inventor assignee_id inventor_id: egen min_year = min(min_helper)

	keep if inrange(app_year, min_year, max_year)

	drop _merge 
	drop count 
	duplicates tag app_year inventor_id, gen(dup)
	drop if dup>0
	gen new_inventor = 1 if app_year==min_year 
	
bysort state_fips_inventor assignee_id app_year: gen count=_N

	collapse (count) n_inventors3=count n_newinventors3 = new_inventor, by(state_fips_inventor assignee_id app_year)
	label var n_inventors3 "Number of Inventors, 3"
	label var n_newinventors3 "Number of New Inventors, 3"
	save "${TEMP}/inventor_3.dta", replace


merge 1:1 state_fips_inventor assignee_id app_year using "${TEMP}/inventor_1.dta", keepusing(n_inventors1 n_newinventors1)
drop _merge 

merge 1:1 state_fips_inventor assignee_id app_year using "${TEMP}/inventor_2.dta", keepusing(n_inventors2)
drop _merge 


order n_inventors1 n_inventors2 n_inventors3 
*n_inventors3b
rename state_fips_inventor fips_state 
save "${TEMP}/inventorcount_state.dta", replace 

/*
erase "${TEMP}/helper.dta"
erase "${TEMP}/inventor_1.dta"
erase "${TEMP}/inventor_2.dta"
erase "${TEMP}/inventor_3.dta"
erase "${TEMP}/inventor_3b.dta"
erase "${TEMP}/inventor_helper.dta"
*/

********************************************************************************
* Running the dofiles to generate the state data 
********************************************************************************

* This dofile generates all the state-level variables 
*do "${CODE}/cleaning_state.do"
 
********************************************************************************
* Running the dofiles to generate the variables indicating tax changes in other
* locations 
********************************************************************************

* This dofile generates the variables based on all years the establishment is present
do "${CODE}/gen_other_variable.do"
    
********************************************************************************
* Merging things together
********************************************************************************
* Only records active years 

use "${TEMP}/patentcount_state.dta", clear 
merge 1:1 fips_state assignee_id app_year using "${TEMP}/inventorcount_state.dta"
* There might be some times mismatches since we have different methods for allocating patents and inventors, in my opinion this is correct however maybe we also might want to check this later on
drop _merge 

* For each state assignee_id observation, expand the number of states such that they are constant 
merge 1:1 fips_state app_year assignee_id using "${TEMP}/state_data_cleaned.dta"
drop if _merge==2
drop _merge


* Merging in the variables at other locations 
merge 1:1 fips_state app_year assignee_id using "${TEMP}/other_all.dta", keepusing(other*)
drop if _merge==2 

merge 1:1 fips_state app_year assignee_id using "${TEMP}/other_threelargest.dta", keepusing(other*)
drop if _merge==2 

merge 1:1 fips_state app_year assignee_id using "${TEMP}/other_first.dta", keepusing(other*)
drop if _merge==2 



/* For the inventors there are a lot of non-matches. This is plausible since there might be new inventors? 
    Result                      Number of obs
    -----------------------------------------
    Not matched                       443,686
        from master                    46,136  (_merge==1)
        from using                    397,550  (_merge==2)

    Matched                         1,272,113  (_merge==3)
    -----------------------------------------
	
*After adding drop if _merge == 2 on previous match:
    Result                      Number of obs
    -----------------------------------------
    Not matched                       767,205
        from master                    43,631  (_merge==1)
        from using                    723,574  (_merge==2)

    Matched                           946,077  (_merge==3)
    -----------------------------------------	
*/

* Actually quite a lot of observations that were not merged

bysort assignee_id app_year: gen nstates=_N 

gen multistatefirm_temp=0 
replace multistatefirm_temp=1 if nstates>1
bysort assignee_id: egen multistatefirm_max = max(multistatefirm_temp)

drop count *_helper* total_inventors* total_inventors_other* 

rename app_year year 
* What should we do with New York, Ohio, Louisiana? 

duplicates drop assignee_id fips_state year, force // sanity check; shouldn't drop anything
compress
save "${TEMP}/final_state_zeros_new.dta", replace 


********************************************************************************
* Variables at other locations
********************************************************************************
/*
* Without weights (total) ------------------------------------------------------

/*
* Generate alternative variable for RD other 
bysort assignee_id app_year: egen total_inventors=total(n_inventors3)
gen total_inventors_other=total_inventors-n_inventors3 

gen rd_weight=n_inventors3*rd_credit 
bysort assignee_id app_year: egen rd_weight_total=total(rd_weight)
gen rd_credit_other_alternative = (rd_weight_total - rd_weight)/total_inventors_other 
*/ 

foreach var of varlist rd_credit pit cit gdp unemployment {
bysort assignee_id app_year: egen total_`var'=total(`var')
	replace total_`var'=(total_`var' -`var')/(nstates-1)
	replace total_`var'=0 if total_`var'<0
}
* For some reason stata does really weird things with the RD Credit

*Only at first location
bysort assignee_id: egen firstyear =min(app_year)
gen firstlocation = 1 if firstyear == app_year
bysort assignee_id fips_state: egen firstlocation_max = max(firstlocation)

bysort assignee_id year: egen nstates_first= count(firstlocation) 
	// Reduce denominator if initial states are not observed anymore later
	
	*IMPORTANT!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
	*We need to extend dataset to unobseerved years to add variables on pit etc. to solve this (balanced panel)
	*!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
	
	/*
	*How big is the problem of firms expanding across many states over time?
	gen diff_first_yearly_n = nstates - nstates_first
	sum diff_first_yearly_n, d
	
		/*								 diff_first_yearly_n
		-------------------------------------------------------------
			  Percentiles      Smallest
		 1%            0              0
		 5%            0              0
		10%            0              0       Obs           1,669,651
		25%            0              0       Sum of wgt.   1,669,651

		50%            0                      Mean           4.119237
								Largest       Std. dev.      7.817846
		75%            4             50
		90%           15             50       Variance       61.11871
		95%           23             50       Skewness       2.517254
		99%           35             50       Kurtosis       9.336707
		*/
	*/

drop firstlocation

foreach var of varlist rd_credit pit cit gdp unemployment {
	
gen `var'_first = `var' if firstlocation_max == 1	// only consider firstlocation states
bysort assignee_id app_year: egen total_`var'_first=total(`var'_first)
	replace total_`var'_first=(total_`var'_first -`var'_first)/(nstates_first-1)
	replace total_`var'_first=0 if total_`var'_first<0
}

* Min 10% of overall patenting across all years
bysort assignee_id fips_state: egen patentsum_state = sum(patents3)
bysort assignee_id: egen patentsum_assign = sum(patents3)
gen patenterloc10 = 1 if patentsum_state / patentsum_assign >= 0.1


bysort assignee_id fips_state: egen firstyear_10pat =min(app_year)
	replace firstyear_10pat = . if  patenterloc10 != 1 
bysort assignee_id year: egen nstates_10pat= count(patenterloc10_counter) 
	replace nstates_10pat = nstates if nstates_10pat > nstates
* This is a bit weird? 
	
bysort assignee_id year: egen nstates_10pat= count(patenterloc10) 

foreach var of varlist rd_credit pit cit gdp unemployment {
	
gen `var'_10pat = `var' if patenterloc10 == 1	// only consider states with at least 10% patenting
bysort assignee_id app_year: egen total_`var'_10pat=total(`var'_10pat)
	replace total_`var'_10pat=(total_`var'_10pat -`var'_10pat)/(nstates_10pat-1)
	replace total_`var'_10pat=0 if total_`var'_10pat<0
}

* 3 biggest locations across all years 
// Ideally by employee count, we go by inventors for now
bysort assignee_id fips_state: egen n_inventors3_statemean = mean(-n_inventors3)
sort assignee_id n_inventors3_statemean 

bysort assignee_id (n_inventors3_statemean): gen rank = n_inventors3_statemean != n_inventors3_statemean[_n-1]
by assignee_id: replace rank = sum(rank)
replace rank = . if n_inventors3_statemean == .

bysort assignee_id fips_state: egen firstyear_rank =min(app_year)
	replace firstyear_rank = . if  rank > 3 
gen rank_counter = 1 if app_year == firstyear_rank
drop firstyear_rank
bysort assignee_id: egen nstates_rank= count(rank_counter) 
	replace nstates_rank = nstates if nstates_rank > nstates

foreach var of varlist rd_credit pit cit gdp unemployment {
	
gen `var'_rank = `var' if rank <= 3	// only consider top 3 states
bysort assignee_id app_year: egen total_`var'_rank=total(`var'_rank)
	replace total_`var'_rank=(total_`var'_rank -`var'_rank)/(nstates_rank-1)
	replace total_`var'_rank=0 if total_`var'_rank<0
}
*/

* Weighted (other) -------------------------------------------------------------
/*
* Weighted variables in other states

* - Weighted by inventors in other states (even if non-patenting!)
	replace n_inventors3=0 if missing(n_inventors3)
		*Inventor count per year per firm across all locations:
	bysort assignee_id app_year: egen total_inventors=total(n_inventors3)	
		*Inventor count per year per firm at all other locations:
	gen total_inventors_other = total_inventors-n_inventors3
		*Weighting:
	foreach var of varlist rd_credit pit cit gdp unemployment state_rd_exp {
		gen `var'_helper = n_inventors3 * `var'
		bysort assignee_id app_year: egen `var'_other=total(`var'_helper)
			replace `var'_other =  `var'_other - `var'_helper
			replace `var'_other = `var'_other/total_inventors_other 
	}
	
	replace n_inventors3b=0 if missing(n_inventors3b)
		*Inventor count per year per firm across all locations:
	*bysort assignee_id app_year: egen total_inventorsb=total(n_inventors3b)	
		*Inventor count per year per firm at all other locations:
	gen total_inventors_otherb = total_inventorsb-n_inventors3b
		*Weighting:
	foreach var of varlist rd_credit pit cit gdp unemployment state_rd_exp {
		gen `var'_helperb = n_inventors3b * `var'
		bysort assignee_id app_year: egen `var'_other_b=total(`var'_helperb)
			replace `var'_other_b =  `var'_other_b - `var'_helperb
			replace `var'_other_b = `var'_other/total_inventors_otherb 
	}

* - Weighted by lagged number of inventors in other states 

	forvalues lag = 1/1 {
		
		foreach var of varlist n_inventors3 total_inventors_other {
		gen `var'_l`lag' = .
		
		sort assignee_id fips_state app_year
			by assignee_id fips_state: replace `var'_l`lag' = `var'[_n-`lag'] ///
				if assignee_id == assignee_id[_n-`lag'] & fips_state == fips_state[_n-`lag'] ///
				& app_year == app_year[_n-`lag'] + `lag'
		}
		
		foreach var of varlist rd_credit pit cit gdp unemployment state_rd_exp {
			gen `var'_l`lag'_helper = n_inventors3_l`lag' * `var'
			bysort assignee_id app_year: egen `var'_l`lag'_other=total(`var'_l`lag'_helper)
				replace `var'_l`lag'_other =  `var'_l`lag'_other - `var'_l`lag'_helper
				replace `var'_l`lag'_other = `var'_l`lag'_other/total_inventors_other_l`lag' 
		}	
	}

	forvalues lag = 1/4 {
		
		foreach var of varlist n_inventors3b total_inventors_otherb {
		gen `var'_l`lag' = .
		
		sort assignee_id fips_state app_year
			by assignee_id fips_state: replace `var'_l`lag' = `var'[_n-`lag'] ///
				if assignee_id == assignee_id[_n-`lag'] & fips_state == fips_state[_n-`lag'] ///
				& app_year == app_year[_n-`lag'] + `lag'
		}
		
		foreach var of varlist rd_credit pit cit gdp unemployment state_rd_exp {
			gen `var'_l`lag'_helperb = n_inventors3b_l`lag' * `var'
			bysort assignee_id app_year: egen `var'_l`lag'_other_b=total(`var'_l`lag'_helperb)
				replace `var'_l`lag'_other_b =  `var'_l`lag'_other_b - `var'_l`lag'_helperb
				replace `var'_l`lag'_other_b = `var'_l`lag'_other_b/total_inventors_otherb_l`lag' 
		}	
	}



* Var labels
label var rd_credit_other "Average RD credit at other Labs"
label var pit_other "Average PIT at other labs"
label var cit_other "Average CIT at other labs"
label var unemployment_other "Unemployment Rate at other labs"
label var state_rd_exp_other "State gov R&D expenditure at other labs"
*/








/*
* Cleaning the Crosswalk from the Dyevre Paper 


forvalues i=1/8 {
import delimited "${IN}/crosswalk/staticTranche`i'.csv", clear 
tempfile static`i'
save `static`i''
}

clear

forvalues i =1/8 {
	append using `static`i''
}


drop if missing(gvkeyuo)
* (457,383 observations deleted)
duplicates drop patent_id gvkeyuo, force 
*(28 observations deleted)
* Usually these duplicates arise between patents were assigned to different entitities (allegedly after they merged) 
rename gvkeyuo gvkey

bysort patent_id: gen count=_n

keep patent_id appyear gvkey count

reshape wide gvkey*, i(patent_id) j(count)

rename patent_id patnum 
rename gvkey1 gvkeyuo 

destring patnum, replace force 
drop if missing(patnum)
*(137038 missing values generated), most of them start with a letter. Don't really know what to do with that. 

/*
I used this code to check the match between the Dorn linking table and the dyevre linking table, there was a discrepancy between the dorn gvkey and the dyevre gvkey for 10% of the patents filed. I manually checked some of the patents which had multiple gvkey myself, usually the dyevre provided the better match. In some instances an M&A was not reported in other instances the match was wrong. Would be interesting to see if results change if we change the assignment
gen patent=patent_id 
tostring patent, replace 
replace  patent = "0" + patent 
merge m:1 patent using "${IN}/crosswalk/cw_patent_compustat_adhps.dta"

keep if _merge==3 
drop _merge 

destring gvkey, replace 
gen tag=1 if gvkey==gvkeyuo

bysort patent_id: egen max_tag=max(tag)
gen indicator=1 if missing(tag)

bysort patent_id: egen max_indicator=max(indicator)

* When checking some of the patents the dyevre database provides a better fit than the Dorn database 
*/

save "${IN}/crosswalk/static_match.dta", replace 
*/
* Overall 3051406 different patents



/*	
******************************************************************************
* Match the Patent Data with the linking tables from Dyevre and Dorn; 
******************************************************************************
gen patent=patnum 
tostring patent, replace 
replace  patent = "0" + patent 
merge m:1 patent using "${IN}/crosswalk/cw_patent_compustat_adhps.dta"
drop if _merge==2 
drop _merge 
rename gvkey gvkey_dorn 
destring gvkey, replace 



    Result                      Number of obs
    -----------------------------------------
    Not matched                     7,271,714
        from master                 6,594,319  (_merge==1)
        from using                    677,395  (_merge==2)

    Matched                         3,342,362  (_merge==3)
    -----------------------------------------



merge m:1 patnum using "${IN}/crosswalk/static_match.dta"
drop if _merge==2
drop _merge 

/*
    Result                      Number of obs
    -----------------------------------------
    Not matched                     6,322,092
        from master                 5,172,336  (_merge==1)
        from using                  1,149,756  (_merge==2)

    Matched                         4,764,345  (_merge==3)
    -----------------------------------------
*/ 
* 3341403 patents have the same gvkey in both datasets 
* Not all variables are matched for some reason 

/* Amount of variation in the data set*/ 

*unique(assignee_id appyear): 335268
*unique(assignee_id appyear state_fips_assignee): 388358
*unique(assignee_id appyear state_fips_assignee state_fips_inventor): 720222

* I think for now it might be better to continue with the USPTO sample.
However, at one point in time we might decide to do this with the other merge.
Just to get an understanding of the differences in the data sets: In the USPTO data set, 
patents are assigned for example to AMVAC Chemical Corporation, while in the Dyevre data set 
they are assigned to American Vanguard Corporation. American Vanguard Corporation is a daughter 
of Amvac Chemical corporation

*/


