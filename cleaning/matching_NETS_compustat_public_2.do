// Project: Inventor Relocation
// Creation Date: 04/10/2023
// Last Update: 04/10/2023
// Author: Laura Arnemann 
// Goal: Name Matching compustat and NETS data which were indicated as public companies in data set, but without multiple establishments 


use "${IN}/main_data/data_NETS/hq_companies_public.dta", clear 

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

gen int_lat=int(latitude)
gen int_lon=int(longitude)

save "${IN}/main_data/data_NETS/hq_companies_public_cleaned.dta", replace 


use "${TEMP}/compustat_nonmerged4.dta", clear
drop Uhqcompany Uhqzipcode Matching_control H 
reclink hqcompany using "${IN}/main_data/data_NETS/hq_companies_public_cleaned.dta", gen(myscore) idm(gvkey) idu(hqduns) 
keep if myscore >0.9 
keep hqduns gvkey hqcompany Uhqcompany NETSzipcode hqzipcode 
export excel using "${TEMP}/matched_reclink_patents_public_name.xlsx", replace firstrow(variables)


