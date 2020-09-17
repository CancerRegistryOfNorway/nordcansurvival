

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
                              estimand
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




