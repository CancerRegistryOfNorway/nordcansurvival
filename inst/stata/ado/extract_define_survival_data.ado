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

********************************************************************************
* find entity table look-up file (NC_survival_entity_table.dta)
********************************************************************************

findfile NC_survival_entity_table.dta
local survival_entities `r(fn)'
confirm file "`survival_entities'"

********************************************************************************
* clean up old files
********************************************************************************

local bkdir oldfiles
capture mkdir `bkdir'

foreach fn in `survival_file_base' `survival_file_analysis' {
	
	local FN = "`fn'.dta"

	capture confirm file `FN'

	if ( _rc == 0 ) {
		
		use in 1 using `FN', clear
		local filedate `c(filedate)' 
		local Mons `c(Mons)'
		local d = word("`filedate'", 1)
		local m : list posof "`=word("`filedate'", 2)'" in Mons  
		local y = word("`filedate'", 3)
		local c = subinstr(word("`filedate'", 4),":", "",.)
		copy `FN' `bkdir'/`y'`m'`d'`c'`fn' , replace
		erase `FN'
	}
}

********************************************************************************
* read NC incidence data
********************************************************************************

if ( strlower(substr("`incidence_data'",-4,.)) == ".csv" ) {
	
	import delimited using "`incidence_data'" , ///
		varnames(1)       /// 
		encoding("UTF-8") ///
	    delimiter(";")    ///
		case(preserve)    ///
		asdouble
		
		local strdates varlist date_of_birth  date_of_incidence end_of_followup 
		
		foreach var of `strdates' {
		    
			rename `var' str_`var'
			gen long `var'= date(str_`var', "YMD") , before(str_`var')   	
			format `var' %td
			drop str_`var'	
		}
}

else {	
	
	use "`incidence_data'"  
}

compress

********************************************************************************
* define macros etc.
********************************************************************************

local inc_year_last = 2018  // TO BE AUTOMATED 


********************************************************************************
* delete variables NOT used for survival analysis 
********************************************************************************


#delim ; 

keep 

	pat                /* Patient idenfification code */
	tum                /* Tumor identification code */ 
	tum_sequence       /* Sequence of tumors for each person */ 
	
	date_of_incidence  /* Date of incidence */ 
	period             
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
	
	excl_imp_total
	excl_surv_total
;
#delim cr                                           


********************************************************************************
* EXCLUTIONS
********************************************************************************

drop if excl_imp_total
drop if excl_surv_total 
drop if entity_level_30 == 999   // Not included in NORDCAN
assert  entity_level_30 != 888   // should NOT exist

drop excl_*  // drop all exclution indicators

********************************************************************************
* some QA
********************************************************************************

* confirm structure of data 

isid tum              // ONE ROW PER Tumor identification code
isid pat tum_sequence // ONE ROW PER patient id  X tum sequence number 

********************************************************************************


********************************************************************************
* confirm existance of variables
********************************************************************************

confirm variable pat 
confirm variable tum 
confirm variable tum_sequence

confirm variable date_of_birth 
confirm variable date_of_incidence
confirm variable vit_sta 
confirm variable end_of_followup
 
********************************************************************************

