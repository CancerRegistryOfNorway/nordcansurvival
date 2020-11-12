

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
#' @param subset `[NULL, logical, integer]` (optional, default `NULL`)
#' 
#' see [nordcancore::handle_subset_arg]
#' @export
nordcanstat_survival <- function(
  cancer_record_dataset,
  national_population_life_table,
  stata_exe_path = NULL,
  subset = NULL
) {
  t_start <- proc.time()
  dbc::assert_is_data.frame_with_required_names(
    cancer_record_dataset,
    required_names =  nordcancore::nordcan_metadata_column_name_set(
      "column_name_set_survival"
    )
  )
  nordcanpreprocessing::assert_national_population_life_table_is_valid(
    national_population_life_table
  )
  
  settings <- nordcan_survival_settings(
    stata_exe_path = stata_exe_path
  )
  gs <- nordcancore::get_global_nordcan_settings()
  first_year <- gs[["stat_survival_follow_up_first_year"]]
  
  subset <- nordcancore::handle_subset_arg(dataset = cancer_record_dataset)
  
  # prepare working directory contents -----------------------------------------
  message("* nordcansurvival::nordcanstat_survival: writing life table to ",
          deparse(settings[["national_population_life_table_path"]]), "...")
  nplt <- data.table::copy(
    national_population_life_table
  )
  data.table::setnames(nplt, c("year", "age"), c("_year", "_age"))
  data.table::fwrite(
    x = nplt,
    file = settings[["national_population_life_table_path"]],
    sep = ";"
  )
  rm(list = "nplt")
  
  message("* nordcansurvival::nordcanstat_survival: writing ",
          "cancer_record_dataset to ",
          deparse(settings[["cancer_record_dataset_path"]]), "...")
  mandatory_subset <- cancer_record_dataset[["excl_surv_total"]] == 0L & 
    cancer_record_dataset[["period_5"]] >= first_year
  subset <- nordcancore::subset_and(
    subset,
    mandatory_subset
  )
  crd <- cancer_record_dataset[
    subset,
    nordcancore::nordcan_metadata_column_name_set(
      "column_name_set_survival"
    ),
    with = FALSE
  ]
  data.table::fwrite(
    x = crd,
    file = settings[["cancer_record_dataset_path"]],
    sep = ";"
  )
  rm(list = "crd")
  gc()
  
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
  # 5-year periods
  survival_statistics(
    stata_exe_path =  settings[["stata_exe_path"]],
    cancer_record_dataset_path = settings[["survival_file_analysis_path"]],
    national_population_life_table_path = settings[["national_population_life_table_path"]],
    outfile = "survival_statistics_period_5",
    estimand = "netsurvival",
    by = c("entity", "sex", "period_5"),
    standstrata = "agegroup_ICSS_5",
    iweight = "weights_ICSS_5"
  )
  # 10-year periods
  survival_statistics(
    stata_exe_path =  settings[["stata_exe_path"]],
    cancer_record_dataset_path = settings[["survival_file_analysis_path"]],
    national_population_life_table_path = settings[["national_population_life_table_path"]],
    outfile = "survival_statistics_period_10",
    estimand = "netsurvival",
    by = c("entity", "sex", "period_10"),
    standstrata = "agegroup_ICSS_3",
    iweight = "weights_ICSS_3"
  )
  message("* nordcansurvival::nordcanstat_survival: ",
          "survival_statistics finished; ", 
          data.table::timetaken(t))
  
  # the stata script has written its output into a new file. read it into R ----
  if (!file.exists(settings[["survival_output_file_path"]])) {
    stop(
      "expected file ", deparse(settings[["survival_output_file_path"]]),
      " to be created by survival function, but it did not exist; see log ",
      "files in ", deparse(settings[["survival_work_dir"]]), " for more ",
      "information"
    )
  }
  message("* nordcansurvival::nordcanstat_survival: reading in results from ",
          "survival_statistics")
  survival_statistics_dataset_period_5 <- data.table::fread(
    file = "survival/survival_statistics_period_5",
    sep = ";", 
    encoding = "UTF-8"
  )
  survival_statistics_dataset_period_10 <- data.table::fread(
    file = "survival/survival_statistics_period_10",
    sep = ";", 
    encoding = "UTF-8"
  )
  
  # final touches --------------------------------------------------------------
  message("* nordcansurvival::nordcanstat_survival: finished whole run; ",
          data.table::timetaken(t_start))
  return(mget(c("survival_statistics_dataset_period_5", "survival_statistics_dataset_period_10")))
}





