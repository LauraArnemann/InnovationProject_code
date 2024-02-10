// Project: Inventor Relocation
// Creation Date: 20/11/2023
// Last Update: 02/02/2024
// Author: Laura Arnemann 
// Goal: Master 

clear
*set maxvar 120000
set more off

/*
*Programs
ssc install rangestat

// Maps: https://www.stata.com/support/faqs/graphics/spmap-and-maps/
ssc install spmap
ssc install shp2dta
ssc install mif2dta
ssc install outreg2
*/

* Set the global so the paths adjust quickly

if c(username) == "laura" {
* G:\.shortcut-targets-by-id\1WdgNEyGs57PgSqqCPP_B2s_Inzx7SKst\Spillover migration data
global IN  C:/Users/laura/Desktop/InnovationProject/data/raw
global code C:/Users/laura/Desktop/InnovationProject/code_git
*global CEO_IN C:/Users/laura/Desktop/data/CEOProject/rawdata
global TEMP C:/Users/laura/Desktop/InnovationProject/data/temp
global OUT C:/Users/laura/Desktop/InnovationProject/data/final
global LINKING  C:/Users/laura/Desktop/InnovationProject/data/linking_table


global PATENTDTA C:/Users/laura/Desktop/InnovationProject/data/raw/main_data/data_patent
global REGDTA C:/Users/laura/Desktop/InnovationProject/data/temp/

global RESULTS C:/Users/laura/Desktop/InnovationProject/results

}

if c(username) == "tbuehrle" {
	
	global IN "C:\Users\tbuehrle\OneDrive - DIW Berlin\3_Forschung\Topics\Spillover migration\2_Empirical\2_1_Data\raw"
	global TEMP "C:\Users\tbuehrle\OneDrive - DIW Berlin\3_Forschung\Topics\Spillover migration\2_Empirical\2_1_Data\temp"
	global OUT  "C:\Users\tbuehrle\OneDrive - DIW Berlin\3_Forschung\Topics\Spillover migration\2_Empirical\2_1_Data\final"
	global LINKING  "C:\Users\tbuehrle\OneDrive - DIW Berlin\3_Forschung\Topics\Spillover migration\2_Empirical\2_1_Data\linking_tables"
	global PATENTDTA "C:\Users\tbuehrle\OneDrive - DIW Berlin\3_Forschung\Data\Patent Data US_Woeppel"
	
	global code "C:\Users\tbuehrle\OneDrive - DIW Berlin\3_Forschung\Topics\Spillover migration\2_Empirical\2_2_Code"
	
	global RESULTS "C:\Users\tbuehrle\OneDrive - DIW Berlin\3_Forschung\Topics\Spillover migration\2_Empirical\2_3_Results"
} 

/*

*-------------------------------------------------------------------------------
*1. MATCHING
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
*2. ANALYSIS
*-------------------------------------------------------------------------------

********************************************************************************
* Ummatched patent data
********************************************************************************

*Generate CZ-level dataset with inventor moves based on Woeppel patent data
do "${code}/cleaning/invmoves_data_Woeppel.do" 

*Analysis
do "${code}/analysis/invmoves_reg.do" 








