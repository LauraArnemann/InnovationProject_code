/// PROJECT: Spillover Effects 
/// GOAL: Regression - Mobility at county/commuting zone level
/// AUTHOR: Theresa Bührle, tbuehrle@diw.de
/// CREATION: 11-01-2024
/// LAST UPDATE: 11-01-2024
/// DATA: Woeppel patent data

///PRE-REQUISITE:  invmoves_data_Woeppel.do
*clear 
*set maxvar 120000

*Set environment
if ${user}==2 {
global REGDTA "C:\Users\tbuehrle\OneDrive - DIW Berlin\3_Forschung\Topics\Spillover migration\2_Empirical\2_1_Data"
global RESULTS "C:\Users\tbuehrle\OneDrive - DIW Berlin\3_Forschung\Topics\Spillover migration\2_Empirical\2_3_Results"
}
*Set variables
global controls GDP corprate rev_totaltaxes rev_corptax revsh_indinctax revsh_corptax payroll_wgt prop_wgt ///
	Losscarryback Losscarryforward FranchiseTax fed_deduction fed_taxbase AllowFedAccDep ACRSDepreciation ///
	fed_bonusdepr throwback combined BEAemp avg_wages ITC_rate rd_credit GOS_s propertytax jobcreationcred ///
	propabatement incr_ma incr_fixed t_pinc_rate t_sales 

*A. ****************************************************************************
*Descriptives ******************************************************************

use "${OUT}/reg_data_patent_invmoves.dta", clear	
keep if year > 1992 & year < 2020

collapse (mean) migration_CZ_UScensus firm_move_CZ_UScensus, by(year)

twoway line migration_CZ_UScensus year, yaxis(1)  ///
	|| line firm_move_CZ_UScensus year, yaxis(2)  ///
	|| , graphregion(color(white)) ytitle("Share") ytitle("Share", axis(2)) ///
	xscale(range(1992 2020)) xlabel(1992 1996 2000 2004 2008 2012 2016 2020) ///
	legend(position(6) label(1 "Inventor moves (left yaxis)") label(2 "Within-firm movers (right yaxis)")) 
	
	graph export "${RESULTS}/share_invmoves_year.png", replace

use "${OUT}/reg_data_patent_invmoves.dta", clear	
keep if year > 1992 & year < 2020

collapse (count) migration_CZ_UScensus firm_move_CZ_UScensus, by(state_inv)

twoway bar migration_CZ_UScensus state_inv, yaxis(1) color(blue%30)  ///
	|| bar firm_move_CZ_UScensus state_inv, yaxis(2) color(red%30)    ///
	|| , graphregion(color(white)) ytitle("Count") ytitle("Count", axis(2)) ///
	legend(position(6) label(1 "Inventor moves (left yaxis)") label(2 "Within-firm movers (right yaxis)")) 
	
	graph export "${RESULTS}/count_invmoves_state.png", replace
	
*B. ****************************************************************************
* Aggregation at CZ level ******************************************************

//Let's take the US cenzus CZ for now; there we have the most inventor moves

use "${OUT}/reg_data_patent_invmoves.dta", clear	

drop if origin_CZ_UScensus == .	// drops 3,148,427	obs; inventors that are not observed in two consecutive years
egen CZpairs = group(CZ_UScensus origin_CZ_UScensus) 	
	
collapse (first) CZ_UScensus origin_CZ_UScensus ///
		 (sum) n_patents migration_CZ_UScensus firm_move_CZ_UScensus ///
		 (mean) citation_count $controls diff*, ///
		 by(CZpairs year)
	
save "${OUT}/reg_data_patent_invmoves_county.dta", replace	
	
*C. ****************************************************************************
*Regression ********************************************************************

*1st stage ---------------------------------------------------------------------
// Exposure of location to inventor moves

use "${OUT}/reg_data_patent_invmoves_county.dta", clear	
keep if year > 1992 & year < 2020

reghdfe n_patents diff*, absorb(year CZ_UScensus) vce(cluster CZpairs)
	outreg2 using "${RESULTS}/Results_Stage1", ///
	replace excel dec(4) stats(coef se) adjr2 noni nodepvar tex(frag) ///
	ctitle("n_patents, CZ FE") lab
