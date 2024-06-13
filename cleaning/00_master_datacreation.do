////////////////////////////////////////////////////////////////////////////////
// Project:        	Moving innovation
// Creation Date:  	13/06/2024
// Last Update:    	13/06/2024
// Authors:         	Laura Arnemann
//			Theresa Bührle
// Goal: 		Creating datasets based on different raw data
////////////////////////////////////////////////////////////////////////////////

global dataset 3
	// 1 = Woeppel
	// 2 = Harvard, 2010
	// 3 = Harvard, 2018


if $dataset == 1 {
	global inventordata "${TEMP}/woeppel_dataset.dta"
}

if $dataset == 2 {
	global inventordata "${TEMP}/new_dataset1_county_states_clean.dta"
}

if $dataset == 3 {
	global inventordata "${TEMP}/new_dataset2.dta"
}




