/// PROJECT: Spillover Effects 
/// GOAL: Regression - Mobility at county/commuting zone level
/// AUTHOR: Theresa Bührle, tbuehrle@diw.de
/// CREATION: 11-01-2024
/// LAST UPDATE: 02-02-2024
/// DATA: Woeppel patent data

///PRE-REQUISITE:  invmoves_data_Woeppel.do

*Set variables
global controls GDP corprate rev_totaltaxes rev_corptax revsh_indinctax revsh_corptax payroll_wgt prop_wgt ///
	Losscarryback Losscarryforward FranchiseTax fed_deduction fed_taxbase AllowFedAccDep ACRSDepreciation ///
	fed_bonusdepr throwback combined BEAemp avg_wages ITC_rate rd_credit GOS_s propertytax jobcreationcred ///
	propabatement incr_ma incr_fixed t_pinc_rate t_sales 

//Let's take the US cenzus CZ for now; there we have the most inventor moves	
	
*A. ****************************************************************************
*Descriptives ******************************************************************

use "$OUT\reg_data_patent_invmoves.dta", clear	
keep if year >= 1992 & year <= 2018

collapse (mean) inmigr_CZ_UScensus inmigr_super_CZ_UScensus firm_move_CZ_UScensus, by(year)

twoway line inmigr_CZ_UScensus year, yaxis(1) color(blue) ///
	|| line inmigr_super_CZ_UScensus year, yaxis(1) color(dknavy) ///
	|| line firm_move_CZ_UScensus year, yaxis(2) color(green)  ///
	|| , graphregion(color(white)) ytitle("Share inventor/superstar moves", axis(1) color(blue)) ytitle("Share within-firm movers", axis(2) color(green)) ///
	xscale(range(1992 2018)) xlabel(1992 1996 2000 2004 2008 2012 2016) ///
	legend(position(6) label(1 "Inventor moves (left yaxis)") label(2 "Superstar moves (left yaxis)") label(3 "Within-firm movers (right yaxis)")) 
	
	graph export "$RESULTS\share_invmoves_year.png", replace

use "$OUT\reg_data_patent_invmoves.dta", clear	
keep if year >= 1992 & year <= 2018

collapse (count) inmigr_CZ_UScensus inmigr_super_CZ_UScensus firm_move_CZ_UScensus, by(state_inv) 

gen state_inv1 = state_inv - 0.2
gen state_inv2 = state_inv + 0.2

twoway bar inmigr_CZ_UScensus state_inv1, yaxis(1) color(blue%30) barw(0.4) ///
	|| bar firm_move_CZ_UScensus state_inv1, yaxis(1) color(red) barw(0.4)   ///
	|| bar inmigr_super_CZ_UScensus state_inv2, yaxis(1) color(dknavy%30) barw(0.4) ///
	|| , graphregion(color(white)) ytitle("Count") ///
	legend(position(6) label(1 "Inventor moves") label(2 "Within-firm movers") label(3 "Superstar moves")) 
		
	graph export "$RESULTS\count_invmoves_state.png", replace
	
//This would be better as heat map
	/*
*Maps

**States
shp2dta using "$IN\maps\states\s_05mr24", database(usdb) coordinates(uscoord) genid(id)

use usdb, clear
rename FIPS state_fips
rename NAME state_name
destring state_fips, replace
save "$IN\maps\states\s_05mr24_data.dta", replace

use uscoord, clear
save "$IN\maps\states\s_05mr24_coord.dta", replace

**Counties
shp2dta using "$IN\maps\counties\c_05mr24", database(usdb_c) coordinates(uscoord_c) genid(id)

use usdb_c, clear
rename COUNTYNAME county_name


	merge m:m county_name using "$IN\var_other\fips_codes_us_county.dta"
drop _merge
rename FIPS state_fips
destring state_fips, replace

save "$IN\maps\counties\c_05mr24_data.dta", replace

use uscoord_c, clear
save "$IN\maps\counties\c_05mr24_coord.dta", replace

*/

use "$OUT\reg_data_patent_invmoves.dta", clear	
keep if year >= 1992 & year <= 2018

