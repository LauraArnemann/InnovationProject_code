// Project: Inventor Relocation
// Creation Date: 10/02/2024
// Last Update: 10/02/2024
// Author: Laura Arnemann 
// Goal: Case Study Evidence 


global dataset 4 
* Information on Assigee Type e.g. if assignee is governmental entity 
use "${TEMP}/patents_helper_${dataset}.dta", clear
bysort assignee_id: gen count = _n 
keep if count ==1  
tempfile patentshelper
save `patentshelper'



use "${TEMP}/final_state_zeros_new_4_assignee.dta", clear 
rename multistatefirm_max max_multistate

merge m:1 assignee_id using `patentshelper', keepusing(noncorp_asg asg_corp pub_assg)
	drop if _merge ==2 
	drop _merge 

rename year app_year 
* For now I will focus on three large changes in rd credit where a lot of innovating activity takes place

* Treatment in California 
  gen treated_CA = 0 
   replace treated_CA = 1 if fips_state ==6 & app_year==1997 
   replace treated_CA = . if treated_CA ==1 & n_inventors3<5 
   replace treated_CA = . if missing(n_inventors3)
   bysort assignee_id app_year: egen max_treated_CA = max(treated_CA)
   gen byte helper_CA = fips_state==6 
   replace helper_CA = 2 if treated_CA ==1 
   bysort assignee_id: egen everpresent_CA = max(helper_CA)


* Treatment in Pennsylvania 
  gen treated_PA = 0 
  replace treated_PA = 1 if fips_state ==42 & app_year ==1997 
  replace treated_PA = . if treated_PA ==1 & n_inventors3<5 
  replace treated_PA = . if missing(n_inventors3)
  bysort assignee_id app_year: egen max_treated_PA = max(treated_PA)
  gen byte helper_PA = fips_state==42
  replace helper_PA = 2 if treated_PA ==1 
  bysort assignee_id: egen everpresent_PA = max(helper_PA)

* Treatment in Texas 
  gen treated_TX = 0 
  replace treated_TX = 1 if fips_state == 48 & (app_year ==2001 | app_year ==2002)
  replace treated_TX = . if treated_TX ==1 & n_inventors3<5
  replace treated_TX = . if missing(n_inventors3)
  bysort assignee_id app_year: egen max_treated_TX = max(treated_TX)
  gen byte helper_TX = fips_state==48
  replace helper_TX = 2 if treated_TX ==1 
  bysort assignee_id: egen everpresent_TX = max(helper_TX)

* Generating Clean Controls
gen clean_control_CA = 0 
replace clean_control_CA = 1 if fips_state==4 | fips_state==9 | fips_state==10 | fips_state==13 | fips_state==15 | fips_state==16 | fips_state==23 | fips_state==24 | fips_state==29 | fips_state==30 | fips_state==33 | fips_state==34 | fips_state==37 | fips_state==42 | fips_state==44 | fips_state==45 | fips_state==48 | fips_state==49
replace clean_control_CA = 0 if app_year <1993 | app_year >2001 
bysort assignee_id: egen nocontrol_CA = max(clean_control_CA)

gen clean_control_PA = 0 
replace clean_control_PA = 1 if fips_state==4 | fips_state==6 | fips_state==9 | fips_state==10 | fips_state==13 | fips_state==15 | fips_state==16 | fips_state==23 | fips_state==24 | fips_state==29 | fips_state==30 | fips_state==33 | fips_state==34 | fips_state==37 | fips_state==44 | fips_state==45 | fips_state==48 | fips_state==49 
replace clean_control_PA = 1 if app_year<1993 | app_year>2001
bysort assignee_id: egen nocontrol_PA = max(clean_control_PA)

gen clean_control_TX = 0 
replace clean_control_TX = 1 if fips_state==4 | fips_state==6 | fips_state==9 | fips_state==10 | fips_state==13 | fips_state==15 | fips_state==16 | fips_state==23| fips_state==24 | fips_state==29 | fips_state==30 | fips_state==33 | fips_state==34 | fips_state==37 | fips_state==42 | fips_state==44 | fips_state==45 | fips_state==49	
replace clean_control_TX = 0 if app_year<1997 | app_year>2005 
bysort assignee_id: egen nocontrol_TX = max(clean_control_TX)

egen state_estab = group(fips_state assignee_id)
xtset state_estab app_year 

