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
#' @param cancer_record_dataset_path path to a dataset of cancer records
#' @param national_population_life_table_path (mandatory, default by NORDCAN system)
#' @param estimand defaults to "netsurvival" the only option so far
#' @param stata_exe_path This is set in the NORDCAN settings by default
#' 
#' @examples 
#' 
#' 
#' library(nordcansurvival)
#' infile <-  paste0(system.file(package = "nordcansurvival"), "/Stata/demo/NCS_NO_anonymous_example_data.dta")
#' lifetable <- paste0(system.file(package = "nordcansurvival"), "/Stata/demo/NO_2018_lifetable.dta")


#' nordcancore::set_global_nordcan_settings(
#'   work_dir = getwd(),
#'   participant_name = "Finland",
#'   stat_cancer_record_count_first_year = 1953L,
#'   stat_prevalent_subject_count_first_year = 1953L,
#'   stat_survival_follow_up_first_year = 1953L,
#'   stat_cancer_death_count_first_year = 1953L
#' )
#'
#'
#'survival_statistics(cancer_record_dataset_path  = infile , 
#'                    national_population_life_table_path = lifetable, 
#'                    stata_exe_path = "S:/Prog64/STATA/Stata16MP/StataMP-64.exe")
#'
#'
#' @export
#' @return
#'
survival_statistics <- function(
  stata_exe_path = NULL,
  cancer_record_dataset_path,
  national_population_life_table_path,
  estimand = "netsurvival"
) {
  dbc::assert_prod_input_file_exists(cancer_record_dataset_path)
  dbc::assert_prod_input_file_exists(national_population_life_table_path)

  ## make template for Stata commad file
  dofile_template <-
    "
    cd %s                // set current working directory
    adopath ++ %s        // add path to Stata programs
    adopath ++ %s/utils  // add path to Stata programs
    adopath ++ %s/1      // add path to Stata programs
    adopath ++ %s/2      // add path to Stata programs

    stata_code_head, function(survival_statistics)

    survival_statistics ,	  /// Stata cmd defined in survival_statistics.ado
    	infile(%s) 		        /// NC S dataset (dta)
    	outfile(%s) 	        /// detailed ressults (dta)
    	lifetable(%s) 	      /// National lifetable file (dta)
    	estimand(%s)          /// What to estimate
    	survival_entities(%s)

    stata_code_tail, function(survival_statistics)  // cleaning up etc

    "

  settings <- nordcan_survival_settings(
    stata_exe_path = stata_exe_path
  )
  

  if (!file.exists(cancer_record_dataset_path)) {
    stop(sprintf("Can not find 'cancer_record_dataset_path': %s !", 
                 cancer_record_dataset_path))
  }
  if (!file.exists(national_population_life_table_path)) {
    stop(sprintf("Can not find 'national_population_life_table_path': %s !", 
                 national_population_life_table_path))
  }
  
  output_file_path <- settings[["survival_output_file_path"]]
  survival_work_dir <- settings[["survival_work_dir"]]
  ## build do file based on 'dofile_template';
  ado_dir <- settings[["ado_dir"]]
  dofile_contents <- sprintf( dofile_template,
                              survival_work_dir,
                              ado_dir, ado_dir, ado_dir, ado_dir,
                              cancer_record_dataset_path,
                              output_file_path,
                              national_population_life_table_path,
                              estimand, 
                              settings[["entity_df_path"]]
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




