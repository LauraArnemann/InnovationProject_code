/// PROJECT: Spillover Effects 
/// GOAL: Master dofile 
/// AUTHOR: Laura Arnemann
/// CREATION: 09-03-2023
/// LAST UPDATE: 09-03-2023
/// SOURCE: 



/* * general settings */

version 16.1

clear all
macro drop _all
capture log close

set more off
set dp period
set linesize 90

* Set Directories

global user=2


*Laura

if $user==0 {
	global basedir  "C:/Users/laura/Dropbox/spillover_effects_inventor_relocation/2_Empirical"
    global datadir  "C:/Users/laura/Desktop/data/Patent_Data"
}

*Theresa

else {
	global basedir  "C:/Users/tbl/Desktop/Unterlagen/3_Forschung/Topics/Spillover migration/2_Empirical"
    global datadir  "C:/Users/tbl/Desktop/Unterlagen/3_Forschung/Data/Patent Data US_Woeppel"
}


global date: di %tdCY-N-D daily("$S_DATE", "DMY")


global IN "${datadir}/Raw"
global OUT "${datadir}/Stata"
global prog "${basedir}/2_2_Code"
global output "${basedir}/2_3_Results"

scalar housekeeping = 0

* Install Programs 

if housekeeping == 1 {
	
    foreach prog in reghdfe  {
        ssc install `prog', replace
    }
}