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
  subset = NULL, 
  surv_ds_nms, 
  survival_test_sample,
  survival_trace = FALSE
) {
 
  # message("*     start to calculate all 'survival_statistics' at ", as.character(Sys.time()))
  
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
    stata_exe_path = settings[["stata_exe_path"]],
    survival_test_sample = survival_test_sample,
    survival_trace = survival_trace
  )
  message("*     finished running 'extract_define_survival_data' ; time used: ", 
          gsub("elapsed.*", "", data.table::timetaken(t)))
  
  
  for (surv_ds in surv_ds_nms) {
    ## survival_statistics
    message(sprintf("*      start to calculate '%s' at ", surv_ds), as.character(Sys.time()))
    t <- proc.time()
    
    infile <- gsub("survival_statistics_.*?_", "survival_file_analysis_", surv_ds)
    
    survival_statistics(
      stata_exe_path = settings[["stata_exe_path"]],
      infile         = settings[[infile]],
      lifetable      = settings[["lifetable"]],
      outfile        = surv_ds,
      estimand       = "netsurvival"
    )
    message(sprintf("*      finish calculating of '%s'; time used: ", surv_ds), gsub("elapsed.*", "", data.table::timetaken(t)))
    
    ## check outfile 
    surv_ds_csv <- sprintf("%s/%s.csv", settings[["survival_work_dir"]], surv_ds)
    if (!file.exists(surv_ds_csv)) {
      stop(
        "expected file ", deparse(surv_ds_csv),
        " to be created by survival function, but it did not exist; see log ",
        "files in ", deparse(settings[["survival_work_dir"]]), " for more ",
        "information"
      )
    }
    
    ## read 'outfile' into R
    surv_ds_dt <- data.table::fread( file = surv_ds_csv, encoding = "UTF-8")
    eval(parse(text = sprintf("%s = surv_ds_dt", surv_ds)))
    
  }

  
  return(mget(surv_ds_nms))
}
