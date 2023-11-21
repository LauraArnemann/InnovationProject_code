// Project: Inventor Relocation
// Creation Date: 04/10/2023
// Last Update: 04/10/2023
// Author: Laura Arnemann 
// Goal: Matching Compustat and NETS data 


global CEO_IN C:/Users/laura/Desktop/data/CEOProject/rawdata
global TEMP C:/Users/laura/Desktop/InnovationProject/data
global compustat_IN C:/Users/laura/Desktop/InnovationProject/data/geocoding_done/compustat


********************************************************************************
* Preparing NETS data to merge with Compustat 
********************************************************************************

use "${TEMP}/geocoding_done/NETS/NETS_geocoded.dta", clear
replace longNETS=-longNETS 
gen int_lon=int(longNETS)
gen int_lat=int(latNETS)
 
* Cleaning the Strings to improve the Name matching 

*replace hqcompany=subinstr(hqcompany,"COMPANY","CO",.)
replace hqcompany=subinstr(hqcompany,"INC","INCORPORATED",.)
replace hqcompany = subinstr(hqcompany,"CORPORATION","CORP",.)
replace hqcompany = subinstr(hqcompany,"INCORPORATED","",.)
replace hqcompany = subinstr(hqcompany,"TECHNNOLOGIES","TECH",.)
replace hqcompany = subinstr(hqcompany,"TECHNNOLOGY","TECH",.)
replace hqcompany = subinstr(hqcompany,"COMPANY","CO",.)
replace hqcompany = subinstr(hqcompany,"PLC","",.)
replace hqcompany = subinstr(hqcompany,"(HOLDINGS)","",.)
replace hqcompany = subinstr(hqcompany,"NV","",.)
replace hqcompany = subinstr(hqcompany,"LTD","LIMITED",.)
replace hqcompany = subinstr(hqcompany,".","",.)
replace hqcompany = subinstr(hqcompany,"PHARMATICALS","PHARMACEUTICALS",.)
replace hqcompany = subinstr(hqcompany,"RSRTS","RESORTS",.)
replace hqcompany = subinstr(hqcompany,"-RDH","",.)
replace hqcompany = subinstr(hqcompany,"-ADS","",.)


save "${TEMP}/geocoding_done/NETS/NETS_geocoded_cleaned.dta", replace 



