/// PROJECT: Spillover Effects 
/// GOAL: Trying to replicate some stats and results from the Moretti Paper 
/// AUTHOR: Laura Arnemann, Theresa Bührle
/// CREATION: 27-12-2022
/// LAST UPDATE: 25-04-2023
/// SOURCE: Raw Data 



********************************************************************************
*Create inventor sample based on Moretti/Wilson approach
********************************************************************************

use "${TEMP}/inventor_applications.dta", clear 
drop if withdrawn==1 

* Moretti Sample Restrictions to check if we have more or less the same observations
keep if inrange(app_year,1977,2010)

duplicates drop patnum inventor_id, force 
* Where do these duplicates come from? Just deletes 748 observations
* Theresa: 322

* Define destination and origin state for every inventor
* If multiple states observed, mode of state-fips (most frequent location in data)

bysort inventor_id app_year: egen residence_state = mode(state_inventor)
bysort inventor_id app_year: gen count=_n 
* Deal with inventors with two modes, just use the first observation for state
replace residence_state=state_inventor if count==1 & missing(residence_state)

*Patent share (count) per inventor
bysort patnum: egen number_inv = count(inventor_id)
gen patent_share = 1/number_inv

*collapse (mean) state_fips_inventor (sum) patent_share, by(inventor_id app_year)
collapse (first) residence_state (sum) patent_share, by(inventor_id app_year)
rename patent_share n_patents

*drop if residence_state == "" // (281,280 observations deleted)

sort inventor_id app_year
gen origin_state=""
bysort inventor_id: replace origin_state=residence_state[_n-1] 
bysort inventor_id: replace origin_state="" if app_year[_n-1]!=app_year-1
gen destination_state=""
bysort inventor_id: replace destination_state =residence_state[_n+1] 
bysort inventor_id: replace destination_state="" if app_year[_n+1]!=app_year+1


*# observations per inventor
bysort inventor_id: egen inv_obs = count(inventor_id)

/*
drop count

bysort inventor_id app_year: gen helper=_N
* Number of patents an inventor applied for in a year 
bysort inventor_id app_year: gen count=_n 
* Numerate the number of patents within a year 
gen num_pat=helper if count==1 
drop helper 

bysort inventor_id (app_year): gen ru_sum_pats=sum(num_pat)
*/ 

*Definition superstar inventors
/* We define star inventors,in a given year, as those who are at or above the ninety-fifth percentile in number of patents over the past ten years.

What does this mean? Are you a superstar inventor once you surpassed this threshold
or does superstar status change once you are not above the 95th percentile anymore? */ 

rangestat (sum) n_patents, by(inventor_id) int(app_year -10 0)
rename n_patents_sum cum_10yrs

* Also generate this for the years before 1987 

bysort inventor_id (app_year): egen sum_pats=total(n_patents)
bysort inventor_id (app_year): gen count=_n 
gen n_sum_pats = sum_pats if count==1 
bysort inventor_id: gen cum_sum_pats=sum(n_sum_pats)
replace cum_10yrs=cum_sum_pats if app_year<=1986



/*
gen pat_10yrs=. 
replace pat_10yrs=ru_sum_pats if app_year<=1987

forvalues i=1988/2010 {
	local c=`i'-10
	display `c'
	gen helper = ru_sum_pats if app_year==`c'
	bysort inventor_id: egen max_helper=max(helper)
	replace pat_10yrs = ru_sum_pats - max_helper if app_year==`i'
	drop helper max_helper 
}
*/ 

gen superstar=0 

forvalues i=1977/2010 {
	qui sum cum_10yrs if app_year== `i', detail 
	replace superstar = 1 if cum_10yrs>=r(p95) & cum_10yrs!=. & app_year==`i'
}

bysort inventor_id: egen max_superstar=max(superstar)

replace superstar=max_superstar


save "${OUT}/moretti_sample1.dta", replace 





use "${OUT}/moretti_sample1.dta", clear 
	
*Migration flows
drop if residence_state == "" // (281,280 observations deleted)

*sort inventor_id app_year
*gen origin_state="" 
*bysort inventor_id: replace origin_state=residence_state[_n-1] 
*bysort inventor_id: replace origin_state="" if app_year[_n-1]!=app_year-1
*gen destination_state=""
*bysort inventor_id: replace destination_state =residence_state[_n+1] 
*bysort inventor_id: replace destination_state="" if app_year[_n+1]!=app_year+1
/*
NOTE:
Not 100% clear how to define migration, but could also be defined as 
migration in next year, i.e. residence_state != destination_state
*/

//Migration in next year
gen migration = 0 if residence_state!="" & origin_state!=""
replace migration=1 if residence_state!=origin_state & residence_state!="" & origin_state!=""

bysort inventor_id: egen number_moves=total(migration)

gen ever_migrated=0 if number_moves==0 
replace ever_migrated=1 if number_moves>0

