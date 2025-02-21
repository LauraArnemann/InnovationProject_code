// Project: Inventor Relocation
// Creation Date: 03/05/2024
// Last Update: 03/05/2024
// Author: Laura Arnemann 
// Goal: Cleaning Headquarters to identify the ultimate headquarter 

version 16.0 

global NETS_path H:/data/2022_NETS_database
global TEMP H:/data/temp

* Import data on counties 
import delimited "${NETS_path}/NETS2022_Misc/NETS2022_FIPS.txt", clear
save "${TEMP}/FIPS.dta", replace

* Import data on Locations 
import delimited "${NETS_path}/NETS2022_Headquarters/NETS2022_HQCompany.txt", clear
save "${TEMP}/hqs.dta", replace

* Generating the first ownership link 
use hqduns dunsnumber using "${TEMP}/hqs.dta", clear 

bysort hqduns: gen count = _N 
keep if count>1 

drop count
bysort hqduns: gen count = _n 
keep if count ==1 
keep hqduns
save "${TEMP}/helper1.dta"

* Only keep companies which are not their own headquarters 
use hqduns dunsnumber using "${TEMP}/hqs.dta", clear 

bysort hqduns: gen count = _N 
keep if count>1 

keep if dunsnumber!=hqduns 
keep dunsnumber hqduns
rename hqduns ultimate_hqduns 
rename dunsnumber hqduns 
save "${TEMP}/helper2.dta"

merge 1:1 hqduns using "${TEMP}/helper1.dta"
br if _merge==3
keep if _merge ==3 
drop _merge 
save "${TEMP}/helper_ownership1.dta", replace




********************************************************************************
* Second Link in Ownership Chain
********************************************************************************


use "${TEMP}/helper_ownership1.dta"
bysort ultimate_hqduns: gen count = _n 
keep if count ==1 
keep ultimate_hqduns 
rename ultimate_hqduns hqduns 
merge 1:m hqduns using "${TEMP}/helper2.dta"
keep if _merge ==3 
drop _merge 

save "${TEMP}/helper_ownership2.dta", replace


/*
* Executing this command does not generate any additional information, apparently two links suffice to determine the ultimate headquarter company

use "${TEMP}/helper_ownership2.dta"
bysort ultimate_hqduns: gen count = _n 
keep if count ==1 
keep ultimate_hqduns 
rename ultimate_hqduns hqduns 
merge 1:m hqduns using "${TEMP}/helper2.dta"
keep if _merge ==3 
drop _merge 
save "${TEMP}/helper_ownership3.dta", replace

*/

********************************************************************************
* Generate a dataset only containing the "ultimate" headquarters of multi-state
* establishment firms 
********************************************************************************

use hqduns dunsnumber using "${TEMP}/hqs.dta", clear 
bysort hqduns: gen count = _N 
keep if count>1 

drop count
merge m:1 hqduns using "${TEMP}/helper_ownership1.dta"

replace ultimate_hqduns = hqduns if _merge!=3
drop hqduns 
rename ultimate_hqduns hqduns 
drop _merge 

merge m:1 hqduns  using "${TEMP}/helper_ownership2.dta"

replace ultimate_hqduns = hqduns if _merge!=3
drop hqduns 
rename ultimate_hqduns hqduns 
drop _merge 

save "${TEMP}/cleaned_owners.dta", replace 

erase "${TEMP}/helper2.dta"
erase "${TEMP}/helper1.dta"



********************************************************************************
* Generate a dataset with a matching of dunsnumbers, hqduns, hqname, hqtradename, 
* then match that with the commuting zones 
********************************************************************************
use "${TEMP}/hqs.dta", clear 

keep hqduns hqcompany hqtradename 
bysort hqduns hqcompany hqtradename: gen count = _n 
keep if count ==1 
drop count
save "${TEMP}/help.dta"

use "${TEMP}/cleaned_owners.dta"
merge m:1 hqduns using "${TEMP}/help.dta"

keep if _merge ==3 
drop _merge 

save "${TEMP}/hq_prepped_merging.dta", replace 





 


