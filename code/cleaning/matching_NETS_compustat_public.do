// Project: Inventor Relocation
// Creation Date: 04/10/2023
// Last Update: 04/10/2023
// Author: Laura Arnemann 
// Goal: Name Matching compustat and NETS data which were indicated as public companies in data set 


use "${IN}/gvkey_patents.dta", clear
destring gvkey, replace 
save "${TEMP}/patmatch.dta", replace 


use "${TEMP}/compustat.dta", clear
merge 1:m gvkey using "${TEMP}/patmatch.dta" , keepusing(gvkey)
* patents from 27 companies not matched 
gen nopatents=1 if _merge==1 
drop indfmt consol popsrc datafmt curcd costat datadate
keep if _merge==1 
duplicates drop gvkey, force 
drop _merge 
save "${TEMP}/nonmerged_companies_compustat.dta", replace 


use "${IN}/NETS2022_hq_multiple.dta", clear 

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

merge 1:1 dunsnumber using "${IN}/public_private/public_companies.dta"
keep if _merge==3 
*  5,805 companies not merged 
drop _merge 
duplicates drop hqduns, force  

rename hqzipcode zipNETS 
save "${TEMP}/NETS2022_public_cleaned.dta", replace 


use "${TEMP}/compustat.dta", clear
merge 1:m gvkey using `patmatch' 
gen nopatents=1 if _merge==1 
keep if missing(nopatents)
drop _merge 
duplicates drop gvkey, force  

* 42979 unique gvkeys 
*Companies with duplicates hqcompanies: ISHARES TRUST ISHARES ESG AW ; UNILEVER PLC; WARNER CHILCOTT PLC 
duplicates drop hqcompany, force  

* 3 duplicates hqcompanies 

replace hqcompany = subinstr(hqcompany," ","",.)
replace hqcompany = subinstr(hqcompany,"CORPORATION","CORP",.)
replace hqcompany = subinstr(hqcompany, "(THE)", "", .)
replace hqcompany = subinstr(hqcompany,"/NV","",.)
replace hqcompany = subinstr(hqcompany,"TECHNNOLOGIES","TECH",.)
replace hqcompany = subinstr(hqcompany,"TECHNNOLOGY","TECH",.)
replace hqcompany = subinstr(hqcompany,"GRP","GROUP",.)
replace hqcompany = subinstr(hqcompany,"INCORPORATED","",.)
replace hqcompany = subinstr(hqcompany,"INC","",.)
replace hqcompany = subinstr(hqcompany,"-ADR","",.)
replace hqcompany = subinstr(hqcompany,"-SPN","",.)
replace hqcompany = subinstr(hqcompany,"PLC","",.)
replace hqcompany = subinstr(hqcompany,"(HOLDINGS)","",.)
replace hqcompany = subinstr(hqcompany,"LTD","LIMITED",.)
replace hqcompany = subinstr(hqcompany,".","",.)
replace hqcompany = subinstr(hqcompany,"PHARMATICALS","PHARMACEUTICALS",.)
replace hqcompany = subinstr(hqcompany,"RSRTS","RESORTS",.)
replace hqcompany = subinstr(hqcompany,"-RDH","",.)
replace hqcompany = subinstr(hqcompany,"-ADS","",.)
replace hqcompany = subinstr(hqcompany,"()","",.)

*53 companies which appeared two times 
duplicates drop hqcompany, force 
destring hqzipcode, replace force 
save "${TEMP}/compustat_names_cleaned.dta", replace 

********************************************************************************
* 1st attempt match based on exact name-matching 
********************************************************************************
use "${TEMP}/compustat_names_cleaned.dta", clear 
merge 1:m hqcompany using "${TEMP}/NETS2022_public_cleaned.dta"


* Only companies which recorded some sort of patenting activity 
/*
    Result                      Number of obs
    -----------------------------------------
    Not matched                        21,482
        from master                     7,470  (_merge==1)
        from using                     14,012  (_merge==2)

    Matched                             9,976  (_merge==3)
    -----------------------------------------
*/ 





/* 


    Result                      Number of obs
    -----------------------------------------
    Not matched                        47,672
        from master                    33,396  (_merge==1)
        from using                     14,276  (_merge==2)

    Matched                             9,712  (_merge==3)
    -----------------------------------------


*/ 

 * This affects 172 observations 

keep if _merge==3
duplicates tag gvkey, gen(dup)
drop if dup>0 & hqzipcode!= zipNETS 
* Figure out where the duplicates come from 
duplicates drop gvkey, force 

keep gvkey hqduns 
*3978 observations matched
save "${TEMP}/linking_table/public_linkingtable1.dta", replace 


use "${TEMP}/compustat_names_cleaned.dta", clear 
merge 1:1 gvkey using "${TEMP}/linking_table/public_linkingtable1.dta"
keep if _merge==1
drop _merge 
drop hqduns 
save "${TEMP}/compustat_notmerged1.dta", replace 


use "${TEMP}/NETS2022_public_cleaned.dta", clear 
merge 1:1 hqduns using "${TEMP}/linking_table/public_linkingtable1.dta"
keep if _merge==1
drop _merge 
rename zipNETS hqzipcode 
drop gvkey 
save "${TEMP}/NETS_notmerged1.dta", replace 

********************************************************************************
* 2nd attempt: Fuzzy merge with the Name 
********************************************************************************

use "${TEMP}/compustat_notmerged1.dta", replace 
reclink hqcompany using "${TEMP}/NETS_notmerged1.dta", gen(myscore) idm(gvkey) idu(hqduns) 
keep if _merge==3 
keep if Uhqcompany!=""
keep if myscore>=0.9 
keep Uhqcompany hqcompany gvkey hqduns myscore 
export excel using "${TEMP}/matched_reclink_patents.xlsx", replace firstrow(variables)

********************************************************************************
* I went through the excel manually to check that the matched data are indeed similar
********************************************************************************

import excel "${TEMP}/matched_reclink_patents_bearbeitet.xlsx", clear firstrow
destring match, replace 
* 1003 companies matched 
merge m:1 gvkey using "${TEMP}/compustat_notmerged1.dta", keepusing(hqzipcode)
keep if _merge==3 
drop _merge 
rename hqzipcode hqzipcode_compustat 

merge m:1 hqduns using "${TEMP}/NETS_notmerged1.dta", keepusing(hqzipcode)
keep if _merge==3 
drop _merge 

* Only keep the observations that were matched based on 

gen flag=0 
replace flag=1 if hqzipcode==hqzipcode_compustat 
keep if match==1 | flag==1
* 55% not matched based on zipcode, what should we do with these data points? 
keep hqzipcode hqzipcode_compustat hqcompany Uhqcompany gvkey hqduns 
save "${TEMP}/linking_table/public_linkingtable2.dta", replace 


********************************************************************************
* Merge with the linking table 
********************************************************************************

use "${TEMP}/compustat_notmerged1.dta", clear 
merge 1:m gvkey using "${TEMP}/public_linkingtable2.dta", keepusing(gvkey)
keep if _merge==1 
drop _merge 
save "${TEMP}/compustat_notmerged2.dta", replace 


use "${TEMP}/NETS_notmerged1.dta", clear
merge 1:m hqduns using "${TEMP}/public_linkingtable2.dta", keepusing(gvkey) 
keep if _merge==1 
drop _merge 
save "${TEMP}/NETS_notmerged2.dta", replace 


********************************************************************************
* 3rd attempt: Reclink merge with geocoding and company name: This was not successful 
********************************************************************************

/*
use "${TEMP}/NETS_notmerged1.dta", replace 
merge 1:1 hqduns using "${TEMP}/geocoding_done/NETS/NETS_geocoded_cleaned_1.dta", keepusing(latNETS longNETS )
keep if _merge==3 
drop _merge 

merge 1:1 hqduns using "${TEMP}/linking_table/public_linkingtable1.dta", keepusing(hqduns)
keep if _merge==1
drop _merge 

merge 1:m hqduns using "${TEMP}/linking_table/public_linkingtable2.dta", keepusing(hqduns)
keep if _merge==1
drop _merge 


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

gen int_lon=int(longNETS)
gen int_lat=int(latNETS)
tempfile NETS 
save `NETS', replace 



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


reclink hqcompany int_lon int_lat using `NETS' , gen(myscore) idm(gvkey) idu(hqduns) 


*/





 
