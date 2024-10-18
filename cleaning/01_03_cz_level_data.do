////////////////////////////////////////////////////////////////////////////////
// Project:        	Moving innovation
// Creation Date:  	09/07/2024
// Last Update:    	17/10/2024
// Authors:         Laura Arnemann
//					Theresa Bührle
// Goal: 			CZ-level controls
////////////////////////////////////////////////////////////////////////////////

*A. Create individual files	x	x	x	x	x	x	x	x	x	x	x	x	x
*x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x

********************************************************************************
/*
Variable: 	 
Source: 	IPUMS USA
Download: 	https://usa.ipums.org/usa/index.shtml
Years: 		
*/
********************************************************************************

use "${IN}/indep_var/var_cz/US census/usa_00002.dta", clear


********************************************************************************
/*
Variable: 	Personal Income, Population, Employment
Source: 	BEA Regional Economic Accounts
Download: 	https://apps.bea.gov/regional/downloadzip.htm
Years: 		https://apps.bea.gov/regional/DataAvailability.htm
			1969-2022
*/
********************************************************************************

// PROBLEM: Some areas in Virginia and Hawaii are combined; doesn't match with fips in other datasets

*CAINC1 - County and MSA personal income summary: personal income, population, per capita personal income
import delimited "${IN}/indep_var/var_cz/BEA/CAINC1__ALL_AREAS_1969_2022.csv", clear 

forvalues i = 9/62	{
	local x = `i'  + 1960
	rename v`i' ct_`x'
}

drop if region == ""
drop industryclassification tablename linecode region unit

replace geofips = subinstr(geofips, `"""',  "", .)
rename geofips county_fips

replace description = "inc_per_cap" if description == "Per capita personal income (dollars) 2/"
replace description = "inc_th" if description == "Personal income (thousands of dollars) "
replace description = "population" if description == "Population (persons) 1/"

reshape long ct_, i(county_fips geoname description) j(year)
replace ct_ = "" if ct_ == "(NA)"
destring ct_, replace

keep if strpos(geoname,",")>0	// drop all state-level observations

compress 
reshape wide ct_, i(county_fips geoname year) j(description) string

destring county_fips, replace

drop if year < 1990
drop if ct_population == .

compress
save "${IN}/indep_var/var_cz/BEA/population_income.dta", replace 

*CAINC4 - Personal income and employment by major component
import delimited "${IN}/indep_var/var_cz/BEA/CAINC4__ALL_AREAS_1969_2022.csv", clear 

forvalues i = 9/62	{
	local x = `i'  + 1960
	rename v`i' ct_`x'
}

drop if region == ""
drop industryclassification tablename linecode region unit

