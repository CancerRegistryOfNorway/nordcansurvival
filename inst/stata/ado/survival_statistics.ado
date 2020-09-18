prog define survival_statistics , rclass

syntax ,			   ///
    [estimand(string)] /// what to estimate
	infile(string) 	   /// NC S dataset (dta)
	outfile(string)    /// detailed ressults (dta)
	lifetable(string)  /// National lifetable file (dta)
	survival_entities(string)

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
	
	mata : st_local("lifetable", pathrmsuffix("`lifetable'"))
	
	save "`lifetable'" , replace
}

********************************************************************************

if ("`estimand'" == "netsurvival") {

	net_survival ,			   			   ///
		infile("`infile'") 	               /// NC S dataset (dta)
		outfile("`outfile'")               /// detailed ressults (dta)
		lifetable("`lifetable'")           ///  National lifetable file (dta)*/
		survival_entities("`survival_entities'")
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
	survival_entities(string)
	
********************************************************************************

use entity using "`infile'" , clear
qui fre entity , all descending
local entities = r(lab_valid)

tempname tmp
capt mkdir `tmp'

local c = 0

qui foreach entity of local entities {

	local c = `c' + 1

	use "`infile'" , clear

	keep if entity == `entity'

	nc_stnet , ///
		lifetable(`lifetable') ///
		outfile("`tmp'/entity_`entity'")

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
rmdir `tmp'

********************************************************************************

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
	*confirm variable weight_err
	*assert inlist(weight_err,0,1)
	*keep if weight_err == 0
}

#delim ;

scalar stnetcmd = 

trim(itrim(

`"

stnet using "`lifetable'" `iweight_arg'   , 
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
*nc_outfile_add_meta_data, outfile(`outfile')

end // nc_stnet

}

{ // nc_rs_format_export VERY PRELIMINARY without formating etc

prog define nc_rs_format_export , nclass

syntax , outfile(string) ///
	survival_entities(string) 

use "`outfile'" if end == 5 , clear

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


 


