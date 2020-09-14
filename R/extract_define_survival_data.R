
extract_define_survival_data <- function(
  cancer_record_dataset_path, 
  work_dir,
  stata_exe_path = NULL
) {
  dbc::assert_prod_input_file_exists(cancer_record_dataset_path)
  settings <- nordcan_survival_settings(
    work_dir = work_dir, stata_exe_path = stata_exe_path
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
  
  
  if (grepl(".csv$", cancer_record_dataset_path)) {
    incidence_data_survival <- data.table::fread(cancer_record_dataset_path)
    incidence_data_survival_columns <- nordcancore::nordcan_metadata_column_name_set("column_name_set_survival")
    incidence_data_survival <- incidence_data_survival[incidence_data_survival[["excl_surv_total"]] == 0L, 
                                                       incidence_data_survival_columns, with = FALSE] 
    incidence_data <- gsub(".csv$", "_for_survival.csv", cancer_record_dataset_path)
    data.table::fwrite(x = incidence_data_survival,  file = cancer_record_dataset_path, sep = ";")
  } else if (grepl(".RData$", cancer_record_dataset_path)) {
    load(cancer_record_dataset_path)
    incidence_data_survival_columns <- nordcancore::nordcan_metadata_column_name_set("column_name_set_survival")
    incidence_data_survival <- incidence_data_survival[incidence_data_survival[["excl_surv_total"]] == 0L, 
                                                       incidence_data_survival_columns, with = FALSE] 
    incidence_data <- gsub(".RData$", "_for_survival.csv", cancer_record_dataset_path)
    data.table::fwrite(x = incidence_data_survival,  file = cancer_record_dataset_path, sep = ";")
  } else if (grepl(".dta$", cancer_record_dataset_path)) {
    ## User the .dta file directly
  } else {
    stop("incidence_data must in .csv/.RData/.dta format. ")
  }
  
  entity_df_path <- settings[["entity_df_path"]]
  
  ado_dir <- settings[["ado_dir"]]
  
  survival_file_base <- paste0(work_dir, "/survival_file_base.dta")
  survival_file_analysis <- paste0(work_dir, "/survival_file_analysis.dta")
  
  ## build do file based on 'dofile_template';
  dofile <- sprintf( dofile_template,
                     work_dir,
                     ado_dir,ado_dir,ado_dir,ado_dir,
                     cancer_record_dataset_path,
                     survival_file_base,
                     survival_file_analysis,
                     entities
  )
  
  
  ## save the  do file
  
  dofile_name <- paste0(work_dir, "/extract_define_survival_data.do")
  cat(dofile, file = dofile_name)
  
  ## comand line to run STATA on Windows or Linux OS;
  flag <- ifelse(.Platform$OS.type[1] == "windows", "/e", "-b")
  CMD <- sprintf("%s %s %s", stata_exe_path, flag , dofile_name)
  
  ## Run command
  system(CMD,  wait = TRUE)
}


