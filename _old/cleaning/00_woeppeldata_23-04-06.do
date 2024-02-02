/// PROJECT: Spillover Effects 
/// GOAL: Just trying out some stuff with patents 
/// AUTHOR: Laura Arnemann
/// CREATION: 27-12-2022
/// LAST UPDATE: 09-03-2023
/// SOURCE: Raw Data 

*Data Import -------------------------------------------------------------------

* Assignee data xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
forvalues i=5/12 {
  import delimited "${IN}/assignee/assignee_`i'm.tsv", clear
  duplicates drop patnum assignee_id location_id, force
	//There are several assignees that have more than one address for the same patnum
	
	foreach var of varlist city state country latitude longitude county state_fips county_fips {
	    rename `var' `var'_assignee	
	}
  save "${IN}/assignee/assignee_`i'm.dta", replace
 }
  
use  "${IN}/assignee/assignee_5m.dta", clear
 forvalues i=6/12 {
     merge 1:1 patnum assignee_id location_id using "${IN}/assignee/assignee_`i'm.dta", nogen
 }

rename type organization_type
 
save "${IN}/assignee/assignee_all.dta", replace

/*
use "${IN}/assignee/assignee_all.dta", clear

count if city == "both of" 
count if city == "BOTH OF"
	//There seems to be a problem in the code with double locations, as city is oftentimes named as "both of"
*/

* Citation Data xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
forvalues i=8/12 {
  import delimited "${IN}/citation/app_cites_`i'm.tsv", clear
  bysort patnum: gen count=_n 
  collapse (mean) sequence (count) count, by(patnum)
  save "${IN}/citation/app_cites_`i'm.dta", replace
}

use  "${IN}/citation/app_cites_8m.dta", clear
 forvalues i=9/12 {
     merge 1:1 patnum using "${IN}/citation/app_cites_`i'm.dta", nogen
}

save "${IN}/citation/app_cites_all.dta", replace 

* Info Data xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
forvalue i=5/12 {
  import delimited "${IN}/info/info_`i'm.tsv", clear
  save "${IN}/info/info_`i'm.dta", replace
}

use  "${IN}/info/info_5m.dta", clear
 forvalues i=6/12 {
     merge 1:1 patnum using "${IN}/info/info_`i'm.dta", nogen
}

rename type patent_type
rename kind patent_kind
rename country patent_country

save "${IN}/info/info_all.dta", replace

