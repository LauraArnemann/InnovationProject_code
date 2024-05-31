/// PROJECT: Spillover Effects 
/// GOAL: Regression - Mobility at county/commuting zone level
/// AUTHOR: Theresa Bührle, tbuehrle@diw.de
/// CREATION: 11-01-2024
/// LAST UPDATE: 07-02-2024
/// DATA: Woeppel patent data

///PRE-REQUISITE:  invmoves_data_Woeppel.do

*Set variables
global controls_inv GDP_inv_log corprate_inv t_pinc_rate_inv RA_inv			
global controls_other GDP_net_wghd_CZ_log corprate_net_wghd_CZ t_pinc_rate_net_wghd_CZ RA_net_wghd_CZ
global controls_add n_inv_total_state_L1_w1_log	

global FE_var CZ_inv app_year
global clustervar state_inv
 
//Let's take the US cenzus CZ for now; there we have the most inventor moves	
	
*dep var: patents, inventors
*indep var: R&D 	

*1. Prepare data ***************************************************************	

/*
// FIRM LEVEL
use "$OUT\woeppel_regsample_firm.dta", clear	
// Unique id: app_year firm_id2 CZ_inv

*Winsorizing
foreach var in "n_patent_firm" "n_inv_firm"	///
		"n_patents_inv_CZ" "n_inv_total_CZ" ///
		"n_inv_new_CZ" "n_inv_newsuper_CZ" ///
		"n_inv_total_state_inv_L1" {
	winsor2 `var', suffix(_w1) cuts(1 99) by(app_year)
}

rename n_inv_total_state_inv_L1_w1 n_inv_total_state_L1_w1

*Logarithm
foreach var in "n_patent_firm_w1" "n_inv_firm_w1" ///
		"n_patents_inv_CZ_w1" "n_inv_total_CZ_w1" ///
		"n_inv_new_CZ_w1" "n_inv_newsuper_CZ_w1" ///
		"GDP_inv" "GDP_net_other" "GDP_net_oth_wghd" ///
		"n_inv_total_state_L1_w1" {
	gen `var'_log = log(`var')
}
*/

// CZ LEVEL
use "$OUT\woeppel_regsample_CZ.dta", clear	

*Winsorizing
foreach var in "n_patents_inv_CZ" "n_inv_total_CZ" ///
		"n_inv_new_CZ" "n_inv_newsuper_CZ" ///
		"n_inv_total_state_inv_L1" {
	winsor2 `var', suffix(_w1) cuts(1 99) by(app_year)
}

rename n_inv_total_state_inv_L1_w1 n_inv_total_state_L1_w1

*Logarithm
foreach var in "n_patents_inv_CZ_w1" "n_inv_total_CZ_w1" ///
		"n_inv_new_CZ_w1" "n_inv_newsuper_CZ_w1" ///
		"GDP_inv" "GDP_net_wghd_CZ" ///
		"n_inv_total_state_L1_w1" {
	gen `var'_log = log(`var')
}


*2. Regression *****************************************************************

*CZ level ------------------------------------------------------------------


reghdfe n_patents_inv_CZ_w1_log n_inv_total_CZ_w1_log rd_credit_inv rd_credit_net_wghd_CZ, absorb($FE_var) vce(cluster $clustervar)
	outreg2 using "$RESULTS\Results_patents_firm_CZ", ///
	replace excel dec(4) stats(coef se) adjr2 noni nodepvar tex(frag) ///
	ctitle("n_patents, reghfe") lab	
	
foreach depvar in "n_patents_inv_CZ_w1_log" "n_inv_total_CZ_w1_log" ///
		"n_inv_new_CZ_w1_log" "n_inv_newsuper_CZ_w1_log" {
			
	foreach control_var in "" ///
		"$controls_inv" "$controls_inv $controls_other" "$controls_inv $controls_other $controls_add" {		

	reghdfe `depvar' rd_credit_inv rd_credit_net_wghd_CZ `control_var', absorb($FE_var) vce(cluster $clustervar)
		outreg2 using "$RESULTS\Results_patents_firm_CZ", ///
		append excel dec(4) stats(coef se) adjr2 noni nodepvar tex(frag) ///
		ctitle("`depvar', reghfe") lab	
	}
}
		
foreach depvar in "n_patents_inv_CZ_w1" "n_inv_total_CZ_w1" ///
		"n_inv_new_CZ_w1" "n_inv_newsuper_CZ_w1" {
			
	foreach control_var in "" ///
		"$controls_inv" "$controls_inv $controls_other" "$controls_inv $controls_other $controls_add" {		
		
	ppmlhdfe `depvar' rd_credit_inv rd_credit_net_wghd_CZ `control_var', absorb($FE_var) vce(cluster $clustervar)
		outreg2 using "$RESULTS\Results_patents_firm_CZ", ///
		append excel dec(4) stats(coef se) addstat(Pseudo R2, e(r2_p)) noni nodepvar tex(frag) ///
		ctitle("`depvar', ppmlhdfe") lab
	}
}








