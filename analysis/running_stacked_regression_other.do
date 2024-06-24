////////////////////////////////////////////////////////////////////////////////
// Project:        	Moving innovation
// Creation Date:  	19/03/2024
// Last Update:    	24/04/2024
// Authors:         Laura Arnemann
//					Theresa Bührle
// Goal: 			Running Stacked Regression: Change in credits at other locations 
////////////////////////////////////////////////////////////////////////////////


macro drop controls controls_other 

global controls rd_credit pit cit 

*assignee 

foreach type in gvkey {

foreach direction in incr {
		

********************************************************************************
* Events indicator on year level: Change at other locations  
********************************************************************************
/*
		foreach var2 in other_all3 other_weighted3 other_threelargest3   {
			
			use "${TEMP}/final_state_stacked_`var2'_incr_${dataset}_`type'_year.dta", replace 
			merge m:1 estab year using "${TEMP}/final_state_stacked_other_zeros_${dataset}_`type'.dta", nogen keep(3)
			
			bysort assignee_id year event: egen total_patents = total(patents3)
			
			egen assignee = group(assignee_id)

			foreach var of varlist patents1 patents2 patents3 n_inventors1 n_inventors2 n_inventors3 n_newinventors3 {
				gstats winsor `var', cut(1 99) gen(`var'_w1)
				gstats winsor `var', cut(1 95) gen(`var'_w2)
				gen ln_`var'=log(`var')
			}
			
			gen ln_gdp = log(`var2'_gdp)
			
		    * Balanced Panel: Only observations present four years before and four years after event
		    bysort estab: egen min_year = min(year)
		    bysort estab: egen max_year = max(year)
			bysort estab: egen estab_patents = total(patents3)
		 
                 
			*Generate the event indicators
			forvalues i=1/4 {
				gen f`i'_binary = ry_`direction'ease==-`i'
				label var f`i'_binary "- `i'"
			}

			forvalues i=0/4 {
				gen l`i'_binary = ry_`direction'ease==`i'
				label var l`i'_binary "`i'"
			}

			drop f1_binary 
			gen zero_1=1
			label var zero_1 "-1" 
			
		*Post dummy for DiD
		gen byte post_tr = (year>=event)
		
			* Set different sample restrictions as well 
		     local sample1 if year>=1988 
		     local sample2 if inrange(year, 1988, 2018)  & total_patents>5 
		     local sample3 if inrange(year, 1988, 2018)  & total_patents!=0
		     local sample4 if inrange(year, 1988, 2018) & estab_patents>5
			 local sample5 if inrange(year, 1988, 2018)  & total_patents>10 
			 local sample6 if inrange(year, 1988, 2018)  & balanced_panel==1
			 local sample7 if inrange(year, 1988, 2018)  & balanced_panel==1 & total_patents>10 
	
			
			forvalues i =4/7 {
				
				foreach outc in patents3 n_inventors3 n_newinventors3 patents3_w1 n_inventors3_w1 n_newinventors3_w1  {
				
				
				*Event studies
				 ppmlhdfe `outc' f4_binary f3_binary f2_binary zero_1 l?_binary `sample`i'', absorb(estab#event year#event) cl(estab#event)
				est sto inventorreg1
				coefplot inventorreg1, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
				xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) keep(f?_binary zero_1 l?_binary) ///
				yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
				title("`var2', `direction' - no controls") xtitle("Years since Change") graphregion(color(white))
				graph export "${RESULTS}/stackedregression/new_`type'_${dataset}/`outc'/stacked_other_`var2'_`direction'_sample`i'_year.png", replace  
						
				ppmlhdfe `outc' f4_binary f3_binary f2_binary zero_1 l?_binary $controls `sample`i'', absorb(estab#event year#event) cl(estab#event)
				 est sto inventorreg2
				coefplot inventorreg2, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
				xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) keep(f?_binary zero_1 l?_binary) ///
				yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
				title("`var2', `direction' - controls") xtitle("Years since Change") graphregion(color(white))
			graph export "${RESULTS}/stackedregression/new_`type'_${dataset}/`outc'/stacked_other_`var2'_`direction'_c1_sample`i'_year.png", replace  
					
				ppmlhdfe `outc' f4_binary f3_binary f2_binary zero_1 l?_binary $controls `var2'_pit `var2'_cit `sample`i'', absorb(estab#event year#event) cl(estab#event)
				 est sto inventorreg3
				coefplot inventorreg3, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
				xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) keep(f?_binary zero_1 l?_binary) ///
				yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
				title("`var2', `direction' - controls (incl other)") xtitle("Years since Change") graphregion(color(white))
				graph export "${RESULTS}/stackedregression/new_`type'_${dataset}/`outc'/stacked_other_`var2'_`direction'_c2_sample`i'_year.png", replace  
					
* Also run the logarithm to give comparability with chaisemartin estimator 
				foreach outc in ln_patents3 ln_n_inventors3 ln_n_newinventors3 {					
		reghdfe `outc' f4_binary f3_binary f2_binary zero_1 l?_binary $controls `var2'_pit `var2'_cit `sample`i'', absorb(estab#event year#event) cl(estab#event)
				est sto inventorreg3
				coefplot inventorreg3, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
				xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) keep(f?_binary zero_1 l?_binary) ///
				yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
				title("`var2', `direction' - controls (incl other)") xtitle("Years since Change") graphregion(color(white))
				graph export "${RESULTS}/stackedregression/new_`type'_${dataset}/`outc'/stacked_other_`var2'_`direction'_c2_sample`i'_year.png", replace  

				}
					

				}
			}
		}

*/
********************************************************************************
* Events indicator on state-year level: Change at other locations  
********************************************************************************		
	
foreach var2 in other_all3 other_weighted3 other_threelargest3   {
		
			use "${TEMP}/final_state_stacked_`var2'_incr_${dataset}_`type'_year.dta", replace 
			merge m:1 estab year using "${TEMP}/final_state_stacked_other_zeros_${dataset}_`type'.dta", nogen keep(3)
			
	
			bysort assignee_id year event: egen total_patents = total(patents3)
			
			egen assignee = group(assignee_id)

			foreach var of varlist patents1 patents2 patents3 n_inventors1 n_inventors2 n_inventors3 n_newinventors3 {
				gstats winsor `var', cut(1 99) gen(`var'_w1)
				gstats winsor `var', cut(1 95) gen(`var'_w2)
				gen ln_`var'=log(`var')
			}
			
			gen ln_gdp = log(`var2'_gdp)
			
		    * Balanced Panel: Only observations present four years before and four years after event
		    bysort estab: egen min_year = min(year)
		    bysort estab: egen max_year = max(year)
			bysort estab: egen estab_patents = total(patents3)
                 
			*Generate the event indicators
			forvalues i=1/4 {
				gen f`i'_binary = ry_`direction'ease==-`i'
				label var f`i'_binary "- `i'"
			}

			forvalues i=0/4 {
				gen l`i'_binary = ry_`direction'ease==`i'
				label var l`i'_binary "`i'"
			}

			drop f1_binary 
			gen zero_1=1
			label var zero_1 "-1" 
			
		*Post dummy for DiD
		gen byte post_tr = (year>=event)
			
			* Set different sample restrictions as well 
		 	local sample1 if inrange(year, 1988, 2018) 
		    local sample2 if inrange(year, 1988, 2014)  & n_patents>5 
		    local sample3 if inrange(year, 1988, 2014)  & n_patents!=0 
			local sample4 if inrange(year, 1988, 2018) & estab_patents>5
			 local sample5 if inrange(year, 1988, 2018)  & total_patents>10 
			 local sample6 if inrange(year, 1988, 2018)  & balanced_panel==1
			 local sample7 if inrange(year, 1988, 2018)  & balanced_panel==1 & total_patents>10 
			

			
			forvalues i =1/1 {
				
				foreach outc in patents3 n_inventors3 n_newinventors3 patents3_w1 n_inventors3_w1 n_newinventors3_w1  {
				
				
				*Event studies
				ppmlhdfe `outc' f4_binary f3_binary f2_binary zero_1 l?_binary `sample`i'', absorb(estab#event year#event#fips_state) cl(estab#event)
				 est sto inventorreg1
				coefplot inventorreg1, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
				xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) keep(f?_binary zero_1 l?_binary) ///
				yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
				title("`var2', `direction' - no controls") xtitle("Years since Change") graphregion(color(white))
					capture noisily graph export "${RESULTS}/stackedregression/new_`type'_${dataset}/`outc'/stacked_other_`var2'_`direction'_sample`i'_stateyear.png", replace  
		
					
				 ppmlhdfe `outc' f4_binary f3_binary f2_binary zero_1 l?_binary `var2'_pit `var2'_cit `sample`i'', absorb(estab#event year#event#fips_state) cl(estab#event)
				 est sto inventorreg3
				coefplot inventorreg3, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
				xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) keep(f?_binary zero_1 l?_binary) ///
				yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
				title("`var2', `direction' - controls (incl other)") xtitle("Years since Change") graphregion(color(white))
					capture noisily graph export "${RESULTS}/stackedregression/new_`type'_${dataset}/`outc'/stacked_other_`var2'_`direction'_c2_sample`i'_stateyear.png", replace  
					
* Also run the logarithm to give comparability with chaisemartin estimator 
				foreach outc in ln_patents3 ln_n_inventors3 ln_n_newinventors3 {					
		reghdfe `outc' f4_binary f3_binary f2_binary zero_1 l?_binary `var2'_pit `var2'_cit `sample`i'', absorb(estab#event year#event#fips_state) cl(estab#event)
				 est sto inventorreg3
				coefplot inventorreg3, vertical levels(95) recast(connected) omitted graphregion(color(white)) ///
				xline(4.5, lpattern(dash) lwidth(thin) lcolor(black)) keep(f?_binary zero_1 l?_binary) ///
				yline(0, lcolor(red) lwidth(thin)) ylabel(,labsize(medlarge)) ///
				title("`var2', `direction' - controls (incl other)") xtitle("Years since Change") graphregion(color(white))
					capture noisily graph export "${RESULTS}/stackedregression/new_`type'_${dataset}/`outc'/stacked_other_`var2'_`direction'_c2_sample`i'_stateyear.png", replace  

				}
			}
		}		
		
		
	}

}
}