label var cum_10yrs "Patents over last 10 years"
label var n_patents "Number of Patents"
label var superstar "Indicator for being a Superstar"
label var max_superstar "Ever Superstar"
label var origin_state "State of Origin in t-1"
label var residence_state "State of Residence in t"
label var destination_state "State of Destination in t+1"
label var migration "Residence State differs from Origin State "
label var ever_migrated "Inventor has ever migrated"

count if ever_migrated == 1 & superstar == 1 // 41,259

*Outmigration odds ratio********************************************************
/* "Probability of a star scientist moving from a given origin state to a given destination state relative to the probability of not moving at all" 
"P odt / P oot is the scientist population share that moves from one state to another ( P odt ) relative to the population share that does not move ( P oot )"
"the log odds-ratio is undefined when the migration flow is 0"*/

sort residence_state origin_state app_year
*Total scientiest population, per year and state
bysort residence_state app_year: egen pop_all = count(inventor_id)
bysort residence_state app_year: egen pop_star95 = sum(superstar) 

*Number of scientists not moving (P oot)
	gen inventor_id_stay = inventor_id if migration == 0 // could also do != 1; how to deal with missings?
bysort residence_state app_year: egen pop_all_stayers = count(inventor_id_stay) 
	gen superstar_stay = superstar if migration == 0
bysort residence_state app_year: egen pop_star95_stayers = sum(superstar_stay)

*Number of scientists moving(P odt)
//HAS TO BE CALCULATED FOR EACH ORIGIN-RESIDENCE PAIR
	gen inventor_id_move = inventor_id if migration == 1
bysort residence_state origin_state app_year: egen outflow_all = count(inventor_id_move)
	replace outflow_all = pop_all_stayers if residence_state == origin_state	
			//Moretti/Wilson do that
	
	gen superstar_move = superstar if migration == 1
bysort residence_state origin_state app_year: egen outflow95 = sum(superstar_move) 
	replace outflow95 = pop_star95_stayers if residence_state == origin_state
	
*Odds ratio (P odt/P oot)
gen oddsratio_all = outflow_all / pop_all_stayers
 gen log_oddsratio_all = log(oddsratio_all)
gen oddsratio95 = outflow95 / pop_star95_stayers
	gen log_oddsratio95 = log(oddsratio95)

duplicates drop residence_state origin_state app_year, force

*Cross-check with Moretti/Wilson sample
drop if origin_state == ""
drop if app_year == 2010

//US districts and territories are not included in Moretti/Wilson sample
foreach state_name in "GU" "PR" "VI" {
	drop if residence_state == "`state_name'"
	drop if origin_state == "`state_name'"
}

keep app_year residence_state origin_state destination_state pop_all pop_star95 pop_all_stayers superstar_stay pop_star95_stayers outflow_all outflow95 oddsratio_all log_oddsratio_all oddsratio95 log_oddsratio95

sum pop_star95 pop_star95_stayers outflow95 oddsratio95 log_oddsratio95


save "${OUT}/moretti_sample.dta", replace 

********************************************************************************
*Borrow control variables from Moretti data
********************************************************************************

use "${mw_datadir}/star_migration_rates.dta", clear

duplicates report state F_state year

drop outflow90 outflow95 outflow99 *star90* *star95* *star99* *rate90* *rate95* *rate99* *ratio90* *ratio95* *ratio99* *nonstar*

rename year app_year
rename state residence_state
rename F_state origin_state

save "${OUT}/moretti_controls.dta", replace 

use "${OUT}/moretti_controls.dta", clear 

merge 1:1 residence_state origin_state app_year using  "${OUT}/moretti_sample.dta" 
drop if _merge == 2 //deletes 4 obs, seem to be miswritten state names
drop _merge

rename app_year year
rename origin_state F_state
rename residence_state state


save "${OUT}/moretti_sample_final.dta", replace 


*Table 1

/*		
use "${datadir}/star_migration_rates.dta", clear
*/	
	
use "${OUT}/moretti_sample.dta", clear
	
keep if app_year>1996
keep if app_year<2007
/*
*List of states kept:
local keepstates "6,25,34,36,48,27,42,17,26,39"
local statelist "CA,IL,MA,MI,MN,NJ,NY,OH,PA,TX"
		
keep if inlist(residence_state,"`statelist'")
keep if inlist(destination_state,"`statelist'")
*/

*Generate average annual outflow matrix
foreach st in CA IL MA MI MN NJ NY OH PA TX {
	egen mig`st' = sum(outflow95) if destination_state=="`st'", by(residence_state)
	replace mig`st' = round(mig`st'/10,1)
	}
keep if residence_state=="CA" | residence_state=="IL" | residence_state=="MA" | residence_state=="MI" | residence_state=="MN" | residence_state=="NJ" | residence_state=="NY" | residence_state=="OH" | residence_state=="PA" | residence_state=="TX"

duplicates drop
collapse (max) migCA migIL migMA migMI migMN migNJ migNY migOH migPA migTX, by(residence_state)


