*Data cleaning NETS data

*Author: Theresa Bührle, tbuehrle@diw.de
*Last update: 06.10.2023


if user==1 {
	
	 cd "C:/Users/laura/Desktop/InnovationProject/data/raw"
}

else {
   cd "C:\Users\tbuehrle\Desktop\Work\Projects\Spillover inventors\NETS Daten\"
}

use "NETS2022_HQs_2000.dta", clear
	merge 1:1 dunsnumber using "NETS2022_Emps_2000", nogen

*Keep only estbalishments in groups ith > 10 employees	
bysort hqduns: egen empl_group = sum(emphere)
keep if empl_group >= 10

drop emp?? empc?? 

*Clean data
replace hqcompany = subinstr(hqcompany, " ", "", .)

*-Drop observations for towns, cities, counties etc.
drop if strpos(hqcompany,"CITYOF")>0
drop if strpos(hqcompany,"TOWNOF")>0
drop if strpos(hqcompany,"COUNTYOF")>0

*- Drop companies without address
drop if hqcompany == "DLISTED" // Check with historical data whether this can be filled
drop if hqaddress == ""

*Keep variables for geocoding
foreach var of varlist hqaddress hqcity {
	replace `var'=subinstr(`var',"  ","",.)
}
tostring hqzipcode, replace
gen hqaddress_python = hqaddress+ " " + hqcity + " " + hqstate
duplicates drop hqduns, force  
keep dunsnumber hqduns hqcompany hqaddress_python

forvalues i=1/40 {
	replace hqaddress_python=subinstr(hqaddress_python, "FL `i'", "", .)
}

foreach let in A B C D E F G H I J K L M N O P Q R S T U V W X Y Z {
	replace hqaddress_python=subinstr(hqaddress_python, "STE `let'", "", .)
}

save "NETS2022_adresses.dta", clear