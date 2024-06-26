// Project: Inventor Relocation
// Creation Date: 10/02/2024
// Last Update: 10/02/2024
// Author: Laura Arnemann 
// Goal: Merging the data set with the number of inventors 


********************************************************************************
* Generate Number of Patents on CZ level 
********************************************************************************

use "$inventordata", clear 

drop assignee_id 
rename gvkey assignee_id
*-Drop if missings in important variables
drop if missing(app_year)
drop if missing(assignee_id)
drop if missing(state_fips_inventor)
drop if missing(county_fips_inventor)

tostring county_fips_inventor, replace 
tostring state_fips_inventor, replace 
replace county_fips_inventor = "0" + county_fips_inventor if strlen(county_fips_inventor)==2
replace county_fips_inventor = "00" + county_fips_inventor if strlen(county_fips_inventor)==1
replace county_fips_inventor = state_fips_inventor + county_fips_inventor 
destring county_fips_inventor, replace 
* First step: Number of patents the firm records in a county and a state

*-Drop duplicates (we only want to count inventors once per recorded patent)
duplicates drop patnum inventor_id county_fips_inventor assignee_id, force

duplicates report patnum inventor_id assignee_id // differences in geocoding (missings or two different locations recorded); 190 cases
duplicates tag patnum inventor_id assignee_id, gen(dup)
drop if dup!=0 
drop dup

duplicates report patnum inventor_id

save "${TEMP}/patents_helper_${dataset}.dta", replace 

* 1 Only keep patents which can be uniquely assigned to one commuting zone during a year
use "${TEMP}/patents_helper_${dataset}.dta", clear
 
rename county_fips_inventor county_fips
rename state_fips_inventor fips_state
* Broomfield county (8014) was formed out of Boulder County in 2001
**# Bookmark #1
replace county_fips = 8013 if county_fips == 8014 

* Merging in the Commuting Zone level data 
merge m:1 county_fips using "$IN\var_CommutingZones\CZ_combined.dta"
drop if _merge!=3  
drop _merge	


drop CZ_depagri_2000 CZ_UScensus county_name_depagri CZ_depagri_1980
rename CZ_depagri_1990 czone 

bysort patnum  czone  app_year: gen cz_count=_N 
bysort patnum app_year: gen pat_count=_N
    keep if pat_count==cz_count 
	duplicates tag patnum, gen(dup)
	drop if dup!=0
	
	collapse (count) patnum, by(czone assignee_id app_year)
	
	rename patnum patents1 
	label var patents1 "Patent count (CZ), using Option 1"
	tempfile patents1 
	save `patents1'
	
	* Already include zeros in the years in which states were inactive 
	 bysort czone assignee_id: egen max_year = max(app_year)
     bysort czone assignee_id: egen min_year = min(app_year)
	 
	 duplicates drop czone assignee_id, force 
	 keep czone assignee_id min_year max_year 
	 
	 expand 51 
	 bysort assignee_id czone: gen count_obs = _n
	 gen app_year = 1969+count_obs

	 keep if inrange(app_year, min_year, max_year)
	 drop count_obs 
	 
	 merge 1:1 czone assignee_id app_year using `patents1', keepusing(patents1)
	 replace patents1 = 0 if _merge ==1 
	 drop _merge 
	 * Not merged 2021 
	 
	 save "${TEMP}/patents1_czone.dta", replace 
	

* 2 Weight patents by number of patents recorded in each czone 
    use "${TEMP}/patents_helper_${dataset}.dta", clear 
    rename county_fips_inventor county_fips

* Merging in the Commuting Zone level data 
    merge m:1 county_fips using "$IN\var_CommutingZones\CZ_combined.dta"
    drop if _merge!=3  
    drop _merge	

    drop CZ_depagri_2000 CZ_UScensus county_name_depagri CZ_depagri_1980
    rename CZ_depagri_1990 czone 

	bysort patnum czone app_year: gen state_count=_N 
	bysort patnum app_year: gen pat_count=_N
	gen weight=state_count/pat_count 

	duplicates tag patnum czone, gen(dup)
	drop if dup!=0

	gen patent=1 
	replace patent = weight * patent 
	collapse (sum) patent, by(czone assignee_id app_year)

	rename patent patents2 
	label var patents2 "Patent count (CZ), using Option 2"

	tempfile patents2 
	save `patents2'
	
	* Already include zeros in states inbetween activity 
	 bysort czone assignee_id: egen max_year = max(app_year)
     bysort czone assignee_id: egen min_year = min(app_year)
	 
	 duplicates drop czone assignee_id, force 
	 keep czone assignee_id min_year max_year 
	 
	 expand 51 
	 bysort assignee_id czone: gen count_obs = _n
	 gen app_year = 1969+count_obs
	 
	 keep if inrange(app_year, min_year, max_year)
	 drop count_obs 
	 
	 merge 1:1 czone assignee_id app_year using `patents2', keepusing(patents2)
	 replace patents2 = 0 if _merge ==1 
	 drop _merge 
	 * Not merged 2021 
	 save "${TEMP}/patents2_czone.dta", replace