reghdfe n_patents diff* $controls, absorb(year CZ_UScensus) vce(cluster CZpairs)
	outreg2 using "${RESULTS}/Results_Stage1", ///
	append excel dec(4) stats(coef se) adjr2 noni nodepvar tex(frag) ///
	ctitle("n_patents, CZ FE") lab
	
reghdfe n_patents diff*, absorb(year CZpairs) vce(cluster CZpairs)
	outreg2 using "${RESULTS}/Results_Stage1", ///
	append excel dec(4) stats(coef se) adjr2 noni nodepvar tex(frag) ///
	ctitle("n_patents, pair FE") lab
reghdfe n_patents diff* $controls, absorb(year CZpairs) vce(cluster CZpairs)
	outreg2 using "${RESULTS}/Results_Stage1", ///
	append excel dec(4) stats(coef se) adjr2 noni nodepvar tex(frag) ///
	ctitle("n_patents, pair FE") lab	
	
foreach depvar in "migration_CZ_UScensus" "firm_move_CZ_UScensus" {

reghdfe `depvar' diff*, absorb(year CZ_UScensus) vce(cluster CZpairs)
	outreg2 using "${RESULTS}/Results_Stage1", ///
	append excel dec(4) stats(coef se) adjr2 noni nodepvar tex(frag) ///
	ctitle("`depvar', CZ FE") lab
reghdfe `depvar' diff* $controls, absorb(year CZ_UScensus) vce(cluster CZpairs)	
	outreg2 using "${RESULTS}/Results_Stage1", ///
	append excel dec(4) stats(coef se) adjr2 noni nodepvar tex(frag) ///
	ctitle("`depvar', CZ FE") lab
reghdfe `depvar' diff*, absorb(year CZpairs) vce(cluster CZpairs)
	outreg2 using "${RESULTS}/Results_Stage1", ///
	append excel dec(4) stats(coef se) adjr2 noni nodepvar tex(frag) ///
	ctitle("`depvar', pair FE") lab
reghdfe `depvar' diff* $controls, absorb(year CZpairs) vce(cluster CZpairs)
	outreg2 using "${RESULTS}/Results_Stage1", ///
	append excel dec(4) stats(coef se) adjr2 noni nodepvar tex(frag) ///
	ctitle("`depvar', pair FE") lab
	
reghdfe `depvar' corprate t_pinc_rate ITC_rate rd_credit, absorb(year CZ_UScensus) vce(cluster CZpairs)
	outreg2 using "${RESULTS}/Results_Stage1", ///
	append excel dec(4) stats(coef se) adjr2 noni nodepvar tex(frag) ///
	ctitle("`depvar', CZ FE") lab
reghdfe `depvar' corprate t_pinc_rate ITC_rate rd_credit $controls, absorb(year CZ_UScensus) vce(cluster CZpairs)	
	outreg2 using "${RESULTS}/Results_Stage1", ///
	append excel dec(4) stats(coef se) adjr2 noni nodepvar tex(frag) ///
	ctitle("`depvar', CZ FE") lab
reghdfe `depvar' corprate t_pinc_rate ITC_rate rd_credit, absorb(year CZpairs) vce(cluster CZpairs)
	outreg2 using "${RESULTS}/Results_Stage1", ///
	append excel dec(4) stats(coef se) adjr2 noni nodepvar tex(frag) ///
	ctitle("`depvar', pair FE") lab
reghdfe `depvar' corprate t_pinc_rate ITC_rate rd_credit $controls, absorb(year CZpairs) vce(cluster CZpairs)
	outreg2 using "${RESULTS}/Results_Stage1", ///
	append excel dec(4) stats(coef se) adjr2 noni nodepvar tex(frag) ///
	ctitle("`depvar', pair FE") lab	///
	sortvar( *corprate *t_pinc_rate *ITC_rate *rd_credit) 
}

*2nd stage ---------------------------------------------------------------------
// Effect of inventor moves on innovation










