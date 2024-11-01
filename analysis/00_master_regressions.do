////////////////////////////////////////////////////////////////////////////////
// Project:        	Moving innovation
// Creation Date:  	01/07/2024
// Last Update:    	29/10/2024
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
global weighting_strategy threelargest3 weighted3
	// all3 weighted3 weighted threelargest

	*patents3 n_inventors3_w1 ln_n_inventors3
global outcome n_lasttimeinventor n_relocatinginventors 
global outcome_log inventor_productivity


********************************************************************************
*Descriptives	
********************************************************************************

*do "${CODE}/analysis/01_descriptive_stats.do"

********************************************************************************
*First stage: Relocation	
********************************************************************************
	
*A. MAIN -----------------------------------------------------------------------

* Standard regression
do "${CODE}/analysis/01_analysis_twowayfe_static_main.do"
do "${CODE}/analysis/02_analysis_twowayfe_dynamic.do"

*B. ROBUSTNESS -----------------------------------------------------------------

* Stacked cohort approach
do "${CODE}/analysis/06_running_stacked_regression_main.do"

*C. ADDITIONAL -----------------------------------------------------------------

do "${CODE}/analysis/08_heterogeneity_analysis.do"


********************************************************************************
*Second stage: Spillover	
********************************************************************************

do "${CODE}/analysis/03_analysis_twowayfe_static_spillover.do"
do "${CODE}/analysis/04_01_analysis_twowayfe_dynamic_spillover.do"

do "${CODE}/analysis/04_02_analysis_twowayfe_dynamic_spillover_tech.do"
do "${CODE}/analysis/05_01_analysis_inventor_productivity_main.do"
do "${CODE}/analysis/05_02_analysis_inventor_productivity_spillover.do"





