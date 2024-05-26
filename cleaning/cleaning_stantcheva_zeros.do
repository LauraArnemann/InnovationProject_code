////////////////////////////////////////////////////////////////////////////////
// Project:        	Moving innovation
// Creation Date:  	06/12/2023
// Last Update:    	24/04/2024
// Authors:         Laura Arnemann
//					Theresa Bührle
// Goal: 			Merging the data set using the number of inventors in a state employed by the respective firm as outcome variable 
////////////////////////////////////////////////////////////////////////////////

/* 
There are a couple of differences in the way Stefanie Stantcheva cleaned her dataset and we did. 
1. We drop all observations where the county is missing. We should overthink this in general because we loose around 1 million observations due to this decision. I will clean this up in the dofile filling counties. 

2. Stantcheva assigns inventors uniquely to one state. However while we only assign the patents which were filed in this state to the inventor, she assigns all patents to the respetive state. So if an inventor records two patents in Wyoming and one in Kansas, she will assign three patents to Wyoming. I do believe this is wrong, but I will try this out as an additional variation. 

3. If an inventor is observed in two states the same number of times she assigns him or her to the state in which he was observed first 
*/
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


/* Here  I will try different things: 

1. Only keep patents in which all inventors live in one state 
2. Weight patents according to the number of inventors living in the respective state
3. Only keep patents in the state in which most inventors report to live. 

* For now choose option 3 and drop patents if they cannot be uniquely assigned to 
one state with this method. 
*/

do "${code}/filing_counties.do"

use "${TEMP}/inventor_helper_v3.dta", clear 

duplicates report patnum inventor_id
drop if missing(assignee_id)

bysort inventor_id: gen pat_count = _N 
bysort patnum: gen inventor_count = _N 

gen weight = 1/inventor_count

bysort inventor_id app_year: egen pat_count_weighted = total(weight)
bysort inventor_id state_fips_inventor app_year: gen state_count = _N 
bysort inventor_id assignee_id app_year: gen assignee_count =_N 

bysort inventor_id app_year : egen max_assignee_count = max(assignee_count)
bysort inventor_id app_year : egen max_state_count = max(state_count)


gen filing_month = month(date_filing)
bysort inventor_id app_year assignee_id: egen min_month_assignee = min(filing_month)
bysort inventor_id app_year state_fips_inventor: egen min_month_state = min(filing_month)

bysort inventor_id app_year: egen min_month1 = min(min_month_assignee)
bysort inventor_id app_year: egen min_month2 = min(min_month_state)

keep if assignee_count == max_assignee_count | max_state_count == state_count
keep if min_month1 == min_month_assignee | min_month2==min_month_state

collapse (first) pat_count pat_count_weighted min_month_state min_month_assignee, by(assignee_id state_fips_inventor inventor_id app_year)

/* 
 duplicates report inventor_id app_year
 
 
--------------------------------------
   Copies | Observations       Surplus
----------+---------------------------
        1 |      4380007             0
        2 |       469520        234760
        3 |        63141         42094
        4 |        11948          8961
        5 |         3350          2680
        6 |         1380          1150
        7 |          532           456
        8 |          312           273
        9 |           90            80
       10 |           70            63
       11 |           22            20
       13 |           26            24
       22 |           22            21
--------------------------------------
 */ 
 
* For now just going to drop all the duplicates 
duplicates tag inventor_id app_year, gen(dup)
keep if dup == 0 
drop dup 

tempfile helper 
save `helper'

* Collapsing patents on state and assignee level 

collapse (total) pat_count_weighted, by(assignee_id state_fips_inventor app_year)

tempfile patents1 
save `patents1'

* Include zeros in states inbetween activity 
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
	 replace pat_count_weighted = 0 if _merge ==1 
	 drop _merge 
	 
save "${TEMP}/patents_stantcheva.dta", replace 


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


* Generate inventor count
*-------------------------------------------------------------------------------

