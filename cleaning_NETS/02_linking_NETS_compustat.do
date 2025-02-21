// Project: Inventor Relocation
// Creation Date: 03/05/2024
// Last Update: 03/05/2024
// Author: Laura Arnemann 
// Goal: Linking the NETS data and the Innovation data 

version 16.0

* First Import data on all Headquarters 
import delimited "${NETS_path}\NETS2022_Headquarters\NETS2022_HQCompany.txt", clear
save "${TEMP}/hqs.dta", replace
duplicates drop hqduns, force 
sort hqcompany 
gen count = _n 
save "${TEMP}/hqs_noduplicates.dta", replace

**
* Linking 
**

import excel "${LINKING}/matched_with_miles_la.xlsx", sheet("Sheet1") firstrow clear 
save "${TEMP}/linking1.dta", replace 


import excel "${LINKING}/matched_with_miles_la_2.xlsx", sheet("Sheet1") firstrow clear 
save "${TEMP}/linking2.dta", replace 

append using "${TEMP}/linking1.dta"

append using "${LINKING}/matched_with_miles_theresa.dta"


replace manual_check="0" if manual_check=="none"
drop if missing(manual_check)
drop if manual_check=="0"
drop if manual_check=="ß"


rename hqcompany compustat_company 

rename hqduns_pub hqduns1
rename hqduns_all hqduns2 
rename hqcompany_pub hqcompany1 
rename hqcompany_all hqcompany2 
rename similarity_all similarity2 
rename similarity_pub similarity1 
rename distance_pub distance1 
rename distance_all distance2 

bysort gvkey: gen count= _n 

tostring gvkey, replace 
tostring count, replace

gen id = gvkey + count
reshape long hqduns hqcompany similarity distance , i(id) j(source)

drop if source==1 & manual_check=="all"
drop if source==1 & manual_check=="sll"
drop if source==2 & manual_check=="pub"
drop if source==2 & manual_check=="pub/all" & comment=="" 
drop if source==2 & manual_check=="all/pub" & comment=="" 
drop if hqduns==-1
drop id 
duplicates drop gvkey hqduns, force 
* Where do these duplicates come form?

duplicates tag hqduns, gen(dup)

gen old = 0 
replace old = 1 if regexm(compustat_company, "-OLD")
bysort hqduns: egen max_old = max(old)

bysort hqduns: egen max_similarity =max(similarity)
drop if similarity!=max_similarity & dup>0 & max_old ==0 
drop dup
* Sometimes for the same hqduns we have different company names (?), match on hqduns and hqcompany to deal with this 
duplicates tag hqcompany hqduns, gen(dup)
matchit hqcompany compustat_company
bysort hqduns : egen max_similscore = max(similscore)
drop if dup>0 & max_old==0 & similscore!=max_similscore
drop dup 

* 14 observations which are not old remain, in two instances hqduns is the same but the name of the hqcompany not, in the other instances the compustat company has the same name 
drop count 
bysort hqduns: gen count = _n
egen id = group(hqcompany hqduns)
keep hqduns hqcompany gvkey compustat_company count id 
reshape wide gvkey compustat_company, i(id) j(count)
* 75 observations with nonmissing gvkey2, 2 observations with not missing gvkey 3  
drop id 
save "${TEMP}/linking.dta", replace 

* Merging in the establishments: 
use "${TEMP}/linking.dta", clear 
* Drop the duplicate hq observations, since the merge does not work for those. 
duplicates tag hqduns, gen(dup)
drop if dup!=0 
merge 1:m hqduns using "${TEMP}/hqs.dta"
keep if _merge==3 
drop _merge 
merge 1:1 dunsnumber using "${TEMP}/fips.dta"
keep if _merge!=2 
drop _merge 
save "${TEMP}/firmnetworks.dta", replace 


* Merging the establishments to their commuting zones 
use "${TEMP}/firmnetworks.dta", clear 
reshape long fips, i(dunsnumber) j(year)
destring year, replace 
replace year = 1900 + year if inrange(year, 90,99)
replace year = 2000 + year if inrange(year, 0, 22)
rename fips county_fips 
drop if missing(county_fips)

merge m:1 county_fips using "$IN\var_CommutingZones\CZ_combined.dta"
drop if _merge==2 
drop _merge 

drop CZ_depagri_2000 CZ_UScensus county_name_depagri CZ_depagri_1980
save "${TEMP}/firmnetworks_cz.dta", replace 


