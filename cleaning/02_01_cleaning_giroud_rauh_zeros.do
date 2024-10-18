////////////////////////////////////////////////////////////////////////////////
// Project:        	Moving innovation
// Creation Date:  	06/12/2023
// Last Update:    	17/10/2024
// Authors:         Laura Arnemann
//					Theresa Bührle
// Goal: 			Generating innovative activity per firm-establishment-year at state level
////////////////////////////////////////////////////////////////////////////////


********************************************************************************
*File: Patent count at state level
********************************************************************************

*Prepare data	----------------------------------------------------------------

use "${TEMP}/patentdata.dta", clear 

if $gvkey == 1 {
    drop assignee_id 
	rename gvkey assignee_id
}

*-Drop if missings in important variables
drop if missing(patnum)	// I guess missings are applications that didn't get granted?
drop if missing(app_year)
drop if missing(assignee_id)
drop if missing(state_fips_inventor)
drop if missing(county_fips_inventor)

* First step: Number of patents the firm records in a county and a state

*-Drop duplicates (we only want to count inventors once per recorded patent)
duplicates drop patnum inventor_id county_fips_inventor assignee_id, force

duplicates report patnum inventor_id assignee_id // differences in geocoding (missings or two different locations recorded)
duplicates tag patnum inventor_id assignee_id, gen(dup)
drop if dup!=0 	// 322  obs
drop dup

duplicates report patnum inventor_id // Check, should be zero 

* Creating an indicator for assignee type 
   do "${CODE}/cleaning/sub_clean_gov_uni_entitites.do"
   gen pub_assg = 0 
   replace pub_assg=1 if !missing(gvkey)

   gen noncorp_asg = 0 
   replace noncorp_asg =1 if asg_hospital ==1 | asg_institute==1 | asg_gov==1 

compress
save "${TEMP}/patentdata_clean.dta", replace 

*Patent count ------------------------------------------------------------------

*1 Only keep patents which can be uniquely assigned to one state during a year
*	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x

use "${TEMP}/patentdata_clean.dta", clear 

bysort patnum state_fips_inventor app_year: gen state_count=_N 
bysort patnum app_year: gen count=_N
keep if count==state_count 	//1,847,032 observations deleted
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
drop _merge // Not merged 2021 

compress	 
save "${TEMP}/patents1.dta", replace 
 
 
*2 Weight patents by number of patents recorded in each state
*	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x

use "${TEMP}/patentdata_clean.dta", clear 

bysort patnum state_fips_inventor app_year: gen state_count=_N 
bysort patnum app_year: gen count=_N
gen weight=state_count/count 

duplicates tag patnum state_fips_inventor, gen(dup)
drop if dup!=0
drop dup

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
drop _merge // Not merged 2021 

compress
save "${TEMP}/patents2.dta", replace


*3 Keep observation with the highest number of patents in one year  
*	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x

use "${TEMP}/patentdata_clean.dta", clear 

bysort patnum state_fips_inventor app_year: gen state_count=_N 
bysort patnum app_year: egen max_state=max(state_count)
keep if max_state==state_count 

bysort patnum: gen count=_N 
drop if count!=state_count

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
drop _merge  // Not merged 2021 

compress
save "${TEMP}/patents3.dta", replace
	   
*Merge everything
*	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x
	   
merge 1:1 fips_state assignee_id app_year using "${TEMP}/patents1.dta", keepusing(patents1)
drop _merge 

merge 1:1 fips_state assignee_id app_year using "${TEMP}/patents2.dta", keepusing(patents2)
drop _merge 

compress
save "${TEMP}/patentcount_state_assignee.dta", replace 

* We still need these datasets for generating the other variables, erase after that 
*erase "${TEMP}/patents1.dta"
*erase "${TEMP}/patents2.dta"
*erase "${TEMP}/patents3.dta"
erase "${TEMP}/patentdata_clean.dta"

********************************************************************************
*File: Inventor count at state level
******************************************************************************** 

*Prepare data	----------------------------------------------------------------

* Helper data set for the inventors: balanced panel from 1970 - 2020 
use "${TEMP}/patentdata.dta", clear 

if $gvkey == 1 {
    drop assignee_id 
	rename gvkey assignee_id
}

drop if missing(assignee_id)
drop if missing(state_fips_inventor)

