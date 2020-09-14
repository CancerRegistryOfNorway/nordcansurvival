



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
#' @param work_dir `[character]` (mandatory, no default)
#' 
#' path to directory where Stata scripts and datasets will be stored
#' for the duration of computing the statistics
#' @export
#' @importFrom foreign read.dta
nordcanstat_survival <- function(
  cancer_record_dataset,
  national_population_life_table,
  stata_exe_path,
  work_dir
) {
  nordcanpreprocessing::assert_processed_cancer_record_dataset_is_valid(
    cancer_record_dataset
  )
  dbc::assert_file_exists(stata_exe_path)
  nordcanpreprocessing::assert_national_population_life_table_is_valid(
    cancer_record_dataset
  )
  dbc::assert_dir_exists(work_dir)

  settings <- nordcanstat_survival_settings(
    work_dir = work_dir,
    stata_exe_path = stata_exe_path
  )
  

  # prepare working directory contents -----------------------------------------
  # copy the stata programme itself into the working directory to be used
  # by the just-generated script
  src_file_dir <- settings[["pkg_stata_script_dir"]]
  src_file_paths <- dir(src_file_dir, full.names = TRUE, recursive = TRUE)
  tgt_file_paths <- paste0(work_dir, "/", src_file_names)
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
  stata_info_output <- stata_info(
    work_dir = work_dir,
    stata_exe_path = stata_exe_path
  )
  
  # define the dataset using a stata script ------------------------------------
  stata_extract_define_survival_data(
    cancer_record_dataset_path = settings[["cancer_record_dataset_path"]], 
    work_dir = settings[["work_dir"]], 
    stata_exe_path = settings[["stata_exe_path"]]
  )
  
  # compile survival statistics using stata ------------------------------------
  stata_survival_statistics(
    stata_exe_path =  settings[["stata_exe_path"]],
    cancer_record_dataset_path = settings[["cancer_record_dataset_path"]],
    work_dir = settings[["work_dir"]],
    national_population_life_table_path = settings[["national_population_life_table_path"]],
    estimand = "netsurvival"
  )
  
  # the stata script has written its output into a new file. read it into R ----
  output_file_ext <- gsub(".+\\.", "", settings[["stata_output_file_path"]])
  output <- switch(
    output_file_ext,
    csv = data.table::fread(file = settings[["stata_output_file_path"]]),
    dta = foreign::read.dta(file = settings[["stata_output_file_path"]]),
    raise_internal_error(
      "no read function defined for output with file extension ",
      deparse(output_file_ext)
    )
  )
  
  # final touches --------------------------------------------------------------
  return(list(output = output, info = stata_info_output))
}





