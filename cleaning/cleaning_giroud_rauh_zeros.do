// Project: Inventor Relocation
// Creation Date: 06/12/2023
// Last Update: 06/12/2023
// Author: Laura Arnemann 
// Goal: Merging the data set using the number of inventors in a state employed by the respective firm as outcome variable 




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
*1 Only keep patents which can be uniquely assigned to one state during a year
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
 
*2 Weight patents by number of patents recorded in each state
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

*3 Keep observation with the highest number of patents in one year  
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

* Helper data set for the inventors  
use inventor_id state_fips_inventor assignee_id using "$PATENTDTA\inventor_applications.dta", clear
duplicates drop state_fips_inventor assignee_id inventor_id, force 
expand 51 
bysort state_fips_inventor assignee_id inventor_id: gen count_obs = _n
gen app_year = 1969+count_obs
save "${TEMP}/helper.dta", replace 

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
save "${TEMP}/inventor_helper.dta", replace 

* Generate similar options to above 
*1 Only keep inventors which can be uniquely assigned to one state during a year
use "${TEMP}/inventor_helper.dta", clear 
bysort inventor_id app_year: gen count_pats=_N 
bysort inventor_id app_year state_fips_inventor: gen count_state=_N
keep if count_state==count_pats

duplicates drop inventor_id state_fips_inventor assignee_id app_year, force 

merge m:1 state_fips_inventor assignee_id inventor_id app_year using "${TEMP}/helper.dta"
drop if _merge==1 
* Observations from year 2021
bysort state_fips_inventor assignee_id inventor_id: egen max_merge=max(_merge)
keep if max_merge==3 

*keep if max_merge==3 
*(38,850,321 observations deleted); why does this make such a difference? 
 
bysort state_fips_inventor assignee_id inventor_id _merge: egen max_helper = max(app_year)
bysort state_fips_inventor assignee_id inventor_id _merge: egen min_helper = min(app_year)
replace max_helper = . if _merge==2
replace min_helper = . if _merge==2


bysort state_fips_inventor assignee_id inventor_id: egen max_year = max(max_helper)
bysort state_fips_inventor assignee_id inventor_id: egen min_year = min(min_helper)

keep if inrange(app_year, min_year, max_year)

gen new_inventor = 1 if app_year==min_year 

replace n_patents = 0 if _merge==2 
drop _merge 

* Drop all observations which cannot unqiuely be assigned to a state in a given year
duplicates tag inventor_id app_year, gen(dup)
drop if dup>0

bysort state_fips_inventor assignee_id app_year: gen count=_N
collapse (count) n_inventors1=count n_newinventors1=new_inventor, by(state_fips_inventor assignee_id app_year)

label var n_inventors1 "Number of Inventors, 1"
label var n_newinventors1 "Number of New Inventors, 1"
save "${TEMP}/inventor_1.dta", replace


*2 Weight inventors by number of patents the recorded in each state
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
duplicates drop inventor_id state_fips_inventor assignee_id app_year, force 
bysort state_fips_inventor assignee_id app_year: gen count=_N

merge m:1 state_fips_inventor assignee_id inventor_id app_year using "${TEMP}/helper.dta"
drop if _merge==1

* Observations from year 2021
bysort state_fips_inventor assignee_id inventor_id: egen max_merge=max(_merge)
keep if max_merge==3 

bysort state_fips_inventor assignee_id inventor_id _merge: egen max_helper = max(app_year)
bysort state_fips_inventor assignee_id inventor_id _merge: egen min_helper = min(app_year)
replace max_helper = . if _merge==2
replace min_helper = . if _merge==2

bysort state_fips_inventor assignee_id inventor_id: egen max_year = max(max_helper)
bysort state_fips_inventor assignee_id inventor_id: egen min_year = min(min_helper)

keep if inrange(app_year, min_year, max_year)

gen new_inventor = 1 if app_year==min_year 

drop _merge 
drop count 
duplicates tag app_year inventor_id, gen(dup)
drop if dup>0

bysort inventor_id app_year: gen count=_N

collapse (count) n_inventors3=count n_newinventors3 = new_inventor, by(state_fips_inventor assignee_id app_year)

label var n_inventors3 "Number of Inventors, 3"
label var n_newinventors3 "Number of New Inventors, 3"
save "${TEMP}/inventor_3.dta", replace



use "${TEMP}/inventor_3.dta", clear 

merge 1:1 state_fips_inventor assignee_id app_year using "${TEMP}/inventor_1.dta", keepusing(n_inventors1 n_newinventors1)
drop _merge 

merge 1:1 state_fips_inventor assignee_id app_year using "${TEMP}/inventor_2.dta", keepusing(n_inventors2)
drop _merge 

