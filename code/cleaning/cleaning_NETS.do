// Project: Inventor Relocation
// Creation Date: 04/10/2023
// Last Update: 04/10/2023
// Author: Laura Arnemann 
// Goal: Preparing Nets Data for merge 

/* 
*/ 

use "${IN}/NETS2022_hq_multiple.dta", clear 
merge 1:1 dunsnumber using "${TEMP}/public_private/public_companies.dta"
keep if _merge==3 
drop _merge 
duplicates drop hqduns, force  
save "${TEMP}/NETS2022_public.dta", replace 



use "${TEMP}/NETS2022_hq_multiple.dta", clear 
local STE strpos(hqaddress, "STE")
gen wanted = trim(cond(`STE', substr(hqaddress, 1, `STE' -1), hqaddress))

local FL strpos(hqaddress, "FL ")
gen wanted2 = trim(cond(`FL', substr(wanted, 1, `FL' -1), wanted))

* Trying to merge over addresses
foreach var of varlist wanted2 hqcity {
	replace `var'=subinstr(`var',"  ","",.)
}
tostring hqzipcode, replace
gen hqaddress_python = wanted2 + " " + hqcity + " " + hqstate
duplicates drop hqduns, force  
keep dunsnumber hqduns hqcompany hqaddress_python
gen count=_n
save "${TEMP}/NETS2022_addresses_old.dta", replace 

********************************************************************************
* Run the dofile cleaning_NETS_10_employees to only keep companies with more than
* 10 employees
********************************************************************************

/* The following step matches the already geocoded data to the new data set which 
we cleaned for companies only having 10 employees */ 

local b=0 
forvalues i=1/20 {
	use "${TEMP}/NETS2022_addresses_old.dta", clear
	local a = 2500*`i' +1
    di `a'
	di `b'
	keep if inrange(count,`b', `a')
	local b=`a'
	save "${TEMP}/NETS2022_addresses`i'.dta", replace 
}


gen max_merge=. 

forvalues i=1/20 {
	merge 1:1 hqduns using "${TEMP}/NETS2022_addresses`i'.dta"
	replace max_merge=1 if _merge==3 
	drop if _merge==2 
	drop _merge 
}
 
drop if max_merge==1
drop count 
sort hqduns 
gen count=_n 
save "${TEMP}/NETS2022_adresses_10emps_cleaned.dta", replace 

local b=1 
forvalues i=1/224 {
	use "${TEMP}/NETS2022_adresses_10emps_cleaned.dta", clear
	local a = 2500*`i'
    di `a'
	di `b'
	keep if inrange(count,`b', `a')
	local b=`a'+1
	local c=`i'+20
	save "${TEMP}/NETS2022_addresses`c'.dta", replace 
}



********************************************************************************
* Run geocoding Python file for all these different datasets 
********************************************************************************
* geocoding_addresses.ipynb

********************************************************************************
* Merging the geocoded NETS data together 
********************************************************************************


use "${TEMP}/geocoding_done/NETS/NETS2022_addresses_geocoded_final2.dta", clear 
append using "${TEMP}/geocoding_done/NETS/NETS2022_addresses_geocoded_final.dta"
gen dataset=1


  append using  "${TEMP}/geocoding_done/NETS/addresses_geocoded1.dta" 
  replace  dataset=1 
 
 append using "${TEMP}/geocoding_done/NETS/addresses_geocoded4.dta"
 replace dataset=4 if missing(dataset)
 
 forvalues i =16/19 {
 append using "${TEMP}/geocoding_done/NETS/addresses_geocoded`i'.dta", force 
 replace dataset=`i'  if missing(dataset)

 }
forvalues i =41/99 {
	append using "${TEMP}/geocoding_done/NETS/addresses_geocoded`i'.dta"
	 replace dataset=`i'  if missing(dataset)


}

forvalues i=201/209 {
	append using "${TEMP}/geocoding_done/NETS/addresses_geocoded`i'.dta"
	 replace dataset=`i'  if missing(dataset)

}

forvalues i=210/223 {
	append using "${TEMP}/geocoding_done/NETS/addresses_geocoded`i'.dta"
	 replace dataset=`i'  if missing(dataset)

}

duplicates drop hqduns, force 
preserve 
keep if missing(lon)
tempfile missing_geocodes 
save "${TEMP}/missing_geocodes_1.dta", replace 
restore 
drop if missing(lon)

save "${TEMP}/geocoding_done/NETS/NETS2022_geocoded_all.dta", replace 

use "${TEMP}/missing_geocodes.dta", clear 
merge 1:1 hqduns using "${TEMP}/geocoding_done/NETS/NETS_geocoded.dta", keepusing(latNETS longNETS)
keep if _merge==3 
drop _merge 
tempfile missing_geocodes 
save `missing_geocodes', replace 


use "${TEMP}/NETS2022_adresses_10emps_cleaned.dta", clear 
*use "${TEMP}/NETS2022_addresses_10employees.dta", clear 

merge 1:1 hqduns using "${TEMP}/geocoding_done/NETS/NETS2022_geocoded_all.dta"
drop if _merge==2 
gen indic_merge=_merge 
drop _merge 
merge 1:1 hqduns using `missing_geocodes', keepusing(latNETS longNETS)
drop if _merge==2 
drop _merge 
replace lat=latNETS if missing(lat)
replace lon=longNETS if missing(lon)
drop latNETS 
drop longNETS

preserve 
keep if missing(lon)
save "${TEMP}/missing_geocodes_2.dta", replace 
restore 

* Now run this geocoding file through Python 

merge 1:1 hqduns using "${TEMP}/geocoding_done/NETS/missing_geocodes_final.dta", keepusing(latNETS lonNETS)
drop if _merge==2 
replace lat=latNETS if missing(lat)
replace lon=lonNETS if missing(lon)
drop _merge 
save "${TEMP}/geocoding_done/NETS_all.dta", replace 