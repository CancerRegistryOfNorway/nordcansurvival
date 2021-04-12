capt prog drop extract_define_survival_data
prog define extract_define_survival_data , nclass

syntax , ///
	incidence_data(string) ///
	survival_file_base(string)   /// 
	survival_file_analysis(string)   /// 
	[survival_entities(string)] ///
	[country(string)] 

qui {	
	
clear
find_entity_table_look_up_file, filename(NC_survival_entity_table.dta)		
local survival_entities `r(survival_entities)'	

clean_up_old_files, ///
	back_up_dir_name(oldfiles) ///
	survival_file_base(`survival_file_base') ///
	survival_file_analysis(`survival_file_analysis') 
	
read_incidence_data, incidence_data(`incidence_data')
define_10_year_periods, five_year_period_variable_name(period_5)

su period_5, meanonly
local inc_year_last = r(max) + 4

select_validate_vars, inc_year_last(`inc_year_last')
longform_pat_entitylevel, survival_entities(`survival_entities')

define_agegr_w_ICCS // 5 ICCS agegroups and 3: (1-2), 3, (4-5) 

local noobs 3 // lower limit for n in age stratum
local tot  30 // lower limit for N in group to be analysed

mark_small_n_strata , ///
	idvar(spid) /// 
	groups(entity sex period_5) ///  
	agegr(agegroup_ICSS_5) ///
	nobs(`noobs') ///
	tot(`tot')
	
mark_small_n_strata , ///
	idvar(spid) /// 
	groups(entity sex period_10) ///  
	agegr(agegroup_ICSS_3) ///
	nobs(`noobs') ///
	tot(`tot')
	
assert agegroup_ICSS_5_NOK if  agegroup_ICSS_3_NOK
assert !agegroup_ICSS_3_NOK if !agegroup_ICSS_5_NOK	
	
********************************************************************************
* define fup 
********************************************************************************
generate byte dead_fup = ( vit_sta == 2 & /// 
	year(end_of_followup) <= `inc_year_last')
generate end_fup = min( end_of_followup, d(31.dec.`inc_year_last') )
drop if end_fup == date_of_incidence  
********************************************************************************
order agegroup_ICSS_5 weights_ICSS_5 agegroup_ICSS_5_NOK , last 
order agegroup_ICSS_3 weights_ICSS_3 agegroup_ICSS_3_NOK , last   
order agegroup_ICSS_5_tot_NOK agegroup_ICSS_3_tot_NOK , last
order year , before(period_5)

capture generate country = "`country'"

compress
noi save "`survival_file_base'" , replace

nc_define_fup, result(`survival_file_analysis') inc_year_last(`inc_year_last')  

noi survival_file_analysis, survival_file_analysis(`survival_file_analysis') 

define_p5_s10_breast_prostate, ///
	survival_file_analysis_5(survival_file_analysis_5.dta) /// 
	survival_file_analysis_5_10(survival_file_analysis_5_10.dta)
	
define_p10_s10_breast_prostate, ///
	survival_file_analysis_10(survival_file_analysis_10.dta) /// 
	survival_file_analysis_10_10(survival_file_analysis_10_10.dta)	

} // quietly

end // extract_define_survival_data_p10

********************************************************************************
* define sub programs
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

syntax , ///
	back_up_dir_name(string) ///
	survival_file_base(string) ///
	survival_file_analysis(string) ///
	
capture mkdir `back_up_dir_name'

foreach fn in `survival_file_base' `survival_file_analysis' {
	
	local FN = cond(substr("`fn'", -4, .) == ".dta", "`fn'", "`fn'.dta")   

	capture confirm file `FN'

	if ( _rc == 0 ) {
		
		use in 1 using `FN', clear
		local filedate `c(filedate)' 
		local Mons `c(Mons)'
		local d = word("`filedate'", 1)
		local m : list posof "`=word("`filedate'", 2)'" in Mons  
		local y = word("`filedate'", 3)
		local c = subinstr(word("`filedate'", 4),":", "",.)
		copy `FN' `back_up_dir_name'/`y'`m'`d'`c'`fn' , replace
		erase `FN'
		clear
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

scalar weights_ICSS_2 = " .36 .19 .22 .16 .07 "
assert `=subinstr(trim(itrim(scalar(weights_ICSS_2)))," ","+",.)' == 1

scalar weights_ICSS_2B = " `= .36 + .19' .22 `= .16 + .07' "
assert `=subinstr(trim(itrim(scalar(weights_ICSS_2B)))," ","+",.)' == 1

tokenize `= scalar(weights_ICSS_2) '

generate double weights_ICSS_2 = . 
replace weights_ICSS_2 = `1' if inrange( int(age) , 0 , 49 ) 
replace weights_ICSS_2 = `2' if inrange( int(age) , 50, 59 )
replace weights_ICSS_2 = `3' if inrange( int(age) , 60, 69 )
replace weights_ICSS_2 = `4' if inrange( int(age) , 70, 79 )
replace weights_ICSS_2 = `5' if inrange( int(age) , 80, 89 )

generate double weights_ICSS_2B = . 
replace weights_ICSS_2B = .55 if inrange( int(age) , 0 , 49 ) 
replace weights_ICSS_2B = .55 if inrange( int(age) , 50, 59 )
replace weights_ICSS_2B = .22 if inrange( int(age) , 60, 69 )
replace weights_ICSS_2B = .23 if inrange( int(age) , 70, 79 )
replace weights_ICSS_2B = .23 if inrange( int(age) , 80, 89 )

********************************************************************************
* ICSS 3 Young adults ( ~2.5% of cancers ) 
********************************************************************************

* 3.1 Testis, Hodgkin lymphoma
* 3.2 Acute lymphatic leukaemia
* 3.3 Bone

* 3.1 Testis, Hodgkin lymphoma *************************************************	

scalar weights_ICSS_31 = " .31 .21 .13 .20 .15 "
assert `=subinstr(trim(itrim(scalar(weights_ICSS_31)))," ","+",.)' == 1

scalar weights_ICSS_31B = " `= .31 + .21' .13 `= .20 + .15' "
assert `=subinstr(trim(itrim(scalar(weights_ICSS_31B)))," ","+",.)' == 1

tokenize `= scalar(weights_ICSS_31) '

generate double weights_ICSS_31 = . 
replace weights_ICSS_31 = `1' if inrange(int(age), 0 , 29 ) 
replace weights_ICSS_31 = `2' if inrange(int(age), 30, 39 )
replace weights_ICSS_31 = `3' if inrange(int(age), 40, 49 )
replace weights_ICSS_31 = `4' if inrange(int(age), 50, 69 )
replace weights_ICSS_31 = `5' if inrange(int(age), 70, 89 )

generate double weights_ICSS_31B = . 
replace weights_ICSS_31B = .52 if inrange(int(age), 0 , 29 ) 
replace weights_ICSS_31B = .52 if inrange(int(age), 30, 39 )
replace weights_ICSS_31B = .13 if inrange(int(age), 40, 49 )
replace weights_ICSS_31B = .35 if inrange(int(age), 50, 69 )
replace weights_ICSS_31B = .35 if inrange(int(age), 70, 89 )

* 3.2 Acute lymphatic leukaemia ************************************************

scalar weights_ICSS_32 = " .31 .34 .20 .10 .05 "
assert `=subinstr(trim(itrim(scalar(weights_ICSS_32)))," ","+",.)' == 1

scalar weights_ICSS_32B = " `= .31 + .34' .20 `= .10 + .05' "
assert `=subinstr(trim(itrim(scalar(weights_ICSS_32B)))," ","+",.)' == 1

tokenize `= scalar(weights_ICSS_32) '

generate double weights_ICSS_32 = . 
replace weights_ICSS_32 = `1' if inrange(int(age), 0 , 29 ) 
replace weights_ICSS_32 = `2' if inrange(int(age), 30, 49 )
replace weights_ICSS_32 = `3' if inrange(int(age), 50, 69 )
replace weights_ICSS_32 = `4' if inrange(int(age), 70, 79 ) 
replace weights_ICSS_32 = `5' if inrange(int(age), 80, 89 ) 

generate double weights_ICSS_32B = . 
replace weights_ICSS_32B = .65 if inrange(int(age), 0 , 29 ) 
replace weights_ICSS_32B = .65 if inrange(int(age), 30, 49 )
replace weights_ICSS_32B = .20 if inrange(int(age), 50, 69 )
replace weights_ICSS_32B = .15 if inrange(int(age), 70, 79 ) 
replace weights_ICSS_32B = .15 if inrange(int(age), 80, 89 ) 

* 3.3 Bone **********************************************************************

scalar weights_ICSS_33 = " .07 .13 .16 .41 .23 "
assert  `=subinstr(trim(itrim(scalar(weights_ICSS_33)))," ","+",.)' == 1
scalar weights_ICSS_33B = " `= .07 + .13' .16 `= .41 + .23' "

assert  `=subinstr(trim(itrim(scalar(weights_ICSS_33B)))," ","+",.)' == 1
tokenize `= scalar(weights_ICSS_33) '

generate double weights_ICSS_33 = . 
replace weights_ICSS_33 = `1' if inrange(int(age), 0 , 29 ) 
replace weights_ICSS_33 = `2' if inrange(int(age), 30, 39 )
replace weights_ICSS_33 = `3' if inrange(int(age), 40, 49 )
replace weights_ICSS_33 = `4' if inrange(int(age), 50, 69 )
replace weights_ICSS_33 = `5' if inrange(int(age), 70, 89 ) 

generate double weights_ICSS_33B = . 
replace weights_ICSS_33B = .2  if inrange(int(age), 0 , 29 ) 
replace weights_ICSS_33B = .2  if inrange(int(age), 30, 39 )
replace weights_ICSS_33B = .16 if inrange(int(age), 40, 49 )
replace weights_ICSS_33B = .64 if inrange(int(age), 50, 69 )
replace weights_ICSS_33B = .64 if inrange(int(age), 70, 89 ) 

********************************************************************************

assert !mi(weights_ICSS_1)  // Elderly ( ~87.3% of cancers )
assert !mi(weights_ICSS_2)  // Little age dependency ( ~10.2% of cancers)
assert !mi(weights_ICSS_31) // Testis, Hodgkin lymphoma
assert !mi(weights_ICSS_32) // Acute lymphatic leukaemia
assert !mi(weights_ICSS_33) // Bone

local offset = 3 * uchar(8199) 

lab var weights_ICSS_1	"{ `= scalar(weights_ICSS_1) ' } Elderly ( ~87.3% of cancers )"
lab var weights_ICSS_2  "{ `= scalar(weights_ICSS_2) ' } Little age dependency ( ~10.2% of cancers)" 
lab var weights_ICSS_31 "{ `= scalar(weights_ICSS_31)' } Testis, Hodgkin lymphoma"
lab var weights_ICSS_32 "{ `= scalar(weights_ICSS_32)' } Acute lymphatic leukaemia" 
lab var weights_ICSS_33 "{ `= scalar(weights_ICSS_33)' } Bone "

assert !mi(weights_ICSS_1B)  // Elderly ( ~87.3% of cancers )
assert !mi(weights_ICSS_2B)  // Little age dependency ( ~10.2% of cancers)
assert !mi(weights_ICSS_31B) // Testis, Hodgkin lymphoma
assert !mi(weights_ICSS_32B) // Acute lymphatic leukaemia
assert !mi(weights_ICSS_33B) // Bone

lab var weights_ICSS_1B	 "{ `offset' `= scalar(weights_ICSS_1B) ' `offset' } Elderly ( ~87.3% of cancers )"
lab var weights_ICSS_2B  "{ `offset' `= scalar(weights_ICSS_2B) ' `offset' } Little age dependency ( ~10.2% of cancers)" 
lab var weights_ICSS_31B "{ `offset' `= scalar(weights_ICSS_31B)' `offset' } Testis, Hodgkin lymphoma"
lab var weights_ICSS_32B "{ `offset' `= scalar(weights_ICSS_32B)' `offset' } Acute lymphatic leukaemia" 
lab var weights_ICSS_33B "{ `offset' `= scalar(weights_ICSS_33B)' `offset' } Bone "

********************************************************************************
* make one variable "weights_ICSS" applying weights above
********************************************************************************

generate double weights_ICSS = . 
generate double weights_ICSSB = .

replace weights_ICSS = weights_ICSS_33 if inlist(entity,340)      // Bone
replace weights_ICSS = weights_ICSS_32 if inlist(entity,401)      // AML
replace weights_ICSS = weights_ICSS_31 if inlist(entity,250,370)  // Testis, H-L

replace weights_ICSSB = weights_ICSS_33B if inlist(entity,340)      // Bone
replace weights_ICSSB = weights_ICSS_32B if inlist(entity,401)      // AML
replace weights_ICSSB = weights_ICSS_31B if inlist(entity,250,370)  // Testis, H-L

* Cervix uteri, Melanoma of skin, Brain and CNS , Thyroid, Soft tissues
	
replace weights_ICSS = weights_ICSS_2 if inlist(entity, 190, 290, 320, 330, 350)
replace weights_ICSSB = weights_ICSS_2B if inlist(entity, 190, 290, 320, 330, 350)	
* other than above

replace weights_ICSS = weights_ICSS_1 if mi(weights_ICSS)
replace weights_ICSSB = weights_ICSS_1B if mi(weights_ICSSB)

rename weights_ICSS weights_ICSS_5
rename weights_ICSSB weights_ICSS_3 

assert !mi(weights_ICSS_5)
assert !mi(weights_ICSS_3)

lab var weights_ICSS_5  "assigned (5) weights from weight sets 1, 2, 31, 32, 33"
lab var weights_ICSS_3 "assigned (3) weights from weight sets 1, 2, 31, 32, 33"
	
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
lab var agegroup_ICSS_A "{`= scalar(agegroup_ICSS_A) '}"

* B:  AML ----------------------------------------------------------------------

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
lab var agegroup_ICSS_B "{`= scalar(agegroup_ICSS_B) '}"

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
lab var agegroup_ICSS_C "{`= scalar(agegroup_ICSS_C) '}"

drop agegroup_ICSS_A_str agegroup_ICSS_B_str agegroup_ICSS_C_str 

assert scalar(agegroup_ICSS_A) != scalar(agegroup_ICSS_B) 
assert scalar(agegroup_ICSS_B) != scalar(agegroup_ICSS_C)   

********************************************************************************
* make one variable "weights_ICSS" applying weights above
********************************************************************************
generate int agegroup_ICSS = .

* A:  TESTIS (250) ,  BONE (340)  , HODGKIN LYMPHOMA (370)  -------------------- 
replace agegroup_ICSS = agegroup_ICSS_A if inlist(entity, 250, 340, 370 )

* B:  401	Acute Lymphatic Leukaemias ----------------------------------------- 
replace agegroup_ICSS = agegroup_ICSS_B if inlist(entity, 401 )  

* agegr C:  other than A and B -------------------------------------------------
replace agegroup_ICSS = agegroup_ICSS_C if mi(agegroup_ICSS)

********************************************************************************
local A5 agegroup_ICSS_5
rename agegroup_ICSS `A5'
lab var `A5' "assigned agegr (5) from agegr sets A, B, C"

assert inlist(`A5', 1, 2, 3, 4, 5)
gen int agegroup_ICSS_3 = cond(`A5' < 3, 1, cond(`A5' > 3, 3, 2) )
lab var agegroup_ICSS_3 "assigned agegr (3) from agegr sets A, B, C"
assert inlist(agegroup_ICSS_3 , 1, 2, 3)
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

syntax , result(string) inc_year_last(numlist max=1 integer <= 2019)

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
 
save `result' , replace

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

`"

stset `time' ,

	fail(`fail')       /* failure indicator                         */
	origin(`origin')   /* define when time == 0                     */
	enter(`enter')     /* define time of entry (> 0 left cencoring) */
	scale(`scale')     /* scale (date days since epoche) to years   */
	id(`id')           /* subject pseudo ID variable                */

"' , "\/\*.+?\*\/", "" /* strip of comments */ )))
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

use "`survival_file_analysis'_10" , clear
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
save `org' , replace
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
save `org' , replace
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

exit // anything after this line will be ignored
 