replace geofips = subinstr(geofips, `"""',  "", .)
rename geofips county_fips

replace description = "empl_total" if description == "Total employment "
replace description = "empl_wagesalary" if description == " Wage and salary employment "
replace description = "empl_proprietor" if description == " Proprietors employment "

keep if description == "empl_total" | description == "empl_wagesalary" | description == "empl_proprietor"
keep if strpos(geoname,",")>0	// drop all state-level observations

reshape long ct_, i(county_fips geoname description) j(year)
replace ct_ = "" if ct_ == "(NA)"
destring ct_, replace

compress 
reshape wide ct_, i(county_fips geoname year) j(description) string

destring county_fips, replace

drop if year < 1990
drop if ct_empl_total == .

compress
save "${IN}/indep_var/var_cz/BEA/employment.dta", replace 

*CAEMP25S - Total full-time and part-time employment by SIC industry
import delimited "${IN}/indep_var/var_cz/BEA/CAEMP25S__ALL_AREAS_1969_2000.csv", clear 

forvalues i = 9/40	{
	local x = `i'  + 1960
	rename v`i' empl_`x'
	replace empl_`x' = "" if empl_`x' == "(D)" | empl_`x' == "(NA)"
	destring empl_`x', replace
}

drop if region == ""
keep if strpos(geoname,",")>0	// drop all state-level observations
drop tablename region unit

replace geofips = subinstr(geofips, `"""',  "", .)
rename geofips county_fips

	*Unify SIC and NAICS based on description
	gen industry_desc = ""
	replace industry_desc = "agriculture" if description == "    Agricultural services, forestry, and fishing "
	replace industry_desc = "mining" if description == "    Mining "
	replace industry_desc = "construction" if description == "    Construction "
	replace industry_desc = "manufacturing" if description == "    Manufacturing "
	replace industry_desc = "transport" if description == "    Transportation and public utilities "
	replace industry_desc = "wholetrade" if description == "    Wholesale trade "
	replace industry_desc = "retail" if description == "    Retail trade "
	replace industry_desc = "FIRE" if description == "    Finance, insurance, and real estate "
	replace industry_desc = "services" if description == "    Services "
	replace industry_desc = "government" if description == "   Government and government enterprises "

	keep if industry_desc == "agriculture" | industry_desc == "mining" | industry_desc == "construction" ///
		| industry_desc == "manufacturing" | industry_desc == "transport" | industry_desc == "wholetrade" ///
		| industry_desc == "retail" | industry_desc == "FIRE" | industry_desc == "services" ///
		| industry_desc == "government"
		
drop linecode industryclassification description geoname
destring county_fips, replace

reshape long empl_, i(county_fips industry_desc) j(year)
reshape wide empl_, i(county_fips year) j(industry_desc) string

compress
save "${IN}/indep_var/var_cz/BEA/employment_SIC.dta", replace 

*CAEMP25N - Total full-time and part-time employment by NAICS industry
import delimited "${IN}/indep_var/var_cz/BEA/CAEMP25N__ALL_AREAS_2001_2022.csv", clear 

forvalues i = 9/30	{
	local x = `i'  + 1992
	rename v`i' ct_`x'
	replace ct_`x' = "" if ct_`x' == "(D)" | ct_`x' == "(NA)"
	destring ct_`x', replace
}

drop if region == ""
keep if strpos(geoname,",")>0	// drop all state-level observations
drop tablename region unit

replace geofips = subinstr(geofips, `"""',  "", .)
rename geofips county_fips
drop linecode industryclassification geoname

reshape long ct_, i(county_fips description) j(year)

	*Unify SIC and NAICS based on description
	gen industry_desc = ""
	replace industry_desc = "agriculture" if description == "   Forestry, fishing, and related activities " | description == " Farm employment "
	replace industry_desc = "mining" if description == "   Mining, quarrying, and oil and gas extraction "
	replace industry_desc = "construction" if description == "   Construction "
	replace industry_desc = "manufacturing" if description == "   Manufacturing "
	replace industry_desc = "transport" if description == "   Transportation and warehousing " | description == "   Utilities "
	replace industry_desc = "wholetrade" if description == "   Wholesale trade "
	replace industry_desc = "retail" if description == "   Retail trade "
	replace industry_desc = "FIRE" if description == "   Finance and insurance " | description == "   Real estate and rental and leasing "
	replace industry_desc = "services" if description == "   Professional, scientific, and technical services " ///
		| description == "   Management of companies and enterprises " | description == "   Administrative and support and waste management and remediation services " ///
		| description == "   Educational services " | description == "   Arts, entertainment, and recreation "  ///
		| description == "   Accommodation and food services " | description == "   Other services (except government and government enterprises) " ///
		| description == "   Information "
	replace industry_desc = "government" if description == "  Government and government enterprises "
	
	keep if industry_desc != ""
		
drop description  
bysort county_fips industry_desc year: egen empl_ = sum(ct_)

drop ct_
duplicates drop 

destring county_fips, replace

reshape wide empl_, i(county_fips year) j(industry_desc) string

compress
save "${IN}/indep_var/var_cz/BEA/employment_NAICS.dta", replace 

merge 1:1 county_fips year using "${IN}/indep_var/var_cz/BEA/employment_SIC.dta", nogen
sort county_fips year

drop if year < 1990

compress
save "${IN}/indep_var/var_cz/BEA/employment_industry.dta", replace

 

********************************************************************************
/*
Variable: 	Density 
Source: 	US Census Bureau
Download: 	https://covid19.census.gov/datasets/USCensus::average-household-size-and-population-density-county/explore?showTable=true
Years: 		2020
*/
********************************************************************************

import delimited "${IN}/indep_var/var_cz/density/Census_PopDens_HousehSize_2020.csv", clear 
keep geographicidentifierfipscode areaoflandsquaremeters areaofwatersquaremeters name averagehouseholdsize averagehouseholdsizeofowneroccup ///
	averagehouseholdsizeofrenteroccu totalpopulation populationdensitypeoplepersquare shape__area shape__length state

rename geographicidentifierfipscode county_fips
rename areaoflandsquaremeters arealand_m2
rename areaofwatersquaremeters areawater_m2
rename name county_name
rename averagehouseholdsize hshld_size
rename averagehouseholdsizeofowneroccup hshld_size_owner
rename averagehouseholdsizeofrenteroccu hshld_size_renter
rename populationdensitypeoplepersquare pop_density_m2

drop hshld_* totalpopulation pop_density_m2 shape__area shape__length

order state county_fips county_name 

*Adjustments to combine with BEA data
gen county_fips_comb = county_fips
replace county_fips_comb = 15901 if county_fips == 15005 | county_fips == 15009
replace county_fips_comb = 51901 if county_fips == 51003 | county_fips == 51540
replace county_fips_comb = 51903 if county_fips == 51005 | county_fips == 51580
replace county_fips_comb = 51907 if county_fips == 51015 | county_fips == 51820 | county_fips == 51790
replace county_fips_comb = 51911 if county_fips == 51031 | county_fips == 51680
replace county_fips_comb = 51913 if county_fips == 51035 | county_fips == 51640
replace county_fips_comb = 51918 if county_fips == 51053 | county_fips == 51730 | county_fips == 51570
replace county_fips_comb = 51919 if county_fips == 51059 | county_fips == 51600 | county_fips == 51610
replace county_fips_comb = 51921 if county_fips == 51069 | county_fips == 51840
replace county_fips_comb = 51923 if county_fips == 51081 | county_fips == 51595
replace county_fips_comb = 51929 if county_fips == 51089 | county_fips == 51690
replace county_fips_comb = 51931 if county_fips == 51095 | county_fips == 51830
replace county_fips_comb = 51933 if county_fips == 51121 | county_fips == 51750
replace county_fips_comb = 51939 if county_fips == 51143 | county_fips == 51590
replace county_fips_comb = 51941 if county_fips == 51149 | county_fips == 51670
replace county_fips_comb = 51942 if county_fips == 51153 | county_fips == 51683 | county_fips == 51685
replace county_fips_comb = 51944 if county_fips == 51161 | county_fips == 51775
replace county_fips_comb = 51945 if county_fips == 51163 | county_fips == 51530 | county_fips == 51678
replace county_fips_comb = 51947 if county_fips == 51165 | county_fips == 51660
replace county_fips_comb = 51949 if county_fips == 51175 | county_fips == 51620
replace county_fips_comb = 51951 if county_fips == 51177 | county_fips == 51630
replace county_fips_comb = 51953 if county_fips == 51191 | county_fips == 51520
replace county_fips_comb = 51955 if county_fips == 51195 | county_fips == 51720
replace county_fips_comb = 51958 if county_fips == 51199 | county_fips == 51735

drop if state == "Puerto Rico"

bysort county_fips_comb: egen land_m2 = sum(arealand_m2)
bysort county_fips_comb: egen water_m2 = sum(areawater_m2)

drop county_fips county_name arealand_m2 areawater_m2
duplicates drop

rename county_fips_comb county_fips

compress
save "${IN}/indep_var/var_cz/density/county_area.dta", replace 

********************************************************************************
/*
Variable: 	Urbanisation
Source: 	Natioonal Center for Health Statistics
Download: 	https://www.cdc.gov/nchs/data_access/urban_rural.htm
Years: 		1990, 2006, 2013 classification scheme
*/
********************************************************************************

import excel "${IN}/indep_var/var_cz/urbanisation/NCHSURCodes2013.xlsx", sheet("NCHSURCodes2013") firstrow clear

drop CBSAtitle CBSA2012pop County2012pop J
rename FIPScode county_fips
rename Countyname county_name
rename code urban_2013
rename H urban_2006
rename basedcode urban_1990
rename StateAbr state_abbr

/*
1: Large central metro
2: Large fringe metro
3: Medium metro
4: Small metro
4: Micropolitan
6: Non-core
*/

destring urban_1990, replace

compress
save "${IN}/indep_var/var_cz/urbanisation/urbanisation_county_codes.dta", replace 

********************************************************************************
/*
Variable: 	R&D conducted by Universities
Source: 	NSF Survey of Research and Development Expenditures at Universities and Colleges
			Higher Education Research and Development Survey
Download: 	https://ncses.nsf.gov/explore-data/microdata/higher-education-research-development
Years: 		1972-2022
*/
********************************************************************************

forval year =1990/2022 {
	import delimited "${IN}/indep_var/var_cz/HERD/herd_`year'.csv", clear 

	keep if question == "Source" & row == "Total"
	capture rename fice inst_id
	keep year inst_id inst_name_long inst_city inst_state inst_zip data
		
	duplicates report inst_id
	drop if inst_id == . 
	
	tempfile herd`year' 
	save `herd`year'' 
}


forval year =2012/2022 {
	capture import delimited "${IN}/indep_var/var_cz/HERD/herd_`year'_short.csv", clear 	// 2013 short is missing

	capture keep if question == "Source" & row == "Total"
	capture keep year inst_id inst_name_long inst_city inst_state inst_zip data
	duplicates report inst_id
	drop if inst_id == . 
	
	keep if year == `year'

	tempfile herd`year'_short 
	save `herd`year'_short'
}


forval year =1990/2022 {
	append using `herd`year''
}

forval year =2012/2021 {
	capture append using `herd`year'_short'
}

sort inst_id year

replace inst_state = inst_state_code if inst_state == ""
drop inst_state_code

rename data uni_RandD
label var uni_RandD "R&D conducted by universities"

gen zipcode = substr(inst_zip, 1,5)
bysort inst_id: replace zipcode = zipcode[_n+1] if zipcode == "" &  zipcode[_n+1] != ""

collapse (sum) uni_RandD, by(year zipcode)

compress
save "${IN}/indep_var/var_cz/HERD/university_RandD_zipcode.dta", replace 



*B. Combine files	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x
*x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x

use "${IN}/indep_var/var_cz/BEA/population_income.dta", clear 

merge 1:1 year county_fips using"${IN}/indep_var/var_cz/BEA/employment.dta", nogen  
merge 1:1 year county_fips using"${IN}/indep_var/var_cz/BEA/employment_industry.dta", nogen  keep(3)

merge m:1 county_fips using "${IN}/indep_var/var_cz/density/county_area.dta"
	// merge ==1: 6 areas in AK
keep if _merge == 3
drop _merge 

order state geoname county_fips

merge m:1 county_fips using "${IN}/indep_var/var_cz/urbanisation/urbanisation_county_codes.dta" 
keep if _merge == 3
drop _merge geoname

gen density = ct_population / land_m2
gen share_selfemployed = ct_empl_proprietor / ct_population

order state state_abbr county_name county_fips 

compress
save "${IN}/indep_var/var_cz/cz_level_controls.dta", replace 


