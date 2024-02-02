// Project: Inventor Relocation
// Creation Date: 04/10/2023
// Last Update: 16/11/2023
// Author: Laura Arnemann 
// Goal: Cleaning Compustat data and geocoding 


********************************************************************************
* Preparing the Compustat Headquarters Data 
********************************************************************************


* Importing Compustat data 

import delimited "${IN}/main_data/data_compustat/compustat_1950_2023.csv", clear
*keep if fyear==2020
*drop if indfmt=="FS"
duplicates drop gvkey, force
rename addzip hqzipcode
gen hqzip4=substr(hqzip,1,4)
destring hqzip4, replace force 
rename add1 hqaddress
rename conm hqcompany
save "${TEMP}/compustat.dta", replace 


********************************************************************************
* Cleaning the data for geocoding 
********************************************************************************

use "${TEMP}/compustat.dta", clear
keep hqcompany hqaddress gvkey city state
replace hqcompany=subinstr(hqcompany," ","",.)

split hqaddress, parse(,)

generate indicator = regexm(hqaddress2, "Floor")
replace indicator = regexm(hqaddress2, "Suite") if indicator==0
replace indicator = regexm(hqaddress2, "Box") if indicator==0

*br hqaddress2 if hqaddress2!="" & indicator!=1
replace hqaddress1=hqaddress2 if hqaddress2!="" & indicator==0
*1,383 real changes made

drop indicator
gen indicator= regexm(hqaddress3, "Street")
replace indicator= regexm(hqaddress3, "St") if indicator==0
replace indicator= regexm(hqaddress3, "Road") if indicator==0
replace indicator= regexm(hqaddress3, "Avenue") if indicator==0
replace indicator= regexm(hqaddress3, "Boulevard") if indicator==0

replace hqaddress1=hqaddress3 if indicator==1 
* 390 real changes made

drop indicator
gen indicator= regexm(hqaddress3, "Street")
replace indicator= regexm(hqaddress3, "St") if indicator==0
replace indicator= regexm(hqaddress3, "Road") if indicator==0
replace indicator= regexm(hqaddress3, "Avenue") if indicator==0
replace indicator= regexm(hqaddress3, "Boulevard") if indicator==0

replace hqaddress1=hqaddress4 if indicator==1 
*391 changes made 

gen hq_address_compustat= hqaddress1 +" "+ city + " " + state 

keep gvkey hq_address_compustat
sort gvkey 
gen count=_n
*42.980 Unternehmen 
save "${TEMP}/compustat_addresses.dta", replace 

local b=0 
forvalues i=1/18 {
	use "${TEMP}/compustat_addresses.dta", clear
	local a = 2500*`i'
    di `a'
	di `b'
	keep if inrange(count,`b', `a')
	local b=`a'+1
	save "${TEMP}/compustat_addresses`i'.dta", replace 
}
*/
clear 
forvalues i=1/18 {
	append using "${TEMP}/geocoding_done/compustat/compustat_geocoded_`i'.dta", clear
}


save "${TEMP}/geocoding_done/compustat/compustat_geocoded_final.dta"



use "${TEMP}/compustat.dta"
merge 1:1 gvkey using "${TEMP}/geocoding_done/compustat/compustat_geocoded_final.dta"