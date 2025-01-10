////////////////////////////////////////////////////////////////////////////////
// Project:        	Moving innovation
// Creation Date:  	05/08/2024
// Last Update:    	29/10/2024
// Authors:         Laura Arnemann
//					Theresa Bührle
// Goal: 			Calculating spillover effects with two-way fixed effects analysis
//					Including technological proximity
////////////////////////////////////////////////////////////////////////////////

********************************************************************************
*SAMPLE
********************************************************************************

use "${TEMP}/final_cz_tech.dta", clear 

foreach var of varlist patents3 n_inventors3 n_newinventors3 {
	gstats winsor `var', cut(1 99) gen(`var'_w1)
	gstats winsor `var', cut(1 95) gen(`var'_w2)
	gen ln_`var'=log(`var')
}


replace change_other_threelargest = 0 if missing(change_other_threelargest)
replace other_credit_threelargest = 0 if missing(other_credit_threelargest)
bysort assignee_id year: egen total_patents = total(patents3)

xtset estab_id year 

********************************************************************************
*DYNAMIC ANALYSIS
********************************************************************************

*Create time dummies 
forvalues i =1/2 {
	
	gen change_otherstates`i' = weightedtec_change`i' 
	gen byte incr_otherstates`i'  = weightedtec_change`i'  >0
	replace incr_otherstates`i'  = . if weightedtec_change`i' <0 
	gen byte decr_otherstates`i'  = weightedtec_change`i'  <0
	replace decr_otherstates`i'  = . if weightedtec_change`i' >0 
			
	foreach x in change_otherstates`i'  {
		
		forval f = 4(-1)1 {
			gen F`f'_`x' = F`f'.`x'		
			label var F`f'_`x' "- `f'"
			} // f

		forval l = 0(1)4{		
			gen L`l'_`x' = L`l'.`x'
			label var L`l'_`x' " `l'"
			} // l
				
		* Binning off of the event studies: 
		capture drop sum_F4_`x'
		gsort estab_id -year
		bysort estab_id: gen sum_F4_`x'=sum(F4_`x')

		sort estab_id year
		capture drop sum_L4_`x'
		bysort estab_id: gen sum_L4_`x'=sum(L4_`x')	
	}
}

drop F1* 
gen zero_1=1
label var zero_1 "-1"

*Set samples
local sample1 if inrange(year, 1988, 2018)
local sample2 if inrange(year, 1988, 2018) & total_patents>10 
local sample3 if inrange(year, 1988, 2018) & total_patents<10 
local sample4 if inrange(year, 1988, 2018) & pub_assg==1 
local sample5 if inrange(year, 1988, 2018) & asg_corp==1
local sample6 if inrange(year, 1988, 2018) & noncorp_asg==0
local sample7 if inrange(year, 1988, 2018) & max_tr_other_threelargest!=1 
local sample8 if inrange(year, 1988, 2018) & tag_local==1
local sample9 if inrange(year, 1988, 2018) & treated!=1  	
local sample10 if inrange(year, 1988, 2018) & multistate_cz ==0 
local sample11 if inrange(year, 1988, 2018) & tag_local==1 & multistate_cz ==0 
local sample12 if inrange(year, 1988, 2018) & noncorp_asg==1

*Set regression elements
local outcome n_inventors3_w1 
local outcome_log ln_n_inventors3 
local direction change
local clusterlevel czone

