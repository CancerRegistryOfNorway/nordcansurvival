



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
#' @template param_stata_exe_path
#' @export
#' @importFrom data.table .SD
#' @return 
#' Returns a `data.table` of the resulting survival statistics.
nordcanstat_survival <- function(
  cancer_record_dataset,
  national_population_life_table,
  stata_exe_path = NULL
) {
  t_start <- proc.time()
  # nordcanpreprocessing::assert_processed_cancer_record_dataset_is_valid(
  #   cancer_record_dataset
  # )
  dbc::assert_file_exists(stata_exe_path)
  # nordcanpreprocessing::assert_national_population_life_table_is_valid(
  #   cancer_record_dataset
  # )
  
  settings <- nordcan_survival_settings(
    stata_exe_path = stata_exe_path
  )

  # prepare working directory contents -----------------------------------------
  message("* nordcansurvival::nordcanstat_survival: writing life table to ",
          deparse(settings[["national_population_life_table_path"]]), "...")
  nplf <- data.table::copy(
    national_population_life_table
  )
  data.table::setnames(
    nplf, c("year", "age"), c("_year", "_age")
  )
  data.table::fwrite(
    x = nplf,
    file = settings[["national_population_life_table_path"]],
    sep = ";"
  )
  
  message("* nordcansurvival::nordcanstat_survival: writing ",
          "cancer_record_dataset to ",
          deparse(settings[["cancer_record_dataset_path"]]), "...")
  crd <- cancer_record_dataset[
    cancer_record_dataset[["excl_surv_total"]] == 0L,
    .SD,
    .SDcols = nordcancore::nordcan_metadata_column_name_set(
      "column_name_set_survival"
    )
  ]
  data.table::fwrite(
    x = crd,
    file = settings[["cancer_record_dataset_path"]],
    sep = ";"
  )
  
  # define the dataset using a stata script ------------------------------------
  message("* nordcansurvival::nordcanstat_survival: started running ",
          "extract_define_survival_data at ",
          as.character(Sys.time()))
  t <- proc.time()
  extract_define_survival_data(
    cancer_record_dataset_path = settings[["cancer_record_dataset_path"]],
    stata_exe_path = settings[["stata_exe_path"]]
  )
  message("* nordcansurvival::nordcanstat_survival: ",
          "extract_define_survival_data finished; ",
          data.table::timetaken(t))
  
  # compile survival statistics using stata ------------------------------------
  message("* nordcansurvival::nordcanstat_survival: started running ",
          "survival_statistics at ", 
          as.character(Sys.time()))
  t <- proc.time()
  # first call creates life_table.dta, but is not able to read it due to a bug.
  survival_statistics(
    stata_exe_path =  settings[["stata_exe_path"]],
    cancer_record_dataset_path = normalizePath("survival/survival_file_analysis.dta"),
    national_population_life_table_path = settings[["national_population_life_table_path"]],
    estimand = "netsurvival"
  )
  # therefore in the second call we refer explicitly to the generated 
  # life_table.dta.
  survival_statistics(
    stata_exe_path =  settings[["stata_exe_path"]],
    cancer_record_dataset_path = normalizePath("survival/survival_file_analysis.dta"),
    national_population_life_table_path = sub("\\.csv", ".dta", settings[["national_population_life_table_path"]]),
    estimand = "netsurvival"
  )
  message("* nordcansurvival::nordcanstat_survival: ",
          "survival_statistics finished; ", 
          data.table::timetaken(t))
  
  # the stata script has written its output into a new file. read it into R ----
  if (!file.exists(settings[["survival_output_file_path"]])) {
    raise_internal_error(
      "expected file ", deparse(settings[["survival_output_file_path"]]),
      " to be created by survival function, but it did not exist"
    )
  }
  message("* nordcansurvival::nordcanstat_survival: reading in results from ",
          "survival_statistics")
  output <- data.table::fread(
    file = gsub("\\.dta", ".csv", settings[["survival_output_file_path"]]), 
    sep = ";", 
    encoding = "UTF-8"
  )
  
  # final touches --------------------------------------------------------------
  message("* nordcansurvival::nordcanstat_survival: finished whole run; ",
          data.table::timetaken(t_start))
  return(output[])
}





