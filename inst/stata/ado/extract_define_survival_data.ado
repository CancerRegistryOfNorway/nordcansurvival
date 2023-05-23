*! version 1.0.7  2023-05-22   
{ /* define extract_define_survival_data */

capt prog drop extract_define_survival_data
prog define extract_define_survival_data , nclass

syntax ,                              ///
	incidence_data(string)            ///
	[survival_file_base(string)]      /// 
	[survival_file_analysis(string)]  /// 
	[survival_entities(string)]       ///
	[country(string)]                 ///
	[trace]                           ///
	[10PCsampleBreastProstateCRCfrom_2001] ///
	[dev] // tabulations, only for QA in developement
	
set type double

* ad-hoc

local survival_file_base survival_file_base.dta 
local survival_file_analysis survival_file_analysis.dta 	
	
local quietly quietly 	

if ( "`trace'" == "trace" ) {
	
	trace_start trace_extract_define_survival_data.log
	
	set trace on 
	capt assert c(trace) == "on" 
	
	if ( _rc == 9 ) {
		
		di as error "trace not active"
		prog dir
		exit 
	}
}

********************************************************************************
		
`quietly' {
	
timer on 1	
		
clear
find_entity_table_look_up_file, filename(NC_survival_entity_table.dta)		
local survival_entities `r(survival_entities)'	

clean_up_old_files 
read_incidence_data, incidence_data(`incidence_data')

if ( "`10PCsampleBreastProstateCRCfrom_2001'" != "" ) {   // SAMPLE
	                                                      // SAMPLE
	keep if period_5 >= 2001                              // SAMPLE
}                                                         // SAMPLE

define_10_year_periods, five_year_period_variable_name(period_5)

su period_5, meanonly
local inc_year_last = r(max) + 4

select_validate_vars, inc_year_last(`inc_year_last')
longform_pat_entitylevel, survival_entities(`survival_entities')

define_agegr_w_ICCS // 5-level ICCS agegroups, and 3-level (1-2), 3, (4-5) 

if ( "`10PCsampleBreastProstateCRCfrom_2001'" != "" ) {  // SAMPLE
	                                                     // SAMPLE 
	keep if inlist(entity, 180, 240, 520)                // SAMPLE
	sample 10 , by(entity period_5 agegroup_ICSS_5)      // SAMPLE
}                                                        // SAMPLE                                                        

local noobs 3 // lower limit for n in age stratum
local tot  30 // lower limit for N in group to be analysed

mark_small_n_strata ,            ///
	idvar(spid)                  /// 
	groups(entity sex period_5)  ///  
	agegr(agegroup_ICSS_5)       ///
	nobs(`noobs')                ///
	tot(`tot')
	
mark_small_n_strata ,            ///
	idvar(spid)                  /// 
	groups(entity sex period_10) ///  
	agegr(agegroup_ICSS_3)       ///
	nobs(`noobs')                ///
	tot(`tot')
	
assert agegroup_ICSS_5_NOK if  agegroup_ICSS_3_NOK
assert !agegroup_ICSS_3_NOK if !agegroup_ICSS_5_NOK	

gen byte dead_fup = ( vit_sta == 2 & year(end_of_followup) <= `inc_year_last')
gen end_fup = min( end_of_followup, d(31.dec.`inc_year_last') )
drop if end_fup == date_of_incidence  

capture generate country = "`country'"
 
order agegroup_ICSS_5 weights_ICSS_5 agegroup_ICSS_5_NOK, last 
order agegroup_ICSS_3 weights_ICSS_3 agegroup_ICSS_3_NOK, last   
order agegroup_ICSS_5_tot_NOK agegroup_ICSS_3_tot_NOK, last
order year, before(period_5)
compress

save "`survival_file_base'" , replace

nc_define_fup, ///
	result(`survival_file_analysis') ///
	inc_year_last(`inc_year_last')  

survival_file_analysis, ///
	survival_file_analysis(`survival_file_analysis') 

define_p5_s10_breast_prostate, ///
	survival_file_analysis_5(survival_file_analysis_5.dta) /// 
	survival_file_analysis_5_10(survival_file_analysis_5_10.dta)
	
define_p10_s10_breast_prostate, ///
	survival_file_analysis_10(survival_file_analysis_10.dta) /// 
	survival_file_analysis_10_10(survival_file_analysis_10_10.dta)	


qui { // ad-hoc new naming
 
	confirm file survival_file_analysis_5.dta
	
	copy survival_file_analysis_5.dta ///
	           survival_file_analysis_survivaltime_05_period_05.dta ///
			   , replace 
			   			   
	confirm file survival_file_analysis_survivaltime_05_period_05.dta
	
	erase survival_file_analysis_5.dta
	
	****************************************************************************
	
	confirm file survival_file_analysis_10.dta
	
	copy survival_file_analysis_10.dta ///
	           survival_file_analysis_survivaltime_05_period_10.dta ///
			    , replace 
			   
	confirm file survival_file_analysis_survivaltime_05_period_10.dta
	
	erase survival_file_analysis_10.dta
	
	****************************************************************************
	
	
	confirm file survival_file_analysis_5_10.dta
	
	copy survival_file_analysis_5_10.dta ///
	           survival_file_analysis_survivaltime_10_period_05.dta ///
			   , replace
	
	confirm file survival_file_analysis_survivaltime_10_period_05.dta
	
	erase survival_file_analysis_5_10.dta

	****************************************************************************
	
	confirm file survival_file_analysis_10_10.dta
	
	copy survival_file_analysis_10_10.dta  ///
		survival_file_analysis_survivaltime_10_period_10.dta ///
		, replace
		
	erase survival_file_analysis_10_10.dta	
}

********************************************************************************

if ( "`trace'" == "trace" ) {

	set trace off
	log close trace
	assert c(trace) == "off"
}

********************************************************************************
timer off 1
	
} // quietly

stata_code_tail, ///
	function(extract_define_survival_data) ///
	timer(1)

noi di _n "The following files are ready for analysis:"
noi dir survival_file_analysis_survivaltime_??_period_??.dta
noi di _n

end // extract_define_survival_data 
}

********************************************************************************
{ // * define sub programs 
********************************************************************************
{ /* sub find_entity_table_look_up_file */

capt prog drop find_entity_table_look_up_file

prog define find_entity_table_look_up_file , rclass

syntax , filename(string)

findfile `filename'
 
return local survival_entities `r(fn)'

end // find_entity_table_look_up_file
}
{ /* sub clean_up_old_files */

capt prog drop clean_up_old_files

prog define clean_up_old_files, rclass

local fls1 : dir . files "survival_file*" 

foreach fn of local fls {
    
	capture confirm file "`fn'"

	if ( _rc == 0 ) {
		
		erase "`fn'"
	}
}
	
end	// clean_up_old_files	
}
{ /* sub read_incidence_data */

capt prog drop read_incidence_data
prog define read_incidence_data 

syntax [anything] , incidence_data(string) 

 
if ( strlower(substr("`incidence_data'",-4,.)) == ".csv" ) {
	
	import delimited using "`incidence_data'" , ///
		varnames(1)       /// 
		encoding("UTF-8") ///
	    delimiter(";")    ///
		case(preserve)    ///
		asdouble ///
		clear
		
		local strdates date_of_birth date_of_incidence end_of_followup 
		
		foreach var of varlist `strdates' {
		    
			rename `var' str_`var'
			gen long `var'= date(str_`var', "YMD") , before(str_`var')   	
			format `var' %td
			drop str_`var'	
		}
}

else {	
	
	use "`incidence_data'" , clear 
}

capture rename period period_5 // AD-HOC

capture confirm variable year 

if ( _rc == 111) {
	
	generate int year = year(date_of_incidence)
}

end // read_incidence_data	
}
{ /* sub define_10_year_periods */

capt prog drop define_10_year_periods

prog define define_10_year_periods, rclass

syntax , ///
	five_year_period_variable_name(varname)
tab `five_year_period_variable_name'
local periods5 = r(r)
qui su `five_year_period_variable_name' , meanonly 
gen int period_10 = (r(max)+5) + ( floor((year-(r(max)+5))/10) * 10 )

if mod(`periods5', 2) {
				
	replace period_10 = . if `five_year_period_variable_name' == r(min) 
}

end // 	five_year_period_variable_name
	
}
{ /* sub select_validate_vars */

capt prog drop select_validate_vars 
prog define select_validate_vars , nclass

syntax , ///
	inc_year_last(int)  
	
capture rename period period_5 // tolerate name "period" 
capture generate year = year(date_of_incidence)
	
********************************************************************************
* delete variables NOT used for survival analysis 
********************************************************************************

#delim ; 

keep 

	pat                /* Patient idenfification code */
	tum                /* Tumor identification code */ 
	tum_sequence       /* Sequence of tumors for each person */ 
	
	date_of_incidence  /* Date of incidence */
	year
	period_5
	period_10
	
	icd10              /* ICD10-code set by IARCCheckTool*/
	
	entity_level_10      /* Cancer groups, all */
	entity_level_11      /* Cancer groups, all except non melanoma */
	entity_level_12      /* Cancer groups, all except non melanoma, prostate and breast */
	entity_level_20      /* Cancer groups, first grouping level*/ 
	entity_level_30      /* Cancer groups, lowest level */
	
	date_of_birth      /* Date of birth */ 
	age                /* Age at diagnosis (in years) */ 
	sex                /* Current sex of patient */ 
	vit_sta            /* Last known vital status of patient */
	end_of_followup    /* Date for last known vital status */
	
	excl_surv_total
;
#delim cr                                           

********************************************************************************
* exclutions
********************************************************************************
capt drop if excl_imp_total != 0 
drop if excl_surv_total != 0 
drop if entity_level_30 == 999   // Not included in NORDCAN
assert  entity_level_30 != 888   // should NOT exist
drop excl_*  // drop all exclution indicators
********************************************************************************
* confirm structure of data 
********************************************************************************
isid tum              // ONE ROW PER Tumor identification code
isid pat tum_sequence // ONE ROW PER patient id  X tum sequence number 
********************************************************************************
* confirm existence of variables
********************************************************************************
confirm variable pat 
confirm variable tum 
confirm variable tum_sequence
confirm variable date_of_birth 
confirm variable date_of_incidence
confirm variable vit_sta 
confirm variable end_of_followup
confirm variable period_5
confirm variable period_10
********************************************************************************
qui su date_of_incidence , meanonly 
assert year(r(max)) == `inc_year_last'
assert age == int(age)
assert inrange(age, 0, 89)      
_recast byte age                 
********************************************************************************
noi assert date_of_birth < end_of_followup
noi assert inlist(sex, 1, 2)     
noi assert inlist(vit_sta, 1, 2, 3) 
********************************************************************************
compress
end // select_validate_vars  
}
{ /* sub longform_pat_entitylevel */
capt prog drop longform_pat_entitylevel 
prog define longform_pat_entitylevel 

syntax [anything] , ///
	survival_entities(string)
	
********************************************************************************	
* restructure
********************************************************************************
isid pat tum
rename (entity_level_*)(entity*)
reshape long entity , i( pat tum ) j(entity_levels)  
drop if mi(entity)
********************************************************************************
* keep first ca per patient per entity (group)
********************************************************************************
bysort pat entity ( date_of_incidence tum_sequence tum ) : keep if ( _n == 1 )
isid pat entity
local spid string(pat,"%20.0f") + "_" + string(entity,"%20.0f")
generate spid = `spid'
char define _dta[NC_var_def_spid] `"generate spid = `spid'"'  
********************************************************************************
* merge NC S data with NC S definitions
********************************************************************************
#delim ;
local survival_entities_vars  = 	
 "
 entity
 entity_str
 entity_description_en 
 entity_level 
 entity_group 
 entity_display_order
 "
; 
#delim cr 
********************************************************************************
merge m:1 entity using "`survival_entities'", ///
	keepusing(`survival_entities_vars') ///
	
drop entity_levels
keep if _merge == 3           // "NC S data" <==> "NC S definitions" 
drop _merge
isid pat entity

********************************************************************************
* reorder variables
********************************************************************************

#delim ; 

order

	pat    /* id patient */
	tum    /* id tumor */ 
	tum_sequence
	
	entity
	entity_str
	entity_level 
	entity_group 
	entity_description_en 
	entity_display_order
	
	date_of_incidence 
	date_of_birth      
	end_of_followup  // Date for last known vital status 
	vit_sta          // Last known vital status of patient
	
	sex
;
#delim cr

********************************************************************************
end // longform_pat_entitylevel 
}
{ /* sub agegrdef */ 
capt prog drop agegrdef
prog define agegrdef

qui nc_s_define_agegr_w_ICCS

assert !mi(period_10)
 
qui nc_s_data_chk_strata ,   		///
		by(entity period_10 sex)		///  
		iweight(weights_ICSS)       ///
		standstrata(agegroup_ICSS) 	
		
confirm variable weight_err 
confirm variable no_obs_in_strata

end // agegrdef
}
{ /* sub define mark_small_n_strata */

capt prog drop mark_small_n_strata 
prog define mark_small_n_strata , rclass

syntax , ///
	idvar(varname) /// 
	groups(varlist) ///  
	agegr(varname) ///
	nobs(integer) ///
	tot(integer)
 	
tempvar f 

* failure 1A minimum `nobs' obs in any age group
* failure 1B all age groups present  (1, 2, ..., r(max) )

qui su `agegr', meanonly  // need global maximum
 
bysort `groups' `agegr' (`idvar') : g byte `f' = _N < `nobs'

by `groups' (`agegr' `idvar') : ///
	replace `f' = sum( cond( `f', `f', ///
						cond(_n==1, `agegr'!= 1, ///
							cond(_n==_N, `agegr'!= r(max), ///
								`agegr'-`agegr'[_n-1] > 1 )))) 

by `groups' (`agegr' `idvar') : g byte `agegr'_NOK =  `f'[_N] > 0 
							
* failure 2 total number in group above criterium  
 
bysort `groups' : gen byte `agegr'_tot_NOK = ( _N < `tot' )

lab var  `agegr'_NOK "mark groups with n < `nobs' in any one stratum"
lab var  `agegr'_tot_NOK "mark groups with N < `tot'"

end // mark_small_n_strata 
}
{ /* sub define_agegr_w_ICCS */

capt prog drop define_agegr_w_ICCS
prog define define_agegr_w_ICCS, nclass 

********************************************************************************
* defining agegroups and weigths ( 1, 2, 3.1, 3.2, 3.3) 
********************************************************************************
********************************************************************************
* agegroup weigths 1, 2, 3.1, 3.2, 3.3
********************************************************************************
********************************************************************************
* ICSS 1 Elderly ( ~87.3% of cancers )
********************************************************************************

/*
	https://gitlab.kreftregisteret.no/nordcan/nordcansurvival/-/issues/2

	1. ICSS 1 Elderly. Most sites and summary groups: 

	A. 0–49  (12), 
	A. 50–59 (17),  [29] A 0-59
	B. 60–69 (27),  [27] B 60–69  
	C. 70–79 (29),  [44] C 70-89
	C. 80–89 (15)
*/

scalar weights_ICSS_1 = " .12 .17 .27 .29 .15 "
assert `=subinstr(trim(itrim(scalar(weights_ICSS_1)))," ","+",.)' == 1

scalar weights_ICSS_1B = " `= .12 + .17' .27 `= round(.29 + .15, 0.01)' "
assert `=subinstr(trim(itrim(scalar(weights_ICSS_1B)))," ","+",.)' == 1

tokenize `= scalar(weights_ICSS_1) '

generate double weights_ICSS_1 = . 
replace weights_ICSS_1 = `1' if inrange( int(age) , 0 , 49 ) 
replace weights_ICSS_1 = `2' if inrange( int(age) , 50, 59 )
replace weights_ICSS_1 = `3' if inrange( int(age) , 60, 69 )
replace weights_ICSS_1 = `4' if inrange( int(age) , 70, 79 )
replace weights_ICSS_1 = `5' if inrange( int(age) , 80, 89 )

generate double weights_ICSS_1B = . 
replace weights_ICSS_1B = .29 if inrange( int(age) , 0 , 49 ) 
replace weights_ICSS_1B = .29 if inrange( int(age) , 50, 59 )
replace weights_ICSS_1B = .27 if inrange( int(age) , 60, 69 )
replace weights_ICSS_1B = .44 if inrange( int(age) , 70, 79 )
replace weights_ICSS_1B = .44 if inrange( int(age) , 80, 89 )

********************************************************************************
* ICSS 2 Little age dependency ( ~10.2% of cancers)
********************************************************************************
	
* 2.1 Bone *********************************************************************

/*
	i. Bone: 

	A. 0–29   (7), 
	A. 30–39 (13), 
	B. 40–49 (16), [36] A 0-49
	C. 50–69 (41), [41] B 50-69 
	C. 70–89 (23)  [23] C 70-89 
*/  

scalar weights_ICSS_21 = " .07 .13 .16 .41 .23 "
assert  `=subinstr(trim(itrim(scalar(weights_ICSS_21)))," ","+",.)' == 1

scalar weights_ICSS_21B = " `= .07 + .13 + .16' .41 .23 "
assert  `=subinstr(trim(itrim(scalar(weights_ICSS_21B)))," ","+",.)' == 1
tokenize `= scalar(weights_ICSS_21) '

generate double weights_ICSS_21 = . 
replace weights_ICSS_21 = `1' if inrange(int(age), 0 , 29 ) 
replace weights_ICSS_21 = `2' if inrange(int(age), 30, 39 )
replace weights_ICSS_21 = `3' if inrange(int(age), 40, 49 )
replace weights_ICSS_21 = `4' if inrange(int(age), 50, 69 )
replace weights_ICSS_21 = `5' if inrange(int(age), 70, 89 ) 

generate double weights_ICSS_21B = . 
replace weights_ICSS_21B = .36  if inrange(int(age), 0 , 29 ) 
replace weights_ICSS_21B = .36  if inrange(int(age), 30, 39 )
replace weights_ICSS_21B = .36  if inrange(int(age), 40, 49 )
replace weights_ICSS_21B = .41 if inrange(int(age), 50, 69 )
replace weights_ICSS_21B = .23 if inrange(int(age), 70, 89 ) 

* 2.2 Melanoma, cervix, brain, thyroid, soft tissue ****************************

/*
	ii. Melanoma, cervix, brain, thyroid, soft tissue: 

	A. 0–49 (36),   [36] A 0–49  
	A. 50–59 (19), 
	B. 60–69 (22),  [41] B 50-69
	C. 70–79 (16),  [23] C 70-89
	C. 80–89 (7)
*/

scalar weights_ICSS_22 = " .36 .19 .22 .16 .07 "
assert `=subinstr(trim(itrim(scalar(weights_ICSS_22)))," ","+",.)' == 1

scalar weights_ICSS_22B = " .36 `= .19 + .22' `= .16 + .07' "
assert `=subinstr(trim(itrim(scalar(weights_ICSS_22B)))," ","+",.)' == 1

tokenize `= scalar(weights_ICSS_22) '

generate double weights_ICSS_22 = . 
replace weights_ICSS_22 = `1' if inrange( int(age) , 0 , 49 ) 
replace weights_ICSS_22 = `2' if inrange( int(age) , 50, 59 )
replace weights_ICSS_22 = `3' if inrange( int(age) , 60, 69 )
replace weights_ICSS_22 = `4' if inrange( int(age) , 70, 79 )
replace weights_ICSS_22 = `5' if inrange( int(age) , 80, 89 )

generate double weights_ICSS_22B = . 
replace weights_ICSS_22B = .36 if inrange( int(age) , 0 , 49 ) 
replace weights_ICSS_22B = .41 if inrange( int(age) , 50, 59 )
replace weights_ICSS_22B = .41 if inrange( int(age) , 60, 69 )
replace weights_ICSS_22B = .23 if inrange( int(age) , 70, 79 )
replace weights_ICSS_22B = .23 if inrange( int(age) , 80, 89 )

********************************************************************************
* ICSS 3 Young adults ( ~2.5% of cancers ) 
********************************************************************************

* 3.1 Testis, Hodgkin lymphoma
* 3.2 Acute lymphatic leukaemia

* 3.1 Testis, Hodgkin lymphoma

/*
	i. Testis, Hodgkin lymphoma: 

	A. 0–29  (31),  [31] A 0–29   
	A. 30–39 (21), 
	B. 40–49 (13),  [34] B 30-49
	C. 50–69 (20),   
	C. 70–89 (15)   [35] C 50-89
*/

scalar weights_ICSS_31 = " .31 .21 .13 .20 .15 "
assert `=subinstr(trim(itrim(scalar(weights_ICSS_31)))," ","+",.)' == 1

scalar weights_ICSS_31B = " .31 `= .21 + .13' `= .20 + .15' "
assert `=subinstr(trim(itrim(scalar(weights_ICSS_31B)))," ","+",.)' == 1

tokenize `= scalar(weights_ICSS_31) '

generate double weights_ICSS_31 = . 
replace weights_ICSS_31 = `1' if inrange(int(age), 0 , 29 ) 
replace weights_ICSS_31 = `2' if inrange(int(age), 30, 39 )
replace weights_ICSS_31 = `3' if inrange(int(age), 40, 49 )
replace weights_ICSS_31 = `4' if inrange(int(age), 50, 69 )
replace weights_ICSS_31 = `5' if inrange(int(age), 70, 89 )

generate double weights_ICSS_31B = . 
replace weights_ICSS_31B = .31 if inrange(int(age), 0 , 29 ) 
replace weights_ICSS_31B = .34 if inrange(int(age), 30, 39 )
replace weights_ICSS_31B = .34 if inrange(int(age), 40, 49 )
replace weights_ICSS_31B = .35 if inrange(int(age), 50, 69 )
replace weights_ICSS_31B = .35 if inrange(int(age), 70, 89 )

* 3.2 Acute lymphatic leukaemia ************************************************

/*
	ii. Acute leukemia: 

	A. 0–29 (31),   [31] A 0-29 
	A. 30–49 (34),  [34] B 30-49
	B. 50–69 (20), 
	C. 70–79 (10), 
	C. 80–89 (5)    [35] C 50-89
*/

scalar weights_ICSS_32 = " .31 .34 .20 .10 .05 "
assert `=subinstr(trim(itrim(scalar(weights_ICSS_32)))," ","+",.)' == 1

scalar weights_ICSS_32B = " .31 .34 `= .20 + .10 + .05' "
assert `=subinstr(trim(itrim(scalar(weights_ICSS_32B)))," ","+",.)' == 1

tokenize `= scalar(weights_ICSS_32) '

generate double weights_ICSS_32 = . 
replace weights_ICSS_32 = `1' if inrange(int(age), 0 , 29 ) 
replace weights_ICSS_32 = `2' if inrange(int(age), 30, 49 )
replace weights_ICSS_32 = `3' if inrange(int(age), 50, 69 )
replace weights_ICSS_32 = `4' if inrange(int(age), 70, 79 ) 
replace weights_ICSS_32 = `5' if inrange(int(age), 80, 89 ) 

generate double weights_ICSS_32B = . 
replace weights_ICSS_32B = .31 if inrange(int(age), 0 , 29 ) 
replace weights_ICSS_32B = .34 if inrange(int(age), 30, 49 )
replace weights_ICSS_32B = .35 if inrange(int(age), 50, 69 )
replace weights_ICSS_32B = .35 if inrange(int(age), 70, 79 ) 
replace weights_ICSS_32B = .35 if inrange(int(age), 80, 89 ) 

********************************************************************************

assert !mi(weights_ICSS_1)  // 1 Elderly  
assert !mi(weights_ICSS_21) // 2 Bone
assert !mi(weights_ICSS_22) // 2 Melanoma, cervix, brain, thyroid, soft tissue 
assert !mi(weights_ICSS_31) // 3 Testis, Hodgkin lymphoma
assert !mi(weights_ICSS_32) // 3 Acute lymphatic leukaemia

local offset = 3 * uchar(8199) 

lab var weights_ICSS_1   "{ `= scalar(weights_ICSS_1) ' } 1. Elderly ( ~87.3% of cancers )"
lab var weights_ICSS_21  "{ `= scalar(weights_ICSS_21) ' } 2.1 Bone" 
lab var weights_ICSS_22  "{ `= scalar(weights_ICSS_22) ' } 2.2 Melanoma, cervix, brain, thyroid, soft tissue" 
lab var weights_ICSS_31  "{ `= scalar(weights_ICSS_31)' } 3.1 Testis, Hodgkin lymphoma"
lab var weights_ICSS_32  "{ `= scalar(weights_ICSS_32)' } 3.2 Acute lymphatic leukaemia" 

assert !mi(weights_ICSS_1B)  // Elderly ( ~87.3% of cancers )
assert !mi(weights_ICSS_21B) // Bone  
assert !mi(weights_ICSS_22B) // Melanoma, cervix, brain, thyroid, soft tissue 
assert !mi(weights_ICSS_31B) // Testis, Hodgkin lymphoma
assert !mi(weights_ICSS_32B) // Acute lymphatic leukaemia

lab var weights_ICSS_1B	 "{ `offset' `= scalar(weights_ICSS_1B) ' `offset' } 1. Elderly ( ~87.3% of cancers )"
lab var weights_ICSS_21B "{ `offset' `= scalar(weights_ICSS_21B) ' `offset' } 2.1 Bone" 
lab var weights_ICSS_22B "{ `offset' `= scalar(weights_ICSS_22B) ' `offset' } 2.2 Melanoma, cervix, brain, thyroid, soft tissue"
lab var weights_ICSS_31B "{ `offset' `= scalar(weights_ICSS_31B)' `offset' } 3.1 Testis, Hodgkin lymphoma"
lab var weights_ICSS_32B "{ `offset' `= scalar(weights_ICSS_32B)' `offset' } 3.2 Acute lymphatic leukaemia" 

********************************************************************************
* make one variable "weights_ICSS" applying weights above
********************************************************************************

generate double weights_ICSS = .  // 5 levels
generate double weights_ICSSB = . // 3 levels

gen weights = ""

* 3.1 Testis, Hodgkin lymphoma
replace weights_ICSS = weights_ICSS_31 if inlist(entity,250,370)  
replace weights_ICSSB = weights_ICSS_31B if inlist(entity,250,370)
replace weights_ICSS_31B = . if ! inlist(entity,250,370) 

replace weights = "NC ICSS 3.1" if inlist(entity,250,370) 
   
* 3.2 Acute leukemia
replace weights_ICSS = weights_ICSS_32 if inlist(entity,401)  
replace weights_ICSSB = weights_ICSS_32B if inlist(entity,401)       
replace weights_ICSS_32B = . if ! inlist(entity,401)

replace weights = "NC ICSS 3.2" if inlist(entity,401)

* 2.1 Bone
replace weights_ICSS = weights_ICSS_21 if inlist(entity,340)      
replace weights_ICSSB = weights_ICSS_21B if inlist(entity,340)       
replace weights_ICSS_21B = . if ! inlist(entity,340)   

replace weights = "NC ICSS 2.1" if inlist(entity,340)

* 2.2 Melanoma, cervix, brain, thyroid, soft tissue	
replace weights_ICSS = weights_ICSS_22 if inlist(entity, 190, 290, 320, 330, 350)
replace weights_ICSSB = weights_ICSS_22B if inlist(entity, 190, 290, 320, 330, 350)	
replace weights_ICSS_22B = . if ! inlist(entity, 190, 290, 320, 330, 350)

replace weights = "NC ICSS 2.2" if inlist(entity, 190, 290, 320, 330, 350)

* OTHER: 1. ICSS 1 Elderly. Most sites and summary groups: 

replace weights_ICSS = weights_ICSS_1 if mi(weights_ICSS)
replace weights_ICSSB = weights_ICSS_1B if mi(weights_ICSSB)
replace weights_ICSS_1B = . if ! ///
	(	inlist(entity,250,370) ///
		| inlist(entity, 190, 290, 320, 330, 350) ///
		| inlist(entity, 190, 290, 320, 330, 350) ///
	)

replace weights = "NC ICSS 1" if mi(weights)
lab var weights "NC ICSS weights"
	
rename weights_ICSS weights_ICSS_5
rename weights_ICSSB weights_ICSS_3 

assert !mi(weights_ICSS_5)
assert !mi(weights_ICSS_3)

lab var weights_ICSS_5 "assigned (5) weights from weight sets 1, 21, 22, 31, 32"
lab var weights_ICSS_3 "assigned (3) weights from weight sets 1B, 21B, 22B, 31B, 32B"
	
********************************************************************************
* define agegroups for weighting:  
********************************************************************************

* A:  Testis, Bone, Soft tissues -----------------------------------------------

scalar agegroup_ICSS_A = " 00-29 30-39 40-49 50-69 70-89 " 
tokenize `= scalar(agegroup_ICSS_A) '
 
generate str6 agegroup_ICSS_A = ""
replace agegroup_ICSS_A = "`1'" if inrange(int(age), 0 , 29 ) 
replace agegroup_ICSS_A = "`2'" if inrange(int(age), 30, 39 )
replace agegroup_ICSS_A = "`3'" if inrange(int(age), 40, 49 )
replace agegroup_ICSS_A = "`4'" if inrange(int(age), 50, 69 )
replace agegroup_ICSS_A = "`5'" if inrange(int(age), 70, 89 )

rename agegroup_ICSS_A agegroup_ICSS_A_str
encode agegroup_ICSS_A_str , gen(agegroup_ICSS_A) 
lab var agegroup_ICSS_A "{`= scalar(agegroup_ICSS_A) '} Testis, Bone, Soft tissues"

* B:  Acute leukemia  ---------------------------------------------------------- 

scalar agegroup_ICSS_B = " 00-29 30-49 50-69 70-79 80-89 " 
tokenize `= scalar(agegroup_ICSS_B) '

generate str6 agegroup_ICSS_B = ""
replace agegroup_ICSS_B = "`1'" if inrange(int(age), 0 , 29 ) 
replace agegroup_ICSS_B = "`2'" if inrange(int(age), 30, 49 )
replace agegroup_ICSS_B = "`3'" if inrange(int(age), 50, 69 )
replace agegroup_ICSS_B = "`4'" if inrange(int(age), 70, 79 )
replace agegroup_ICSS_B = "`5'" if inrange(int(age), 80, 89 )

rename agegroup_ICSS_B agegroup_ICSS_B_str
encode agegroup_ICSS_B_str , gen(agegroup_ICSS_B) 
lab var agegroup_ICSS_B "{`= scalar(agegroup_ICSS_B) '} Acute leukemia"

* agegr C:  other than A and B -------------------------------------------------

scalar agegroup_ICSS_C = " 00-49 50-59 60-69 70-79 80-89 " 
tokenize `= scalar(agegroup_ICSS_C) '

generate str6 agegroup_ICSS_C = ""
replace agegroup_ICSS_C =  "`1'"  if inrange( int(age) , 0 , 49 ) 
replace agegroup_ICSS_C =  "`2'"  if inrange( int(age) , 50, 59 )
replace agegroup_ICSS_C =  "`3'"  if inrange( int(age) , 60, 69 )
replace agegroup_ICSS_C =  "`4'"  if inrange( int(age) , 70, 79 )
replace agegroup_ICSS_C =  "`5'"  if inrange( int(age) , 80, 89 )

rename agegroup_ICSS_C agegroup_ICSS_C_str
encode agegroup_ICSS_C_str , gen(agegroup_ICSS_C)
lab var agegroup_ICSS_C "{`= scalar(agegroup_ICSS_C) '} most entities"

drop agegroup_ICSS_A_str agegroup_ICSS_B_str agegroup_ICSS_C_str 

assert scalar(agegroup_ICSS_A) != scalar(agegroup_ICSS_B) 
assert scalar(agegroup_ICSS_B) != scalar(agegroup_ICSS_C)   

********************************************************************************
* make one common variable agegroup_ICSS
********************************************************************************

generate byte agegroup_ICSS = .

* A:  TESTIS (250) ,  BONE (340)  , HODGKIN LYMPHOMA (370)  -------------------- 
replace agegroup_ICSS_A = . if  ! inlist(entity, 250, 340, 370 )
replace agegroup_ICSS = agegroup_ICSS_A if inlist(entity, 250, 340, 370 )

* B:  Acute Lymphatic Leukaemias (401) -----------------------------------------  
replace agegroup_ICSS_B = . if  ! inlist(entity, 401 )  
replace agegroup_ICSS = agegroup_ICSS_B if inlist(entity, 401 )  

* C:  other than A and B -------------------------------------------------------  
replace agegroup_ICSS_C = . if !mi(agegroup_ICSS_A) | !mi(agegroup_ICSS_B)   
replace agegroup_ICSS = agegroup_ICSS_C if mi(agegroup_ICSS)

gen int agegroup = .
replace agegroup = 1 if ! mi(agegroup_ICSS_C) // "ICSS 1.and 2.ii"  
replace agegroup = 2 if ! mi(agegroup_ICSS_A) // "ICSS 2.i and 3.i"    
replace agegroup = 3 if ! mi(agegroup_ICSS_B) // "ICSS 3.2"  

lab def agegroup ///
	1 "NC ICSS 1, 2.2"  ///
	2 "NC ICSS 2.1, 3.1" ///
	3 "NC ICSS 3.2" 

lab val agegroup agegroup
lab var agegroup "3 five-level age-groups defined"	
	
assert inlist(agegroup_ICSS, 1, 2, 3, 4, 5)
assert inlist(agegroup, 1, 2, 3)

********************************************************************************
local A5 agegroup_ICSS_5
rename agegroup_ICSS `A5'
lab var `A5' "assigned agegr (5) from agegr sets A, B, C"
assert inlist(`A5', 1, 2, 3, 4, 5)

generate str5 agegroup_ICSS_5_str = ""

local agegroup_ICSS  = "agegroup_ICSS_A agegroup_ICSS_B agegroup_ICSS_C"

foreach v of varlist `agegroup_ICSS' { 
	
	tempvar str 
	decode `v' , generate(`str') 
	replace  agegroup_ICSS_5_str = `str' if !mi(`v')
}

if ( "`dev'" == "dev" ) {
	
	noi table agegroup_ICSS_5_str agegroup , nototal
}

********************************************************************************
* defining 3-level age-groups
********************************************************************************

* 1. ICSS 1 Elderly. Most sites and summary groups: 

local A5 agegroup_ICSS_5

gen byte agegroup_ICSS_3_1 = cond(`A5' < 3, 1, cond(`A5' > 3, 3, 2) ) ///
	if ! ( /// 
		inlist(entity, 340) /// 
	    | inlist(entity, 190, 290, 320, 330, 350) /// 
		| inlist(entity, 250, 370) ///  
		| inlist(entity, 401) /// 
	) 

#delim;
	
label define agegroup_ICSS_3_1

	1 "00-59"
	2 "60-69"
	3 "70-89"	 
;
#delim cr	

lab val agegroup_ICSS_3_1 agegroup_ICSS_3_1 

if ( "`dev'" == "dev" ) {

	table agegroup_ICSS_C agegroup_ICSS_3_1 , nototal  
}
	
* 2. ICSS 2.i  Little age dependency 

	* 340 Bone
	
gen byte agegroup_ICSS_3_2_1 = cond(`A5' < 4, 1, cond(`A5' > 4, 3, 2) ) ///
	if inlist(entity, 340) 

#delim;
	
label define agegroup_ICSS_3_2_1

	1   "00-49"
	2   "50-69"
	3   "70-89"
;
#delim cr	

lab val agegroup_ICSS_3_2_1 agegroup_ICSS_3_2_1

if ( "`dev'" == "dev" ) {
	
	table agegroup_ICSS_A agegroup_ICSS_3_2_1, nototal 	
}

* 2. ICSS 2.ii  Little age dependency: 

	* 190 Cervix uteri
	* 290 Skin, non-melanoma
	* 320 Brain and CNS excluding endocrine tumors
	* 320 Thyroid
	* 350 Soft tissues

gen byte agegroup_ICSS_3_2_2 = cond(`A5' == 1, 1, cond(`A5' > 3, 3, 2) ) ///
	if inlist(entity, 190, 290, 320, 330, 350) 

#delim;
	
label define agegroup_ICSS_3_2_2

	1   "00-49"
	2   "50-69"
	3   "70-89"
;
#delim cr	

lab val agegroup_ICSS_3_2_2 agegroup_ICSS_3_2_2

if ( "`dev'" == "dev" ) {
	
	table agegroup_ICSS_C agegroup_ICSS_3_2_2, nototal	 

}	

* 3. ICSS 3.i Young adults. 
	
	* 250 Testis
	* 370 Hodgkin lymphomas

gen byte agegroup_ICSS_3_3_1 = cond(`A5' == 1, 1, cond(`A5' > 3, 3, 2) ) ///
	if inlist(entity, 250, 370) 
	
#delim;
	
label define agegroup_ICSS_3_3_1

	1   "00-29"
	2   "30-49"
	3   "50-89"
;
#delim cr	

lab val agegroup_ICSS_3_3_1 agegroup_ICSS_3_3_1

if ( "`dev'" == "dev" ) {
	
	table agegroup_ICSS_A agegroup_ICSS_3_3_1, nototal 	
}

* 3. ICSS 3.ii Young adults.

	* 401 Acute lymphatic leukaemias

gen byte agegroup_ICSS_3_3_2  = cond(`A5' == 1, 1, cond(`A5' > 2, 3, 2) ) ///
	if inlist(entity, 401)  
		
#delim;
	
label define agegroup_ICSS_3_3_2

	1   "00-29"
	2   "30-49"
	3   "50-89"
;
#delim cr	

lab val agegroup_ICSS_3_3_2 agegroup_ICSS_3_3_2

if ( "`dev'" == "dev" ) {
	
	table agegroup_ICSS_B agegroup_ICSS_3_3_2, nototal 	
}

gen byte agegroup_ICSS_3 = .
gen str5 agegroup_ICSS_3_str = ""
	
foreach v of varlist agegroup_ICSS_3*1  agegroup_ICSS_3*2 {
	
		replace agegroup_ICSS_3 = `v' if !mi(`v')
		
		tempvar str 
		decode `v' , generate(`str') 
		replace  agegroup_ICSS_3_str = `str' if !mi(`v')
		drop `str'
}

lab var agegroup_ICSS_3_str "assigned agegr (3) from agegr sets"
lab var agegroup_ICSS_3     "assigned agegr (3) from agegr sets"

assert inlist(agegroup_ICSS_3, 1, 2, 3) 
 
********************************************************************************
end	// define_agegr_w_ICCS

}	
{ /* sub nc_s_data_chk_strata */

capt prog drop nc_s_data_chk_strata 
prog define nc_s_data_chk_strata , nclass

syntax ,                 ///
	by(varlist)          ///  
	iweight(varname)     ///
	standstrata(varname) ///  

quietly {
	
* verify : weights sum to on within life-table strata (by)  
 
tempvar chkbrw agegr

bysort `by' `standstrata' : gen `chkbrw' = `iweight' if ( _n == 1 )
by `by' : replace `chkbrw' = sum(`chkbrw')
by `by' : generate byte weight_err = round(`chkbrw'[_N], 0.01) != 1 
drop `chkbrw'

* mark life-table strata (`by') without observations  

assert inrange(`standstrata',1 ,9)
levelsof `standstrata' , local(strata)

generate no_obs_in_strata = ///
	trim(subinstr("`strata'"," ","",.)) if ( weight_err )    

* report agegroup with no observations 
	
by `by' : replace no_obs_in_strata = ///
				subinstr(no_obs_in_strata[_n-1], ///
					strofreal(`standstrata'), " ", . ) ///
						if ( weight_err & _n > 1 ) 
						
by `by' : replace no_obs_in_strata = "" if ( weight_err & _n < _N )   

} // quietly

end  // nc_s_data_chk_strata
}
{ /* sub nc_define_fup  define common file for cohort + period */
    
********************************************************************************
* define common file for cohort + period
********************************************************************************
capt prog drop define nc_define_fup
prog define nc_define_fup , nclass

syntax , result(string) inc_year_last(numlist max=1 integer <= 2022)

su period_5 , meanonly
local year_start_last_5_year_period = r(max) 
assert `inc_year_last' - 4 == r(max)

tempfile cohort
nc_stset
save "`cohort'" , replace

drop if end_of_followup <=  d(1.jan`year_start_last_5_year_period')    // exit before/on enter (zero fup)
keep if year(date_of_incidence) > (`year_start_last_5_year_period' - 11 ) // not relevant for 10 year fup

nc_stset, enter(time d(1.jan`year_start_last_5_year_period'))

replace period_5 = `year_start_last_5_year_period' 
replace spid = "period" + spid
append using "`cohort'"

drop if period_5 == `year_start_last_5_year_period' & ! strpos(spid, "period")

gen fup_def = cond(strpos(spid,"period"), "period", "cohort") 

compress

isid pat entity fup_def
isid spid 
assert _st
 
save "`result'" , replace

end //  nc_define_fup
}
{ /* sub nc_stset */

capt prog drop nc_stset

prog define nc_stset ,  ///
	nclass              ///
	properties("NORDCAN survival definition") 
	
syntax	,  [ enter(string) ]  // OPT left censoring ("period")
	
* args defaults to NC S definitions 	

if "`time'" == ""   local time   = "end_fup"               // "end_of_followup"
if "`fail'"== ""    local fail   = "dead_fup"              // "vit_sta == 2"
if "`origin'"== ""  local origin = "date_of_incidence"
if "`enter'" == ""  local enter  = "date_of_incidence"
if "`scale'" == ""  local scale  = 365.25 
if "`id'"  == ""    local id     = "spid"

********************************************************************************

#delim ;

scalar stsetcmd = 

trim(itrim(ustrregexra(

`"  stset `time' ,
	fail(`fail')       /* failure indicator                         */
	origin(`origin')   /* define when time == 0                     */
	enter(`enter')     /* define time of entry (> 0 left cencoring) */
	scale(`scale')     /* scale (date days since epoche) to years   */
	id(`id')           /* subject pseudo ID variable                */
"' , 
"\/\*.+?\*\/", "" /* strip of comments */ )))
;
#delim cr 

mata: nc_stset_cmd = st_strscalar("stsetcmd")

********************************************************************************
* run stset  
********************************************************************************

mata: stata(nc_stset_cmd)  	 

********************************************************************************
* add meta data
********************************************************************************

if ("`enter'" == "`origin'") {

	char define _dta[NC_stsetcmd_cohort] "`=scalar(stsetcmd)'"
}

else {
	
	char define _dta[NC_stsetcmd_period] "`=scalar(stsetcmd)'"	
}

********************************************************************************
* describe fup data
********************************************************************************
 
stdescribe

********************************************************************************

assert "`: properties nc_stset '" == "NORDCAN survival definition"
 
end // define nc_stset
}
{ /* sub survival_file_analysis */
capt prog drop  survival_file_analysis 
prog define survival_file_analysis 

syntax, ///
	survival_file_analysis(string) ///
	[survival_file_base(string)]  	
	
#delim;

local vars 
	
	spid
	entity 
	date_of_incidence
	date_of_birth
	sex
	age
	period_5  agegroup_ICSS_5 weights_ICSS_5 agegroup_ICSS_5_NOK agegroup_ICSS_5_tot_NOK
	period_10 agegroup_ICSS_3 weights_ICSS_3 agegroup_ICSS_3_NOK agegroup_ICSS_3_tot_NOK
	agegroup_ICSS_5_str
	agegroup_ICSS_3_str
	dead_fup
	end_of_followup
	end_fup    
	dead_fup 
	_st _d _origin _t _t0
	country
;
#delim cr	
	
if 	( "`survival_file_base'" != "" ) {
	
	use `vars' using "`survival_file_base'" , clear 
}

else {
	
	keep `vars'  	
}

********************************************************************************
* saving 10 and 5 year calendar period files
********************************************************************************

local survival_file_analysis = subinstr("`survival_file_analysis'",".dta","",1)

local including "min(30) in group, and min(3) in any agestratum within group."

keep if ( agegroup_ICSS_3_NOK == 0 )  & ( agegroup_ICSS_3_tot_NOK == 0 )
label data "10-year calendar periods. 3-age-groups. `including' "
noi save "`survival_file_analysis'_10.dta" , replace

tempvar only_left_truncated
keep if ( agegroup_ICSS_5_NOK == 0 )  & ( agegroup_ICSS_5_tot_NOK == 0 )
bysort period_5 sex entity (_t0) : gen byte `only_left_truncated' = _t0[1] > 0 
drop if `only_left_truncated'

drop  agegroup_ICSS_3 weights_ICSS_3 period_10 *NOK
label data "5-year calendar periods. 5-age-groups. `including'"
noi save "`survival_file_analysis'_5.dta" , replace

use "`survival_file_analysis'_10.dta" , clear
drop if _t0 > 0  // left truncated pseudo observations
save "`survival_file_analysis'_10.dta" , replace  // last period "complete approach"  

********************************************************************************

end // survival_file_analysis 
} 
{ /* sub define_p5_s10_breast_prostate */

capture prog drop  define_p5_s10_breast_prostate 
prog define define_p5_s10_breast_prostate

syntax , ///
	survival_file_analysis_5(string) ///
	survival_file_analysis_5_10(string)
	
	confirm file `"`survival_file_analysis_5'"'

qui {

use `"`survival_file_analysis_5'"' , clear
	
capture drop __*
keep if inlist(entity, 180, 240) // breast, prostate

tempfile org
isid spid
save "`org'" , replace
qui su period_5, meanonly   
local last_period_5 = r(max)
keep if  period_5 == -10 + `last_period_5'	 // source period
replace period_5 =   -5  + `last_period_5'   // target period
streset, enter(time d(1jan`last_period_5'))  // left truncation
replace spid = spid + "_2005" // ID extra left truncated obs for target period 
assert strpos(spid,"_2005") if _st == 0
keep if _st
append using "`org'" // org data added to extra left truncated obs

noi save `"`survival_file_analysis_5_10'"' , replace

}

end

}
{ /* sub define_p10_s10_breast_prostate */
capture prog drop  define_p10_s10_breast_prostate 
prog define define_p10_s10_breast_prostate

syntax , ///
	survival_file_analysis_10(string) ///
	survival_file_analysis_10_10(string)
	
	confirm file `"`survival_file_analysis_10'"'

qui {

use `"`survival_file_analysis_10'"' , clear
	
capture drop __*
keep if inlist(entity, 180, 240) // breast, prostate

tempfile org
isid spid
save "`org'" , replace
qui su period_10, meanonly   
local last_period_10 = r(max)
keep if  period_10 == -10 + `last_period_10' // source period
replace period_10 = `last_period_10'    
streset, enter(time d(1jan`last_period_10'))  // left truncation
replace spid = spid + "_left_truncated" // ID extra left truncated obs for target period 
keep if _st
append using "`org'" // org data added to extra left truncated obs

noi save `"`survival_file_analysis_10_10'"' , replace

}
end
}
{ /* sub trace_start */

capt prog drop trace_start
prog define trace_start
args fn	
noi di "hello from trace_start"
assert "`fn'" != ""	
log using "`fn'", text replace name(trace)

set trace on
set tracedepth  4 
set tracesep on 
set traceexpand on
set traceindent on
set tracenumber on

c_local quietly

about 

end // trace_start
}
}
exit // anything after this line will be ignored