foreach fips in CA PA TX {
forval i =0(1)4 {
   
    gen L`i'_treated_`fips' = l`i'.max_treated_`fips'
	label var L`i'_treated_`fips' "`i'"
	
    gen F`i'_treated_`fips' = f`i'.max_treated_`fips'
	label var F`i'_treated_`fips' "-`i'"  
	
}
   drop F0_treated_`fips' F1_treated_`fips'
}

* winsorizing 

foreach var of varlist patents1 patents2 patents3 n_inventors1 n_inventors2 n_inventors3 n_newinventors3 {
				gstats winsor `var', cut(1 99) gen(`var'_w1)
				gstats winsor `var', cut(1 95) gen(`var'_w2)
				gen ln_`var'=log(`var')
			}
						
gen zero_1 = 1	

bysort assignee_id app_year: egen total_patents = sum(patents3)


*patents3 n_inventors3 n_newinventors3 patents3_w1  n_newinventors3_w1 

forvalues i =6/6 {

foreach fips in CA {
foreach var of varlist n_inventors3_w1 {
      local sample1 
      local sample2 & everpresent_`fips'!=1 
      local sample3 & max_multistate ==1 & everpresent_`fips'!=1 
      local sample4 & max_multistate ==1 & everpresent_`fips'!=1 & patents3_w1>=10 & patents3_w1!=.
	  local sample5 & max_multistate ==1 & everpresent_`fips'!=1 & asg_corp==1
	  local sample6 & max_multistate ==1 & everpresent_`fips'!=1 & asg_corp==1 & clean_control_CA==0
	  *local sample6 & max_multistate ==1 & everpresent_`fips'!=1 & asg_corp==1 & nocontrol_`fips'!=1
	  *local sample7 & max_multistate ==1 & everpresent_`fips'!=1 & asg_corp==1 & total_patents>10  
	  *local sample5 & max_multistate ==1 & everpresent_`fips'!=1 & patents3_w1>=10 

    
	if "`fips'"=="CA" {
	local c = 6 
	}
	
	if "`fips'"=="PA" {
	local c = 42 
	}	
	
	else {	
	local c = 48 
    }
	
	ppmlhdfe `var' F?_treated_`fips' zero_1 L?_treated_`fips' if fips!=`c' `sample`i'' , absorb(state_estab app_year#fips_state) cl(state_estab)
	est sto inventorreg1 
	* Exporting the graph 
	coefplot inventorreg1, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
	xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) keep( F?_treated_`fips' zero_1  L?_treated_`fips') ///
	yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
    xtitle("Years since Change") graphregion(color(white))
	capture noisily graph export "${RESULTS}/casestudies/var`var'_`fips'_sample`i'.png", replace  
}

*ln_n_newinventors3 ln_patents3 
foreach var of varlist ln_n_inventors3   {
    
	reghdfe `var' F?_treated_`fips' zero_1 L?_treated_`fips' if fips!=`c' `sample`i'' , absorb(state_estab app_year#fips_state) cl(state_estab)
	est sto inventorreg1 
	* Exporting the graph 
	coefplot inventorreg1, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
	xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) keep( F?_treated_`fips' zero_1  L?_treated_`fips') ///
	yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
    xtitle("Years since Change") graphregion(color(white))
	capture noisily graph export "${RESULTS}/casestudies/var`var'_`fips'_sample`i'.png", replace  
							

}
}
}
 