qui su date_of_incidence , meanonly 
assert year(r(max)) == `inc_year_last'

assert age == int(age)
assert inrange(age, 0, 89)      // inlist(agr_all_sites, 1, 2, 3, 4, 5)
_recast byte age                // max byte==100 TECHNICAL COMMENT IGNORE

noi assert date_of_birth < end_of_followup
noi assert inlist(sex, 1, 2)  // NB life-table {0,1} 
noi assert inlist(vit_sta, 1, 2, 3)  // NB QA (problem with Island?)

********************************************************************************
*  NB CORRECT: end_of_followup MAY BE > 2018

generate byte dead_fup = ( vit_sta == 2 & year(end_of_followup) <= `inc_year_last' ) 
generate end_fup = min( end_of_followup, d(31.dec.`inc_year_last') )
drop if end_fup == date_of_incidence // 31.dec.2018

********************************************************************************
* QA 
********************************************************************************

* assert !mi(entity_level_30)

********************************************************************************
* expand data to long form:
*    from: ONE ROW PER "Tumor identification code" 
*      to: ONE ROW PER "Tumor identification code" X  "entity_level"
********************************************************************************

isid pat tum
rename (entity_level_*)(entity*)
reshape long entity , i( pat tum ) j(entity_levels)  
drop if mi(entity)

qui su pat , meanonly 
list pat tum entity entity_levels if inlist(pat,r(min),r(max)) , ///
	sepby(pat) noobs abbr(20) 

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
local surv_entities_vars  = 	
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
	keepusing(`surv_entities_vars') ///
	/// assert(master match)
	
********************************************************************************
* assert entity_levels == 30 if _merge == 1
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

qui nc_s_define_agegr_w_ICCS

qui nc_s_data_chk_strata ,   		///
		by(entity period sex)		///  
		iweight(weights_ICSS)       ///
		standstrata(agegroup_ICSS) 	
		
confirm variable weight_err 
confirm variable no_obs_in_strata

compress
sort entity pat	

capt generate country = "`country'"

noi save "`survival_file_base'" , replace

nc_define_fup , result(`survival_file_analysis') 

survival_file_analysis , survival_file_analysis(`survival_file_analysis') 	

} // quietly

end

********************************************************************************
* define sub routines
********************************************************************************

prog define nc_s_define_agegr_w_ICCS , nclass 

********************************************************************************
* defining agegroups (A, B, C) and weigths ( 1, 2, 3.1, 3.2, 3.3)
********************************************************************************

********************************************************************************
* agegroup weigths 1, 2, 3.1, 3.2, 3.3
********************************************************************************

********************************************************************************
* ICSS 1 Elderly ( ~87.3% of cancers )
********************************************************************************

scalar weights_ICSS_1 = " .12 .17 .27 .29 .15 "
tokenize `= scalar(weights_ICSS_1) '

generate float weights_ICSS_1 = . 
replace weights_ICSS_1 = `1' if inrange( int(age) , 0 , 49 ) 
replace weights_ICSS_1 = `2' if inrange( int(age) , 50, 59 )
replace weights_ICSS_1 = `3' if inrange( int(age) , 60, 69 )
replace weights_ICSS_1 = `4' if inrange( int(age) , 70, 79 )
replace weights_ICSS_1 = `5' if inrange( int(age) , 80, 89 )

********************************************************************************
* ICSS 2 Little age dependency ( ~10.2% of cancers)
********************************************************************************

scalar weights_ICSS_2 = " .36 .19 .22 .16 .07 "
tokenize `= scalar(weights_ICSS_2) '

generate float weights_ICSS_2 = . 
replace weights_ICSS_2 = `1' if inrange( int(age) , 0 , 49 ) 
replace weights_ICSS_2 = `2' if inrange( int(age) , 50, 59 )
replace weights_ICSS_2 = `3' if inrange( int(age) , 60, 69 )
replace weights_ICSS_2 = `4' if inrange( int(age) , 70, 79 )
replace weights_ICSS_2 = `5' if inrange( int(age) , 80, 89 )

********************************************************************************
* ICSS 3 Young adults ( ~2.5% of cancers ) 
********************************************************************************

* 3.1 Testis, Hodgkin lymphoma
* 3.2 Acute lymphatic leukaemia
* 3.3 Bone

* 3.1 Testis, Hodgkin lymphoma	

scalar weights_ICSS_31 = " .31 .21 .13 .20 .15 "
tokenize `= scalar(weights_ICSS_31) '

generate float weights_ICSS_31 = . 
replace weights_ICSS_31 = `1' if inrange(int(age), 0 , 29 ) 
replace weights_ICSS_31 = `2' if inrange(int(age), 30, 39 )
replace weights_ICSS_31 = `3' if inrange(int(age), 40, 49 )
replace weights_ICSS_31 = `4' if inrange(int(age), 50, 69 )
replace weights_ICSS_31 = `5' if inrange(int(age), 70, 89 )

* 3.2 Acute lymphatic leukaemia

scalar weights_ICSS_32 = " .31 .34 .20 .10 .05 "
tokenize `= scalar(weights_ICSS_32) '

generate float weights_ICSS_32 = . 
replace weights_ICSS_32 = `1' if inrange(int(age), 0 , 29 ) 
replace weights_ICSS_32 = `2' if inrange(int(age), 30, 49 )
replace weights_ICSS_32 = `3' if inrange(int(age), 50, 69 )
replace weights_ICSS_32 = `4' if inrange(int(age), 70, 79 ) 
replace weights_ICSS_32 = `5' if inrange(int(age), 80, 89 ) 

* 3.3 Bone

scalar weights_ICSS_33 = " .07 .13 .16 .41 .23 "
tokenize `= scalar(weights_ICSS_33) '

generate float weights_ICSS_33 = . 
replace weights_ICSS_33 = `1' if inrange(int(age), 0 , 29 ) 
replace weights_ICSS_33 = `2' if inrange(int(age), 30, 39 )
replace weights_ICSS_33 = `3' if inrange(int(age), 40, 49 )
replace weights_ICSS_33 = `4' if inrange(int(age), 50, 69 )
replace weights_ICSS_33 = `5' if inrange(int(age), 70, 89 ) 

********************************************************************************

assert !mi(weights_ICSS_1)  // Elderly ( ~87.3% of cancers )
assert !mi(weights_ICSS_2)  // Little age dependency ( ~10.2% of cancers)
assert !mi(weights_ICSS_31) // Testis, Hodgkin lymphoma
assert !mi(weights_ICSS_32) // Acute lymphatic leukaemia
assert !mi(weights_ICSS_33) // Bone

lab var weights_ICSS_1	"{ `= scalar(weights_ICSS_1) ' } Elderly ( ~87.3% of cancers )"
lab var weights_ICSS_2  "{ `= scalar(weights_ICSS_2) ' } Little age dependency ( ~10.2% of cancers)" 
lab var weights_ICSS_31 "{ `= scalar(weights_ICSS_31)' } Testis, Hodgkin lymphoma"
lab var weights_ICSS_32 "{ `= scalar(weights_ICSS_32)' } Acute lymphatic leukaemia" 
lab var weights_ICSS_33 "{ `= scalar(weights_ICSS_33)' } Bone "

********************************************************************************
* make one variable "weights_ICSS" applying weights above
********************************************************************************

generate float weights_ICSS = . 

replace weights_ICSS = weights_ICSS_33 if inlist(entity,340)      // Bone
replace weights_ICSS = weights_ICSS_32 if inlist(entity,401)      // AML
replace weights_ICSS = weights_ICSS_31 if inlist(entity,250,370)  // Testis, H-L

* Cervix uteri, Melanoma of skin, Brain and CNS , Thyroid, Soft tissues
	
replace weights_ICSS = weights_ICSS_2 if inlist(entity, 190, 290, 320, 330, 350)
	
* other than above

replace weights_ICSS = weights_ICSS_1 if mi(weights_ICSS)

assert !mi(weights_ICSS)

lab var weights_ICSS  "assigned weights from weight sets 1, 2, 31, 32, 33"
	
********************************************************************************
* define 3 agegroups for weighting:  
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
generate agegroup_ICSS = .

* A:  TESTIS (250) ,  BONE (340)  , HODGKIN LYMPHOMA (370)  -------------------- 

replace agegroup_ICSS = agegroup_ICSS_A if inlist(entity, 250, 340, 370 )

* B:  401	Acute Lymphatic Leukaemias ----------------------------------------- 

replace agegroup_ICSS = agegroup_ICSS_B if inlist(entity, 401 )  

* agegr C:  other than A and B -------------------------------------------------

replace agegroup_ICSS = agegroup_ICSS_C if mi(agegroup_ICSS)

assert inlist(agegroup_ICSS, 1, 2, 3, 4, 5)

lab var agegroup_ICSS " assigned agegr from agegr sets A, B, C"

********************************************************************************

end

********************************************************************************

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

********************************************************************************
* define common file for cohort + period
********************************************************************************

prog define nc_define_fup , nclass

syntax , result(string)  

tempfile cohort

nc_stset

save "`cohort'" , replace

drop if end_of_followup <=  d(1.jan2014)    // exit before/on enter (zero fup)
keep if year(date_of_incidence) > 2003      // not relevant for 10 year fup

nc_stset, enter(time d(1.jan2014))

replace period = 2014 

replace spid = "period" + spid

append using "`cohort'"

drop if period == 2014 & ! strpos(spid, "period")

gen fup_def = cond(strpos(spid,"period"), "period", "cohort") 

compress

isid pat entity fup_def
isid spid 
assert _st
 
save `result' , replace

end

********************************************************************************
********************************************************************************

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

********************************************************************************

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
	period
	dead_fup
	end_of_followup
	weights_ICSS
	agegroup_ICSS
	
	end_fup    
	dead_fup  
	
	_st
	_d       
	_origin  
	_t       
	_t0
	
	weight_err
	
	country
;
#delim cr	
	
if 	( "`survival_file_base'" != "" ) {
	
	use `vars' using "`survival_file_base'" , clear 
}

else {
	
	keep `vars'  	
}

keep if ( weight_err == 0 )
drop weight_err 
compress
noi save "`survival_file_analysis'" , replace

end

********************************************************************************

exit // anything after this line will be ignored

********************************************************************************
********************************************************************************

ad-hoc testing: 

assert "`: properties nc_stset '" == "NORDCAN survival definition"
********************************************************************************

exit // anything after this line will be ignored

********************************************************************************
********************************************************************************


 

