////////////////////////////////////////////////////////////////////////////////
// Project:        	Moving innovation
// Creation Date:  	11/07/2024
// Last Update:    	11/07/2024
// Authors:         Laura Arnemann
//					Theresa Bührle
// Goal: 			Technological proximity 
///////////////////////////////////////////////////////////////////////////////

*Data source: Patensview, https://patentsview.org/download/data-download-tables
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