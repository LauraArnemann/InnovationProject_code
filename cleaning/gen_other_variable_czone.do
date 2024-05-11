// Project: Inventor Relocation
// Creation Date: 10/02/2024
// Last Update: 10/02/2024
// Author: Laura Arnemann 
// Goal: Generating the variation in the other variable on commuting zone level 


use "${TEMP}/patentcount_czone.dta"
merge 1:1 czone assignee_id app_year using "${TEMP}/inventorcount_cz.dta"
drop _merge 


* Merging in the other variables generated before 
merge m:1 fips_state assignee_id app_year using "${TEMP}/other_all_3.dta", keepusing(other_all* other_weighted)


* Generate the weights for the other variable 
bysort czone assignee_id: egen total_patents_assg = total(patents3)
bysort czone: egen total_patents_czone = total(patents3) 


gen share = total_patents_assg/total_patents_czone 

* Matray for example weights the commuting zone by the stock of patents an assignee has at the beginning of the sample period
foreach var of varlist other_all other_weighted {
	replace `var'_cz = share * `var'	
}

save "${TEMP}/other_variable_czone.dta", replace 