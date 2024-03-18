// Project: Inventor Relocation
// Creation Date: 06/12/2023
// Last Update: 06/12/2023
// Author: Laura Arnemann 
// Goal: Preparing the State Level Data 


import excel "${IN}/indep_var/var_state/unemployment.xlsx", sheet("ststdsadata") firstrow clear 

drop E F G H I J 
rename fips_code fips_state
drop if fips_state=="51000"
* New York City listed separately 
drop if fips_state=="037"
* Los Angeles county also listed separately
destring fips_state, replace 
destring year, replace 
collapse (mean) Unemployment_rate, by(year fips_state)
rename Unemployment_rate unemployment_rate
label var unemployment_rate "Unemployment"
save "${IN}/indep_var/var_state/unemployment.dta", replace 




* Merging the GDP data 
import delimited "${IN}/indep_var/var_state/gdp_before_1997.csv", clear 
destring geofips, replace 
gen fips_state = geofips/1000
forval i =3/8 {
local c: var label v`i'
rename v`i' gdp`c'
}

reshape long gdp, i(geofips) j(year)
keep year fips_state gdp
drop if year==1997

tempfile gdp1997 
save `gdp1997' 

import delimited "${IN}\indep_var\var_state\gdp_1997_2018.csv", delimiter(comma) clear 
keep if industryid==1
destring geofips, replace 
gen fips_state = geofips/1000

forval i =10/31 {
local c: var label v`i'
rename v`i' gdp`c'
}

keep fips_state gdp*
reshape long gdp, i(fips_state) j(year)
destring gdp, replace 
destring year, replace 

keep year fips_state gdp
append using `gdp1997'
label var gdp "GDP"
save "${IN}/indep_var/var_state/gdp.dta", replace 






* Preparing the Personal Income Tax Rate 
import excel "${IN}/indep_var/var_tax/pit.xlsx", sheet("Tabelle1") clear
* Extracted from: https://taxsim.nber.org/state-rates/maxrate.html, which also indicates which column contains which data 
rename A year 
rename D pit 
rename L state 
drop if state=="federal"
replace state = state +" " + M if M!=""
keep year state pit 
destring year, replace 
replace state="District of Columbia" if state=="Washington DC"
label var pit "Personal Income Tax"
save "${IN}/indep_var/var_tax/pit.dta", replace 






* Preparing the Corporate Income Tax Rate 
*>2010
import excel "${IN}/indep_var/var_tax/corporate_tax_rate_28_10.xlsx", sheet("corporate_tax") firstrow clear
foreach letter in D E F G H I J K L M N O P Q R S T U V W X Y Z AA AB AC AD AE  {
local c: var label `letter'
rename `letter' cit`c'
destring cit`c', replace 
}
rename State state 
replace state="California" if state=="Kalifornien"
replace state="New Hampshire" if state=="New Hamspire"
reshape long cit, i(state) j(year)
keep if year>=2011 
keep state year cit
tempfile cit 
save `cit'

*1980 until 2010
import delimited "${IN}/indep_var/var_tax/Corp-Tax-Rates.csv", clear 
rename statecorporatetaxrate cit 
rename fips fips_state 
keep year fips_state cit state 
append using `cit', force 
destring year, replace 
label var cit "Corporate Income Tax"
save "${IN}/indep_var/var_tax/cit.dta", replace 

merge 1:1 state year using "${IN}/indep_var/var_tax/pit.dta"
drop _merge 
bysort state: egen max_fips = max(fips_state)
drop fips_state
rename max_fips fips_state
drop state 

save "${IN}/indep_var/var_tax/tax_final.dta", replace 


* Merging the RD Credits
import excel "${IN}/indep_var/var_RDcredits/RD_credits_final.xlsx", sheet("rd_summary") firstrow clear 
drop if missing(fips_state)

rename DT1lowesttier rd_credit 
keep fips_state year rd_credit 

save "${IN}/indep_var/var_RDcredits/RD_credits_final.dta", replace 
