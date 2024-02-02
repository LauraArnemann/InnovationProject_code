// Project: Inventor Relocation
// Creation Date: 06/12/2023
// Last Update: 06/12/2023
// Author: Laura Arnemann 
// Goal: Merging the data set using the number of inventors in a state employed by the respective firm as outcome variable 


********************************************************************************
* Merging the dataset 
********************************************************************************
* Merging the RD Credits

import excel "${IN}/indep_var/var_RDcredits/RD_credits_final.xlsx", sheet("rd_summary") firstrow clear 
drop if missing(fips_state)

rename DT1lowesttier rd_credit 
keep fips_state year rd_credit 

save "${IN}/indep_var/var_RDcredits/RD_credits_final.dta", replace 



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

use patnum citation_count withdrawn date_filing date_grant app_year ///
	inventor_id first_name last_name male location_id state_fips_inventor county_fips_inventor ///
	assignee_id state_fips_assignee county_fips_assignee  ///
	using "$PATENTDTA\inventor_applications.dta", clear

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

********************************************************************************
* Similar cleaning steps as in Theresas data set 
********************************************************************************

	
drop if withdrawn==1 
drop withdrawn

*-Drop if missings in important variables
drop if app_year == .
drop if county_fips_inventor == .

* First step: Number of patents the firm records in a county and a state

*-Drop duplicates (we only want to count inventors once per recorded patent)
duplicates drop patnum inventor_id county_fips_inventor assignee_id, force 
* (132 observations deleted)
duplicates report patnum inventor_id assignee_id // differences in geocoding (missings or two different locations recorded); 190 cases
duplicates drop patnum inventor_id assignee_id, force 

duplicates report patnum inventor_id

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

preserve 
* Option 1: 
bysort patnum state_fips_inventor app_year: gen state_count=_N 
bysort patnum app_year: gen count=_N
keep if count==state_count 
* (1,847,032 observations deleted)
duplicates drop patnum, force 

collapse (count) patnum, by(state_fips_inventor assignee_id app_year)

rename patnum patents1 
label var patents1 "Patent count, using Option 1"

tempfile patents1 
save `patents1'

restore
 
* Option 2: 
preserve 
bysort patnum state_fips_inventor app_year: gen state_count=_N 
bysort patnum app_year: gen count=_N
gen weight=state_count/count 

duplicates drop patnum state_fips_inventor, force 

gen patent=1 
replace patent = weight * patent 
collapse (sum) patent, by(state_fips_inventor assignee_id app_year)

rename patent patents2 
label var patents2 "Patent count, using Option 2"

tempfile patents2 
save `patents2'

restore 
* Option 3: 
bysort patnum state_fips_inventor app_year: gen state_count=_N 
bysort patnum app_year: egen max_state=max(state_count)
keep if max_state==state_count 
* (405,003 observations deleted)

bysort patnum: gen count=_N 
drop if count!=state_count
* (483,736 observations deleted)

duplicates drop patnum, force 

collapse (count) patnum, by(state_fips_inventor assignee_id app_year)
rename patnum patents3 
label var patents3 "Patent count, using Option 3"

tempfile patents3 
save `patents3'

merge 1:1 state_fips_inventor assignee_id app_year using `patents1', keepusing(patents1)
drop _merge 

merge 1:1 state_fips_inventor assignee_id app_year using `patents2', keepusing(patents2)
drop _merge 

rename state_fips_inventor fips_state 

save "${TEMP}/patentcount_state.dta", replace 



********************************************************************************
* Preparing the inventor data 
******************************************************************************** 

use patnum citation_count withdrawn date_filing date_grant app_year ///
	inventor_id first_name last_name male location_id state_fips_inventor county_fips_inventor ///
	assignee_id state_fips_assignee county_fips_assignee  ///
	using "$PATENTDTA\inventor_applications.dta", clear
	
drop if withdrawn==1 
drop withdrawn

*-Drop if missings in important variables
drop if app_year == .
drop if county_fips_inventor == .

* First step: Number of patents the firm records in a county and a state

*-Drop duplicates (we only want to count inventors once per recorded patent)
duplicates drop patnum inventor_id county_fips_inventor assignee_id, force 
* (132 observations deleted)
duplicates report patnum inventor_id assignee_id // differences in geocoding (missings or two different locations recorded); 190 cases
duplicates drop patnum inventor_id assignee_id, force 

* Cleaning 
collapse (count) n_patents=patnum, by(inventor_id assignee_id state_fips_inventor state_fips_assignee app_year)

bysort inventor_id app_year: gen count=_N
* Drop all inventors working in 3 or more firms and working in 3 or more states 
drop if count>=3 
* 148,111 observations deleted
drop count 


* Generate similar options to above 
*1 Only keep inventors which can be uniquely assigned to one state during a year
preserve
bysort inventor_id app_year: gen count_pats=_N 
bysort inventor_id app_year state_fips_inventor: gen count_state=_N
keep if count_state==count_pats


duplicates drop inventor_id state_fips_inventor assignee_id app_year, force 
bysort state_fips_inventor assignee_id app_year: gen count=_N


collapse (count) n_inventors1=count, by(state_fips_inventor assignee_id app_year)

label var n_inventors1 "Number of Inventors, 1"

tempfile inventors1 
save `inventors1 '

