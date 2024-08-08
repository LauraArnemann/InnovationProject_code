////////////////////////////////////////////////////////////////////////////////
// Project:        	Moving innovation
// Creation Date:  	01/07/2024
// Last Update:    	01/07/2024
// Authors:         Laura Arnemann
//					Theresa Bührle
// Goal: 			Master Regression
////////////////////////////////////////////////////////////////////////////////

/*
local sample1 if year>=1988 
local sample2 if inrange(year, 1988, 2018)  & total_patents>5 
local sample3 if inrange(year, 1988, 2018)  & total_patents!=0
local sample4 if inrange(year, 1988, 2018) & estab_patents>5
local sample5 if inrange(year, 1988, 2018)  & total_patents>10 
local sample6 if inrange(year, 1988, 2018)  & balanced_panel==1
local sample7 if inrange(year, 1988, 2018)  & balanced_panel==1 & total_patents>10 
*/

global direction incr 
global weighting_strategy weighted threelargest
	// all3 weighted3

	*patents3 n_inventors3_w1 ln_n_inventors3
global outcome 
global outcome_log inventor_productivity


global dataset 4
	// 1 = Woeppel
	// 2 = Harvard, 2010
	// 3 = Harvard, 2018
	// 4 = Patentsview, 2018

********************************************************************************
*First stage: Relocation	
********************************************************************************
	
*A. MAIN -----------------------------------------------------------------------

* Standard regression
*do "${CODE}/analysis_twowayfe_static.do"
*do "${CODE}/analysis/analysis_twowayfe_dynamic_assignee.do"
*do "${CODE}/analysis/analysis_twowayfe_spillover_estab.do"

*B. ROBUSTNESS -----------------------------------------------------------------

* Stacked cohort approach
*do "${CODE}/running_stacked_regression_current.do"
*do "${CODE}/running_stacked_regression_other.do"

* Chaisemartin
*do "${CODE}/chaisemartin_estimator.do"

********************************************************************************
*Second stage: Spillover	
********************************************************************************

*do "${CODE}/analysis_twowayfe_spillover.do"