********************************************************************************
* Name and Latitude/Longitude: NETS and Compustat Data 
********************************************************************************
clear
forvalues i=1/11 {
	append using "${compustat_IN}/addresses_geocoded`i'.dta", force 
}
drop if missing(lon)
append using "${compustat_IN}/missing_geocoded_compustat.dta", force 
duplicates drop gvkey, force  
*drops around 10 observations 
tempfile compustat_geocoded 
save `compustat_geocoded', replace 


merge 1:1 gvkey using "${TEMP}/compustat.dta"
keep if _merge==3 
drop _merge 

tostring naics, replace 
gen naics_2_digit=substr(naics,1,2)
destring naics_2_digit, replace  
drop if naics_2_digit==52

keep lon lat hqcompany hq_address_compustat gvkey
save "${TEMP}/compustat_geocoded.dta", replace 



*use "${TEMP}/geocoding_done/compustat/compustat_geocoded.dta", clear 

use "${TEMP}/compustat_geocoded.dta", replace 

replace hqcompany = subinstr(hqcompany," ","",.)

replace hqcompany = subinstr(hqcompany,"CORPORATION","CORP",.)
replace hqcompany = subinstr(hqcompany, "(THE)", "", .)
replace hqcompany = subinstr(hqcompany,"INC","INCORPORATED",.)
replace hqcompany = subinstr(hqcompany,"/NV","",.)
replace hqcompany = subinstr(hqcompany,"TECHNNOLOGIES","TECH",.)
replace hqcompany = subinstr(hqcompany,"TECHNNOLOGY","TECH",.)
replace hqcompany = subinstr(hqcompany,"GRP","GROUP",.)
replace hqcompany = subinstr(hqcompany,"INCORPORATED","",.)
replace hqcompany = subinstr(hqcompany,"-ADR","",.)
replace hqcompany = subinstr(hqcompany,"-SPN","",.)
replace hqcompany = subinstr(hqcompany,"PLC","",.)
replace hqcompany = subinstr(hqcompany,"(HOLDINGS)","",.)
replace hqcompany = subinstr(hqcompany,"NV","",.)
replace hqcompany = subinstr(hqcompany,"LTD","LIMITED",.)
replace hqcompany = subinstr(hqcompany,".","",.)
replace hqcompany = subinstr(hqcompany,"PHARMATICALS","PHARMACEUTICALS",.)
replace hqcompany = subinstr(hqcompany,"RSRTS","RESORTS",.)
replace hqcompany = subinstr(hqcompany,"-RDH","",.)
replace hqcompany = subinstr(hqcompany,"-ADS","",.)


gen int_lon=int(lon)
gen int_lat=int(lat)
merge 1:m hqcompany int_lat int_lon using "${TEMP}/geocoding_done/NETS/NETS_geocoded_cleaned.dta"

/*
    Result                      Number of obs
    -----------------------------------------
    Not matched                       892,760
        from master                     4,268  (_merge==1)
        from using                    888,492  (_merge==2)

    Matched                             2,360  (_merge==3)
    -----------------------------------------
*/

keep if _merge==3
drop _merge 
duplicates tag gvkey, gen(dup)
gen distance =abs(lat - latNETS)
bysort gvkey: egen min_distance=min(distance)
keep if distance==min_distance
drop count
bysort gvkey: gen count=_N 
br if count>1 
* Only keep the closest matched headquarters
keep if count==1 
keep gvkey hqduns hqcompany 
save "${TEMP}/linking_table/linking_table1.dta", replace 



********************************************************************************
* Only Name Matching: In particular for Pharmaceuticals HQ company in Compustat 
* somewhere abroad (mostly Ireland) 
********************************************************************************

* Erase the matched data from NETS and compustat 
use "${TEMP}/compustat_geocoded.dta", clear 
merge 1:1 gvkey using "${TEMP}/linking_table/linking_table1.dta"
keep if _merge==1 
drop _merge 
drop hqduns 
save "${TEMP}/geocoding_done/compustat/compustat_geocoded_1.dta", replace 


use "${TEMP}/geocoding_done/NETS/NETS_geocoded_cleaned.dta", replace 
merge 1:1 hqduns using "${TEMP}/linking_table/linking_table1.dta"
keep if _merge==1 
drop _merge 
drop gvkey 
keep latNETS longNETS hqduns hqaddress hqcompany
save "${TEMP}/geocoding_done/NETS/NETS_geocoded_cleaned_1.dta", replace 


********************************************************************************
* Merging using the reclink package 
********************************************************************************

use "${TEMP}/geocoding_done/compustat/compustat_geocoded_1.dta"

reclink hqcompany using "${TEMP}/geocoding_done/NETS/NETS_geocoded_cleaned_1.dta", gen(myscore) idm(gvkey) idu(hqduns) 

* matches 334 observations 
save "${TEMP}/name_matching_reclink.dta", replace 



use "${TEMP}/name_matching_reclink.dta", clear 

gen int_lon_NETS=int(longNETS)
gen int_lat_NETS=int(latNETS)

gen int_lon=int(lon)
gen int_lat=int(lat)

gen indicator=1 if myscore>=0.9 & int_lon==int_lon_NETS & int_lat==int_lat_NETS
keep if myscore>=0.95 & indicator==. 
keep Uhqcompany hqcompany hqduns int_lon int_lat int_lon_NETS int_lat_NETS 
export excel using "${TEMP}/reclink_match.xlsx", firstrow(variables) replace 


use "${TEMP}/geocoding_done/NETS/NETS_geocoded_cleaned_1.dta", clear 
********************************************************************************
* Geomatching: Runy Jupyter Notebook geomatching 
********************************************************************************

* geomatching.ipynb 

* After running the first matching batch through python 

use "${TEMP}/geocoding_done/geomatch_attempt1.dta", clear 

rename index_right hqduns 
keep if similarity_score>=0.6 
* 340 observations 
duplicates tag gvkey, gen(dup)

sort gvkey similarity_score 
bysort gvkey: gen count=_n 
keep if count==1 
drop count
drop dup 

duplicates tag hqduns, gen(dup)

sort hqduns similarity_score 
bysort hqduns: gen count=_n 
keep if count==1 
drop count
drop dup 


rename hqcompany_left hqcompany_compustat
keep gvkey hqduns hqcompany_compustat

save "${TEMP}/linking_table/linking_table2.dta", replace 



* Erase the matched data from NETS and compustat 
use "${TEMP}/geocoding_done/compustat/compustat_geocoded_1.dta", clear 
merge 1:1 gvkey using "${TEMP}/linking_table/linking_table2.dta"
keep if _merge==1 

drop _merge 
drop hqduns 
save "${TEMP}/geocoding_done/compustat/compustat_geocoded_2.dta", replace 


use "${TEMP}/geocoding_done/NETS/NETS_geocoded_cleaned_1.dta", clear 
merge m:1 hqduns using "${TEMP}/linking_table/linking_table2.dta"
keep if _merge==1 
drop _merge 
drop gvkey 
keep latNETS longNETS hqduns hqaddress hqcompany
save "${TEMP}/geocoding_done/NETS/NETS_geocoded_cleaned_2.dta", replace 


use "${TEMP}/geocoding_done/geomatch2.dta", clear 
merge m:1 gvkey using "${TEMP}/geocoding_done/compustat/compustat_geocoded_2.dta"
drop hqcompany_compustat
keep if _merge==3 
rename hqcompany hqcompany_compustat 
drop _merge 
merge m:1 hqduns using "${TEMP}/geocoding_done/NETS/NETS_geocoded_cleaned_2.dta"
rename hqcompany hqcompany_NETS
keep if _merge==3  
drop _merge 

save "${TEMP}/geocoding_done/geomatch_names.dta", replace 
*2.184 observations not merged 


* For some reason only five companies are matched following this procedure (?) 
use "${TEMP}/geocoding_done/compustat/compustat_geocoded_1.dta", replace 
merge 1:m hqcompany using "${TEMP}/geocoding_done/NETS/NETS_geocoded_cleaned_1.dta"



* Make an Excel with all the values between 0.6 and 0.7 to compare whether or not the match was correct 

use "${TEMP}/geocoding_done/geomatch_attempt1.dta", clear 

rename index_right hqduns 
keep if inrange(similarity_score,0.6,0.7) 
duplicates tag gvkey, gen(dup)

sort gvkey similarity_score 
rename hqcompany_left hqcompany_compustat
keep gvkey hqduns hqcompany_compustat hqcompany_right similarity_score 

export excel using "${TEMP}/notmatched.xlsx", replace firstrow(variables)


use "${TEMP}/geocoding_done/compustat/compustat_geocoded_1.dta", clear 
merge 1:1 gvkey using "${TEMP}/linking_table/linking_table2.dta"
keep if _merge==1 
drop _merge 
drop hqduns 
save "${TEMP}/geocoding_done/compustat/compustat_geocoded_2.dta", replace 


use "${TEMP}/geocoding_done/NETS/NETS_geocoded_cleaned_1.dta", replace 
merge 1:m hqduns using "${TEMP}/linking_table/linking_table2.dta"
keep if _merge==1 
drop _merge 
drop gvkey 
keep latNETS longNETS hqduns hqaddress hqcompany
sort hqduns 
gen count=_n 
keep if count< 10000
save "${TEMP}/geocoding_done/NETS/NETS_geocoded_cleaned_2.dta", replace 


