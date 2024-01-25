// Project: Inventor Relocation
// Creation Date: 20/11/2023
// Last Update: 20/11/2023
// Author: Laura Arnemann 
// Goal: Master 

* Set the global so the paths adjust quickly

global user 1 


*ssc install outreg2

if $user==1 {
* G:\.shortcut-targets-by-id\1WdgNEyGs57PgSqqCPP_B2s_Inzx7SKst\Spillover migration data
global IN  C:/Users/laura/Desktop/InnovationProject/data/raw
global code C:/Users/laura/Desktop/InnovationProject/code_git
*global CEO_IN C:/Users/laura/Desktop/data/CEOProject/rawdata
global TEMP C:/Users/laura/Desktop/InnovationProject/data/temp
global OUT C:/Users/laura/Desktop/InnovationProject/data/final
global LINKING  C:/Users/laura/Desktop/InnovationProject/data/linking_table


global PATENTDTA C:/Users/laura/Desktop/InnovationProject/data/raw/main_data/data_patents
global REGDTA C:/Users/laura/Desktop/InnovationProject/data/temp/

global RESULTS C:/Users/laura/Desktop/InnovationProject/results

}


else {
	
	global IN C:\Users\tbuehrle\Desktop\Work\Projects\Spillover inventors\
	global TEMP
	global OUT
	
	
}

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