////////////////////////////////////////////////////////////////////////////////
// Project:        	Moving innovation
// Creation Date:  	11/07/2024
// Last Update:    	11/07/2024
// Authors:         Laura Arnemann
//					Theresa Bührle
// Goal: 			Technological proximity 
///////////////////////////////////////////////////////////////////////////////

global dataset 4
	

*Data source: Patensview, https://patentsview.org/download/data-download-tables

*A. CITATIONS
*-------------------------------------------------------------------------------
*Files: g_us_patent_citation

import delimited "${IN}/main_data/data_new/Patentsview/Citation/g_us_patent_citation.tsv", clear
drop citation_category // cited by examiner/applicant/other/third party/imported from related application

split citation_date, parse("-")
rename citation_date1 year
rename citation_date2 month
rename citation_date3 day

destring year, replace
destring month, replace
destring day, replace

gen cite_date = mdy(month, day, year)
format cite_date %d 

drop citation_date year month day

compress
save "${IN}/main_data/data_new/Patentsview/Citation/g_us_patent_citation.dta", replace


*B. TECHNOLOGICAL CLASS
*-------------------------------------------------------------------------------
*Files: g_ipc_at_issue

*A1 - Prepare data	x	x	x	x	x	x	x	x	x	x	x	x	x	x	x

/* We need:
- Unique ID: patent_id x assignee_id (or gvkey)
- Variables: assignee_id ind_class patent_id
*/


*Prepare technological class data	-	-	-	-	-	-	-	-	-	-	-	
import delimited "${IN}/main_data/data_new/Patentsview/Classification/g_ipc_at_issue.tsv", clear

egen ipc_group = group(section ipc_class subclass main_group subgroup)
duplicates drop patent_id ipc_group, force

drop if missing(patent_id)
destring patent_id, replace force 

rename patent_id patnum
drop if patnum == .	// 239,069 obs

egen ipc_group_1 = group(section ipc_class subclass main_group)
egen ipc_group_2 = group(section ipc_class subclass)
egen ipc_group_3 = group(section ipc_class)

distinct ipc_group		// 223,523 distinct 
distinct ipc_group_1	// 40,502 distinct 
distinct ipc_group_2	// 4,914 distinct 	
distinct ipc_group_3	// 940 distinct - let's got for this level !

keep patnum section ipc_class ipc_group_3
rename ipc_group_3 ipc_group
duplicates drop

save "${IN}/main_data/data_new/Patentsview/Classification/g_ipc_at_issue.dta", replace

*Create patent dataset 	-	-	-	-	-	-	-	-	-	-	-	-	-	-

* Prepare sub-files with assignee_ids by group
// Problem: Limit on the number of rows to 65,534 in MP version; matrix doesn't work with too many observations 
/*
Just drop like this for now to test code; but we do need the full set of pairwaise correlations.
Solution: By state
*/

* Read in the patents data from Patentsview

use "${TEMP}/patents_helper_4.dta", clear 

rename county_fips_inventor county_fips
rename state_fips_inventor fips_state
* Broomfield county (8014) was formed out of Boulder County in 2001
replace county_fips = 8013 if county_fips == 8014 

* Merging in the Commuting Zone level data 
merge m:1 county_fips using "$IN/var_CommutingZones/CZ_combined.dta"
drop if _merge!=3  
drop _merge	

rename CZ_depagri_1990 czone 
keep assignee_id patnum czone 

drop if missing(patnum)
bysort patnum czone: gen count = _n 
bysort patnum: egen max_count =max(count) 
keep if count == max_count 
drop count max_count 
bysort patnum: gen count =_n 

reshape wide czone, i(patnum) j(count)
merge 1:m patnum using "${IN}/main_data/data_new/Patentsview/Classification/g_ipc_at_issue.dta"	

keep if _merge == 3

keep patnum assignee_id czone* ipc_group
duplicates drop

egen assignee_id_num = group(assignee_id)

preserve

keep assignee_id assignee_id_num
duplicates drop
save "${TEMP}/new_dataset3_techspill_assignee_ids.dta", replace

restore
drop assignee_id
rename assignee_id_num assignee_id

egen pat_ipc = group(patnum ipc_group)
reshape long czone, i(pat_ipc) j(count)
drop if missing(czone) 

drop pat_ipc count 
compress
save "${TEMP}/new_dataset3_techspill.dta", replace

* Now run in Python using the technology_closeness file