********************************************************************************
* Trying to replicate some of the Summary Statistics 
******************************************************************************

/*
use "${OUT}/moretti_sample1.dta", clear 
*use "${TEMP}/inventor_applications.dta", clear 


sum superstar if superstar==1 & residence_state!="" & destination_state!=""
*Moretti Paper has 260.000 superstar x year observations; we have around 361.919 observations 

sum max_superstar if max_superstar==1
 * 751,996 
 
sum superstar if superstar==1 & residence_state!=""  & destination_state!="" 
* This is more in the ballpark of the Moretti sample: 280,856 observations


sum max_superstar if max_superstar==1 & residence_state!="" & origin_state!="" 
* 472,159 observations  

sum cum_10yrs if app_year==2006 & superstar==1 , detail
* A lot higher that what they found in the Moretti sample, mean in Moretti 15.7, for us 26.10255

sum cum_10yrs if app_year==2006 & max_superstar==1 , detail

sum n_patents if superstar==1, detail
* 3,5 patents each year, mean inventor has 1.5 patents each year ?  

sum migration if app_year==2006 & superstar==1
* Slightly lower migration rate than in the Moretti sample with 4.54712   percent of superstar migrants; Moretti Paper (6 percent)

sum ever_migrated if superstar==1
* 20 percent of sample migrated 

sum number_moves if superstar==1, detail
* Average: .4185881

sum number_moves if superstar==1 & number_moves>=1, detail
* Mean: 2.00483 , smaller than 2.66 reported in Moretti paper

*/

********************************************************************************
*REPLICATION MORETTI/WILSON 2017
********************************************************************************

**FIGURE 5 - ORIGINAL CODE


