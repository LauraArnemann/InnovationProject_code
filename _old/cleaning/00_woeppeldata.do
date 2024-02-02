/// PROJECT: Spillover Effects 
/// GOAL: Just trying out some stuff with patents 
/// AUTHOR: Laura Arnemann
/// CREATION: 27-12-2022
/// LAST UPDATE: 09-03-2023
/// SOURCE: Raw Data 



* Assignee data 
forvalues i=5/12 {
  import delimited "${IN}/assignee/assignee_`i'm.tsv", clear 
**# Bookmark #1
  tempfile assignee_`i'm 
  save `assignee_`i'm'
  
}

* Citation Data 
forvalues i=8/12 {
  import delimited "${IN}/citation/app_cites_`i'm.tsv", clear
  bysort patnum: gen count=_n 
  collapse (mean) sequence (count) count, by(patnum)
  tempfile cite_`i'm 
  save `cite_`i'm'
}

* Info Data 
forvalue i=5/12 {
  import delimited "${IN}/info/info_`i'm.tsv", clear
  tempfile info_`i'm 
  save `info_`i'm'
}

* Merge the data which start with 5 to 7 
forvalues i=5/7 {
	use `info_`i'm'
	merge 1:m patnum using `assignee_`i'm', force
	drop if _merge==2 
	drop _merge 
	tempfile all_`i'm 
	save `all_`i'm'
}

forvalues i=8/12 {
	use `info_`i'm'
	merge 1:m patnum using `assignee_`i'm', force
	drop if _merge==2 
	drop _merge 
	merge m:1 patnum using `cite_`i'm', force
	drop if _merge==2 
	drop _merge
	tempfile all_`i'm 
	save `all_`i'm'
}





clear 
forvalues i=5/12 {
	append using `all_`i'm', force
}
compress 
save "${OUT}/joint_applications.dta", replace 


* Inventor Data 
forvalues i=5/12 {
  import delimited "${IN}/inventors/inventor_`i'm.tsv", clear 

   foreach var of varlist country latitude longitude county state_fips county_fips {
	    rename `var' `var'_inventor
 }
   tempfile inventor_`i'm 
   save `inventor_`i'm'
}

clear 
forvalues i=5/12 {
	append using `inventor_`i'm', force
}

* Only keep inventors for which we have information on state level, usually inventors residing in other countries 
drop if state==""

save "${OUT}/inventor_all.dta", replace



********************************************************************************
* Merge the inventor data and the data on applications 
********************************************************************************
use "${OUT}/joint_applications.dta", clear

duplicates drop

/* Remove duplicates of patents that multiple location ids for one patent number 

drop if missing(county_fips)
* 4,371,049 observations deleted; To Do: Think about what this implies for us? 
*/


 
gen app_year = substr(fdate,-4,.)
destring app_year, replace 

drop if app_year<1970 | app_year>2021 


keep assignee_id city state latitude longitude county state_fips county_fips type patnum count app_year
duplicates tag patnum app_year, gen(dup)

* Create an extra data set for the duplicates, since reshaping the data set with that many patents will take for ever
preserve 
keep if dup>0
drop dup
drop count
bysort patnum: gen count=_n
drop if count>10
* I cross-checked this, this bloats up the data set and there are only 5 patents that have so many different entries 
reshape wide assignee_id city state latitude longitude county state_fips county_fips type, i(patnum) j(count) 
save "${TEMP}/applications_v2.dta", replace 
restore 

keep if dup==0 
save "${TEMP}/applications_v1.dta", replace 




* Merging the two data sets together 
use "${OUT}/inventor_all.dta", clear 


merge m:1 patnum using "${TEMP}/applications_v1.dta"

/*
    Result                      Number of obs
    -----------------------------------------
    Not matched                     3,601,886
        from master                   293,968  (_merge==1)
        from using                  3,307,918  (_merge==2)

    Matched                         8,658,778  (_merge==3)
    -----------------------------------------
*/ 

preserve 
keep if _merge==1 
drop _merge 
merge m:1 patnum using "${TEMP}/applications_v2.dta"
keep if _merge==3 
* If we also do this match we merge all but 88,975 observations, quite okay 
save "${TEMP}/inventor_matched_v2.dta", replace 
restore 

keep if _merge==3 
drop _merge 

*append using "${TEMP}/inventor_matched_v2.dta", force
* The append takes super long, might need to make the data set before bit smaller 
save  "${TEMP}/inventor_applications.dta", replace 