collapse (sum) inmigr_CZ_UScensus inmigr_super_CZ_UScensus firm_move_CZ_UScensus ///
	n_inv_total_CZ_UScensus n_inv_totalsuper_CZ_UScensus n_inv_new_CZ_UScensus n_inv_newsuper_CZ_UScensus ///
	outmigr_CZ_UScensus outmigr_super_CZ_UScensus, by(state_inv) 

rename state_inv state_fips
merge 1:1 state_fips using "$IN\maps\states\s_05mr24_data.dta", nogen keep(3)
save "$TEMP\map_woeppel_inv.dta", replace

use "$TEMP\map_woeppel_inv.dta", clear

foreach var in "inmigr_CZ_UScensus" "inmigr_super_CZ_UScensus" "firm_move_CZ_UScensus" ///
	"n_inv_total_CZ_UScensus" "n_inv_totalsuper_CZ_UScensus" ///
	"outmigr_CZ_UScensus" "outmigr_super_CZ_UScensus" {
spmap `var' using "$IN\maps\states\s_05mr24_coord.dta" if id !=12 & id!=56 & id != 59, id(id) fcolor(Blues)
graph export "$RESULTS\heatmap_`var'.png", replace
}




/*
use "$OUT\reg_data_patent_invmoves.dta", clear	
keep if year >= 1992 & year <= 2018

collapse (count) inmigr_CZ_UScensus inmigr_super_CZ_UScensus firm_move_CZ_UScensus, by(county_inv) 

rename county_inv county_fips
merge 1:m county_fips using "$IN\maps\counties\c_05mr24_data.dta"

, nogen keep(3)
save "$TEMP\map_woeppel_inv_county.dta", replace

use "$TEMP\map_woeppel_inv.dta", clear

foreach var in "inmigr_CZ_UScensus" "inmigr_super_CZ_UScensus" "firm_move_CZ_UScensus" {
spmap `var' using "$IN\maps\counties\c_05mr24_coord.dta" if id !=12 & id!=56, id(id) fcolor(Blues)
graph export "$RESULTS\heatmap_`var'_county.png", replace
}
*/

	
*B. ****************************************************************************
* Aggregation at CZ level ******************************************************

use "$OUT\reg_data_patent_invmoves.dta", clear	

drop if origin_CZ_UScensus == .	// drops 3,148,427	obs; inventors that are not observed in two consecutive years
egen CZpairs = group(CZ_UScensus origin_CZ_UScensus) 	
	
collapse (first) CZ_UScensus origin_CZ_UScensus inmigr_CZ_UScensus inmigr_super_CZ_UScensus firm_move_CZ_UScensus ///
			n_inv_total_CZ_UScensus n_inv_totalsuper_CZ_UScensus n_inv_new_CZ_UScensus n_inv_newsuper_CZ_UScensus n_inv_old_CZ_UScensus n_inv_oldsuper_CZ_UScensus ///
			n_patents_inv_CZ_UScensus n_cite_inv_CZ_UScensus av_cite_inv_CZ_UScensus ///
		 (mean)  $controls diff*, ///
		 by(CZpairs year)
	
save "$OUT\reg_data_patent_invmoves_county.dta", replace	
	
*C. ****************************************************************************
*Regression ********************************************************************

*1st stage ---------------------------------------------------------------------
// Exposure of location to inventor moves

use "$OUT\reg_data_patent_invmoves_county.dta", clear	
keep if year >= 1992 & year <= 2018

reghdfe n_patents_inv_CZ_UScensus diff*, absorb(year CZ_UScensus) vce(cluster CZpairs)
	outreg2 using "$RESULTS\Results_Stage1", ///
	replace excel dec(4) stats(coef se) adjr2 noni nodepvar tex(frag) ///
	ctitle("n_patents, CZ FE") lab
reghdfe n_patents_inv_CZ_UScensus diff* $controls, absorb(year CZ_UScensus) vce(cluster CZpairs)
	outreg2 using "$RESULTS\Results_Stage1", ///
	append excel dec(4) stats(coef se) adjr2 noni nodepvar tex(frag) ///
	ctitle("n_patents, CZ FE") lab
	