duplicates drop state_fips_inventor assignee_id inventor_id, force
keep state_fips_inventor assignee_id inventor_id
drop if state_fips_inventor == . 

expand 51 
bysort state_fips_inventor assignee_id inventor_id: gen count_obs = _n
gen app_year = 1969+count_obs

compress
save "${TEMP}/helper_inventor.dta", replace 

* Helper data set for the inventors: patent count per firm, location and year 
use "${TEMP}/patentdata.dta", clear 

if $gvkey == 1 {
    drop assignee_id 
	rename gvkey assignee_id
}

* Drop if missings in important variables
drop if missing(patnum)
drop if missing(app_year)
drop if missing(assignee_id)
drop if missing(state_fips_inventor)
drop if missing(county_fips_inventor)

* Drop duplicates (we only want to count inventors once per recorded patent)
duplicates drop patnum inventor_id county_fips_inventor assignee_id, force
	// 523 observations deleted
duplicates report patnum inventor_id assignee_id // differences in geocoding (missings or two different locations recorded); 190 cases

* Drop all patents for which two locations were reported
duplicates tag patnum inventor_id assignee_id, gen(dup) 
drop if dup!=0
drop dup

* Patent count by inventor - assignee - state - year
collapse (count) n_patents=patnum, by(inventor_id assignee_id state_fips_inventor app_year)

* Drop all inventors working in 3 or more firms and working in 3 or more states 
bysort inventor_id app_year: gen count=_N
drop if count>=3 	// 125,029 observations deleted
drop count 

compress
save "${TEMP}/inventordata_clean.dta", replace 

*Inventor count	 ---------------------------------------------------------------
// Generate similar options to above 

*1 Only keep inventors which can be uniquely assigned to one state during a year
*	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x

use "${TEMP}/inventordata_clean.dta", clear 

bysort inventor_id app_year: gen count_pats=_N 
bysort inventor_id app_year state_fips_inventor: gen count_state=_N
keep if count_state==count_pats
drop count_state count_pats

duplicates tag inventor_id state_fips_inventor assignee_id app_year, gen(dup)
drop if dup!=0
drop dup

merge m:1 state_fips_inventor assignee_id inventor_id app_year using "${TEMP}/helper_inventor.dta"
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

compress
save "${TEMP}/inventor1.dta", replace


*2 Weight inventors by number of patents recorded in each state
*	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x

use "${TEMP}/inventordata_clean.dta", clear

bysort inventor_id app_year: egen total_patents=total(n_patents)
gen share_patents= n_patents/total_patents 

gen inventor= 1 * share_patents 

collapse (sum) n_inventors2=inventor, by(state_fips_inventor assignee_id app_year)

label var n_inventors2 "Number of Inventors, 2"

compress
save "${TEMP}/inventor2.dta", replace


*3 Keep observation with the highest number of patents in one year
*	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x
  
use "${TEMP}/inventordata_clean.dta", clear

bysort inventor_id app_year: egen max_patents=max(n_patents)
keep if max_patents==n_patents 

* Drop all observations for which inventors could not be uniquely assigned to a firm or state this way 
bysort inventor_id app_year: gen count=_N 
drop if count>=2 
drop count 
	
duplicates tag inventor_id state_fips_inventor assignee_id app_year, gen(dup)
drop if dup!=0
drop dup
bysort state_fips_inventor assignee_id app_year: gen count=_N

merge m:1 state_fips_inventor assignee_id inventor_id app_year using "${TEMP}/helper_inventor.dta"
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
drop dup
	
* Generate an indicator when an inventor is observed for the first time
gen new_inventor = 1 if app_year==min_year 
	
bysort assignee_id inventor_id: egen assignee_firstmax = min(max_year)
bysort assignee_id inventor_id: egen assignee_lastmax = max(max_year)
gen relocating_inventor = 1 if max_year < assignee_lastmax 
replace relocating_inventor = . if app_year != max_year 
	
gen lasttime_inventor = 1 if app_year == max_year 
	
bysort state_fips_inventor assignee_id app_year: gen count=_N

collapse (count) n_inventors3=count n_newinventors3 = new_inventor n_relocatinginventors = relocating_inventor n_lasttimeinventor = lasttime_inventor , by(state_fips_inventor assignee_id app_year)

label var n_inventors3 "Number of Inventors, 3"
label var n_newinventors3 "Number of New Inventors, 3"
label var n_relocatinginventors "Number of relocating inventors "
label var n_lasttimeinventor "Number of lasttime Inventors"

