

*******************************************************************************
* Assess the number of linked companies 
********************************************************************************
 use "${TEMP}/linking_table/public_linkingtable2.dta", clear 
 duplicates drop gvkey, force 
 save  "${TEMP}/linking_table/public_linkingtable2_v2.dta", replace 
 


import delimited "${IN}/main_data/data_compustat/compustat_1950_2023_rd.csv", clear 
merge m:1 gvkey using "${TEMP}/linking_table/public_linkingtable1_v2.dta"

/*

    Result                      Number of obs
    -----------------------------------------
    Not matched                       404,956
        from master                   404,956  (_merge==1)
        from using                          0  (_merge==2)

    Matched                           201,948  (_merge==3)
    -----------------------------------------
*/

drop if _merge==2 
gen max_merge = _merge if _merge==3 
drop _merge 


merge m:1 gvkey using "${TEMP}/linking_table/public_linkingtable2_v2.dta"
* 3.218 observations already matched 
replace max_merge =3 if _merge==3 
drop _merge 
replace max_merge=0 if missing(max_merge)

merge m:1 gvkey using "${TEMP}/linking_table/nonpublic_linkingtable3.dta"
replace max_merge =3 if _merge==3 
drop _merge

merge m:1 gvkey using "${TEMP}/linking_table/linking_table1.dta"
replace max_merge =3 if _merge==3 
drop _merge

merge m:1 gvkey using "${TEMP}/linking_table/linking_table2.dta"
replace max_merge =3 if _merge==3 
drop _merge

* This way I already matched 40% of the observations with the NETS database 

/*
 max_merge |      Freq.     Percent        Cum.
------------+-----------------------------------
          0 |    281,103       73.33       73.33
          3 |    102,216       26.67      100.00
------------+-----------------------------------
      Total |    383,319      100.00

*/

rename fyear gyear 
merge 1:m gvkey gyear using "${IN}/main_data/data_patents/patmatch.dta"

/* 
    Result                      Number of obs
    -----------------------------------------
    Not matched                       889,216
        from master                   498,011  (_merge==1)
        from using                    391,205  (_merge==2)

    Matched                         1,764,502  (_merge==3)
*/

* Currently we match half of the companies with positive R+D expenditure, overall 26.67 percent of all companies 

/*
use "C:\Users\laura\Desktop\patent_gvkey_merge_reclink_allmatched.dta", clear

duplicates tag gvkey, gen(dup)
drop if dup>0 

tempfile patents 
save `patents', replace 


use "${IN}/main_data/data_compustat/crosswalk/gvkey_patents.dta", clear 
duplicates drop gvkey, force 
tempfile autor_dorn_match 
save `autor_dorn_match', replace 


import delimited "${IN}/main_data/data_compustat/compustat_1950_2023_rd.csv", clear 

merge m:1 gvkey using `patents'
bysort gvkey: egen max_merge=max(_merge)
drop if _merge==2 
drop _merge

merge m:1 gvkey using `autor_dorn_match'
replace max_merge=_merge if max_merge!=3 

*/

