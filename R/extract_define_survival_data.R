
#' @title extract_define_survival_data
#' @description
#' 
#' Run a Stata script on a dataset saved on-disk to prepare datasets for analysis 
#' for computing survival.
#' 
#' survival_file_base.dta  includes all potential records, all relevant variables including strings
#' 
#' survival_file_analysis.dta includes a minimum of variables used for estimation and only observations
#' for entities were data exists in all strata used for weighting
#' 
#' the dta files can be read in R using the optional haven package
#' 
#' 
#' @param cancer_record_dataset_path `[character]` (mandatory, no default) path 
#'     to a dataset of cancer records
#' @param stata_exe_path This is set in the NORDCAN settings by default
#' 
#' @param survival_test_sample Logical, if set to TRUE, the function will extract
#'     only a sample of the input cancer record dataset, which contains  
#'     10 percent of Breast, Prostate and colorectal cancers start from 2001. 
#' 
#' @param survival_trace Logical, if set to TRUE, run Stata in debug mode. 
#' 
#' @export
#' 
#' @return It will generate four dta files for further survival analysis: 
#'   \itemize{
#'     \item \emph{survival_file_analysis_survivaltime_05_period_05.dta}
#'     \item \emph{survival_file_analysis_survivaltime_05_period_10.dta}
#'     \item \emph{survival_file_analysis_survivaltime_10_period_05.dta}
#'     \item \emph{survival_file_analysis_survivaltime_10_period_10.dta}
#'   }
#'    add additional files: 
#'   \itemize{
#'     \item \emph{survival_file_base.dta }
#'     \item \emph{survival_file_analysis.dta}
#'    }
#' 
#' Detailed documentation is available at \url{https://github.com/CancerRegistryOf Norway/NORDCAN/wiki/nordcansurvival}
#' 
#' 
extract_define_survival_data <- function(
  cancer_record_dataset_path, 
  stata_exe_path = NULL,
  survival_test_sample, 
  survival_trace = FALSE
) {
  dbc::assert_prod_input_file_exists(
    cancer_record_dataset_path
  )
  settings <- nordcan_survival_settings(
    stata_exe_path = stata_exe_path
  )
  
  ## make template for Stata command file
  
  if (survival_trace) {
    if (survival_test_sample) {
      dofile_template <-
        "
      cd \"%s\"                // set current working directory
      adopath ++ \"%s\"        // add path to Stata programs
      adopath ++ \"%s/utils\"  // add path to Stata programs
      adopath ++ \"%s/1\"      // add path to Stata programs
      adopath ++ \"%s/2\"      // add path to Stata programs
      adopath ++ \"%s\"        // survival entities look-up file
      
      stata_code_head, function(extract_define_survival_data)
      
      extract_define_survival_data ,   ///
      	incidence_data(\"%s\")         ///
      	survival_file_base(\"%s\")     /// 
      	survival_file_analysis(\"%s\") /// 
      	country(\"%s\")                ///
      	trace                          ///
      	10PCsampleBreastProstateCRCfrom_2001
	
    "
    } else {
      dofile_template <-
        "
      cd \"%s\"                // set current working directory
      adopath ++ \"%s\"        // add path to Stata programs
      adopath ++ \"%s/utils\"  // add path to Stata programs
      adopath ++ \"%s/1\"      // add path to Stata programs
      adopath ++ \"%s/2\"      // add path to Stata programs
      adopath ++ \"%s\"        // survival entities look-up file
      
      stata_code_head, function(extract_define_survival_data)
      
      extract_define_survival_data ,   ///
      	incidence_data(\"%s\")         ///
      	survival_file_base(\"%s\")     /// 
      	survival_file_analysis(\"%s\") /// 
      	country(\"%s\")                ///
      	trace                          
	
    "
    }
  } else {
    if (survival_test_sample) {
      dofile_template <-
        "
      cd \"%s\"                // set current working directory
      adopath ++ \"%s\"        // add path to Stata programs
      adopath ++ \"%s/utils\"  // add path to Stata programs
      adopath ++ \"%s/1\"      // add path to Stata programs
      adopath ++ \"%s/2\"      // add path to Stata programs
      adopath ++ \"%s\"        // survival entities look-up file
      
      stata_code_head, function(extract_define_survival_data)
      
      extract_define_survival_data ,   ///
      	incidence_data(\"%s\")         ///
      	survival_file_base(\"%s\")     /// 
      	survival_file_analysis(\"%s\") /// 
      	country(\"%s\")                ///
      	10PCsampleBreastProstateCRCfrom_2001
	
    "
    } else {
      dofile_template <-
        "
      cd \"%s\"                // set current working directory
      adopath ++ \"%s\"        // add path to Stata programs
      adopath ++ \"%s/utils\"  // add path to Stata programs
      adopath ++ \"%s/1\"      // add path to Stata programs
      adopath ++ \"%s/2\"      // add path to Stata programs
      adopath ++ \"%s\"        // survival entities look-up file
      
      stata_code_head, function(extract_define_survival_data)
      
      extract_define_survival_data ,   ///
      	incidence_data(\"%s\")         ///
      	survival_file_base(\"%s\")     /// 
      	survival_file_analysis(\"%s\") /// 
      	country(\"%s\")               
	
    "
    }
  }

  
  
  
  
  entity_df_path <- settings[["entity_df_path"]]
  
  ado_dir <- settings[["ado_dir"]]
  
  survival_file_base <- settings[["survival_file_base_path"]]
  survival_file_analysis <- settings[["survival_file_analysis_path"]]
  ## build do file based on 'dofile_template';
  dofile_contents <- sprintf( dofile_template,
                              settings[["survival_work_dir"]],
                              ado_dir,ado_dir,ado_dir,ado_dir,
                              settings[["entity_table_dir"]],
                              cancer_record_dataset_path,
                              survival_file_base,
                              survival_file_analysis,
                              nordcancore::get_global_nordcan_settings()$participant_name
  )
  
  ## save the  do file
  dofile_name <- paste0(
    settings[["survival_work_dir"]], "/extract_define_survival_data.do"
  )
  cat(dofile_contents, file = dofile_name)
  
  ## Run command
  call_stata_script(
    stata_exe_path = settings[["stata_exe_path"]], 
    stata_script_path = dofile_name
  )
}