use "${TEMP}/adjacent_commuting_zones.dta", clear  
duplicates drop zone_id, force 
rename zone_id czone
tempfile adjacent_cz 
save `adjacent_cz'


use "${TEMP}/inventorcount_cz.dta", replace 
rename assignee_id gvkey 
tempfile inventorcount_cz
save `inventorcount_cz', replace 

use "${TEMP}/patentcount_czone.dta", replace 
rename assignee_id gvkey 
tempfile inventorcount_cz
save `patentcount_cz', replace 


* Matching the NETS companies 
use "${TEMP}/firmnetworks_cz.dta", clear 
rename gvkey1 gvkey 
rename year app_year 
rename CZ_depagri_1990 czone

merge m:1 czone using  `adjacent_cz'
drop if _merge ==2 
drop _merge 

split adjacent_zones, parse(,)

replace gvkey ="0" + gvkey if strlen(gvkey)==5 
replace gvkey = "00" + gvkey if strlen(gvkey)==4 
merge m:1 gvkey czone using `inventorcount_cz'
 
/* Result                           # of obs.
    -----------------------------------------
    not matched                     6,230,964
        from master                 6,144,124  (_merge==1)
        from using                     86,840  (_merge==2)

    matched                         1,351,974  (_merge==3)
    -----------------------------------------
*/
* 15.939 unique gvkey czone information merged 

preserve 
keep if _merge ==3
drop _merge 
save "${TEMP}/matched_gvkey_czone.dta", replace 

restore
drop if _merge ==2 | _merge ==3
drop _merge 
rename czone czone_old 


forvalues i =1/10 {
preserve 
rename adjacent_zones`i' czone 
destring czone, replace 
merge m:1 gvkey czone using "${TEMP}/patents_cz_gvkey.dta"
keep if _merge ==3 
drop _merge 
save "${TEMP}/matched_gvkey_czone_`i'.dta", replace 
restore 
}

 clear 
 forvalues i =1/10 {
 	append using "${TEMP}/matched_gvkey_czone_`i'.dta"
 }


save "${TEMP}/linked_gvkey_NETS.dta", replace 



********************************************************************************
**** MISC***********************************************************************
********************************************************************************

* Checking whether the HQ duns always identifies the ultimate HQ! Check whether Companies which are are not listed as their own headquarter appear as Headquarters
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

* Checking if one ownership link is enough to nail down ownership chain

use "${TEMP}/helper_ownership1.dta"
bysort ultimate_hqduns: gen count = _n 
keep if count ==1 
keep ultimate_hqduns 
rename ultimate_hqduns hqduns 
merge 1:m hqduns using "${TEMP}/helper2.dta"
keep if _merge ==3 
drop _merge 

save "${TEMP}/helper_ownership2.dta", replace


use "${TEMP}/helper_ownership2.dta"
bysort ultimate_hqduns: gen count = _n 
keep if count ==1 
keep ultimate_hqduns 
rename ultimate_hqduns hqduns 
merge 1:m hqduns using "${TEMP}/helper2.dta"
keep if _merge ==3 
drop _merge 
save "${TEMP}/helper_ownership3.dta", replace



use "${TEMP}/helper_ownership3.dta"
bysort ultimate_hqduns: gen count = _n 
keep if count ==1 
keep ultimate_hqduns 
rename ultimate_hqduns hqduns 
merge 1:m hqduns using "${TEMP}/helper2.dta"
keep if _merge ==3 
drop _merge 
save "${TEMP}/helper_ownership4.dta", replace

use "${TEMP}/helper_ownership4.dta"
bysort ultimate_hqduns: gen count = _n 
keep if count ==1 
keep ultimate_hqduns 
rename ultimate_hqduns hqduns 
merge 1:m hqduns using "${TEMP}/helper2.dta"
keep if _merge ==3 
drop _merge 

save "${TEMP}/helper_ownership5.dta", replace

use "${TEMP}/helper_ownership5.dta"
bysort ultimate_hqduns: gen count = _n 
keep if count ==1 
keep ultimate_hqduns 
rename ultimate_hqduns hqduns 
merge 1:m hqduns using "${TEMP}/helper2.dta"
keep if _merge ==3 
drop _merge 

save "${TEMP}/helper_ownership6.dta", replace

use "${TEMP}/helper_ownership6.dta"
bysort ultimate_hqduns: gen count = _n 
keep if count ==1 
keep ultimate_hqduns 
rename ultimate_hqduns hqduns 
merge 1:m hqduns using "${TEMP}/helper2.dta"
keep if _merge ==3 
drop _merge 

save "${TEMP}/helper_ownership7.dta", replace

erase "${TEMP}/helper2.dta"
erase "${TEMP}/helper1.dta"