*3 Assign Patent to the Commuting Zone where the most inventors are located
    use "${TEMP}/patents_helper_${dataset}.dta", clear 
    rename county_fips_inventor county_fips

* Merging in the Commuting Zone level data 
    merge m:1 county_fips using "$IN\var_CommutingZones\CZ_combined.dta"
    drop if _merge!=3  
    drop _merge	

    drop CZ_depagri_2000 CZ_UScensus county_name_depagri CZ_depagri_1980
    rename CZ_depagri_1990 czone 
	
	
	bysort patnum czone app_year: gen state_count=_N 
	bysort patnum app_year: egen max_state=max(state_count)
	keep if max_state==state_count 
	* (405,003 observations deleted)

	bysort patnum: gen pat_count=_N 
	drop if pat_count!=state_count
	* (483,736 observations deleted)

	duplicates tag patnum, gen(dup)
	drop if dup!=0

	collapse (count) patnum, by(czone assignee_id app_year)
	rename patnum patents3 
	label var patents3 "Patent count (CZ), using Option 3"
	
	tempfile patents3 
	save `patents3'
	
	* Already include zeros in states inbetween activity 
	 bysort czone assignee_id: egen max_year = max(app_year)
     bysort czone assignee_id: egen min_year = min(app_year)
	 
	 duplicates drop czone assignee_id, force 
	 keep czone assignee_id min_year max_year 
	 
	 expand 51 
	 bysort assignee_id czone: gen count_obs = _n
	 gen app_year = 1969+count_obs
	 
	 keep if inrange(app_year, min_year, max_year)
	 drop count_obs 
	 
	 merge 1:1 czone assignee_id app_year using `patents3', keepusing(patents3)
	 replace patents3 = 0 if _merge ==1 
	 drop _merge 
	 * Not merged 2021 
	 save "${TEMP}/patents3_czone.dta", replace

* Merging the different data sets together	 
   merge 1:1 czone assignee_id app_year using "${TEMP}/patents1_czone.dta", keepusing(patents1)
   drop _merge 
   
   merge 1:1 czone assignee_id app_year using "${TEMP}/patents2_czone.dta", keepusing(patents2)
   drop _merge 

save "${TEMP}/patentcount_czone.dta", replace 

********************************************************************************
* Generate Number of Inventors on CZ level
* The difference between the inventor and the patent data is that we generate somewhat
* of a stock of inventors  
********************************************************************************

*  Balanced panel from 1970 - 2020

use inventor_id county_fips_inventor state_fips_inventor gvkey using "${inventordata}", clear 

rename gvkey assignee_id
drop if missing(assignee_id)
drop if missing(state_fips_inventor)
drop if missing(county_fips_inventor)

* Cleaning the Fips County Codes 
tostring county_fips_inventor, replace 
tostring state_fips_inventor, replace 
replace county_fips_inventor = "0" + county_fips_inventor if strlen(county_fips_inventor)==2
replace county_fips_inventor = "00" + county_fips_inventor if strlen(county_fips_inventor)==1
replace county_fips_inventor = state_fips_inventor + county_fips_inventor 
destring county_fips_inventor, replace 

replace county_fips_inventor = 8013 if county_fips_inventor == 8014 
rename county_fips_inventor county_fips

* Merging in the Commuting Zone level data 
    merge m:1 county_fips using "$IN\var_CommutingZones\CZ_combined.dta"
    drop if _merge!=3  
    drop _merge	
	
	 drop CZ_depagri_2000 CZ_UScensus county_name_depagri CZ_depagri_1980
    rename CZ_depagri_1990 czone
	
	duplicates drop czone assignee_id inventor_id, force
   drop if missing(czone)

	expand 51 
	bysort czone assignee_id inventor_id: gen count_obs = _n
	gen app_year = 1969+count_obs

