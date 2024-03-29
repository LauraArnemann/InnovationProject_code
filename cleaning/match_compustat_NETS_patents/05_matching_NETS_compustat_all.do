// Project: Inventor Relocation
// Creation Date: 04/10/2023
// Last Update: 04/10/2023
// Author: Laura Arnemann 
// Goal: Name Matching compustat and NETS data which were indicated as public companies in data set 


* For now only establishments with multiple headquarters; probably all Compustat companies will have multiple establishments 
********************************************************************************
*  Prepare NETS Data 
******************************************************************************** 

use "${TEMP}/NETS2022_hq_multiple.dta", clear 

drop if hqcompany=="DLISTED" 
replace hqcompany=subinstr(hqcompany,"INC","INCORPORATED",.)
replace hqcompany = subinstr(hqcompany,"CORPORATION","CORP",.)
replace hqcompany = subinstr(hqcompany, "(THE)", "", .)
replace hqcompany = subinstr(hqcompany,"INCORPORATED","",.)
replace hqcompany = subinstr(hqcompany,"TECHNNOLOGIES","TECH",.)
replace hqcompany = subinstr(hqcompany,"TECHNNOLOGY","TECH",.)
replace hqcompany = subinstr(hqcompany,"COMPANY","CO",.)
replace hqcompany = subinstr(hqcompany,"PLC","",.)
replace hqcompany = subinstr(hqcompany,"(HOLDINGS)","",.)
replace hqcompany = subinstr(hqcompany,"LTD","LIMITED",.)
replace hqcompany = subinstr(hqcompany,".","",.)
replace hqcompany = subinstr(hqcompany,"PHARMATICALS","PHARMACEUTICALS",.)
replace hqcompany = subinstr(hqcompany,"RSRTS","RESORTS",.)
replace hqcompany = subinstr(hqcompany,"-RDH","",.)
replace hqcompany = subinstr(hqcompany,"-ADS","",.)
replace hqcompany = subinstr(hqcompany,"-NV","",.)
replace hqcompany = subinstr(hqcompany,"(THE)","",.)
replace hqcompany = subinstr(hqcompany,"-OLD","",.)
replace hqcompany = subinstr(hqcompany,"()","",.)
replace hqcompany = subinstr(hqcompany,"(","",.)
replace hqcompany = subinstr(hqcompany,")","",.)
replace hqcompany = subinstr(hqcompany,"-CLA","",.)
replace hqcompany = subinstr(hqcompany,"(","",.)
replace hqcompany = subinstr(hqcompany,")","",.)
replace hqcompany = subinstr(hqcompany,"(DEL)","",.)
replace hqcompany = subinstr(hqcompany,"-REDH","",.)
replace hqcompany = subinstr(hqcompany,"MANAGEMENT","MGT",.)
replace hqcompany = subinstr(hqcompany,"RESOURCES","RES",.)
replace hqcompany = subinstr(hqcompany,"PHARMACEUTICALS","PHARMA",.)
replace hqcompany = subinstr(hqcompany,"PHARMACEUTICAL","PHARMA",.)
replace hqcompany = subinstr(hqcompany,"INTERNATIONAL","INTL",.)
replace hqcompany = subinstr(hqcompany,"SERVICES","SVCS",.)
replace hqcompany = subinstr(hqcompany,"MATERIALS","MTLS",.)
replace hqcompany = subinstr(hqcompany,"LABORATORIES","LABS",.)
replace hqcompany = subinstr(hqcompany,"LABORATORY","LAB",.)


foreach char in "'" ".""!" "?" "*" ","{
	qui replace hqcompany = subinstr(hqcompany, "`char'",  "",.)
}

foreach char in "'" ".""!" "?" "*" ","{
	qui replace hqcompany = subinstr(hqcompany, "`char'",  "",.)
}

duplicates drop hqduns, force
drop if missing(hqcompany)

rename hqzipcode NETSzipcode 
save "${TEMP}/NETS2022_hq_multiple_cleaned.dta", replace 


********************************************************************************
*  Prepare Compustat Data 
******************************************************************************** 

clear 
forvalues i=1/18 {
	append using "${TEMP}/geocoding_done/compustat/compustat_geocoded_`i'.dta", force 
	*981 observations without latitude or longitude for most hqdadress is missing  	
}

tempfile geocoding_compustat 
save `geocoding_compustat', replace 


use "${TEMP}/compustat_notmerged2.dta", clear 
 merge 1:1 gvkey using `geocoding_compustat' , keepusing(lat lon)
 drop if _merge==2 
 drop _merge 
 * 190 gvkeys do not have latitude or longitude 
 drop if missing(gvkey)