foreach expl of numlist 1 2 {
	
	foreach x in `direction'_otherstates`expl' {
		replace F4_`x'=sum_F4_`x'
		replace L4_`x'=sum_L4_`x'
	}
	
	forvalues i = 1/2 {
		
		** Poisson regression
		foreach var of varlist `outcome' {
			
			if `i'!=9 {
				ppmlhdfe `var' F?_`direction'_otherstates`expl' L?_`direction'_otherstates`expl' zero_1 `sample`i'' & treated!=1, absorb(estab_id year#i.fips_state) cl(`clusterlevel')
						est sto regres1
						coefplot regres1, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
							keep( F?_`direction'_otherstates`expl' zero_1 L?_`direction'_otherstates`expl' ) yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
							order( F?_`direction'_otherstates`expl' zero_1 L?_`direction'_otherstates`expl' ) ///
							xtitle("Years since `direction'") graphregion(color(white)) 
				capture noisily graph export "$RESULTS/eventstudies/tech/weight`expl'/`var'_spillover_sample`i'_c1_bin_`direction'.png", replace
				
				ppmlhdfe `var' F?_`direction'_otherstates`expl' L?_`direction'_otherstates`expl' zero_1 `sample`i'' & treated!=1, absorb(estab_id year#i.fips_state year#czone) cl(`clusterlevel')
						est sto regres1
						coefplot regres1, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
							keep( F?_`direction'_otherstates`expl' zero_1 L?_`direction'_otherstates`expl' ) yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
							order( F?_`direction'_otherstates`expl' zero_1 L?_`direction'_otherstates`expl' ) ///
							xtitle("Years since `direction'") graphregion(color(white)) 
				capture noisily graph export "$RESULTS/eventstudies/tech/weight`expl'/`var'_spillover_sample`i'_c1b_bin_`direction'.png", replace
				
				
			}
			
			ppmlhdfe `var' F?_`direction'_otherstates`expl' L?_`direction'_otherstates`expl' change_other_threelargest zero_1 `sample`i'', absorb(estab_id year#i.fips_state) cl(`clusterlevel')
					est sto regres2
					coefplot regres2, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
						keep( F?_`direction'_otherstates`expl' zero_1 L?_`direction'_otherstates`expl' ) yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
						order( F?_`direction'_otherstates`expl' zero_1 L?_`direction'_otherstates`expl' ) ///
						xtitle("Years since `direction'")  graphregion(color(white)) 
			capture noisily graph export "$RESULTS/eventstudies/tech/weight`expl'/`var'_spillover_sample`i'_c2_bin_`direction'.png", replace
			
			ppmlhdfe `var' F?_`direction'_otherstates`expl' L?_`direction'_otherstates`expl' change_other_threelargest zero_1 `sample`i'', absorb(estab_id year#i.fips_state year#czone) cl(`clusterlevel')
					est sto regres2
					coefplot regres2, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
						keep( F?_`direction'_otherstates`expl' zero_1 L?_`direction'_otherstates`expl' ) yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
						order( F?_`direction'_otherstates`expl' zero_1 L?_`direction'_otherstates`expl' ) ///
						xtitle("Years since `direction'")  graphregion(color(white)) 
			capture noisily graph export "$RESULTS/eventstudies/tech/weight`expl'/`var'_spillover_sample`i'_c2b_bin_`direction'.png", replace
		}
		
		/*
		** Regular regression
		foreach var of varlist `outcome_log' {
			
			if `i'!=9 {
				reghdfe `var' F?_`direction'_otherstates`expl' L?_`direction'_otherstates`expl'  zero_1 `sample`i'' & treated!=1, absorb(estab_id year#i.fips_state) cl(`cl')
						est sto regres3
						coefplot regres3, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
							keep( F?_`direction'_otherstates`expl' zero_1 L?_`direction'_otherstates`expl' ) yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
							order( F?_`direction'_otherstates`expl' zero_1 L?_`direction'_otherstates`expl' ) ///
							xtitle("Years since `direction'") graphregion(color(white)) 
				capture noisily graph export "$RESULTS/eventstudies/tech/weight`expl'/`var'_spillover_sample`i'_c1_bin_`direction'.png", replace
			}
			
			reghdfe `var' F?_`direction'_otherstates`expl' L?_`direction'_otherstates`expl' change_other_threelargest zero_1 `sample`i'', absorb(estab_id year#i.fips_state) cl(`cl')
					est sto regres4
					coefplot regres4, vertical  levels(95)  recast(connected)  omitted graphregion(color(white)) xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) ///
						keep( F?_`direction'_otherstates`expl' zero_1 L?_`direction'_otherstates`expl' ) yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
						order( F?_`direction'_otherstates`expl' zero_1 L?_`direction'_otherstates`expl' ) ///
						xtitle("Years since `direction'")  graphregion(color(white)) 
			capture noisily graph export "$RESULTS/eventstudies/tech/weight`expl'/`var'_spillover_sample`i'_c2_bin_`direction'.png", replace
		}
		*/
	}
}