save "${TEMP}/helper.dta", replace 

* Inventor Count on Commuting Zone level 

    use "${inventordata}", clear 
	
	drop assignee_id 
	rename gvkey assignee_id
	* Drop if missings in important variables
	drop if missing(app_year)
	drop if missing(county_fips_inventor)
	drop if missing(assignee_id)
	
	* Cleaning the Fips County Codes 
      tostring county_fips_inventor, replace 
      tostring state_fips_inventor, replace 
      replace county_fips_inventor = "0" + county_fips_inventor if strlen(county_fips_inventor)==2
      replace county_fips_inventor = "00" + county_fips_inventor if strlen(county_fips_inventor)==1
      replace county_fips_inventor = state_fips_inventor + county_fips_inventor 
      destring county_fips_inventor, replace force
	  replace county_fips_inventor = 8013 if county_fips_inventor == 8014 
	
	rename county_fips_inventor county_fips

* Merging in the Commuting Zone level data 
    merge m:1 county_fips using "$IN\var_CommutingZones\CZ_combined.dta"
    drop if _merge!=3  
    drop _merge	
	
	drop CZ_depagri_2000 CZ_UScensus county_name_depagri CZ_depagri_1980
    rename CZ_depagri_1990 czone 
	
	
* Drop duplicates (we only want to count inventors once per recorded patent)
   duplicates tag patnum inventor_id czone assignee_id, gen(dup)
   drop if dup!=0 
   drop dup	// 132 observations deleted
   duplicates report patnum inventor_id assignee_id // differences in geocoding (missings or two different locations recorded); 190 cases
   duplicates tag patnum inventor_id assignee_id, gen(dup) 
   drop if dup!=0
   drop dup
* Patent count by inventor - assignee - state - year
   collapse (count) n_patents=patnum, by(inventor_id assignee_id czone app_year)

* Drop all inventors working in 3 or more firms and working in 3 or more czones
   bysort inventor_id app_year: gen pat_count=_N
   drop if pat_count>=3 
   drop pat_count 

save "${TEMP}/inventor_helper_${dataset}.dta", replace 


* Generate inventor count
*-------------------------------------------------------------------------------

*1 Only keep inventors which can be uniquely assigned to one state during a year
    use "${TEMP}/inventor_helper_${dataset}.dta", clear 
	bysort inventor_id app_year: gen count_pats=_N 
	bysort inventor_id app_year czone: gen count_state=_N
	keep if count_state==count_pats
	drop count_state count_pats

	duplicates tag inventor_id czone assignee_id app_year, gen(dup)
	drop if dup!=0
	drop dup

	merge m:1 czone assignee_id inventor_id app_year using "${TEMP}/helper.dta"
	drop if _merge==1 // Observations from year 2021
	bysort czone assignee_id inventor_id: egen max_merge=max(_merge)
	
	keep if max_merge==3 
			
	* Keep inventor obs between first and last patent 
	bysort czone assignee_id inventor_id _merge: egen max_helper = max(app_year)
	bysort czone assignee_id inventor_id _merge: egen min_helper = min(app_year)
	replace max_helper = . if _merge==2
	replace min_helper = . if _merge==2

	bysort czone assignee_id inventor_id: egen max_year = max(max_helper)
	bysort czone assignee_id inventor_id: egen min_year = min(min_helper)
	
	gen new_inventor = 1 if app_year==min_year 
	keep if inrange(app_year, min_year, max_year)

* Drop all observations which cannot unqiuely be assigned to a state in a given year
	duplicates tag inventor_id app_year, gen(dup)
	drop if dup>0
	drop dup 
	
	bysort czone assignee_id app_year: gen count=_N
	
	collapse (count) n_inventors1=count n_newinventors1=new_inventor, by(czone assignee_id app_year)
	
	label var n_inventors1 "Number of Inventors (CZ), 1"
	label var n_newinventors1 "Number of New Inventors (CZ), 1"
save "${TEMP}/inventor1_czone.dta", replace


