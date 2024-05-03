////////////////////////////////////////////////////////////////////////////////
// Project:        	Moving innovation
// Creation Date:  	19/03/2024
// Last Update:    	24/04/2024
// Authors:         Laura Arnemann
//					Theresa Bührle
// Goal: 			Running Stacked Regression
////////////////////////////////////////////////////////////////////////////////

global controls pit cit 
global controls_other rd_credit_other pit_other cit_other

global controls2 $controls ln_gdp unemployment ln_state_rd_exp
global controls_other2 $controls_other ln_gdp_other unemployment_other ln_state_rd_exp_other

local direction incr decr
*incr decr 
local indepvar rd_credit 
*pit cit rd_credit_first rd_credit_10pat rd_credit_rank
local outcome patents3 share_patents3_multistate n_inventors3 n_newinventors3


local weightingvar rd_credit rd_credit_first rd_credit_10pat rd_credit_rank

foreach var in `weightingvar' {
local other_var  total_`weightingvar'  
*total_`indepvar'  `indepvar'_other_b `indepvar'_l1_other `indepvar'_l2_other `indepvar'_l3_other `indepvar'_l4_other `indepvar'_l1_other_b `indepvar'_l2_other_b `indepvar'_l3_other_b `indepvar'_l4_other_b 
}

* Call dofiles for the different effects 

do "${CODE}/running_stacked_regression_current.do"
do "${CODE}/running_stacked_regression_other.do"