use `helper'

merge m:1 state_fips_inventor assignee_id inventor_id app_year using "${TEMP}/helper.dta"
 drop if _merge==1 // Observations from year 2021
 bysort state_fips_inventor assignee_id inventor_id: egen max_merge=max(_merge)
 keep if max_merge==3

* Keep inventor obs between first and last patent 
bysort state_fips_inventor assignee_id inventor_id _merge: egen max_helper = max(app_year)
bysort state_fips_inventor assignee_id inventor_id _merge: egen min_helper = min(app_year) 

replace max_helper = . if _merge==2
replace min_helper = . if _merge==2
bysort state_fips_inventor assignee_id inventor_id: egen max_year = max(max_helper)
bysort state_fips_inventor assignee_id inventor_id: egen min_year = min(min_helper)
	
gen new_inventor = 1 if app_year==min_year 
keep if inrange(app_year, min_year, max_year)
replace pat_count_weighted = 0 if missing(pat_count_weighted)
replace pat_count = 0 if missing(pat_count)


collapse (count) n_inventors1 = inventor_id n_newinventors1=new_inventor (total) pat_count_weighted pat_count, by(assignee_id state_fips_inventor app_year)

label var n_inventors1 "Number of Inventors, 1"
label var n_newinventors1 "Number of New Inventors, 1"
save "${TEMP}/inventors_stantcheva.dta", replace


erase "${TEMP}/helper.dta"
erase "${TEMP}/inventor_1.dta"
erase "${TEMP}/inventor_2.dta"
erase "${TEMP}/inventor_3.dta"
erase "${TEMP}/inventor_3b.dta"
erase "${TEMP}/inventor_helper.dta"


********************************************************************************
* Running the dofiles to generate the state data 
********************************************************************************

* This dofile generates all the state-level variables 
do "${CODE}/cleaning_state.do"
 
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

use "${TEMP}/patents_stantcheva.dta", clear 
merge 1:1 fips_state assignee_id app_year using "${TEMP}/inventors_stantcheva.dta"
* There might be some times mismatches since we have different methods for allocating patents and inventors, in my opinion this is correct however maybe we also might want to check this later on
drop _merge 

* For each state assignee_id observation, expand the number of states such that they are constant 
merge m:1 fips_state app_year using "${TEMP}/state_data_cleaned.dta", keepusing(rd_credit gdp cit pit unemployment)
drop if _merge!=3
drop _merge

rename app_year year 

foreach num of numlist 3 {
* Merging in the variables at other locations

merge 1:1 fips_state year assignee_id using "${TEMP}/other_all_`num'.dta", keepusing(other*)
drop if _merge==2
drop _merge  

foreach var of varlist rd_credit cit gdp unemployment pit {
	rename other_`var'_all other_`var'_all`num' 
	rename other_`var'_weighted other_`var'_weighted`num'
}


merge 1:1 fips_state year assignee_id using "${TEMP}/other_threelargest_`num'.dta", keepusing(other*)
drop if _merge==2 
drop _merge 

foreach var of varlist rd_credit cit gdp unemployment pit {
	rename other_`var'_threelargest other_`var'_threelargest`num' 
}
 
merge 1:1 fips_state year assignee_id using "${TEMP}/other_first`num'.dta", keepusing(other*)
drop if _merge==2 
drop _merge 

foreach var of varlist rd_credit cit gdp unemployment pit {
	rename other_`var'_first other_`var'_first`num'
}

}


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

bysort assignee_id year: gen nstates=_N 

gen multistatefirm_temp=0 
replace multistatefirm_temp=1 if nstates>1
bysort assignee_id: egen multistatefirm_max = max(multistatefirm_temp)
 

* What should we do with New York, Ohio, Louisiana? 

duplicates report assignee_id fips_state year // Sanity Check
compress
save "${TEMP}/final_state_zeros_stantcheva.dta", replace 


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