********************************************************************************
*STATIC ANALYSIS
********************************************************************************
*Set samples
local sample1 if inrange(year, 1988, 2018)
local sample2 if inrange(year, 1988, 2018) & max_tr_other_threelargest!=1 
local sample3 if inrange(year, 1988, 2018) & total_patents>10 
local sample4 if inrange(year, 1988, 2018) & max_tr_other_threelargest!=1  & total_patents>10
local sample5 if inrange(year, 1988, 2018) & tag_local ==1  

*Set regression elements
local outcome n_inventors3_w1 
local outcome_log ln_n_inventors3 
local direction change
local clusterlevel czone

foreach expl of numlist 2  {
	
	** Poisson regression
	foreach var of varlist `outcome' {
	
		forvalues i = 1/5 {
			
			capture noisily ppmlhdfe `var' weightedtec_change`expl' `sample`i'', absorb(estab_id year#i.fips_state) cl(`clusterlevel')
			cap est sto regres1`i'_p
			estadd local yearfe "\checkmark", replace
			estadd local estabfe "\checkmark", replace
			
			capture noisily ppmlhdfe `var' weightedtec_change`expl' `sample`i'', absorb(estab_id year#i.fips_state year#czone) cl(`clusterlevel')
			est sto regres1b`i'_p
			estadd local yearfe "\checkmark", replace
			estadd local estabfe "\checkmark", replace
				
			capture noisily ppmlhdfe n_inventors3_w1 weightedtec_change`expl' other_threelargest `sample`i'', absorb(estab_id year#i.fips_state) cl(`clusterlevel')
			est sto regres2`i'_p
			estadd local stateyearfe "\checkmark", replace
			estadd local estabfe "\checkmark", replace
			estadd local othercontrols "\checkmark", replace
			
			capture noisily ppmlhdfe n_inventors3_w1 weightedtec_change`expl' other_threelargest `sample`i'', absorb(estab_id year#i.fips_state year#czone) cl(`clusterlevel')
			est sto regres2b`i'_p
			estadd local stateyearfe "\checkmark", replace
			estadd local estabfe "\checkmark", replace
			estadd local othercontrols "\checkmark", replace
			
			
		}
		
	esttab regres11_p regres21_p regres12_p regres22_p using "${RESULTS}/tables/spillovers/var`var'_spillovers1_tech_p.tex", replace noconstant mtitles keep(`explaining') ///
				cells(b(star fmt(%9.3f)) se(par)) stats( estabfe stateyearfe othercontrols N, ///
				fmt(%9.0g %9.0g %9.0g %9.0g %9.0g %9.0g ) label("Firm FE" "State-Year FE"  "R\&D Credit, other" "Observations")) mgroups("All" "No Treatment", ///
				pattern(1 0 1 0) prefix(\multicolumn{@span}{c}{) suffix(}) span) ///
				collabels(none) starl(* .10 ** .05 *** .01) label 
	
	esttab regres1b1_p regres2b1_p regres1b2_p regres2b2_p using "${RESULTS}/tables/spillovers/var`var'_spillovers1b_tech_p.tex", replace noconstant mtitles keep(`explaining') ///
				cells(b(star fmt(%9.3f)) se(par)) stats(estabfe stateyearfe czyearfe othercontrols N, ///
				fmt(%9.0g %9.0g %9.0g %9.0g %9.0g %9.0g ) label("Firm FE" "State-Year FE"  "CZ-year FE" "R\&D Credit, other" "Observations")) mgroups("All" "No Treatment", ///
				pattern(1 0 1 0) prefix(\multicolumn{@span}{c}{) suffix(}) span) ///
				collabels(none) starl(* .10 ** .05 *** .01) label 
				
	
	esttab regres13_p regres23_p regres14_p regres24_p using "${RESULTS}/tables/spillovers/var`var'_spillovers2_tech_p.tex", replace noconstant mtitles keep(`explaining') ///
				cells(b(star fmt(%9.3f)) se(par)) stats( estabfe stateyearfe othercontrols N, ///
				fmt(%9.0g %9.0g %9.0g %9.0g %9.0g %9.0g ) label("Firm FE" "State-Year FE"  "R\&D Credit, other" "Observations")) mgroups("All" "No Treatment", ///
				pattern(1 0 1 0) prefix(\multicolumn{@span}{c}{) suffix(}) span) ///
				collabels(none) starl(* .10 ** .05 *** .01) label 
				
	esttab regres1b3_p regres2b3_p regres1b4_p regres2b4_p using "${RESULTS}/tables/spillovers/var`var'_spillovers2b_tech_p.tex", replace noconstant mtitles keep(`explaining') ///
				cells(b(star fmt(%9.3f)) se(par)) stats( estabfe stateyearfe czyearfe othercontrols N, ///
				fmt(%9.0g %9.0g %9.0g %9.0g %9.0g %9.0g ) label("Firm FE" "State-Year FE" "CZ-year FE"  "R\&D Credit, other" "Observations")) mgroups("All" "No Treatment", ///
				pattern(1 0 1 0) prefix(\multicolumn{@span}{c}{) suffix(}) span) ///
				collabels(none) starl(* .10 ** .05 *** .01) label 
				
				
	esttab regres15_p regres25_p  regres1b5_p regres2b5_p using "${RESULTS}/tables/spillovers/var`var'_spillovers3_tech_p.tex", replace noconstant mtitles keep(`explaining') ///
				cells(b(star fmt(%9.3f)) se(par)) stats( estabfe stateyearfe othercontrols N, ///
				fmt(%9.0g %9.0g %9.0g %9.0g %9.0g %9.0g ) label("Firm FE" "State-Year FE"  "R\&D Credit, other" "Observations")) mgroups("Local" "Large local", ///
				pattern(1 0 1 0) prefix(\multicolumn{@span}{c}{) suffix(}) span) ///
				collabels(none) starl(* .10 ** .05 *** .01) label 
			
	}
	/*
	** Regular regression
	foreach var of varlist `outcome_log' {
		
		forvalues i = 5/6 {
			capture noisily reghdfe `var' weightedtec_change`expl' `sample`i'', absorb(estab_id year#i.fips_state) cl(`clusterlevel')
			est sto regres1`i'_lin
			estadd local yearfe "\checkmark", replace
			estadd local estabfe "\checkmark", replace
			
			capture noisily reghdfe n_inventors3_w1 weightedtec_change`expl' other_threelargest `sample`i'', absorb(estab_id year#i.fips_state) cl(`clusterlevel')
			est sto regres2`i'_lin
			estadd local stateyearfe "\checkmark", replace
			estadd local estabfe "\checkmark", replace
			estadd local othercontrols "\checkmark", replace
		}
		
	esttab regres11_lin regres21_lin regres12_lin regres22_lin using "${RESULTS}/tables/spillovers/var`var'_spillovers1_tech_lin.tex", replace noconstant mtitles keep(`explaining') ///
				cells(b(star fmt(%9.3f)) se(par)) stats( estabfe stateyearfe othercontrols N, ///
				fmt(%9.0g %9.0g %9.0g %9.0g %9.0g %9.0g ) label("Firm FE" "State-Year FE"  "R\&D Credit, other" "Observations")) mgroups("All" "No Treatment", ///
				pattern(1 0 1 0) prefix(\multicolumn{@span}{c}{) suffix(}) span) ///
				collabels(none) starl(* .10 ** .05 *** .01) label 

	esttab regres13_lin regres23_lin regres14_lin regres24_lin using "${RESULTS}/tables/spillovers/var`var'_spillovers2_tech_lin.tex", replace noconstant mtitles keep(`explaining') ///
				cells(b(star fmt(%9.3f)) se(par)) stats( estabfe stateyearfe othercontrols N, ///
				fmt(%9.0g %9.0g %9.0g %9.0g %9.0g %9.0g ) label("Firm FE" "State-Year FE"  "R\&D Credit, other" "Observations")) mgroups("All" "No Treatment", ///
				pattern(1 0 1 0) prefix(\multicolumn{@span}{c}{) suffix(}) span) ///
				collabels(none) starl(* .10 ** .05 *** .01) label 	
	}
	*/
}