/*
********************************************************************************
* Spillover Analysis 
******************************************************************************** 


use "${TEMP}/patentcount_czone_${dataset}_assignee.dta", clear 
merge 1:1 fips_state czone assignee_id app_year using "${TEMP}/inventorcount_czone_${dataset}_assignee.dta"
drop _merge 

merge m:1 assignee_id using `patentshelper', keepusing(noncorp_asg asg_corp pub_assg)
drop if _merge ==2 
drop _merge 


destring fips_state, replace 
* Generate an indicator for multistatefirms
bysort app_year assignee_id: gen count1 = _N 
bysort app_year assignee_id fips_state: gen count2 = _N 

gen multistatefirm = 0 
replace multistatefirm = 1 if count2>count1 
bysort assignee_id: egen max_multistatefirm = max(multistatefirm)
drop count1 count2 

bysort assignee_id fips_state: egen n_inventors_state = total(n_inventors3)

* Treatment in California 
   gen treated_CA = 0 
   replace treated_CA = 1 if fips_state ==6 & app_year ==1997 
   replace treated_CA = . if treated_CA ==1 & n_inventors_state<5 
   *replace treated_CA = . if asg_corp!=1 & treated_CA==1
   replace treated_CA = . if missing(n_inventors_state)
   bysort assignee_id app_year: egen max_treated_CA = max(treated_CA)
   gen byte helper_CA = fips_state==6 
   replace helper_CA = 2 if treated_CA ==1
   replace helper_CA = 0 if app_year <1993 | app_year >2001 
   bysort assignee_id: egen everpresent_CA = max(helper_CA)
/*
* Treatment in Pennsylvania 
  gen treated_PA = 0 
  replace treated_PA = 1 if fips_state ==42 & app_year ==1997 
  replace treated_PA = . if treated_PA ==1 & n_inventors_state<5 
  replace treated_PA = . if missing(n_inventors_state)
  bysort assignee_id app_year: egen max_treated_PA = max(treated_PA)
  gen byte helper_PA = fips_state==42
  replace helper_PA = 2 if treated_PA ==1 
  replace helper_PA = 0 if app_year<1993 | app_year>2001
  bysort assignee_id: egen everpresent_PA = max(helper_PA)

* Treatment in Texas 
  gen treated_TX = 0 
  replace treated_TX = 1 if fips_state == 48 & (app_year ==2001 | app_year ==2002)
  replace treated_TX = . if treated_TX ==1 & n_inventors_state<5
  replace treated_TX = . if missing(n_inventors_state)
  bysort assignee_id app_year: egen max_treated_TX = max(treated_TX)
  gen byte helper_TX = fips_state==48 
  replace helper_TX = 2 if treated_TX ==1 
  replace helper_TX = 0 if app_year<1997 | app_year>2005 
  bysort assignee_id: egen everpresent_TX = max(helper_TX)
 */ 
/* Generate an indicator on czone level if more than 10 percent of inventors in the czone were exposed to a tax change */ 

* Indicator for multistate CZ 
bysort app_year czone: gen count1 = _N 
bysort app_year czone fips_state: gen count2 = _N

gen multistate_cz = 0 
replace multistate_cz = 1 if count1>count2 
drop count1 count2 

bysort czone: egen max_multistate_cz = max(multistate_cz)
bysort czone app_year: egen inventors_total = total(n_inventors3)