compress
save "${TEMP}/inventor3.dta", replace

*Merge everything
*	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x

merge 1:1 state_fips_inventor assignee_id app_year using "${TEMP}/inventor1.dta", keepusing(n_inventors1 n_newinventors1)
drop _merge 

merge 1:1 state_fips_inventor assignee_id app_year using "${TEMP}/inventor2.dta", keepusing(n_inventors2)
drop _merge 

order n_inventors1 n_inventors2 n_inventors3 

rename state_fips_inventor fips_state 
save "${TEMP}/inventorcount_state_assignee.dta", replace 

erase "${TEMP}/helper_inventor.dta"
erase "${TEMP}/inventor1.dta"
erase "${TEMP}/inventor2.dta"
erase "${TEMP}/inventor3.dta"
erase "${TEMP}/inventordata_clean.dta"
		
********************************************************************************
* Generate the variables indicating tax changes in other locations 
********************************************************************************

* This dofile generates the variables based on all years the establishment is present
do "${CODE}/cleaning/sub_gen_other_var.do"
    
erase "${TEMP}/patents1.dta"
erase "${TEMP}/patents2.dta"
erase "${TEMP}/patents3.dta"    
	
	
********************************************************************************
* Merging things together
********************************************************************************
* Only records active years 

use "${TEMP}/patentcount_state_assignee.dta", clear 
merge 1:1 fips_state assignee_id app_year using "${TEMP}/inventorcount_state_assignee.dta"
// There might be some times mismatches since we have different methods for allocating patents and inventors, 
// in my opinion this is correct however maybe we also might want to check this later on
drop _merge 

* For each state assignee_id observation, expand the number of states such that they are constant 
merge m:1 fips_state app_year using "${TEMP}/state_data_cleaned.dta", keepusing(rd_credit gdp cit pit unemployment)
drop if _merge!=3
drop _merge

rename app_year year 

* Merging in the variables at other locations
foreach num of numlist $patentvar {

	if $gvkey == 0 {
		merge 1:1 fips_state year assignee_id using "${TEMP}/other_all`num'.dta", keepusing(other*)
}
	if $gvkey == 1 {
		merge 1:1 fips_state year assignee_id using "${TEMP}/other_all`num'_gvkey.dta", keepusing(other*)
}
	drop if _merge==2
	drop _merge  

	foreach var of varlist rd_credit cit gdp unemployment pit {
		rename other_`var'_all other_`var'_all`num' 
		rename other_`var'_weighted other_`var'_weighted`num'
	}

	if $gvkey == 0 {
		merge 1:1 fips_state year assignee_id using "${TEMP}/other_threelargest`num'.dta", keepusing(other*)
}
	if $gvkey == 1 {
		merge 1:1 fips_state year assignee_id using "${TEMP}/other_threelargest`num'_gvkey.dta", keepusing(other*)
}
	drop if _merge==2 
	drop _merge 

	foreach var of varlist rd_credit cit gdp unemployment pit {
		rename other_`var'_threelargest other_`var'_threelargest`num' 
	}
	 
	if $gvkey == 0 {
		merge 1:1 fips_state year assignee_id using "${TEMP}/other_first`num'.dta", keepusing(other*)
}
	if $gvkey == 1 {
		merge 1:1 fips_state year assignee_id using "${TEMP}/other_first`num'_gvkey.dta", keepusing(other*)
} 
	drop if _merge==2 
	drop _merge 

	foreach var of varlist rd_credit cit gdp unemployment pit {
		rename other_`var'_first other_`var'_first`num'
	}
}

bysort assignee_id year: gen nstates=_N 

gen multistatefirm_temp=0 
replace multistatefirm_temp=1 if nstates>1
bysort assignee_id: egen multistatefirm_max = max(multistatefirm_temp)
 
// What should we do with New York, Ohio, Louisiana? 

duplicates report assignee_id fips_state year // Sanity Check
compress

if $gvkey == 0 {
    save "${TEMP}/final_state_zeros_assignee.dta", replace 
}

if $gvkey == 1 {
    save "${TEMP}/final_state_zeros_assignee_gvkey.dta", replace 
}

erase "${TEMP}/patentcount_state_assignee.dta"
erase "${TEMP}/inventorcount_state_assignee.dta"