////////////////////////////////////////////////////////////////////////////////
// Project:        	Moving innovation
// Creation Date:  	06/12/2023
// Last Update:    	24/04/2024
// Authors:         Laura Arnemann
//					Theresa Bührle
// Goal: 			Cleaning the data from the Harvard Patent Database 
///////////////////////////////////////////////////////////////////////////////

/* 
It is a bit tricky to understand which data source is the appropriate data source to use, since there are different versions available online. However, for now I will work with the disambiguated inventor data set I could download from the Harvard Patent Database. 
I also downloaded a disambiguated dataset  from this website: https://github.com/funginstitute/downloads/blob/master/README.md. However, the link for the csv file does not work. I downloaded the sql file and then converted it into a csv file using Python. When matched with the data downloaded from the Harvard database not all inventors could be matched to one another. There were around 230.000 observations from the database available through the Harvard Patent Database which could not be matched. 

/*   Result                      Number of obs
    -----------------------------------------
    Not matched                     1,872,681
        from master                 1,636,605  (_merge==1)
        from using                    236,076  (_merge==2)

    Matched                         9,578,153  (_merge==3)
    -----------------------------------------
*/

 
*/

forvalues i =1/8 { 
import delimited "${IN}\main_data\data_new\dyevre\staticTranche`i'.csv", clear 
tempfile static`i'
save `static`i''
}

clear 
forvalues i=1/8 {
	append using `static`i''
}
rename patent_id patno 
* around 20.000 duplicate observations; 3644430 unique patents 
save "${TEMP}/dyevre_link.dta", replace 

import delimited "${IN}\main_data\data_new\harvard_patentdatabase\patentcity\inventor.geo.assignee.combo.disambig.tsv", clear 
merge m:m patno using "${TEMP}/dyevre_link.dta"
*9,918,844 merged; 46.160 unique companies, 52.817 unique pdpass gvkeys; 9.354 unique gvkeys






/*
   1971 |      2,112        0.01        0.04
       1972 |      4,005        0.02        0.06
       1973 |     15,869        0.10        0.16
       1974 |     67,631        0.42        0.58
       1975 |    114,509        0.71        1.28
       1976 |    118,288        0.73        2.01
       1977 |    121,213        0.75        2.76
       1978 |    121,622        0.75        3.51
       1979 |    122,854        0.76        4.27
       1980 |    125,785        0.78        5.04
       1981 |    123,201        0.76        5.80
       1982 |    127,561        0.79        6.59
       1983 |    122,225        0.75        7.34
       1984 |    133,914        0.83        8.17
       1985 |    147,817        0.91        9.08
       1986 |    157,570        0.97       10.05
       1987 |    173,402        1.07       11.12
       1988 |    195,520        1.21       12.33
       1989 |    211,187        1.30       13.63
       1990 |    221,046        1.36       14.99
       1991 |    227,096        1.40       16.39
       1992 |    239,032        1.47       17.87
       1993 |    254,115        1.57       19.43
       1994 |    296,410        1.83       21.26
       1995 |    363,052        2.24       23.50
       1996 |    351,888        2.17       25.67
       1997 |    417,185        2.57       28.24
       1998 |    416,940        2.57       30.82
       1999 |    454,944        2.81       33.62
       2000 |    503,987        3.11       36.73
       2001 |    544,074        3.36       40.08
       2002 |    565,288        3.49       43.57
       2003 |    556,001        3.43       47.00
       2004 |    555,617        3.43       50.43
       2005 |    569,126        3.51       53.93
       2006 |    588,984        3.63       57.57
       2007 |    620,927        3.83       61.40
       2008 |    625,008        3.85       65.25
       2009 |    606,826        3.74       68.99
       2010 |    654,734        4.04       73.03
       2011 |    711,311        4.39       77.42
       2012 |    775,109        4.78       82.20
       2013 |    806,796        4.98       87.17
       2014 |    764,784        4.72       91.89
       2015 |    660,138        4.07       95.96
       2016 |    457,764        2.82       98.78
       2017 |    186,208        1.15       99.93
       2018 |     10,813        0.07      100.0

*/




use "${TEMP}/invpat.dta", clear 
merge m:1 patent using "${IN}/main_data/data_new/cw_patent_compustat_adhps/cw_patent_compustat_adhps.dta", force 
* not matched 246,703 patents 


destring patent, replace force
merge m:1 patent using "${IN}/main_data/data_new/NBER_Patentdata/pat76_06_assg.dta" 
save "${TEMP}/invpat.dta", replace

* Not possible to match inventors to patents with this database 
import delimited "H:\InnovationProject\data\raw\main_data\data_new\harvard_patentdatabase\patentcity\inventor.geo.assignee.combo.disambig.tsv", clear 
keep if country=="US"
rename patno patent 
merge m:m patent using "${TEMP}/invpat.dta", force  



merge m:m patent using "${IN}/main_data/data_new/cw_patent_compustat_adhps/cw_patent_compustat_adhps.dta" 

recast str firstname
recast str lastname
merge m:m patent  using "${TEMP}/invpat.dta", force

/*  Result                      Number of obs
    -----------------------------------------
    Not matched                     5,676,116
        from master                 3,197,344  (_merge==1)
        from using                  2,478,772  (_merge==2)

    Matched                         1,424,671  (_merge==3)
    -----------------------------------------

*/



* Checking the difference between the Dorn dataset and the data for 1976 and 2006
use "${IN}/main_data/data_new/NBER_Patentdata/pat76_06_assg.dta", clear


 
merge m:1 pdpass using "${IN}/main_data/data_new/NBER_Patentdata/dynass.dta"


gen original_merge = _merge 
drop if original_merge==2 
drop _merge 
*  13400 unique assignee observations, 7.402 unique gvkey observations. So pdpass does not uniquely identify listed companies 

forvalues i =1/5 {
 rename gvkey`i' gvkey_nber`i' 
}

tostring patent, replace 
replace patent = "0" + patent 

merge m:1 patent using "${IN}/main_data/data_new/cw_patent_compustat_adhps/cw_patent_compustat_adhps.dta"
destring gvkey, replace



 
use "${IN}/main_data/data_new/cw_patent_compustat_adhps/cw_patent_compustat_adhps.dta", clear









* Importing the Patent Data City Set
import delimited "${IN}/main_data/data_new/harvard_patentdatabase/geoc_app_person.txt", clear 


import delimited "${IN}/main_data/data_new/invpat.csv", clear 
rename lower inventor_id 
* Unique Inventor State Year Observations: 6117827; Unique Inventor Year observations: 6077996 ; 

* Assigning the patents to the different locations 
bysort inventor_id appyear state: gen count =_N 
bysort inventor_id appyear: egen max_count = max(count)

keep if max_count == count 
* deletes 28,386  observations, still around 17.000 duplicates (Stantcheva assigns them randomly to a state, should we do the same?) 
egen pat_id = group(patent)
*Unique Inventor Assignee State Year Observations: 6555649
collapse (count) n_patents = pat_id, by(inventor_id appyear state assignee)


* Should we match the patents with gvkey according to https://github.com/arnauddyevre/compustat-patents? 

* Cleaning steps to fill in inventors 


