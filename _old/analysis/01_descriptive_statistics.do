/// PROJECT: Spillover Effects 
/// GOAL: Maps for CIT and R+D 
/// AUTHOR: Laura Arnemann, Theresa Bührle
/// CREATION: 27-12-2022
/// LAST UPDATE: 25-04-2023
/// SOURCE: Raw Data 


import excel "${basedir}\2_1_Data\state_abbrev.xlsx", sheet("Sheet1") firstrow clear
save "$TEMP/abbrev.dta", replace 


import excel "${basedir}\2_1_Data\corporate_tax_rate_28_10.xlsx", sheet("corporate_tax") firstrow clear 

foreach var of varlist _all {
	local f: variable label `var'
	rename `var' cit`f'
}

rename citState state 
drop citAbk citComment
destring cit*, replace force 
reshape long cit, i(state) j(year)
destring cit, replace 
replace cit=cit*100

encode state, gen(state_id)
xtset state_id year 
gen cit_change=cit-l.cit

replace cit_change=0 if cit_change<0.5 & cit_change>-0.5
gen change=1 if cit_change!=0 & cit_change!=. 
replace change=0 if cit_change==0 
 
*bysort state: egen mean_change=mean(cit_change)

merge m:1 state using "$TEMP/abbrev.dta"
drop if _merge==2 
drop _merge 
replace abbrev="CA" if state=="Kalifornien"
replace abbrev="NH" if state=="New Hamspire"

drop state_id state 
rename abbrev state 

save "$TEMP/cit.dta", replace 

*Figure 4 
*Generate the maps
cd "$basedir/2_1_Data/cb_2018_us_state_20m"
*cd "${root}\raw\communes-20180101-shp"
* A. Convert shapefile to Stata attribute and coordinate datasets *
#delimit ; 
shp2dta using cb_2018_us_state_20m, data("reg‐attr.dta") coord("reg‐coord.dta")
genid(stid) gencentroids(cc) replace
;
#delimit cr
* B. Merge data with attribute dataset *
use "reg‐attr.dta", clear
rename STUSPS state 

save "reg‐attr.dta", replace


use "reg‐attr.dta", clear
merge 1:m state using "$TEMP/cit.dta"
drop if _merge<3

*Puerto Rico is not in our dataset ok*
drop _merge
drop if  state=="HI" | state=="AK"


*Generate mean level of statetax


keep if year==2006
*Map with number of variations
foreach v in mean_change {
	su `v', d 
	label define scale 0 "0" 1 "1" 2 "2" 3 "3" 4 ">4" 
	gen gr=0 if `v'==0 
	replace gr=1 if `v'==1 
	replace gr=2 if `v'==2 
	replace gr=3 if `v'==3 
	replace gr=4 if `v'>3 & `v'!=.

	if "`v'"=="n_change" {
		local f `"Number of Changes"'
	}
	
	label value gr scale 
	local color YlOrRd
	* C. Draw map *
	#delimit ; 
	spmap gr using "reg‐coord.dta", id(stid) fcolor(`color')  clmethod(unique)
	ocolor(gs13 ..) osize(vvthin ..) ndfcolor(white) ndocolor(gs13) legend(		position(5) size(medium))
	legtitle("`f'") 
	;
	graph export "$output/`v'-map.png", replace
	; 
	#delimit cr	
	label drop scale
	drop gr

} //v




********************************************************************************
* Changes in R+D User Cost
********************************************************************************
use "${OUT}/moretti_sample_final.dta", clear
rename rho_low RD_usercost
keep state year RD_usercost 
duplicates drop state year, force 
keep if year>=1992 
encode state, gen(state_id)
xtset state_id  year

gen change_usercost=RD_usercost-l.RD_usercost
*replace change_usercost=0 if inrange(change_usercost,-0.09999, 0.0999)

bysort state: egen mean_change=mean(change_usercost)


save "${TEMP}/rd_usercost.dta", replace 


*Figure 4 
*Generate the maps
cd "$basedir/2_1_Data/cb_2018_us_state_20m"
*cd "${root}\raw\communes-20180101-shp"
* A. Convert shapefile to Stata attribute and coordinate datasets *
#delimit ; 
shp2dta using cb_2018_us_state_20m, data("reg‐attr.dta") coord("reg‐coord.dta")
genid(stid) gencentroids(cc) replace
;
#delimit cr
* B. Merge data with attribute dataset *
use "reg‐attr.dta", clear
rename STUSPS state 

save "reg‐attr.dta", replace


use "reg‐attr.dta", clear
merge 1:m state using "${TEMP}/rd_usercost.dta"
drop if _merge<3

*Puerto Rico is not in our dataset ok*
drop _merge
drop if state=="HI" | state=="AK"


*Generate mean level of statetax

keep if year==2006
*Map with number of variations
foreach v in mean_change {
	su `v', d 
	label define scale 0 "<-0.005" 1 "(-0.005; -0.003]" 2 "(-0.003; 0]" 3 "(0; 0.0006]" 4 ">0.0006" 
	gen gr=0 if `v'<-0.005
	replace gr=1 if inrange(`v', -0.005, -0.003) 
	replace gr=2 if inrange(`v', -0.003, 0) 
	replace gr=3 if inrange(`v', 0, 0.0006) 
	replace gr=4 if `v'>0.0006 & `v'!=.

	if "`v'"=="n_change" {
		local f `"Number of Changes"'
	}
	
	label value gr scale 
	local color YlOrRd
	* C. Draw map *
	#delimit ; 
	spmap gr using "reg‐coord.dta", id(stid) fcolor(`color')  clmethod(unique)
	ocolor(gs13 ..) osize(vvthin ..) ndfcolor(white) ndocolor(gs13) legend(		position(5) size(medium))
	legtitle("`f'") 
	;
	graph export "$output/`v'-map.png", replace
	; 
	#delimit cr	
	label drop scale
	drop gr

} //v


* Descriptives: Number of Inventors Migrating each year/Number of Inventors migrating but staying in the same firm

use "${TEMP}/inventor_applications.dta", clear 
drop if withdrawn==1 

* Moretti Sample Restrictions to check if we have more or less the same observations
keep if inrange(app_year,1992,2018)
duplicates drop inventor_id app_year, force  
drop move 
gen move=0
bysort inventor_id (app_year): replace move=1 if state_inventor!=state_inventor[_n-1]
bysort inventor_id (app_year): gen count=_n 
replace move=0 if count==1

gen firm_move=0 
bysort inventor_id (app_year): replace firm_move=1 if state_inventor!=state_inventor[_n-1] & assignee_id==assignee_id[_n-1]

replace firm_move=0 if count==1 
replace firm_move=. if move==0


*******************************************************************************
* Share of movers per year/Share of within-firm movers per year 
******************************************************************************* 
graph bar move if app_year>1992, over(app_year, label(angle(45) labsize(small))) bgcolor(white) graphregion(color(white)) ytitle("Fraction of Inventors") 
graph export "$output/movers.pdf", replace 

graph bar firm_move if app_year>1992, over(app_year, label(angle(45) labsize(small))) bgcolor(white) bar(1, color(red%75) ) graphregion(color(white)) ytitle("Fraction of Movers")
graph export "$output/firmmovers.pdf", replace 