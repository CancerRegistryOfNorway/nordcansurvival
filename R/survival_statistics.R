#' @title survival_statistics
#' @description
#' Provides non-parametric estimate of marginal relative survival, which under assumptions can be 
#' interpreted as marginal net survival. survival_statistics() is calling the Stata stnet program, 
#' using the Pohar Perme estimator with Brenner weighting to estimate age-standardized net survival.
#' 
#' The beta version provides 5-year survival only.
#' 
#' For some entities estimation is not possible because there are no data in some age stratum used
#' for weighting. 
#' 
#' In the beta version there is no lower limit to data, execpt there must be at least one observation 
#' in each strata.
#' 
#'
#' @param infile path to a dataset of cancer records
#' @param lifetable (mandatory, default by NORDCAN system)
#' @param outfile
#' 
#' path where to write result file
#' 
#' @param estimand defaults to "netsurvival" the only option so far
#' @param stata_exe_path This is set in the NORDCAN settings by default
#' 
#' @param by 
#' 
#' names of columns in file `infile` by which to stratify
#' results
#' 
#' @param standstrata
#' 
#' names of columns in file `infile` by which to standardise
#' results
#' 
#' @param iweight
#' 
#' name of weight column in file `infile`
#' 
#' @return survival analysis output in csv and dta format.
#' @examples 
#' 
#' 
#' library(nordcansurvival)
#' infile <-  paste0(system.file(package = "nordcansurvival"), 
#'                   "/Stata/demo/NCS_NO_anonymous_example_data.dta")
#' lifetable <- paste0(system.file(package = "nordcansurvival"), 
#'                     "/Stata/demo/NO_2018_lifetable.dta")
#' 
#' 
#' nordcancore::set_global_nordcan_settings(
#'   work_dir = getwd(),
#'   participant_name = "Norway",
#'   first_year_incidence = 1953L,
#'   first_year_mortality = 1953L,
#'   first_year_region = 1953L,
#'   last_year_incidence = 2018L,
#'   last_year_mortality = 2018L,
#'   last_year_survival = 2018L
#' )
#'
#'
#'survival_statistics(infile  = infile , 
#'                    lifetable = lifetable, 
#'                    stata_exe_path = "S:/Prog64/STATA/Stata16MP/StataMP-64.exe")
#'
#'
#' @export
#' @return
#'
survival_statistics <- function(
  stata_exe_path = NULL,
  infile,
  lifetable,
  outfile = "survival_statistics",
  estimand = "netsurvival",
  by = c("entity", "sex", "period_5"),
  standstrata = "agegroup_ICSS_5",
  iweight = "weights_ICSS_5"
) {
  dbc::assert_prod_input_file_exists(infile)
  dbc::assert_prod_input_file_exists(lifetable)

  dbc::assert_is_character_nonNA_vector(by)
  dbc::assert_is_character_nonNA_atom(standstrata)
  dbc::assert_is_character_nonNA_atom(iweight)
  
  ## make template for Stata commad file
  dofile_template <-
    "
    cd \"%s\"                // set current working directory
    adopath ++ \"%s\"        // add path to Stata programs
    adopath ++ \"%s/utils\"  // add path to Stata programs
    adopath ++ \"%s/1\"      // add path to Stata programs
    adopath ++ \"%s/2\"      // add path to Stata programs
    adopath ++ \"%s\"    // survival entities look-up file
    
    stata_code_head, function(survival_statistics)

    survival_statistics ,	  /// Stata cmd defined in survival_statistics.ado
    	infile(\"%s\") 		        /// NC S dataset (dta)
    	outfile(\"%s\") 	        /// detailed ressults (dta)
    	lifetable(\"%s\") 	      /// National lifetable file (dta)
    	estimand(%s)          /// What to estimate
    	country(\"%s\")       ///
    	by(%s)                 ///
      standstrata(%s)     ///  
      iweight(%s)  

    stata_code_tail, function(survival_statistics)  // cleaning up etc

    "

  settings <- nordcan_survival_settings(
    stata_exe_path = stata_exe_path
  )
  

  if (!file.exists(infile)) {
    stop(sprintf("Can not find 'infile': %s !", 
                 infile))
  }
  if (!file.exists(lifetable)) {
    stop(sprintf("Can not find 'lifetable': %s !", 
                 lifetable))
  }
  
  survival_work_dir <- settings[["survival_work_dir"]]
  ## build do file based on 'dofile_template';
  ado_dir <- settings[["ado_dir"]]
  dofile_contents <- sprintf( 
    dofile_template,
    survival_work_dir,
    ado_dir, ado_dir, ado_dir, ado_dir,
    settings[["entity_table_dir"]],
    infile,
    outfile,
    lifetable,
    estimand, 
    nordcancore::get_global_nordcan_settings()$participant_name,
    paste0(by, collapse = " "),
    standstrata,
    iweight
  )
  
  ## save the  do file
  dofile_name <- paste0(survival_work_dir, "/survival_statistics.do")
  cat(dofile_contents, file = dofile_name)
  
  ## Run command
  call_stata_script(
    stata_exe_path = settings[["stata_exe_path"]], 
    stata_script_path = dofile_name
  )
}