foreach fips in CA  {
    
	gen inventors3_`fips' = n_inventors3 if max_treated_`fips'==1 
    bysort czone app_year: egen inventors3_`fips'_total = total(inventors3_`fips')
	gen share_treated_`fips' =  inventors3_`fips'_total/ inventors_total
	
	drop treated_`fips'
	*gen treated_`fips' = share_treated_CA 
	gen treated_`fips' = 0 
	replace treated_`fips' = 1 if share_treated_`fips'>=0.1 & !missing(share_treated_`fips')
	drop inventors3_`fips' inventors3_`fips'_total
	

	}

********************************************************************************	
* Generating indicators for clean controls 	
********************************************************************************


gen clean_control_CA = 0 
replace clean_control_CA = 1 if fips_state==4 | fips_state==9 | fips_state==10 | fips_state==13 | fips_state==15 | fips_state==16 | fips_state==23 | fips_state==24 | fips_state==29 | fips_state==30 | fips_state==33 | fips_state==34 | fips_state==37 | fips_state==42 | fips_state==44 | fips_state==45 | fips_state==48 | fips_state==49
replace clean_control_CA = 0 if app_year <1993 | app_year >2001 
bysort assignee_id: egen nocontrol_CA = max(clean_control_CA)

*gen clean_control_PA = 0 
*replace clean_control_PA = 1 if fips_state==4 | fips_state==6 | fips_state==9 | fips_state==10 | fips_state==13 | fips_state==15 | fips_state==16 | fips_state==23 | fips_state==24 | fips_state==29 | fips_state==30 | fips_state==33 | fips_state==34 | fips_state==37 | fips_state==44 | fips_state==45 | fips_state==48 | fips_state==49 
*replace clean_control_PA = 1 if app_year<1993 | app_year>2001
*bysort assignee_id: egen nocontrol_PA = max(clean_control_PA)

*gen clean_control_TX = 0 
*replace clean_control_TX = 1 if fips_state==4 | fips_state==6 | fips_state==9 | fips_state==10 | fips_state==13 | fips_state==15 | fips_state==16 | fips_state==23| fips_state==24 | fips_state==29 | fips_state==30 | fips_state==33 | fips_state==34 | fips_state==37 | fips_state==42 | fips_state==44 | fips_state==45 | fips_state==49	
*replace clean_control_TX = 0 if app_year<1997 | app_year>2005 
*bysort assignee_id: egen nocontrol_TX = max(clean_control_TX)


foreach fips in CA {

    gen inventors3_`fips' = n_inventors3 if nocontrol_`fips'==1 
    bysort czone app_year: egen inventors3_`fips'_total = total(inventors3_`fips')
	gen share_control_`fips' =  inventors3_`fips'_total/ inventors_total

	gen control_`fips' = 0 
	replace control_`fips' = 1 if share_control_`fips'>=0.1 & !missing(share_control_`fips')
	bysort czone: egen max_control_`fips' = max(control_`fips')
	
}

	
egen state_estab = group(fips_state assignee_id czone)
xtset state_estab app_year 

foreach fips in CA  {
forval i =0(1)4 {
   
    gen L`i'_treated_`fips' = l`i'.treated_`fips'
	label var L`i'_treated_`fips' "`i'"
	
    gen F`i'_treated_`fips' = f`i'.treated_`fips'
	label var F`i'_treated_`fips' "-`i'"  
	
}
   drop F0_treated_`fips' F1_treated_`fips'
}	

* Winsorizing 

foreach var of varlist patents1 patents2 patents3 n_inventors1 n_inventors2 n_inventors3 n_newinventors3 {
				gstats winsor `var', cut(1 99) gen(`var'_w1)
				gstats winsor `var', cut(1 95) gen(`var'_w2)
				gen ln_`var'=log(`var')
			}
						
gen zero_1 = 1	

* Run everything on assignee level 
  

forvalues i =5/5 {

*patents3 n_inventors3 n_newinventors3 patents3_w1 n_newinventors3_w1 
foreach fips in CA  {
foreach var of varlist  n_inventors3_w1 {
      local sample1 & everpresent_`fips'!=2 
	  local sample2 & everpresent_`fips'==0
	  local sample3 & everpresent_`fips'==0 & multistate_cz==0 
	  local sample4 & everpresent_`fips'==0 & max_multistatefirm==0
	  local sample5 & everpresent_`fips'==0 & nocontrol_`fips'!=1 
	  local sample6 & everpresent_`fips'==0 & nocontrol_`fips'!=1 & asg_corp==1 
	  local sample7 & everpresent_`fips'==0 & nocontrol_`fips'!=1 & noncorp_asg==0
 	  local sample8 & everpresent_`fips'==0 & nocontrol_`fips'!=1 & noncorp_asg==1 	 
	  *local sample6 & everpresent_`fips'==0 & max_control_`fips'!=1

	if "`fips'"=="CA" {
	local c = 6 
	}
	
	if "`fips'"=="PA" {
	local c = 42 
	}	
	
	else {	
	local c = 48 
    }
	
	ppmlhdfe `var' F?_treated_`fips' zero_1 L?_treated_`fips' if fips!=`c' `sample`i'' , absorb(state_estab app_year#fips_state) cl(czone)
	est sto inventorreg1 
	* Exporting the graph 
	coefplot inventorreg1, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
	xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) keep( F?_treated_`fips' zero_1  L?_treated_`fips') ///
	yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
    xtitle("Years since Change") graphregion(color(white))
	capture noisily graph export "${RESULTS}/casestudies/spillover_`var'_`fips'_sample`i'.png", replace  

	}
	
*ln_patents3 	ln_n_newinventors3 
	foreach var of varlist ln_n_inventors3   {
	
	
 reghdfe `var' F?_treated_`fips' zero_1 L?_treated_`fips' if fips!=`c' `sample`i'' , absorb(state_estab app_year#fips_state) cl(czone)
	est sto inventorreg1 
	* Exporting the graph 
	coefplot inventorreg1, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
	xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) keep( F?_treated_`fips' zero_1  L?_treated_`fips') ///
	yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
	 xtitle("Years since Change") graphregion(color(white))
	capture noisily graph export "${RESULTS}/casestudies/spillover_`var'_`fips'_sample`i'.png", replace  

}
}
}
 
 