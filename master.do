////////////////////////////////////////////////////////////////////////////////
// Project:        	Moving innovation
// Creation Date:  	20/11/2023
// Last Update:    	17/10/2024
// Authors:         	Laura Arnemann
//			Theresa Bührle
// Goal: 		Master
////////////////////////////////////////////////////////////////////////////////
   
clear
*set maxvar 120000
*set max_memory 80g, permanently
set more off

/*
*Programs
ssc install rangestat, replace
ssc install distinct, replace

// Maps: https://www.stata.com/support/faqs/graphics/spmap-and-maps/
ssc install spmap, replace
ssc install shp2dta, replace
ssc install mif2dta, replace
ssc install outreg2, replace
ssc install gtools, replace
ssc install ppmlhdfe, replace
ssc install coefplot, replace
ssc install ftools, replace
ssc install reghdfe, replace

ssc install avar, replace
ssc install xtivreg2, replace
ssc install newey2, replace
ssc install ivreg2, replace
ssc install ranktest, replace

ssc install did_multiplegt_dyn, replace
ssc install egenmore, replace
*/

*Graphing scheme:
set scheme plotplainblind

* Set the global so the paths adjust quickly
if c(username) == "laura" {
	
	global path C:/Users/laura/Desktop/InnovationProject
	* 
	global IN  ${path}/data/raw
	global code ${path}/code
	*global CEO_IN C:/Users/laura/Desktop/data/CEOProject/rawdata
	global TEMP ${path}/data/temp
	global OUT ${path}/data/final
	global LINKING  ${path}/linking_table
	global OVERLEAF ${path}/overleaf
	global CODE ${path}/code


	global PATENTDTA ${path}/raw/main_data/data_patent
	global REGDTA C:/Users/laura/Desktop/InnovationProject/data/temp/

	global RESULTS C:/Users/laura/Desktop/InnovationProject/results
}

if c(username) == "tbuehrle" {
	
	global path "C:/Users/tbuehrle/OneDrive - DIW Berlin/3_Forschung/Topics/Spillover migration/2_Empirical"
	
	global IN "${path}/2_1_Data/raw"
	global TEMP "${path}/2_1_Data/temp"
	global OUT  "${path}/2_1_Data/final"
	global LINKING  "${path}/2_1_Data/linking_tables"
	global TECHDATA "D:/DOCS/3_Forschung/Topics/Spillover migration/2_Empirical/2_1_Data/temp/tech"
	
	global CODE "${path}/2_2_Code/"
	
	global RESULTS "${path}/2_3_Results"
	global OVERLEAF "${path}/2_3_Results/overleaf"	
} 

if c(username) == "there" {
	
	global path "D:/DOCS/3_Forschung/Topics/Spillover migration/2_Empirical"
	
	global IN "${path}/2_1_Data/raw"
	global TEMP "${path}/2_1_Data/temp"
	global OUT  "${path}/2_1_Data/final"
	global LINKING  "${path}/2_1_Data/linking_tables"
	global TECHDATA "D:/DOCS/3_Forschung/Topics/Spillover migration/2_Empirical/2_1_Data/temp/tech"
	
	global CODE "C:/Users/there/Desktop/Forschung/Topics/Spillover migration/2_2_Code"
	
	global RESULTS "${path}/2_3_Results"
	global OVERLEAF "${path}/2_3_Results/overleaf"
} 

else {
	
	global path H:/InnovationProject
	* 
	global IN  ${path}/data/raw
	global code ${path}/code
	*global CEO_IN C:/Users/laura/Desktop/data/CEOProject/rawdata
	global TEMP ${path}/data/temp
	global OUT ${path}/data/final
	global LINKING  ${path}/linking_table
	global OVERLEAF ${path}/overleaf
	global CODE ${path}/code


	global PATENTDTA ${path}/data/raw/main_data/data_patent
	global REGDTA ${path}data/temp/

	global RESULTS ${path}/results
}


/*


*-------------------------------------------------------------------------------
*0. MATCHING
*-------------------------------------------------------------------------------
	
	
	
********************************************************************************
* Matching NETS + Patent Data via Compustat
********************************************************************************

do "${code}/01_cleaning_compustat.do" 
do "${code}/02_cleaning_NETS.do"


* Matching the NETS data with the compustat companies 

* this merges only compustat companies which were in the 2020 dataset  
do "${code}/name_matching_2020.do"

* this merges only NETS companies which were indicated as public companies 
do "${code}/matching_NETS_compustat_public.do"

* this merges only NETS companies which reported to have multiple HQs 
do "${code}/matching_NETS_compustat_all.do"

* To check the number of merges one can run 
do "${code}/checking_RD_expenditure.do" 

*1: cleaning_NETS + cleaning_NETS_10employees 
*2: cleaning_compustat 
*3: matching_NETS_compustat_public * Only matching all public companies (according to NETS) with multiple estabs
*4: matching_NETS_compustat_all * matching all companies with multiple estabs



********************************************************************************
* Matching Patent and Compustat data 
********************************************************************************

*5: patent_link_compustat 


********************************************************************************
* Matching Patent and NETS data 
********************************************************************************

*6: patent_link_NETS


* Old dofile using only companies from 2020 
* name_matching_2020



*-------------------------------------------------------------------------------
*1. REGRESSION SAMPLE
*-------------------------------------------------------------------------------

*Prep state-level variables: cleaning_state.do

*Construct state-level dataset: cleaning_giroud_rauh.do
*Construct CZ-level dataset: cleaning_cz.do

*Generate stacked sample: stacked_regression.do



*-------------------------------------------------------------------------------
*2. ANALYSIS
*-------------------------------------------------------------------------------

*Stacked reg: running_stacked_regression.do