rename state_fips_inventor fips_state 
save "${TEMP}/inventorcount_state.dta", replace 

/*

erase "${TEMP}/inventor_1.dta"
erase "${TEMP}/inventor_2.dta"
erase "${TEMP}/inventor_3.dta"
erase "${TEMP}/inventor_helper.dta"
*/

********************************************************************************
* Merging in the R+D data 
********************************************************************************
use "${TEMP}/patentcount_state.dta", clear 

* Generate max and min year of patenting activity: 
bysort fips_state assignee_id: egen max_year = max(app_year)
bysort fips_state assignee_id: egen min_year = min(app_year)

duplicates drop fips_state assignee_id, force 
keep fips_state assignee_id min_year max_year 
expand 51 
bysort assignee_id fips_state: gen count_obs = _n
gen app_year = 1969+count_obs
keep if inrange(app_year, min_year, max_year)
drop count_obs 

rename app_year year 
merge m:1 fips_state year using "${IN}/indep_var/var_RDcredits/RD_credits_final.dta"
keep if _merge==3 
drop _merge 

destring rd_credit, replace force
bysort assignee_id year: gen count=_N 

* Unemployment
merge m:1 fips_state year using "${IN}/indep_var/var_state/unemployment.dta"
drop if _merge==2 
*1970-1975 not merged from master, 2019-2021 from using not matched  
drop _merge 

* GDP
merge m:1 fips_state year using "${IN}/indep_var/var_state/gdp.dta"
drop if _merge==2 
drop _merge 

* PIT and CIT
merge m:1 fips_state year using "${IN}/indep_var/var_tax/tax_final.dta"
* Year 2019 not matched 
drop if _merge==2 
drop _merge 

*Government R&D expenditure
merge m:1 fips_state year using "${IN}/var_other/rd_exp_states_us/rd_exp_states.dta" 
drop if _merge==2 
drop _merge 

rename year app_year 
merge 1:1 fips_state assignee_id app_year using "${TEMP}/inventorcount_state.dta"
drop if _merge==2 
drop _merge 

replace n_inventors3=0 if missing(n_inventors3)
bysort assignee_id app_year: egen total_inventors=total(n_inventors3)

* Number of inventors in other states 
gen total_inventors_other = total_inventors-n_inventors3

rename unemployment_rate unemployment 
 
foreach var of varlist rd_credit pit cit gdp unemployment {
	
gen `var'_helper = n_inventors3 * `var'
bysort assignee_id app_year: egen `var'_other=total(`var'_helper)
replace `var'_other =  `var'_other - `var'_helper
replace `var'_other = `var'_other/total_inventors_other 

}

label var rd_credit_other "Average RD credit at other Labs"
label var pit_other "Average PIT at other labs"
label var cit_other "Average CIT at other labs"
label var unemployment_other "Unemployment Rate at other labs"

drop count *_helper n_inventors* total_inventors total_inventors_other 

save "${TEMP}/rdcredits_cleaned.dta", replace 


********************************************************************************
* Merging things together
********************************************************************************
* Only records active years 

use "${TEMP}/patentcount_state.dta", clear 
merge 1:1 fips_state assignee_id app_year using "${TEMP}/inventorcount_state.dta"
* With states this is not such a huge problem
drop _merge 

* How can I fix the number of states in which the firm has ever been present 

merge 1:1 fips_state app_year assignee_id using "${TEMP}/rdcredits_cleaned.dta"
drop if _merge==1 

/* For the inventors there are a lot of non-matches. This is plausible since there might be new inventors? 
    Result                      Number of obs
    -----------------------------------------
    Not matched                       443,686
        from master                    46,136  (_merge==1)
        from using                    397,550  (_merge==2)

    Matched                         1,272,113  (_merge==3)
    -----------------------------------------
*/

* Actually quite a lot of observations that were not merged
* 2019-2021 not merged 
bysort assignee_id app_year: gen nstates=_N 

gen multistatefirm_temp=0 
replace multistatefirm_temp=1 if nstates>1
bysort assignee_id: egen multistatefirm_max = max(multistatefirm_temp)

foreach var of varlist patents1 patents2 patents3 {
	replace `var' = 0 if _merge==2
}

* For the inventors this method is not correct  
drop _merge 

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

replace rd_credit=100*rd_credit
replace rd_credit_other=100*rd_credit_other
replace total_rd_credit = 100* total_rd_credit


rename app_year year 
* What should we do with New York, Ohio, Louisiana? 
save "${TEMP}/final_state_zeros.dta", replace 






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

********************************************************************************
* Similar cleaning steps as in Theresas data set 
********************************************************************************





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



