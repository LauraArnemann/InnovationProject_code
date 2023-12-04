**** Assess how many of the linked companies have positive R+D expenditures**** 



use "C:\Users\laura\Desktop\patent_gvkey_merge_reclink_allmatched.dta", clear

duplicates tag gvkey, gen(dup)
drop if dup>0 

tempfile patents 
save `patents', replace 


use "${IN}/gvkey_patents.dta", clear 
duplicates drop gvkey, force 
tempfile autor_dorn_match 
save `autor_dorn_match', replace 


import delimited "${IN}\compustat_1950_2023.csv", clear 

merge m:1 gvkey using `patents'
bysort gvkey: egen max_merge=max(_merge)
drop if _merge==2 
drop _merge

merge m:1 gvkey using `autor_dorn_match'
replace max_merge=_merge if max_merge!=3 



