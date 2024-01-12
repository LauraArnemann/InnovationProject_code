* Checking why the results from the merge changed 






use "${TEMP}/compustat_names_cleaned.dta", clear 
merge 1:m gvkey using "${TEMP}/linking_table/public_linkingtable1.dta", keepusing(hqduns)
keep if _merge==3 
drop _merge
rename hqduns hqduns_original 
save "${TEMP}/compustat_fuckup_1.dta", replace 

use "${IN}/main_data/data_NETS/NETS2022_hq_multiple.dta", clear 
duplicates drop hqduns, force 
merge 1:m hqduns using "${TEMP}/linking_table/public_linkingtable1.dta", keepusing(gvkey)
keep if _merge==3 
drop _merge
rename gvkey gvkey_master
rename hqcompany hqcompany_master
save "${TEMP}/NETS_fuckup_1.dta", replace 


use "${TEMP}/NETS2022_public_cleaned.dta"
merge 1:m hqduns using "${TEMP}/linking_table/public_linkingtable1.dta", keepusing(gvkey)
keep if _merge==3 
drop _merge
rename gvkey gvkey_using 
rename hqcompany hqcompany_using
save "${TEMP}/NETS_fuckup_2.dta", replace 



use "${TEMP}/NETS2022_public_cleaned.dta", clear 
merge 1:m hqduns using "${TEMP}/linking_table/public_linkingtable1.dta", keepusing(gvkey)
keep if _merge==2 
drop _merge
rename hqcompany hqcompany_using
save "${TEMP}/NETS_fuckup_public_notmerged.dta", replace 


use "${TEMP}/compustat_fuckup_1.dta", replace 
merge 1:1 gvkey using "${TEMP}/NETS_fuckup_public_notmerged.dta"
drop if _merge==3 
drop _merge 
keep hqduns hqcompany gvkey 
save "${TEMP}/compustat_fuckup_2.dta", replace 

use "${TEMP}/NETS_fuckup_2.dta", clear 
rename hqcompany_using hqcompany 
merge 1:m hqcompany using "${TEMP}/compustat_fuckup_2.dta"
sort hqcompany
br hqcompany _merge if _merge!=3 

use "${IN}/main_data/data_NETS/NETS2022_public_cleaned.dta", clear 
merge 1:1 dunsnumber using "${IN}/main_data/data_NETS/NETS2022_hq_multiple.dta"





















use "${TEMP}/NETS_fuckup_1.dta", clear 
merge 1:1 hqduns using "${TEMP}/NETS_fuckup_2.dta"
rename _merge original_merge 

merge 1:1 dunsnumber using "${IN}/main_data/data_NETS/public_companies.dta"

preserve 
keep if _merge==1 
keep hqduns hqcompany_master gvkey_master 
rename gvkey_master gvkey 
duplicates drop gvkey, force 
tempfile public_merge 
save `public_merge', replace 

restore
keep if _merge==3 
drop _merge 
rename hqcompany_using hqcompany
merge 1:1 hqcompany using "${TEMP}/compustat_fuckup_1.dta"
rename _merge first_merge 

merge m:1 gvkey using `public_merge'
drop if _merge ==3 

tab first_merge 


*br if _merge==1 