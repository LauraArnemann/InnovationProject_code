use "C:\Users\laura\Desktop\InnovationProject\data\matched_with_miles.dta", clear 
merge 1:1 gvkey using "C:\Users\laura\Desktop\InnovationProject\data\matched_with_miles_theresa.dta"
keep if _merge==1 
drop _merge 
* Drop all non-matched observations
drop if hqduns_all==-1 & hqduns_pub==-1
*(6,833 observations deleted)

* Drop all observations for which there is a unique match
drop if similarity_pub==1 & similarity_all==-1
*(1,315 observations deleted)
drop if similarity_all==1 & similarity_pub==-1
* 745 observations deleted
drop if hqduns_pub==hqduns_all & similarity_pub==1 & similarity_all==1
* (3,193 observations deleted)

export excel "C:\Users\laura\Desktop\InnovationProject\data\matched_with_miles.xlsx", firstrow(variables) replace

import excel "C:\Users\laura\Desktop\InnovationProject\data\matched_with_miles_la.xlsx", firstrow clear

replace manual_check="all" if hqcompany_pub=="" & similarity_all>=0.98 & distance_all<=1 
replace manual_check="pub" if hqcompany_all=="" & similarity_pub>=0.98
replace manual_check="pub/all" if hqduns_pub == hqduns_all & similarity_pub>=0.95
replace manual_check="pub" if similarity_pub>=0.98 & similarity_all<0.95 & distance_all>=0.1
replace manual_check="pub" if similarity_pub==1 & similarity_all<=0.95 
replace manual_check="all" if similarity_all==1 & similarity_pub<=0.95 & distance_all<=1
replace manual_check="pub" if similarity_pub==1 & distance_pub<=0.1

replace comment ="check" if similarity_all==1 & similarity_pub==1 
replace manual_check="pub/all" if similarity_all==1 & similarity_pub==1 
drop if manual_check!=""

*replace hqcompany_pub = subinstr(hqcompany,"-CLA","",.)
*replace hqcompany_pub = subinstr(hqcompany,"-OLD","",.)
*replace hqcompany_pub = subinstr(hqcompany,"(DEL)","",.)


*4095 observations left 
export excel "C:\Users\laura\Desktop\InnovationProject\data\matched_with_miles_la_2.xlsx", firstrow(variables) replace