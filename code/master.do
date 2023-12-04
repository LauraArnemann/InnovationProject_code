// Project: Inventor Relocation
// Creation Date: 20/11/2023
// Last Update: 20/11/2023
// Author: Laura Arnemann 
// Goal: Master 


* Set the global so the paths adjust quickly

global user 1 


if $user==1 {
* G:\.shortcut-targets-by-id\1WdgNEyGs57PgSqqCPP_B2s_Inzx7SKst\Spillover migration data
global IN  C:/Users/laura/Desktop/InnovationProject/data/raw
*global CEO_IN C:/Users/laura/Desktop/data/CEOProject/rawdata
global TEMP C:/Users/laura/Desktop/InnovationProject/data/temp
global OUT C:/Users/laura/Desktop/InnovationProject/data/final
global LINKING  C:/Users/laura/Desktop/InnovationProject/data/linking_table

}


else {
	
	global IN C:\Users\tbuehrle\Desktop\Work\Projects\Spillover inventors\
	global TEMP
	global OUT
	
	
}

********************************************************************************
* Matching NETS + Patent Data via Compustat
********************************************************************************

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