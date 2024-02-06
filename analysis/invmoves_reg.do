/// PROJECT: Spillover Effects 
/// GOAL: Regression - Mobility at county/commuting zone level
/// AUTHOR: Theresa Bührle, tbuehrle@diw.de
/// CREATION: 11-01-2024
/// LAST UPDATE: 02-02-2024
/// DATA: Woeppel patent data

///PRE-REQUISITE:  invmoves_data_Woeppel.do

*Set variables
global controls_a GDP_inv_log corprate_inv t_pinc_rate_inv RA_inv			
global controls_b GDP_net_other_log corprate_net_other t_pinc_rate_net_other RA_net_other

global controls_a1 GDP_inv_log corprate_inv t_pinc_rate_inv 			
global controls_b1 GDP_net_other_log corprate_net_other t_pinc_rate_net_other 

global FE_var CZ_inv app_year
global clustervar fips_state_inv
 
//Let's take the US cenzus CZ for now; there we have the most inventor moves	
	
*dep var: patents, inventors
*indep var: R&D 	

*1. Prepare data ***************************************************************	
use "$OUT\woeppel_regsample.dta", clear	

*Winsorizing
foreach var in "n_patent_firm" "n_inv_firm" {
	winsor2 `var', suffix(_w1) cuts(1 99) by(app_year)
}

*Logarithm
foreach var in "n_patent_firm_w1" "n_inv_firm_w1" ///
		"GDP_inv" "GDP_net_other" {
	gen `var'_log = log(`var')
}


*2. Regression ****************************************************************

reghdfe n_patent_firm_w1_log n_inv_firm_w1_log rd_credit_inv rd_credit_net_other, absorb($FE_var) vce(cluster $clustervar)
	outreg2 using "$RESULTS\Results_patents_firm_CZ", ///
	replace excel dec(4) stats(coef se) adjr2 noni nodepvar tex(frag) ///
	ctitle("n_patents, reghfe") lab	
	
	
foreach depvar in "n_patent_firm_w1_log" "n_inv_firm_w1_log" {

reghdfe `depvar' rd_credit_inv rd_credit_net_other, absorb($FE_var) vce(cluster $clustervar)
	outreg2 using "$RESULTS\Results_patents_firm_CZ", ///
	append excel dec(4) stats(coef se) adjr2 noni nodepvar tex(frag) ///
	ctitle("`depvar', reghfe") lab
	
reghdfe `depvar' rd_credit_inv rd_credit_net_other $controls_a, absorb($FE_var) vce(cluster $clustervar)
	outreg2 using "$RESULTS\Results_patents_firm_CZ", ///
	append excel dec(4) stats(coef se) adjr2 noni nodepvar tex(frag) ///
	ctitle("`depvar', reghfe") lab	
	
reghdfe `depvar' rd_credit_inv rd_credit_net_other $controls_a1, absorb($FE_var) vce(cluster $clustervar)
	outreg2 using "$RESULTS\Results_patents_firm_CZ", ///
	append excel dec(4) stats(coef se) adjr2 noni nodepvar tex(frag) ///
	ctitle("`depvar', reghfe") lab		
	
reghdfe `depvar' rd_credit_inv rd_credit_net_other  $controls_a $controls_b, absorb($FE_var) vce(cluster $clustervar)
	outreg2 using "$RESULTS\Results_patents_firm_CZ", ///
	append excel dec(4) stats(coef se) adjr2 noni nodepvar tex(frag) ///
	ctitle("`depvar', reghfe") lab	
	
reghdfe `depvar' rd_credit_inv rd_credit_net_other $controls_a1 $controls_b1, absorb($FE_var) vce(cluster $clustervar)
	outreg2 using "$RESULTS\Results_patents_firm_CZ", ///
	append excel dec(4) stats(coef se) adjr2 noni nodepvar tex(frag) ///
	ctitle("`depvar', reghfe") lab	
}	
	
foreach depvar in "n_patent_firm_w1" "n_inv_firm_w1" {
	
ppmlhdfe `depvar' rd_credit_inv rd_credit_net_other, absorb($FE_var) vce(cluster $clustervar)
	outreg2 using "$RESULTS\Results_patents_firm_CZ", ///
	append excel dec(4) stats(coef se) addstat(Pseudo R2, e(r2_p)) noni nodepvar tex(frag) ///
	ctitle("`depvar', ppmlhdfe") lab
	
ppmlhdfe `depvar' rd_credit_inv rd_credit_net_other $controls_a, absorb($FE_var) vce(cluster $clustervar)
	outreg2 using "$RESULTS\Results_patents_firm_CZ", ///
	append excel dec(4) stats(coef se) addstat(Pseudo R2, e(r2_p)) noni nodepvar tex(frag) ///
	ctitle("`depvar', ppmlhdfe") lab	
	
ppmlhdfe `depvar' rd_credit_inv rd_credit_net_other $controls_a1, absorb($FE_var) vce(cluster $clustervar)
	outreg2 using "$RESULTS\Results_patents_firm_CZ", ///
	append excel dec(4) stats(coef se) addstat(Pseudo R2, e(r2_p)) noni nodepvar tex(frag) ///
	ctitle("`depvar', ppmlhdfe") lab	
	
ppmlhdfe `depvar' rd_credit_inv rd_credit_net_other $controls_a $controls_b, absorb($FE_var) vce(cluster $clustervar)
	outreg2 using "$RESULTS\Results_patents_firm_CZ", ///
	append excel dec(4) stats(coef se) addstat(Pseudo R2, e(r2_p)) noni nodepvar tex(frag) ///
	ctitle("`depvar', ppmlhdfe") lab			
	
ppmlhdfe `depvar' rd_credit_inv rd_credit_net_other $controls_a1 $controls_b1, absorb($FE_var) vce(cluster $clustervar)
	outreg2 using "$RESULTS\Results_patents_firm_CZ", ///
	append excel dec(4) stats(coef se) addstat(Pseudo R2, e(r2_p)) noni nodepvar tex(frag) ///
	ctitle("`depvar', ppmlhdfe") lab		
}
















