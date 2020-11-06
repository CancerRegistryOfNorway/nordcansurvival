prog define survival_statistics , rclass

syntax ,			   ///
    [estimand(string)] /// what to estimate
	infile(string) 	   /// NC S dataset (dta)
	outfile(string)    /// detailed ressults (dta)
	lifetable(string)  /// National lifetable file (dta)
	[survival_entities(string)] ///
	[country(string)] 

********************************************************************************

findfile NC_survival_entity_table.dta
local survival_entities `r(fn)'
confirm file "`survival_entities'"
 
********************************************************************************

mata : st_local("infilename", pathbasename("`infile'"))

if ( "`infilename'" == "NCS_NO_anonymous_example_data.dta" ) {
	
	local outfile = "NCS_NO_anonymous_example_data_result"
	local dir NCS_NO_anonymous_example_data_result_dir
	capture mkdir `dir'
	local outfile = "`dir'\NCS_NO_anonymous_example_data_result"
	local country = "NO"
}

********************************************************************************

if ( "`estimand'" == "" ) {

	local estimand = "netsurvival"
}

if ( strlower(substr("`lifetable'",-4,.)) != ".dta" ) {
	
	import delimited using "`lifetable'" , ///
		varnames(1)       /// 
		encoding("UTF-8") ///
	    delimiter(";")    ///
		case(preserve)    ///
		asdouble
		
	capture rename age _age
	capture rename year _year
	
	sort  _year  sex  _age
	
	mata : st_local("stub", pathrmsuffix("`lifetable'"))
	
	save "`stub'" , replace
	confirm file "`stub'.dta" 
	local lifetable = "`stub'.dta" 
}

 
********************************************************************************

if ("`estimand'" == "netsurvival") {

	net_survival ,			   ///
		infile("`infile'") 	               /// NC S dataset (dta)
		outfile("`outfile'")               /// detailed ressults (dta)
		lifetable("`lifetable'")           ///  National lifetable file (dta)*/
		survival_entities("`survival_entities'") ///
		country("`country'")
}

end

********************************************************************************
{ // * define sub net_survial
********************************************************************************

capt prog drop net_survial

prog define net_survival  , rclass

syntax ,			   ///
	infile(string) 	   /// NC S dataset (dta)
	outfile(string)    /// detailed ressults (dta)
	lifetable(string)  /// National lifetable file (dta)*/
	survival_entities(string) ///
	[country(string)]
	
********************************************************************************

use entity using "`infile'" , clear
qui fre entity , all descending
local entities = r(lab_valid)

tempname tmp
capture rmdir "`tmp'" 
capt mkdir "`tmp'"

local c = 0

qui foreach entity of local entities {

	local c = `c' + 1

	use "`infile'" , clear

	keep if entity == `entity'

	noi di "stnet running for entity: `entity'"
	
	capture noi nc_stnet , ///
		lifetable("`lifetable'") ///
		outfile("`tmp'/entity_`entity'")
		
	if ( _rc ) {
	
		noi di  as err "stnet failed for entity: `entity'"
	}	
	
	noi di "stnet finished for entity: `entity'"
	
	clear
	mata : mata clear
}

********************************************************************************

cd `tmp'

local files : dir . files "entity_*"

foreach file of local files {
	append using `file'
	rm `file'
}

cd ..
rmdir "`tmp'"

********************************************************************************

generate country = "`country'"

save "`outfile'" , replace

describe using "`outfile'"

nc_rs_format_export , ///
	outfile("`outfile'") ///
	survival_entities("`survival_entities'")

********************************************************************************

end
}

{ // sub nc_stnet

prog define nc_stnet , sclass

syntax , ///
	lifetable(string) /// REQUIRED name of lifetable file
	outfile(string) /// REQUIRED name of outfile 
	[iweight(varname)] /// OPTIONAL weights age std variable name
	[standstrata(varname)] /// OPTIONAL age std strata variable name
	[brenner]  /// OPTIONAL Brenner weighting
	
**********************************************************************

if "`by'" == ""           local by = "entity sex period"
if "`breaks'" == ""       local breaks = "0(`=1/12')5"
if "`birthdate'" == ""    local birthdate = "date_of_birth"
if "`diagdate'" == ""  	  local diagdate = "date_of_incidence"
if "`mergeby'" == ""      local mergeby = "_year sex _age"
if "`survprob'" == ""     local survprob = "prob"

**********************************************************************

confirm file `"`lifetable'"'

local lifetable = subinstr(`"`lifetable'"', ".dta", "", 1 )

if "`brenner'" == ""      local brenner = "brenner"

if "`iweight'" == "" {
	
	local iweight = "weights_ICSS"
	local iweight_arg = " [ iweight = `iweight' ] "
}

if "`standstrata'" == "" {
	
	local standstrata = "agegroup_ICSS"
	local standstrata_arg = " standstrata(`standstrata')"
}

if ( "`brenner'" == "brenner" ) {
	
	confirm variable `iweight'
	confirm variable `standstrata'
}

#delim ;

scalar stnetcmd = 

trim(itrim(

`"

capture stnet using "`lifetable'" `iweight_arg'   , 
	`standstrata_arg' 
	`brenner'						    						
	by(`by')                             
	breaks(`breaks')                     
	birthdate(`birthdate')              
	diagdate(`diagdate')                
	mergeby(`mergeby')                   
	survprob(`prob')                     
	saving(`outfile', replace)          
	notab  
	
"'
))
;
#delim cr

mata: nc_stnet_cmd = st_strscalar("stnetcmd")
mata: stata(nc_stnet_cmd) // run stnet 

if (_rc) {
	
	local rc = _rc
	error `rc'
}


end // nc_stnet

}

{ // nc_rs_format_export VERY PRELIMINARY without formating etc

prog define nc_rs_format_export , nclass

syntax , outfile(string) ///
	survival_entities(string) 

use if inlist(end, 1 , 5 ) using "`outfile'" , clear

********************************************************************************
* merge NC S data with NC S definitions
********************************************************************************
local surv_entities_vars entity entity_description_en  entity_display_order
merge m:1 entity using "`survival_entities'", ///
keepusing(`surv_entities_vars') ///
keep(master match) 
capt drop _merge
capt drop start n d dstarpoh ypoh dpoh dpohsq secns

order entity entity_description_en entity_display_order
sort entity_display_order period sex

/*
cns   double  %6.4f  Cumulative net survival (Pohar Perme et al)
secns double  %6.4f  Standard error of CNS (Pohar Perme et al)
locns double  %6.4f  Lower 95% CI for CNS (Pohar Perme et al)
upcns double  %6.4f  Upper 95% CI for CNS (Pohar Perme et al)
*/

foreach v of varlist cns locns upcns {
	
	replace `v' = 100 * `v'
}

* TODO:
*
* 	convert to percent
* 	select observarions and variables
* 	rename variables
* 	add display format

local outfile = subinstr("`outfile'", ".dta", ".csv", 1 )

export delimited using "`outfile'" , /// std encoding UTF-8
	delimiter(";") ///
	replace

end  // nc_rs_format_export

}

exit