*2 Weight inventors by number of patents recorded in each state
    use "${TEMP}/inventor_helper_${dataset}.dta", clear 
	bysort inventor_id app_year: egen total_patents=total(n_patents)
	gen share_patents= n_patents/total_patents 

	gen inventor= 1 * share_patents 

	collapse (sum) n_inventors2=inventor, by(czone assignee_id app_year)

	label var n_inventors2 "Number of Inventors (CZ), 2"
	save "${TEMP}/inventor2_czone.dta", replace


*3 Keep observation with the highest number of patents in one year  
    use "${TEMP}/inventor_helper_${dataset}.dta", clear 
	bysort inventor_id app_year: egen max_patents=max(n_patents)
	keep if max_patents==n_patents 

	* Drop all observations for which inventors could not be uniquely assigned to a firm or state this way 
	bysort inventor_id app_year: gen inv_count=_N 
	drop if inv_count>=2 
	drop inv_count 
	
	duplicates tag inventor_id czone assignee_id app_year, gen(dup)
	drop if dup!=0
	drop dup
	bysort czone assignee_id app_year: gen cz_count=_N

	merge m:1 czone assignee_id inventor_id app_year using "${TEMP}/helper.dta"
	drop if _merge==1	// Observations from year 2021
	bysort czone assignee_id inventor_id: egen max_merge=max(_merge)
	keep if max_merge==3 
	
	* Keep inventor obs between first and last patent 
	bysort czone assignee_id inventor_id _merge: egen max_helper = max(app_year)
	bysort czone assignee_id inventor_id _merge: egen min_helper = min(app_year)
	replace max_helper = . if _merge==2
	replace min_helper = . if _merge==2

	bysort czone assignee_id inventor_id: egen max_year = max(max_helper)
	bysort czone assignee_id inventor_id: egen min_year = min(min_helper)

	keep if inrange(app_year, min_year, max_year)

	drop _merge 
	drop cz_count 
	duplicates tag app_year inventor_id, gen(dup)
	drop if dup>0
	drop dup 
	gen new_inventor = 1 if app_year==min_year 
	
bysort czone assignee_id app_year: gen cz_count=_N

	collapse (count) n_inventors3=cz_count n_newinventors3 = new_inventor, by(czone assignee_id app_year)
	label var n_inventors3 "Number of Inventors (CZ), 3"
	label var n_newinventors3 "Number of New Inventors (CZ), 3"
	save "${TEMP}/inventor3_czone.dta", replace


merge 1:1 czone assignee_id app_year using "${TEMP}/inventor1_czone.dta", keepusing(n_inventors1 n_newinventors1)
drop _merge 

merge 1:1 czone assignee_id app_year using "${TEMP}/inventor2_czone.dta",keepusing(n_inventors2)
drop _merge 

save "${TEMP}/inventorcount_cz.dta", replace 


********************************************************************************
* Running the dofiles to generate the variables indicating tax changes in other
* locations 
********************************************************************************

* This dofile generates the variables based on all years the establishment is present
do "${CODE}/cleaning/03_01_gen_other_variable_czone.do"
********************************************************************************
* Merging data together 
********************************************************************************
/*Difficulty in measuring spillover effects atm: We want to measure spillover effects, so 
we need to exclude the patents of treated units. In my opinion the cleanest approach would be to focus on firms which are only active in one commuting zone  */

use "${TEMP}/patentcount_czone.dta", clear 
merge 1:1 czone assignee_id app_year using "${TEMP}/inventorcount_cz.dta"
drop _merge 

bysort assignee_id app_year: gen cz_count = _N 
keep if cz_count == 1 


gen tag=1 

* Check out how many observations are left, if too little observations then just do this as a robustness check 

/* Alternative Approach to merging: Merging in the identfying variation and then dropping observations from firms which experienced a treatment, would be sth like: 
merge 1:1 czone assignee_id app_year 
bysort assignee_id app_year czone: egen max_change = max(change_other)
bysort assignee_id app_year czone: egen min_change = min(change_other)

drop if max_change >=1 
drop if min_change <=-1

*/ 

* Merging in the other variable 
collapse (sum) tag patents1 patents2 patents3 n_inventors1 n_inventors2 n_inventors3 n_newinventors1 n_newinventors3, by(czone app_year)

rename tag total_labs 

merge 1:1 czone app_year using "${TEMP}/other_variable_czone.dta"
drop if _merge==2 
drop _merge 


save "${TEMP}/final_cz_${dataset}_gvkey.dta", replace 