*** figure 5 and appendix figure 5

	local figure_eventplot_start = "$S_TIME"
	
	graph drop _all
	
	foreach interval in 1 {
		
		use "${OUT}/moretti_sample_final.dta", clear
		replace outflow95=0 if missing(outflow95)
		
		/*
		use "${OUT}/moretti_sample_final.dta", clear
		*/
		rename itc_state I_credit
		rename itc_state_dest I_credit_dest
		rename itc_state_diff I_credit_diff
		rename itc_state_not I_credit_not
		rename itc_state_not_dest I_credit_not_dest
		rename itc_state_not_diff I_credit_not_diff
		rename cit_state CIT
		rename cit_state_dest CIT_dest
		rename cit_state_diff CIT_diff
		rename cit_state_not CIT_not
		rename cit_state_not_dest CIT_not_dest
		rename cit_state_not_diff CIT_not_diff
		rename state_cred_lowest_tier RD_credit
		rename state_cred_lowest_tier_diff RD_credit_diff
		rename state_cred_lowest_tier_dest RD_credit_dest
		rename state_cred_lowest_tier_not RD_credit_not
		rename state_cred_lowest_tier_not_diff RD_credit_not_diff
		rename state_cred_lowest_tier_not_dest RD_credit_not_dest
		rename rho_low RD_usercost
		rename rho_low_dest RD_usercost_dest
		rename rho_low_diff RD_usercost_diff
		rename rho_low_not RD_usercost_not
		rename rho_low_not_dest RD_usercost_not_dest
		rename rho_low_not_diff RD_usercost_not_diff
		rename srate* MTR*
		rename phasedin_srate_p99_not_diff phMTR_p99_not_diff
		rename phasedin_srate_p99_not phMTR_p99_not
		rename phasedin_srate_p99_not_dest phMTR_p99_not_dest

		************************************************************************
		*** SCATTERPLOTS - LOG ODDS RATIO VS TAX DIFFERENTIAL, BOTH DEMEANED ***
		************************************************************************
		local taxvars "ATR_p99 CIT I_credit RD_credit"
		foreach taxvar of local taxvars {
			sum `taxvar'_not_diff if `taxvar'_not_diff, detail
		}
		foreach taxvar of local taxvars {
			#delimit ;
			local eventlist`taxvar' D_`taxvar'_unrev5_dummy1pp D_`taxvar'_unrev5_dummy
			;
			#delimit cr;
			*local eventlist`taxvar' D_`taxvar' D_`taxvar'_atMTRchanges D_`taxvar'_unrev3 D_`taxvar'_unrev5 D_`taxvar'_unrev10
		}
		pause on
		gen temp = (pop + pop_dest)/2
		sort pairIDasymmetric year
		bysort pairIDasymmetric: egen temp1 = mean(outflow95)
		egen fipsyear = group(F_fips year)
		egen F_fipsyear = group(fips year)
		egen clustall = group(pairIDasymmetric year)
		egen regpairyear = group(regionpairID year)

		gen log_outflow95 = ln(outflow95)

		local depvar = "log_oddsratio95"

		local intervalp10 = `interval'+10
		local prestart = 6
		tsset pairIDasymmetric year

		xi i.year
		foreach taxvar of local taxvars {
		sum S`interval'.`taxvar'_not_diff if S`interval'.`taxvar'_not_diff>0, detail
		}

		foreach taxvar of local taxvars {
			if "`taxvar'" == "ATR_p99" | "`taxvar'" == "MTR_p99" | "`taxvar'" == "ATR_p95" {
			local controls "CIT_not_diff I_credit_not_diff RD_credit_not_diff"
			}
			if "`taxvar'" == "CIT" {
			local controls "ATR_p99_not_diff I_credit_not_diff RD_credit_not_diff"
			}
			if "`taxvar'" == "I_credit"  {
			local controls "ATR_p99_not_diff CIT_not_diff RD_credit_not_diff"
			}
			if "`taxvar'" == "RD_credit" {
			local controls "ATR_p99_not_diff CIT_not_diff I_credit_not_diff"
			}
			local controls ""

			/// DEFINE POTENTIAL "EVENT" VARIABLES
			gen D_`taxvar' = S`interval'.`taxvar'_not_diff
			gen D5_`taxvar' = F4S5.`taxvar'_not_diff
			gen D5_`taxvar'_1pp = 0
			replace D5_`taxvar'_1pp = F4S5.`taxvar'_not_diff if abs(F4S5.`taxvar'_not_diff)>0.01

			gen poschange = D_`taxvar' if D_`taxvar'>0 & D_`taxvar'~=.
			gen negchange = D_`taxvar' if D_`taxvar'<0 & D_`taxvar'~=.
			egen p50pos = pctile(poschange), p(25)  
			egen p50neg = pctile(negchange), p(75)  
			gen big = 0
			replace big = 1 if (D_`taxvar'>p50pos | D_`taxvar'<p50neg) & D_`taxvar'~=.

			if "`taxvar'"~="CIT" & "`taxvar'"~="I_credit" & "`taxvar'"~="RD_credit" {
			gen D_`taxvar'_atMTRchanges = 0
			replace D_`taxvar'_atMTRchanges = D_`taxvar' if S`interval'.MTR_p99_not_diff~=0
			}
			else {
			gen D_`taxvar'_atMTRchanges = D_`taxvar'
			}
			gen D_`taxvar'_dummy = 0
			replace D_`taxvar'_dummy = sign(D_`taxvar')
			gen D5_`taxvar'_dummy = 0
			replace D5_`taxvar'_dummy = sign(D5_`taxvar')
			foreach size in 05 1 2 {
			gen D_`taxvar'_dummy`size'pp = 0
			replace D_`taxvar'_dummy`size'pp = 1 if D_`taxvar'>0.0`size'
			replace D_`taxvar'_dummy`size'pp = -1 if D_`taxvar'<-0.0`size'
			gen D5_`taxvar'_dummy`size'pp = 0
			replace D5_`taxvar'_dummy`size'pp = 1 if D5_`taxvar'>0.0`size'
			replace D5_`taxvar'_dummy`size'pp = -1 if D5_`taxvar'<-0.0`size'
			}
			sum S`interval'.`taxvar'_not_diff if S`interval'.`taxvar'_not_diff>0, detail
			foreach size in 10 25 50 75 90 {
			scalar p`size' = r(p`size')
			gen D_`taxvar'_dummy`size'pct = 0
			replace D_`taxvar'_dummy`size'pct = 1 if D_`taxvar'>r(p`size')
			replace D_`taxvar'_dummy`size'pct = -1 if D_`taxvar'<-1*r(p`size')
			}
			/// Generate unrevd and unaltered tax change variables 
			foreach i of num 1/15 {
			local im1 = `i' - 1
			if "`taxvar'"~="CIT" & "`taxvar'"~="I_credit" & "`taxvar'"~="RD_credit" {
			gen d`i' = F`im1'S`i'.`taxvar'_not_diff
			*gen d`i' = F`im1'S`i'.`taxvar'_not_dest
			replace d`i' = 0 if d`i'==.
			}
			else {
			gen d`i' = F`im1'S`i'.`taxvar'_not_diff
			*gen d`i' = F`im1'S`i'.`taxvar'_not_dest
			replace d`i' = 0 if d`i'==.        
			}
			}
			egen diff_thru3 = diff(d1-d3)
			egen diff_thru5 = diff(d1-d5)
			egen diff_thru10 = diff(d1-d10)
			egen diff_thru15 = diff(d1-d15)

			gen D_`taxvar'_unrev3 = 0
			replace D_`taxvar'_unrev3 = d1 if abs(d2)>=abs(d1) & abs(d3)>=abs(d1) & sign(d1)==sign(d2) & sign(d1)==sign(d3) 
			gen D_`taxvar'_unrev3_1pp = 0
			replace D_`taxvar'_unrev3_1pp = d1 if abs(d1)>0.01 & abs(d2)>=abs(d1) & abs(d3)>=abs(d1) & sign(d1)==sign(d2) & sign(d1)==sign(d3) 
			gen D_`taxvar'_unrev3_dummy = 0 
			replace D_`taxvar'_unrev3_dummy = sign(d1) if abs(d2)>=abs(d1) & abs(d3)>=abs(d1) & sign(d1)==sign(d2) & sign(d1)==sign(d3) 
			gen D_`taxvar'_unalter3 = 0
			replace D_`taxvar'_unalter3 = d1 if diff_thru3==0
			gen D_`taxvar'_unalter3_dummy = 0
			replace D_`taxvar'_unalter3_dummy = sign(d1) if diff_thru3==0

			gen D_`taxvar'_unrev5 = 0
			replace D_`taxvar'_unrev5 = d1 if abs(d2)>=abs(d1) & abs(d3)>=abs(d1) & abs(d4)>=abs(d1) & abs(d5)>=abs(d1) & sign(d1)==sign(d2) & sign(d1)==sign(d3) & sign(d1)==sign(d4) & sign(d1)==sign(d5)
			gen D_`taxvar'_unrev5_1pp = 0
			replace D_`taxvar'_unrev5_1pp = d1 if abs(d1)>0.01 & abs(d2)>=abs(d1) & abs(d3)>=abs(d1) & abs(d4)>=abs(d1) & abs(d5)>=abs(d1) & sign(d1)==sign(d2) & sign(d1)==sign(d3) & sign(d1)==sign(d4) & sign(d1)==sign(d5)
			gen D_`taxvar'_unrev5_dummy = 0
			replace D_`taxvar'_unrev5_dummy = sign(d1) if abs(d2)>=abs(d1) & abs(d3)>=abs(d1) & abs(d4)>=abs(d1) & abs(d5)>=abs(d1) & sign(d1)==sign(d2) & sign(d1)==sign(d3) & sign(d1)==sign(d4) & sign(d1)==sign(d5) 
			gen D_`taxvar'_unalter5 = 0
			replace D_`taxvar'_unalter5 = d1 if diff_thru5==0
			gen D_`taxvar'_unalter5_dummy = 0
			replace D_`taxvar'_unalter5_dummy = sign(d1) if diff_thru5==0

			gen D_`taxvar'_unrev3_dummy05pp = 0
			replace D_`taxvar'_unrev3_dummy05pp = sign(d1) if abs(d1)>0.005 & abs(d2)>=abs(d1) & abs(d3)>=abs(d1) & sign(d1)==sign(d2) & sign(d1)==sign(d3) 
			gen D_`taxvar'_unrev3_dummy1pp = 0
			replace D_`taxvar'_unrev3_dummy1pp = sign(d1) if abs(d1)>0.01 & abs(d2)>=abs(d1) & abs(d3)>=abs(d1) & sign(d1)==sign(d2) & sign(d1)==sign(d3) 
			gen D_`taxvar'_unrev3_dummy2pp = 0
			replace D_`taxvar'_unrev3_dummy2pp = sign(d1) if abs(d1)>0.02 & abs(d2)>=abs(d1) & abs(d3)>=abs(d1) & sign(d1)==sign(d2) & sign(d1)==sign(d3) 
			gen D_`taxvar'_unrev5_dummy05pp = 0
			replace D_`taxvar'_unrev5_dummy05pp = sign(d1) if abs(d1)>0.005 & abs(d2)>=abs(d1) & abs(d3)>=abs(d1) & abs(d4)>=abs(d1) & abs(d5)>=abs(d1) & sign(d1)==sign(d2) & sign(d1)==sign(d3) & sign(d1)==sign(d4) & sign(d1)==sign(d5)
			gen D_`taxvar'_unrev5_dummy1pp = 0
			replace D_`taxvar'_unrev5_dummy1pp = sign(d1) if abs(d1)>0.01 & abs(d2)>=abs(d1) & abs(d3)>=abs(d1) & abs(d4)>=abs(d1) & abs(d5)>=abs(d1) & sign(d1)==sign(d2) & sign(d1)==sign(d3) & sign(d1)==sign(d4) & sign(d1)==sign(d5)
			gen D_`taxvar'_unrev5_dummy2pp = 0
			replace D_`taxvar'_unrev5_dummy2pp = sign(d1) if abs(d1)>0.02 & abs(d2)>=abs(d1) & abs(d3)>=abs(d1) & abs(d4)>=abs(d1) & abs(d5)>=abs(d1) & sign(d1)==sign(d2) & sign(d1)==sign(d3) & sign(d1)==sign(d4) & sign(d1)==sign(d5)

			foreach size in 10 25 50 75 90 {
			gen D_`taxvar'_unrev3_dummy`size'pct = 0
			replace D_`taxvar'_unrev3_dummy`size'pct = sign(d1) if abs(d1)>p`size' & abs(d2)>=abs(d1) & abs(d3)>=abs(d1) & sign(d1)==sign(d2) & sign(d1)==sign(d3) 
			gen D_`taxvar'_unrev5_dummy`size'pct = 0
			replace D_`taxvar'_unrev5_dummy`size'pct = sign(d1) if abs(d1)>p`size' & abs(d2)>=abs(d1) & abs(d3)>=abs(d1) & abs(d4)>=abs(d1) & abs(d5)>=abs(d1) & sign(d1)==sign(d2) & sign(d1)==sign(d3) & sign(d1)==sign(d4) & sign(d1)==sign(d5)
			}

			#delimit ;
			gen D_`taxvar'_unrev10 = 0;
			replace D_`taxvar'_unrev10 = d1 if
			abs(d2)>=abs(d1) & abs(d3)>=abs(d1) & abs(d4)>=abs(d1) & abs(d5)>=abs(d1) & abs(d6)>=abs(d1) & abs(d7)>=abs(d1) & abs(d8)>=abs(d1) & abs(d9)>=abs(d1) & abs(d10)>=abs(d1) &
			sign(d1)==sign(d2) & sign(d1)==sign(d3) & sign(d1)==sign(d4) & sign(d1)==sign(d5) & sign(d1)==sign(d6) & sign(d1)==sign(d7) & sign(d1)==sign(d8) & sign(d1)==sign(d9) & sign(d1)==sign(d10);
			gen D_`taxvar'_unrev10_dummy = 0;
			replace D_`taxvar'_unrev10_dummy = sign(d1) if
			abs(d2)>=abs(d1) & abs(d3)>=abs(d1) & abs(d4)>=abs(d1) & abs(d5)>=abs(d1) & abs(d6)>=abs(d1) & abs(d7)>=abs(d1) & abs(d8)>=abs(d1) & abs(d9)>=abs(d1) & abs(d10)>=abs(d1) &
			sign(d1)==sign(d2) & sign(d1)==sign(d3) & sign(d1)==sign(d4) & sign(d1)==sign(d5) & sign(d1)==sign(d6) & sign(d1)==sign(d7) & sign(d1)==sign(d8) & sign(d1)==sign(d9) & sign(d1)==sign(d10);
			gen D_`taxvar'_unrev10_dummy1pp = 0;
			replace D_`taxvar'_unrev10_dummy1pp = sign(d1) if abs(d1)>0.01 &
			abs(d2)>=abs(d1) & abs(d3)>=abs(d1) & abs(d4)>=abs(d1) & abs(d5)>=abs(d1) & abs(d6)>=abs(d1) & abs(d7)>=abs(d1) & abs(d8)>=abs(d1) & abs(d9)>=abs(d1) & abs(d10)>=abs(d1) &
			sign(d1)==sign(d2) & sign(d1)==sign(d3) & sign(d1)==sign(d4) & sign(d1)==sign(d5) & sign(d1)==sign(d6) & sign(d1)==sign(d7) & sign(d1)==sign(d8) & sign(d1)==sign(d9) & sign(d1)==sign(d10);
			gen D_`taxvar'_unalter10 = 0;
			replace D_`taxvar'_unalter10 = d1 if diff_thru10==0;
			gen D_`taxvar'_unalter10_dummy = 0;
			replace D_`taxvar'_unalter10_dummy = sign(d1) if diff_thru10==0;

			gen D_`taxvar'_unrev15 = 0;
			replace D_`taxvar'_unrev15 = d1 if
			abs(d2)>=abs(d1) & abs(d3)>=abs(d1) & abs(d4)>=abs(d1) & abs(d5)>=abs(d1) & abs(d6)>=abs(d1) & abs(d7)>=abs(d1) & abs(d8)>=abs(d1) & abs(d9)>=abs(d1) & abs(d10)>=abs(d1) &
			abs(d11)>=abs(d1) & abs(d12)>=abs(d1) & abs(d13)>=abs(d1) & abs(d14)>=abs(d1) & abs(d15)>=abs(d1) &
			sign(d1)==sign(d2) & sign(d1)==sign(d3) & sign(d1)==sign(d4) & sign(d1)==sign(d5) & sign(d1)==sign(d6) & sign(d1)==sign(d7) & sign(d1)==sign(d8) & sign(d1)==sign(d9) & sign(d1)==sign(d10) & sign(d1)==sign(d11) & sign(d1)==sign(d12) & sign(d1)==sign(d13) & sign(d1)==sign(d14) & sign(d1)==sign(d15);
			gen D_`taxvar'_unrev15_dummy = 0;
			replace D_`taxvar'_unrev15_dummy = sign(d1) if
			abs(d2)>=abs(d1) & abs(d3)>=abs(d1) & abs(d4)>=abs(d1) & abs(d5)>=abs(d1) & abs(d6)>=abs(d1) & abs(d7)>=abs(d1) & abs(d8)>=abs(d1) & abs(d9)>=abs(d1) & abs(d10)>=abs(d1) &
			abs(d11)>=abs(d1) & abs(d12)>=abs(d1) & abs(d13)>=abs(d1) & abs(d14)>=abs(d1) & abs(d15)>=abs(d1) &
			sign(d1)==sign(d2) & sign(d1)==sign(d3) & sign(d1)==sign(d4) & sign(d1)==sign(d5) & sign(d1)==sign(d6) & sign(d1)==sign(d7) & sign(d1)==sign(d8) & sign(d1)==sign(d9) & sign(d1)==sign(d10) & sign(d1)==sign(d11) & sign(d1)==sign(d12) & sign(d1)==sign(d13) & sign(d1)==sign(d14) & sign(d1)==sign(d15);
			gen D_`taxvar'_unalter15 = 0;
			replace D_`taxvar'_unalter15 = d1 if diff_thru15==0;
			gen D_`taxvar'_unalter15_dummy = 0;
			replace D_`taxvar'_unalter15_dummy = sign(d1) if diff_thru15==0;

			#delimit cr;
			drop p50pos p50neg poschange negchange big
			scalar drop _all

			foreach event of local eventlist`taxvar' {
				matrix `event' = J(45,5,.)
				matrix `event'W = J(45,5,.)
				gen insample = 1
				fvset base 1990 year
				
			***************************************************	
			*THIS IS THE ACTUAL REGRESSION FOR THE EVENT STUDY!	
			***************************************************	
				
				qui reg F10S`intervalp10'.`depvar' i.year##i.regionpairID L(-9/5).`event' `controls' if fips~=F_fips & year<2010 & year>1976, noconst vce(cluster pairID)

				qui sum year if e(sample)
				di "r(min) = " r(min) "   and r(max) = " r(max)
				replace `event' = . if inrange(year,r(min),r(max))==0

				foreach h of num 1/10 {
					local hp = `h'+`interval'
					local s = `h'+`prestart'+1
					local hm1 = `h'-1
					*******************************************************
					*3-way Standard Errors
					local clust = 1
					foreach c in fipsyear F_fipsyear pairIDasymmetric clustall {
						*qui reg F`h'S`hp'.`depvar' i.year##i.regionpairID `event' `controls' if insample, noconst vce(cluster `c') 
						qui reg F`h'S`hp'.`depvar' i.year `event' `controls' if insample, noconst vce(cluster `c') 
						*qui reg F`h'S`hp'.`depvar' `event' `controls' if insample, noconst vce(cluster `c') 
						scalar c_`clust' = _se[`event']
						local clust = `clust'+1
					}
					scalar se_reg = (c_1^2+c_2^2+c_3^2-2*(c_4^2))^.5
					*******************************************************
					*scalar cum`h' = cum`hm1' + _b[`event']
					*display "cumulative thru `h' equals      " cum`h'
					matrix `event'[`s',1] = _b[`event']
					matrix `event'[`s',2] = _b[`event'] + 1.65*se_reg
					matrix `event'[`s',3] = _b[`event'] - 1.65*se_reg
					matrix `event'[`s',4] = _b[`event'] + 1.96*se_reg
					matrix `event'[`s',5] = _b[`event'] - 1.96*se_reg
				}
				foreach h of num 0/`prestart' {
					if `h' ~= `interval' {
						local s = `prestart' - `h' + 1
						gen L`h'_`depvar' = L`h'.`depvar' - L`interval'.`depvar'
						*******************************************************
						*3-way Standard Errors
						local clust = 1
						foreach c in fipsyear F_fipsyear pairIDasymmetric clustall{
						*qui reg L`h'_`depvar' i.year##i.regionpairID `event' `controls' if insample, noconst vce(cluster `c') 
						qui reg L`h'_`depvar' i.year `event' `controls' if insample, noconst vce(cluster `c') 
						*qui reg L`h'_`depvar' `event' `controls' if insample, noconst vce(cluster `c') 
						scalar c_`clust' = _se[`event']
						local clust = `clust'+1
						}
						scalar se_reg = (c_1^2+c_2^2+c_3^2-2*(c_4^2))^.5
						*******************************************************
						matrix `event'[`s',1] = _b[`event']
						matrix `event'[`s',2] = _b[`event'] + 1.65*se_reg
						matrix `event'[`s',3] = _b[`event'] - 1.65*se_reg
						matrix `event'[`s',4] = _b[`event'] + 1.96*se_reg
						matrix `event'[`s',5] = _b[`event'] - 1.96*se_reg
						drop L`h'_`depvar'
					}
				}
				matrix preavg = J(1,1,.)
				matrix preavg[1,1] = (`event'[1,1] + `event'[2,1] + `event'[3,1] + `event'[4,1] + `event'[5,1])/5
				global p_`event' = preavg[1,1]
				matrix list `event'
				di "pre-treatment average = ${p_`event'} "

				drop insample
				display "`event'"
			} // end event loop
			drop d1-d15 diff_thru*
		}  // end taxvar loop

		// Unweighted graphs
		foreach taxvar of local taxvars {
			display "here1, `taxvar'"
			foreach event of local eventlist`taxvar' {
				display "`event'"
				clear
				svmat `event', names(col)
				gen s = _n
				gen h = s - `prestart'
				gen zero = 0
				rename c1 beta
				rename c2 CI90_upper
				rename c3 CI90_lower
				rename c4 CI95_upper
				rename c5 CI95_lower
				replace beta = 0 if h==0

				label var h "Years Before/After Tax Change (h)"
				if "`taxvar'_not" == "MTR_p99_not" {
				local title "Top Individual MTR"
				display "1 `title'"
				}
				if "`taxvar'_not" == "ASTR_p99_not" {
				local title "Top Individual ASTR"
				display "1 `title'"
				}
				if "`taxvar'_not" == "ATR_p99_not" {
				local title "Top Individual ATR"
				display "1 `title'"
				}
				if "`taxvar'_not" == "ATR_p95_not" {
				local title "Top Individual ATR95"
				display "1 `title'"
				}
				if "`taxvar'_not" == "CIT_not" {
				local title "Corporate Tax Rate"
				display "2 `title'"
				}
				if "`taxvar'_not" == "I_credit_not" {
				local title "Investment Credit Rate"
				display "3 `title'"
				}
				if "`taxvar'_not" == "RD_credit_not" {
				local title "R&D Credit Rate"
				display "4 `title'"
				}
				display "title is `title'"
				list
				#delimit ;
				twoway (rcap CI90_upper CI90_lower h, lcolor(gs7) lwidth(vthin)) 
				(connected beta h, mcolor(blue) lcolor(blue) ) if h>=-5 & h<=10, 
				legend(off)  xline(0.5, lcolor(red) lpattern(dash) lwidth(thin)) yline(${p_`event'}, lcolor(black) lpattern(dash) lwidth(vthin))
				graphregion(fcolor(white) lcolor(white))
				title("")
				subtitle("`title'")
				ytitle("Outmigration Log Odds-Ratio");
				graph copy `event';
				*graph export ${resultdir}/g`event'.pdf, as(pdf) replace;
				#delimit cr;
			} // end event loop
		} // end taxvar loop
	} // end interval loop

	#delimit ; 

	graph combine D_ATR_p99_unrev5_dummy1pp D_CIT_unrev5_dummy, col(2) imargin(1 1 10 10)
	note("Notes: The dashed black line indicates the average coefficient over the pre-treatment period. We use", span)
	note("a balanced panel from 5 years before event to 10 years after. The graph plots {&beta}{sup:h} from the regressions: ", suffix span)
	note("lnOR{sub:o,d,t+h} {&minus} lnOR{sub:o,d,t} = {&beta}{sup:h}D{sub:o,d,t} + {&epsilon}{sub:o,d,t} , where lnOR is the outmigration log odds-ratio. D{sub:o,d,t} is an event", suffix span)
	note("indicator that takes the value 1 if the destination-origin differential in the net-of-tax rate increases", suffix span)
	note("between t and t+1, -1 if the differential decreases between t and t+1, and 0 if the differential does not ", suffix span)
	note("change. Only permanent tax changes are included (defined as changes that are not reversed in the", suffix span)
	note("next 5 years).", suffix span)
	graphregion(fcolor(white) lcolor(white))
	title("Outmigration Before and After Tax Change Event")
	;

	graph export "${mw_resultsdir}/figure5_all.pdf", as(pdf) replace;

	graph combine D_I_credit_unrev5_dummy D_RD_credit_unrev5_dummy, imargin(0 0 10 10)
	note("Notes: The dashed black line indicates the average coefficient over the pre-treatment period. We use", span)
	note("a balanced panel from 5 years before event to 10 years after. The graph plots {&beta}{sup:h} from the regressions: ", suffix span)
	note("lnOR{sub:o,d,t+h} {&minus} lnOR{sub:o,d,t} = {&beta}{sup:h}D{sub:o,d,t} + {&epsilon}{sub:o,d,t} , where lnOR is the outmigration log odds-ratio. D{sub:o,d,t} is an event", suffix span)
	note("indicator that takes the value 1 if the destination-origin differential in the net-of-tax rate increases", suffix span)
	note("between t and t+1, -1 if the differential decreases between t and t+1, and 0 if the differential does not ", suffix span)
	note("change. Only permanent tax changes are included (defined as changes that are not reversed in the", suffix span)
	note("next 5 years).", suffix span)
	graphregion(fcolor(white) lcolor(white))
	title("Outmigration Before and After Tax Change Event")
	;
	graph export "${mw_resultsdir}/appendix_figure5_all.pdf", as(pdf) replace;
	

	
**FIGURE 5 - REPLICATION CODE WITH STATA PROGRAMS ------------------------------------------------

*GOAL: gD_ATR_p99_unrev5_dummy1pp

		
	




