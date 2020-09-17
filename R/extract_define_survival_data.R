
extract_define_survival_data <- function(
  cancer_record_dataset_path, 
  stata_exe_path = NULL
) {
  dbc::assert_prod_input_file_exists(
    cancer_record_dataset_path
  )
  settings <- nordcan_survival_settings(
    stata_exe_path = stata_exe_path
  )
  
  ## make template for Stata command file
  dofile_template <-
    "
    cd %s                // set current working directory
    adopath ++ %s        // add path to Stata programs
    adopath ++ %s/utils  // add path to Stata programs
    adopath ++ %s/1      // add path to Stata programs
    adopath ++ %s/2      // add path to Stata programs

    stata_code_head, function(extract_define_survival_data)

    extract_define_survival_data , ///
    	incidence_data(%s)             ///
    	survival_file_base(%s)      /// 
    	survival_file_analysis(%s)  /// 
    	survival_entities(%s)

    stata_code_tail, function(extract_define_survival_data)  // cleaning up etc

    "
  
  
  entity_df_path <- settings[["entity_df_path"]]
  
  ado_dir <- settings[["ado_dir"]]
  
  survival_file_base <- paste0(settings[["survival_work_dir"]], "/survival_file_base.dta")
  survival_file_analysis <- paste0(settings[["survival_work_dir"]], "/survival_file_analysis.dta")
  ## build do file based on 'dofile_template';
  dofile_contents <- sprintf( dofile_template,
                              settings[["survival_work_dir"]],
                              ado_dir,ado_dir,ado_dir,ado_dir,
                              cancer_record_dataset_path,
                              survival_file_base,
                              survival_file_analysis,
                              settings[["entity_df_path"]]
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


