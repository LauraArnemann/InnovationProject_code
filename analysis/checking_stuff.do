

use "${TEMP}/final_cz_${dataset}_corp_new_07_08.dta", clear

keep n_inventors3 patents3 n_newinventors3 cz_treated_change_w6 czone assignee_id fips_state year

foreach var of varlist  n_inventors3 patents3 n_newinventors3 cz_treated_change_w6 {
rename `var' `var'_new
}

merge 1:1 assignee_id fips_state czone year using "${TEMP}/final_cz_${dataset}_corp.dta"