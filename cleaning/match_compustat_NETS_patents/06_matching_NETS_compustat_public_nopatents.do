// Project: Inventor Relocation
// Creation Date: 04/10/2023
// Last Update: 04/10/2023
// Author: Laura Arnemann 
// Goal: Explicitly merge the companies from Compustat for which no patenting activity was recorded 

use "${TEMP}/nonmerged_companies_compustat.dta", clear 
merge 1:1 gvkey using  "${TEMP}/linking_table/public_linkingtable1_v2.dta"
keep if _merge==1
drop _merge 
replace hqcompany = subinstr(hqcompany," ","",.)
replace hqcompany = subinstr(hqcompany,"CORPORATION","CORP",.)
replace hqcompany = subinstr(hqcompany, "(THE)", "", .)
*replace hqcompany = subinstr(hqcompany,"(DEL)","",.)
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


drop hqduns 
save "${TEMP}/nonmerged_companies_compustat_1.dta", replace 


reclink hqcompany using "${TEMP}/NETS_notmerged1.dta", gen(myscore) idm(gvkey) idu(hqduns) 
keep if _merge==3 
keep if Uhqcompany!=""
keep if myscore>=0.9 
keep Uhqcompany hqcompany gvkey hqduns myscore 
export excel using "${TEMP}/matched_reclink_nopatents.xlsx", replace firstrow(variables)