
use "${TEMP}/patentcount_czone_${dataset}_assignee.dta", clear 
merge 1:1 fips_state czone assignee_id app_year using "${TEMP}/inventorcount_czone_${dataset}_assignee.dta"
drop _merge 

destring fips_state, replace
* Merging in R&D credit observations 
merge m:1 fips_state app_year using "${TEMP}/state_data_cleaned.dta", keepusing(cit pit rd_credit )
	drop if _merge ==2
	drop _merge

*Changes at other locations
rename app_year year 


merge m:1 fips_state assignee_id year using "${TEMP}/other_threelargest_3_$dataset_treated.dta"
	drop if _merge == 2
	drop _merge

* Creating an indicator for only local firms 
bysort assignee_id year czone: gen helper = _n 
replace helper = . if helper!=1 
bysort assignee_id year: egen total_labs = total(helper)
bysort assignee_id : egen max_labs = max(total_labs)

gen tag_local = 1 if max_labs == 1 	
bysort czone year fips_state: gen n_labs = _N 

*CZ with firms that are treated	
bysort czone year: egen cz_treated = max(change_other_threelargest_d)

*Average rd_credit change of treated firms within CZ
bysort czone year: egen cz_treated_change = mean(change_other_threelargest)
replace cz_treated_change = 0 if cz_treated_change == .

*Weighted:
gen inv_count_multistate = n_inventors3 if tag_local != 1 
bysort czone year fips_state: egen sum_inv_multi = sum(inv_count_multistate)
gen weight_multi = inv_count_multistate / sum_inv_multi if inv_count_multistate != .
gen weighted_change = change_other_threelargest * weight_multi

bysort czone year fips_state: egen total_weighted_change = total(weighted_change)

* Importance of multi-state firms: 
	bysort fips_state czone year: egen sum_inv = sum(n_inventors3)
	gen share_inv = sum_inv_multi/sum_inv
	
* Trying to create similar outcomes as for the establishment level regression above
* Only assignees with more than 5 patents 
bysort assignee_id fips_state czone: egen estab_patents = total(patents3)
gen byte tag_estab_patents = estab_patents>5 

* Only assignees with a total of more than 10 patents in the respective year 
bysort assignee_id year: egen total_patents = total(patents3)
gen byte tag_total_patents = total_patents>10 

foreach var of varlist n_inventors3 n_newinventors3 patents3 {
	gen local_`var' = `var' if tag_local==1 
	gen estab_`var' = `var' if tag_estab_patents == 1
	gen total_`var' = `var' if tag_total_patents == 1 
	gen pub_`var' = `var' if pub_asg == 1 
}
	
	
*Drop firms with changes 4 years before and four years after 
egen estab_id = group(assignee_id fips_state czone)

xtset estab_id year 

local x change_other_threelargest
forval f = 4(-1)1 {
		gen F`f'_`x' = F`f'.`x'		
		label var F`f'_`x' "- `f'"
		} // f

	forval l = 0(1)4{		
		gen L`l'_`x' = L`l'.`x'
		label var L`l'_`x' " `l'"
		} // l

forvalues i =1/4 {
	drop if F`i'_change_other_threelargest!=0 & F`i'_change_other_threelargest!=. 
	drop if L`i'_change_other_threelargest!=0 & L`i'_change_other_threelargest!=. 
}

drop if change_other_threelargest!=0 & change_other_threelargest!=. 

* Collapse everything on commuting zone level 
collapse (sum) n_inventors3 patents3 n_newinventors3 local_n_inventors3 local_n_newinventors3 local_patents3 estab_n_inventors3 estab_n_newinventors3 estab_patents3 total_n_inventors3 total_n_newinventors3 total_patents3 (max) cz_treated_change_w = total_weighted_change  max_labs = n_labs max_pit = pit max_rd_credit = rd_credit max_cit = cit max_share_inv = share_inv, by(czone year fips_state)

bysort czone year: gen count = _N 
gen byte multistate_cz = count>1 

save "${TEMP}/final_cz_${dataset}_aggregate.dta", replace 