* Classification Data xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
 if ${classification} ==1 {

**Cooperative patent classification (CPC) 

forvalue i=5/12 {
  import delimited "${IN}/classifications/cpc_`i'm.tsv", clear
  save "${IN}/classifications/cpc_`i'm.dta", replace
}

use  "${IN}/classifications/cpc_5m.dta", clear
 forvalues i=6/12 {
     merge 1:1 patnum cpc_sequence using "${IN}/classifications/cpc_`i'm.dta", nogen
}

label var patnum "Patent number"
label var cpc_section "CPC section"
label var cpc_subsection "CPC subsection"
label var cpc_group "CPC group"
label var cpc_subgroup "CPC subgroup"
label var cpc_sequence "Patent-level position within CPC fields"
label var cpc_category "0=additional; 1=inventional"

save "${IN}/classifications/cpc_all.dta", replace

**International patent classification (IPC)

forvalue i=5/12 {
  import delimited "${IN}/classifications/ipc_`i'm.tsv", clear
  
  forvalues n = 1/9 {
	capture replace ipc_class = "0`n'" if ipc_class == "O`n'"
  }
  
  capture replace ipc_subgroup = subinstr(ipc_subgroup, "/", "",.)
  
  foreach var of varlist ipc_class ipc_main_group ipc_subgroup {
	  capture gen byte notnumeric = real(`var') == .	//There seem to be problems with mixed up columns for a small number of obs
	  capture drop if notnumeric == 1
	  capture drop notnumeric
	  destring `var', replace
  }
  
  tostring ipc_date, replace
  
  save "${IN}/classifications/ipc_`i'm.dta", replace
}

use  "${IN}/classifications/ipc_5m.dta", clear
 forvalues i=6/12 {
     merge 1:1 patnum ipc_sequence using "${IN}/classifications/ipc_`i'm.dta", nogen
}

label var patnum "Patent number"
label var ipc_symbol "IPC section symbol"
label var ipc_class "IPC class symbol"
label var ipc_subclass "IPC subclass symbol"
label var ipc_main_group "IPC main group symbol"
label var ipc_subgroup "IPC subgroup symbol"
label var ipc_sequence "Patent-level position within IPC classifications"
label var ipc_date "IPC version date"

save "${IN}/classifications/ipc_all.dta", replace

**US patent classification (USPC)

forvalue i=5/10 {
  import delimited "${IN}/classifications/uspc_`i'm.csv", clear
  duplicates drop patnum uspc_sequence, force
  save "${IN}/classifications/uspc_`i'm.dta", replace
}

use  "${IN}/classifications/uspc_5m.dta", clear
 forvalues i=6/10 {
     merge 1:1 patnum uspc_sequence using "${IN}/classifications/uspc_`i'm.dta", nogen
}

label var patnum "Patent number"
label var uspc_main_class "USPC main classification"
label var uspc_sub_class "USPC sub-classification"
label var uspc_sequence "Patent-level position within USPC classifications"

save "${IN}/classifications/uspc_all.dta", replace

**World intellectual patent organization (WIPO)

forvalue i=5/12 {
  import delimited "${IN}/classifications/wipo_`i'm.tsv", clear
  save "${IN}/classifications/wipo_`i'm.dta", replace
}

use  "${IN}/classifications/wipo_5m.dta", clear
 forvalues i=6/12 {
     merge 1:1 patnum wipo_sequence using "${IN}/classifications/wipo_`i'm.dta", nogen
}

label var patnum "Patent number"
label var wipo_field_id "WIPO field"
label var wipo_sequence "Patent-level position within WIPO classifications"
label var wipo_sector_title "WIPO sector title"
label var wipo_field_title "WIPO field title"

save "${IN}/classifications/wipo_all.dta", replace

 }
* Inventor Data xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
forvalues i=5/12 {
  import delimited "${IN}/inventors/inventor_`i'm.tsv", clear 

   foreach var of varlist city state country latitude longitude county state_fips county_fips {
	    rename `var' `var'_inventor
 }
 duplicates drop patnum inventor_id location_id, force
 
  save "${IN}/inventors/inventor_`i'm.dta", replace
}

* Waurm machst du bei den Inventors einen Merge? Das sind ja immer unterschiedliche Patente, die die Inventors filen, da wird ja nichts gemergt
use  "${IN}/inventors/inventor_5m.dta", clear
 forvalues i=6/12 {
     merge 1:1 patnum inventor_id location_id using "${IN}/inventors/inventor_`i'm.dta", nogen
}

label var inventor_id "USPTO inventor identification" 
label var first_name "First and middle name/initial (if present) of inventor" 
label var last_name "Last name of inventor" 
label var male "1=male, 0=female, .=missing" 
label var city_inventor "City of inventor" 
label var state_inventor "State of inventor" 
label var country_inventor "Country of inventor" 
label var latitude_inventor "Geographic coordinate" 
label var longitude_inventor "Geographic coordinate" 
label var county_inventor "County of inventor" 
label var state_fips_inventor "State FIPS code" 
label var county_fips_inventor "County FIPS code" 

save "${IN}/inventors/inventor_all.dta", replace


 if ${classification} ==1 {

*Data Merge --------------------------------------------------------------------

use "${IN}/citation/app_cites_all.dta", clear
	merge 1:1 patnum using "${IN}/info/info_all.dta"
	drop _merge
	//There's only info for ~50% of patnums
	merge 1:m patnum using "${IN}/assignee/assignee_all.dta"
	drop _merge
	//Not all info can be matched to an assigned patent
	// Also merge with the information on inventors 

compress

label var patnum "Patent number"
label var assignee_id "USPTO assignee identification"
label var organization "Assignee"
label var city_assignee "City of assignee"
label var state_assignee "State of assign"
label var country_assignee "Country of assignee"
label var latitude_assignee "Geographic coordinate"
label var longitude_assignee "Geographic coordinate"
label var county_assignee "County of assignee"
label var state_fips_assignee "State FIPS code"
label var county_fips_assignee "County FIPS code"
label var organization_type "Organization type"
label var location_id "USPTO location identification"
*label var appcite_num "Application number of application citation"
*label var appcite_idate "Filing date of application citation (mm/yyyy)"
*label var app_kind "Application kind"
*label var cited_by "Person who cited patent (examiner, applicant, etc.)"
label var sequence "Patent-level position within application citations"
label var fdate "Filing date of patent (mm/dd/yyyy)"
label var idate "Issue (grant) date of patent (mm/dd/yyyy)"
label var patent_type "Patent type"
label var appnum "Application number"
label var series_code "Application type"
label var num_claims "Number of claims"
label var num_figures "Number of figures"
label var num_sheets "Number of drawings"
label var patent_kind "Patent kind"
label var withdrawn "1=withdrawn, 0=not withdrawn"
label var patent_country "Country of patent (all US)"
  
save "${OUT}/joint_applications.dta", replace 


 }

/*


use "${OUT}/joint_applications.dta", clear 

merge m:m patnum using "${IN}/classifications/cpc_all.dta"
merge m:m patnum using "${IN}/classifications/ipc_all.dta"

merge m:m patnum using "${IN}/classifications/uspc_all.dta"

merge m:m patnum using "${IN}/classifications/wipo_all.dta"




*Data analysis -----------------------------------------------------------------


use "${OUT}/joint_applications.dta", clear 

use "${IN}/inventors/inventor_all.dta", clear
*/ 