reghdfe n_patents_inv_CZ_UScensus diff*, absorb(year CZpairs) vce(cluster CZpairs)
	outreg2 using "$RESULTS\Results_Stage1", ///
	append excel dec(4) stats(coef se) adjr2 noni nodepvar tex(frag) ///
	ctitle("n_patents, pair FE") lab
reghdfe n_patents_inv_CZ_UScensus diff* $controls, absorb(year CZpairs) vce(cluster CZpairs)
	outreg2 using "$RESULTS\Results_Stage1", ///
	append excel dec(4) stats(coef se) adjr2 noni nodepvar tex(frag) ///
	ctitle("n_patents, pair FE") lab	
	
foreach depvar in "n_cite_inv_CZ_UScensus" "av_cite_inv_CZ_UScensus" ///
		"inmigr_CZ_UScensus" "inmigr_super_CZ_UScensus" "firm_move_CZ_UScensus" ///
		"n_inv_total_CZ_UScensus" "n_inv_totalsuper_CZ_UScensus" {

reghdfe `depvar' diff*, absorb(year CZ_UScensus) vce(cluster CZpairs)
	outreg2 using "$RESULTS\Results_Stage1", ///
	append excel dec(4) stats(coef se) adjr2 noni nodepvar tex(frag) ///
	ctitle("`depvar', CZ FE") lab
reghdfe `depvar' diff* $controls, absorb(year CZ_UScensus) vce(cluster CZpairs)	
	outreg2 using "$RESULTS\Results_Stage1", ///
	append excel dec(4) stats(coef se) adjr2 noni nodepvar tex(frag) ///
	ctitle("`depvar', CZ FE") lab
reghdfe `depvar' diff*, absorb(year CZpairs) vce(cluster CZpairs)
	outreg2 using "$RESULTS\Results_Stage1", ///
	append excel dec(4) stats(coef se) adjr2 noni nodepvar tex(frag) ///
	ctitle("`depvar', pair FE") lab
reghdfe `depvar' diff* $controls, absorb(year CZpairs) vce(cluster CZpairs)
	outreg2 using "$RESULTS\Results_Stage1", ///
	append excel dec(4) stats(coef se) adjr2 noni nodepvar tex(frag) ///
	ctitle("`depvar', pair FE") lab
	
reghdfe `depvar' corprate t_pinc_rate ITC_rate rd_credit, absorb(year CZ_UScensus) vce(cluster CZpairs)
	outreg2 using "$RESULTS\Results_Stage1", ///
	append excel dec(4) stats(coef se) adjr2 noni nodepvar tex(frag) ///
	ctitle("`depvar', CZ FE") lab
reghdfe `depvar' corprate t_pinc_rate ITC_rate rd_credit $controls, absorb(year CZ_UScensus) vce(cluster CZpairs)	
	outreg2 using "$RESULTS\Results_Stage1", ///
	append excel dec(4) stats(coef se) adjr2 noni nodepvar tex(frag) ///
	ctitle("`depvar', CZ FE") lab
reghdfe `depvar' corprate t_pinc_rate ITC_rate rd_credit, absorb(year CZpairs) vce(cluster CZpairs)
	outreg2 using "$RESULTS\Results_Stage1", ///
	append excel dec(4) stats(coef se) adjr2 noni nodepvar tex(frag) ///
	ctitle("`depvar', pair FE") lab
reghdfe `depvar' corprate t_pinc_rate ITC_rate rd_credit $controls, absorb(year CZpairs) vce(cluster CZpairs)
	outreg2 using "$RESULTS\Results_Stage1", ///
	append excel dec(4) stats(coef se) adjr2 noni nodepvar tex(frag) ///
	ctitle("`depvar', pair FE") lab	///
	sortvar( *corprate *t_pinc_rate *ITC_rate *rd_credit) 
}

*2nd stage ---------------------------------------------------------------------
// Effect of inventor moves on innovation










