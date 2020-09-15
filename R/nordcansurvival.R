



#' @title NORDCAN Survival Statistics
#' @description
#' Compute survival statistics for NORDCAN. Data is written onto disk and 
#' Stata is called on the on-disk dataset.
#' @param cancer_record_dataset `[data.table]` (mandatory, no default)
#' 
#' the NORDCAN dataset of cancer records after pre-processing
#' @param national_population_life_table `[data.table]` (mandatory, no default)
#' 
#' the national population life table
#' @param stata_exe_path `[character]` (mandatory, no default)
#' 
#' full path to Stata executable
#' @export
#' @importFrom data.table .SD
nordcanstat_survival <- function(
  cancer_record_dataset,
  national_population_life_table,
  stata_exe_path
) {
  nordcanpreprocessing::assert_processed_cancer_record_dataset_is_valid(
    cancer_record_dataset
  )
  dbc::assert_file_exists(stata_exe_path)
  nordcanpreprocessing::assert_national_population_life_table_is_valid(
    cancer_record_dataset
  )

  settings <- nordcanstat_survival_settings(
    stata_exe_path = stata_exe_path
  )
  

  # prepare working directory contents -----------------------------------------
  # copy the stata programme itself into the working directory to be used
  # by the just-generated script
  src_file_dir <- settings[["pkg_stata_script_dir"]]
  src_file_paths <- dir(src_file_dir, full.names = TRUE, recursive = TRUE)
  tgt_file_paths <- paste0(settings[["survival_work_dir"]], "/", src_file_names)
  file.copy(src_file_paths, tgt_file_paths, overwrite = TRUE)

  # write files that the stata script needs
  cancer_record_dataset <- cancer_record_dataset[
    cancer_record_dataset[["excl_surv_total"]] == 0L,
    .SD,
    .SDcols = nordcancore::nordcan_metadata_column_name_set(
      "column_name_set_survival"
    )
  ]
  data.table::fwrite(
    x = cancer_record_dataset,
    file = settings[["cancer_record_dataset_path"]]
  )
  data.table::fwrite(
    x = national_population_life_table,
    file = settings[["national_population_life_table_path"]]
  )
  
  # retrieve basic information about stata -------------------------------------
  stata_info_output <- get_stata_info(
    stata_exe_path = stata_exe_path
  )
  
  # define the dataset using a stata script ------------------------------------
  stata_extract_define_survival_data(
    cancer_record_dataset_path = settings[["cancer_record_dataset_path"]], 
    stata_exe_path = settings[["stata_exe_path"]]
  )
  
  # compile survival statistics using stata ------------------------------------
  stata_survival_statistics(
    stata_exe_path =  settings[["stata_exe_path"]],
    cancer_record_dataset_path = settings[["cancer_record_dataset_path"]],
    national_population_life_table_path = settings[["national_population_life_table_path"]],
    estimand = "netsurvival"
  )
  
  # the stata script has written its output into a new file. read it into R ----
  output_file_ext <- gsub(".+\\.", "", settings[["survival_output_file_path"]])
  output <- data.table::fread(file = settings[["survival_output_file_path"]])
  
  # final touches --------------------------------------------------------------
  return(list(output = output, info = stata_info_output))
}





