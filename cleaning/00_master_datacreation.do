////////////////////////////////////////////////////////////////////////////////
// Project:        	Moving innovation
// Creation Date:  	13/06/2024
// Last Update:    	13/06/2024
// Authors:         	Laura Arnemann
//			Theresa Bührle
// Goal: 		Creating datasets based on different raw data
////////////////////////////////////////////////////////////////////////////////


global dataset 4
	// 1 = Woeppel
	// 2 = Harvard, 2010
	// 3 = Harvard, 2018
	// 4 = Patentsview, 2018


if $dataset == 1 {
	global inventordata "${TEMP}/woeppel_dataset.dta"
}

if $dataset == 2 {
	global inventordata "${TEMP}/new_dataset1_county_states_clean.dta"
}

if $dataset == 3 {
	global inventordata "${TEMP}/new_dataset2.dta"
}

if $dataset == 4 {
	global inventordata "${TEMP}/new_dataset3.dta"
}

* Run the dofiles 
*do "${CODE}/cleaning/02_cleaning_giroud_rauh_zeros.do"
*do "${CODE}/cleaning/02_cleaning_giroud_rauh_zeros_gvkey.do"
*do "${CODE}/analysis/analysis_twowayfe_static.do"
*do "${CODE}/analysis/analysis_twowayfe_dynamic.do"
*do "${CODE}/cleaning/07_cleaning_stacked_regression_stateyear.do"
*do "${CODE}/analysis/running_stacked_regression_other.do"