restore 


*2 Weight inventors by number of patents the recorded in each state
preserve  
bysort inventor_id app_year: egen total_patents=total(n_patents)
gen share_patents= n_patents/total_patents 

gen inventor=1 * share_patents 

collapse (sum) n_inventors2=inventor, by(state_fips_inventor assignee_id app_year)

label var n_inventors2 "Number of Inventors, 2"

tempfile inventors2 
save `inventors2 '

*3 Keep observation with the highest number of patents in one year  
restore 
bysort inventor_id app_year: egen max_patents=max(n_patents)
keep if max_patents==n_patents 

* Drop all observations for which inventors could not be uniquely assigned to a firm or state this way 
bysort inventor_id app_year: gen count=_N 
drop if count>=2 
drop count 
duplicates drop inventor_id state_fips_inventor assignee_id app_year, force 
bysort state_fips_inventor assignee_id app_year: gen count=_N



collapse (count) n_inventors3=count, by(state_fips_inventor assignee_id app_year)

label var n_inventors3 "Number of Inventors, 3"

tempfile inventors3 
save `inventors3 '


merge 1:1 state_fips_inventor assignee_id app_year using `inventors1', keepusing(n_inventors1)
drop _merge 

merge 1:1 state_fips_inventor assignee_id app_year using `inventors2', keepusing(n_inventors2)
drop _merge 

rename state_fips_inventor fips_state 


save "${TEMP}/inventorcount_state.dta", replace 




********************************************************************************
* Merging in the R+D data 
********************************************************************************


use "${TEMP}/patentcount_state.dta", clear 
merge 1:1 fips_state assignee_id app_year using "${TEMP}/inventorcount_state.dta"
drop _merge 

bysort assignee_id app_year: gen nstates=_N 

gen multistatefirm=0 
replace multistatefirm=1 if nstates>1

rename app_year year 


merge m:1 fips_state year using "${IN}/indep_var/var_RDcredits/RD_credits_final.dta"
keep if _merge==3 
drop _merge 

* Generate the average credit rate at other states: should this be static or dynamic? 
destring rd_credit, replace force
gen helper = rd_credit/(nstates-1) 
bysort assignee_id: egen avg_credit_rate = total(helper)
replace avg_credit_rate=avg_credit_rate - helper

drop helper 
label var avg_credit_rate "Average credit rate in other states in which the firm is active"

* What should we do with New York, Ohio, Louisiana? 
save "${TEMP}/final_state.dta", replace 















/*

bysort gvkey inventor_id appyear: gen patents=_N 
bysort state_fips_inventor gvkey inventor_id appyear: gen statepatents=_N 


gen share_statepatents=statepatents/patents 
bysort gvkey inventor_id appyear: egen max_stateshare=max(share_statepatents)

* (23,843 observations deleted)

drop patents 

bysort inventor_id appyear: gen patents=_N 
bysort gvkey inventor_id appyear: gen firmpatents=_N
gen share_firmpatents=firmpatents/patents 

bysort inventor_id appyear: egen max_firmshare=max(share_firmpatents)
keep if share_firmpatents==max_firmshare

duplicates drop inventor_id appyear gvkey state_fips_inventor, force 
duplicates tag inventor_id appyear gvkey, gen(dup)

gen state_weight=1
replace state_weight = share_statepatents if dup>0 
drop dup

duplicates tag inventor_id state_fips_inventor appyear, gen(dup)

gen firm_weight=1 
replace firm_weight = share_firmpatents if dup>0 
drop dup 

gen weight=firm_weight*state_weight 

gen inventors=1 

collapse (sum) n_inventors=inventors n_patents=firmpatents [pw=weight], by(gvkey appyear state_fips_inventor)

* Only keep companies with inventors present in multiple states 
bysort gvkey appyear: gen count=_N 
keep if count >1 

rename state_fips_inventor fips_state 
rename appyear year 



********************************************************************************
* Merging the data set with the RD Tax Credits 
********************************************************************************


merge m:1 fips_state year using `rd_credit_long'
keep if _merge==3 
drop _merge 

rename count n_labs

* Generate the average credit rate at other states
gen weighted_labs = rd_credit/(n_labs-1) 
bysort gvkey: egen avg_credit_rate = total(weighted_labs)
replace avg_credit_rate=avg_credit_rate-weighted_labs/(n_labs-1) 

label var avg_credit_rate "Average credit rate in other states in which the firm is active"

drop n_labs 
drop weighted_labs

* Credit rate weighted by number of inventors

bysort appyear gvkey: egen total_inventors=total(inventors)

gen rd_credit_w1=n_inventors*rd_credit_rate 

bysort appyear gvkey: gen avg_credit_rate_w=total(rd_credit_w1)
replace avg_credit_rate_w1 = (avg_credit_rate_w1 - rd_credit_w1)/(total_inventors -n_inventors)



* Credit rate weighted by share of patents in the respective state 

bysort appyear gvkey: egen total_patents=total(patents)

gen rd_credit_w2=n_patents*rd_credit_rate 

bysort appyear gvkey: gen avg_credit_rate_w=total(rd_credit_w1)
replace avg_credit_rate_w2 = (avg_credit_rate_w2 - rd_credit_w2)/(total_patents -n_patents)



save "${TEMP}/"



