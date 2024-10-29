////////////////////////////////////////////////////////////////////////////////
// Project:        	Moving innovation
// Creation Date:  	06/12/2023
// Last Update:    	29/10/2024
// Authors:         Laura Arnemann
//					Theresa Bührle
// Goal: 			Master Data Creation
///////////////////////////////////////////////////////////////////////////////

********************************************************************************
* 01 COMPILE RAW DATA
********************************************************************************

* Patent data
do "${CODE}/cleaning/01_01_patent_data.do"

* State-level data
do "${CODE}/cleaning/01_02_state_level_data.do"

* CZ-level data
do "${CODE}/cleaning/01_03_cz_level_data.do"


********************************************************************************
* 02 COMPILE REGRESSION DATA WITH CHANGES IN OTHER LOCATIONS
********************************************************************************

* Generate state-level innovative activity based on Giroud/Rauh (patent, inventor count)
do "${CODE}/cleaning/02_01_cleaning_state_zeros.do"
	// Includes sub-routine "sub_clean_gov_uni_entitites"
	// Includes sub-routine "sub_gen_other_var"
	
* Generate cz-level innovative activity (patent, inventor count)
do "${CODE}/cleaning/02_02_cleaning_cz_zeros.do"

foreach num of numlist $patentvar {
	cap erase "${TEMP}/other_all`num'"
	cap erase "${TEMP}/other_all`num'_gvkey"
	cap erase "${TEMP}/other_first`num'"
	cap erase "${TEMP}/other_first`num'_gvkey"
	cap erase "${TEMP}/other_threelargest`num'"
	cap erase "${TEMP}/other_threelargest`num'_gvkey"
}

********************************************************************************
* 03 ADDITIONAL MEASURES
********************************************************************************

// CAREFUL: INCLUDES PARTS RUN IN PYTHON!

* Technological proximity
do "${CODE}/cleaning/03_01_preparing_techproximity.do"

* Inventor productivity
do "${CODE}/cleaning/03_02_gen_inventor_productivity.do"


********************************************************************************
* 04 COMPILE STACKED REGRESSION
********************************************************************************

do "${CODE}/cleaning/04_01_cleaning_stacked_regression.do" 
do "${CODE}/cleaning/04_02_cleaning_stacked_regression_other.do" 




