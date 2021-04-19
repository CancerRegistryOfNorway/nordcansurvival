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
  
  settings <- nordcan_survival_settings( stata_exe_path = stata_exe_path)
  gs <- nordcancore::get_global_nordcan_settings()
  first_year <- gs[["first_year_survival"]]
  
  subset <- nordcancore::handle_subset_arg(dataset = cancer_record_dataset)
  
  # prepare working directory contents -----------------------------------------
  message("*     writing 'life table' to ",
          deparse(settings[["lifetable"]]), "...")
  nplt <- data.table::copy(national_population_life_table)
  data.table::setnames(nplt, c("year", "age"), c("_year", "_age"))
  data.table::fwrite(
    x = nplt,
    file = settings[["lifetable"]],
    sep = ";"
  )
  rm(list = "nplt")
  
  message("*     writing 'cancer_record_dataset' to ",
          deparse(settings[["infile"]]), "...")
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
    file = settings[["infile"]],
    sep = ";"
  )
  rm(list = "crd")
  gc()
  
  # define the dataset using a stata script ------------------------------------
  message("*      started running 'extract_define_survival_data' at ", 
          as.character(Sys.time()))
  t <- proc.time()
  extract_define_survival_data(
    cancer_record_dataset_path = settings[["infile"]], 
    stata_exe_path = settings[["stata_exe_path"]]
  )
  message("*     finished running 'extract_define_survival_data' ; time used: ", 
          gsub("elapsed.*", "", data.table::timetaken(t)))
  
  
  # compile survival statistics using stata ------------------------------------

  #############################
  # 5 year survival statistics 
  #############################
  
  # 5 year survival statistics based on 5-year periods
  message("*      started running '5 year survival_statistics' based on 5-year periods at ",
          as.character(Sys.time()))
  t <- proc.time()
  survival_statistics(
    stata_exe_path =  settings[["stata_exe_path"]],
    infile = settings[["survival_file_analysis_path_5"]],
    lifetable = settings[["lifetable"]],
    outfile = "survival_statistics_period_5_dataset",
    estimand = "netsurvival",
    by = c("entity", "sex", "period_5"),
    standstrata = "agegroup_ICSS_5",
    iweight = "weights_ICSS_5"
  )
  message("*     finished running '5 year survival_statistics' based on 5-year periods; time used: ",
          gsub("elapsed.*", "", data.table::timetaken(t)))
  
  # 5 year survival statistics based 10-year periods
  message("*      started running '5 year survival_statistics' based on 10-year periods at ",
          as.character(Sys.time()))
  t <- proc.time()
  survival_statistics(
    stata_exe_path =  settings[["stata_exe_path"]],
    infile = settings[["survival_file_analysis_path_10"]],
    lifetable = settings[["lifetable"]],
    outfile = "survival_statistics_period_10_dataset",
    estimand = "netsurvival",
    by = c("entity", "sex", "period_10"),
    standstrata = "agegroup_ICSS_3",
    iweight = "weights_ICSS_3"
  )
  message("*     finished running '5 year survival_statistics' based on 10-year periods; time used: ",
          gsub("elapsed.*", "", data.table::timetaken(t)))
  
  
  # the stata script has written its output into a new file. read it into R ----
  output_file_path_period_5 <- paste0(
    settings[["survival_work_dir"]], "/",
    "survival_statistics_period_5_dataset.csv"
  )
  message("*     reading in results from 'survival_statistics'")
  if (!file.exists(output_file_path_period_5)) {
    stop(
      "expected file ", deparse(output_file_path_period_5),
      " to be created by survival function, but it did not exist; see log ",
      "files in ", deparse(settings[["survival_work_dir"]]), " for more ",
      "information"
    )
  }
  survival_statistics_period_5_dataset <- data.table::fread(
    file = output_file_path_period_5,
    encoding = "UTF-8"
  )
  output_file_path_period_10 <- paste0(
    settings[["survival_work_dir"]], "/",
    "survival_statistics_period_10_dataset.csv"
  )
  if (!file.exists(output_file_path_period_10)) {
    stop(
      "expected file ", deparse(output_file_path_period_10),
      " to be created by survival function, but it did not exist; see log ",
      "files in ", deparse(settings[["survival_work_dir"]]), " for more ",
      "information"
    )
  }
  survival_statistics_period_10_dataset <- data.table::fread(
    file = output_file_path_period_10,
    encoding = "UTF-8"
  )
  
  
  
  
  #############################
  # 10 year survival statistics 
  #############################
  
  # 10 year survival statistics based on 5-year periods
  message("*      started running '10 year survival_statistics' based on 5-year periods at ", 
          as.character(Sys.time()))
  t <- proc.time()
  survival_statistics(
    stata_exe_path =  settings[["stata_exe_path"]],
    infile = settings[["survival_file_analysis_path_5_10"]],
    outfile = "survival_statistics_period_5_10_dataset",
    lifetable = settings[["lifetable"]],
    estimand = "netsurvival",
    by = c("entity", "sex", "period_5"),
    standstrata = "agegroup_ICSS_5",
    iweight = "weights_ICSS_5",
    breaks = "0(0.08333333)11"
  )
  message("*     finished running '10 year survival_statistics' based on 5-year periods; time used: ", 
          gsub("elapsed.*", "", data.table::timetaken(t)))
  
  
  # 10 year survival statistics based on 10-year periods
  message("*      started running '10 year survival_statistics' based on 10-year periods at ", 
          as.character(Sys.time()))
  t <- proc.time()
  survival_statistics(
    stata_exe_path =  settings[["stata_exe_path"]],
    infile = settings[["survival_file_analysis_path_10_10"]],
    outfile = "survival_statistics_period_10_10_dataset",
    lifetable = settings[["lifetable"]],
    estimand = "netsurvival",
    by = c("entity", "sex", "period_10"),
    standstrata = "agegroup_ICSS_3",
    iweight = "weights_ICSS_3",
    breaks =  "0(0.08333333)11"
  )
  message("*     finished running '10 year survival_statistics' based on 10-year periods; time used: ", 
          gsub("elapsed.*", "", data.table::timetaken(t)))
  
 
  
  # final touches --------------------------------------------------------------
  message("*     Finished whole 'survival_statistics_period_5/10_dataset'; time used: ",
          gsub("elapsed.*", "", data.table::timetaken(t_start)))
  
  ds_nsm <- c("survival_statistics_period_5_dataset", 
              "survival_statistics_period_10_dataset")
  return(mget(ds_nsm))
}