replace hqcompany = subinstr(hqcompany,"-CLA","",.)
replace hqcompany = subinstr(hqcompany,"(","",.)
replace hqcompany = subinstr(hqcompany,")","",.)
replace hqcompany = subinstr(hqcompany,"(DEL)","",.)
replace hqcompany = subinstr(hqcompany,"-REDH","",.)
replace hqcompany = subinstr(hqcompany,"MANAGEMENT","MGT",.)
replace hqcompany = subinstr(hqcompany,"RESOURCES","RES",.)
replace hqcompany = subinstr(hqcompany,"PHARMACEUTICALS","PHARMA",.)
replace hqcompany = subinstr(hqcompany,"PHARMACEUTICAL","PHARMA",.)
replace hqcompany = subinstr(hqcompany,"INTERNATIONAL","INTL",.)
replace hqcompany = subinstr(hqcompany,"SERVICES","SVCS",.)
replace hqcompany = subinstr(hqcompany,"MATERIALS","MTLS",.)
replace hqcompany = subinstr(hqcompany,"LABORATORIES","LABS",.)
replace hqcompany = subinstr(hqcompany,"LABORATORY","LAB",.)

gen int_lon=int(lon)
gen int_lat=int(lat)

duplicates tag hqcompany, gen(dup)
drop if dup>0 & fyear==1950 
drop if dup>0 


save "${TEMP}/compustat_notmerged2_cleaned.dta", replace 

********************************************************************************
* Direct Name to Name matching: with all NETS observations that had multiple headquarters 
********************************************************************************

merge 1:m hqcompany using "${TEMP}/NETS2022_hq_multiple_cleaned.dta"
* 978 gvkey matched 
drop dup
keep if _merge==3
duplicates tag gvkey, gen(dup)
drop if dup>0 & hqzipcode!= NETSzipcode
* Figure out where the duplicates come from 
duplicates drop gvkey, force 

keep gvkey hqduns 
save "${TEMP}/linking_table/nonpublic_linkingtable3.dta", replace 


use "${TEMP}/compustat_notmerged2_cleaned.dta"
merge 1:1 gvkey using "${TEMP}/linking_table/nonpublic_linkingtable3.dta"
keep if _merge==1 
drop _merge 
drop hqduns 
save "${TEMP}/compustat_nonmerged3.dta", replace 

use "${TEMP}/NETS2022_hq_multiple_cleaned.dta", clear 
merge 1:1 hqduns using "${TEMP}/linking_table/nonpublic_linkingtable3.dta"
keep if _merge==1 
drop _merge 
rename NETSzipcode hqzipcode 
drop gvkey 
save "${TEMP}/NETS_nonmerged3_all.dta", replace 


********************************************************************************
* Fuzzy Name-to-Name matching using reclink command 
********************************************************************************

use "${TEMP}/compustat_nonmerged3.dta", clear 
reclink hqcompany hqzipcode using "${TEMP}/NETS_nonmerged3_all.dta", gen(myscore) idm(gvkey) idu(hqduns) 
keep if myscore>0.9
keep if _merge==3 
keep hqduns gvkey hqcompany Uhqcompany Uhqzipcode hqzipcode

export excel using "${TEMP}/matched_reclink_patents_all_zipcode_name.xlsx", replace firstrow(variables)

********************************************************************************
* An RA manually assessed the quality of the match: Then read it in again 
********************************************************************************

import excel using "${TEMP}/matched_reclink_patents_all_zipcode_name_reviewed.xlsx", firstrow clear 
keep if Matching_control==1 
duplicates tag gvkey if Matching_control==1, gen(dup)
drop if dup==1 
drop dup 
duplicates tag hqduns if Matching_control==1, gen(dup)
drop if dup==1
drop dup 
* two companies, which we will probably need to research independently 
save "${TEMP}/linking_table/nonpublic_linkingtable4.dta", replace 

use "${TEMP}/compustat_nonmerged3.dta", clear 
merge 1:1 gvkey using "${TEMP}/linking_table/nonpublic_linkingtable4.dta"
keep if _merge==1 
drop _merge 
drop hqduns 
save "${TEMP}/compustat_nonmerged4.dta", replace 


* Generate new linking table based on work from RA


* Match with all companies that reported being a public company 

use "${TEMP}/compustat_nonmerged4.dta", clear
drop Uhqcompany Uhqzipcode Matching_control H 
reclink hqcompany using "${IN}/main_data/data_NETS/hq_companies_public_cleaned.dta", gen(myscore) idm(gvkey) idu(hqduns) 
keep if myscore >0.9 
keep hqduns gvkey hqcompany Uhqcompany NETSzipcode hqzipcode 
export excel using "${TEMP}/matched_reclink_patents_public_name.xlsx", replace firstrow(variables)

* Again this was checked manually by an RA 


import excel using "${TEMP}/matched_reclink_patents_public_name_bearbeitet.xlsx", firstrow clear
keep if Match==1 
duplicates tag gvkey, gen(dup)
duplicates drop gvkey, force 
* This deletes two observations 
keep gvkey hqduns 
save "${TEMP}/linking_table/nonpublic_linkingtable5.dta"


********************************************************************************
* Merge with all headquarters of publicly listed companies not only those with
* multiple establishments 
********************************************************************************






/*
********************************************************************************
*  Carrying out the Merge 
********************************************************************************
reclink hqcompany int_lon int_lat using `NETS' , gen(myscore) idm(gvkey) idu(hqduns) 