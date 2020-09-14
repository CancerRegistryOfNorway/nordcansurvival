


#' @importFrom utils maintainer
raise_internal_error <- function(...) {
  stop(
    "Internal error: ",
    ..., 
    "; if you see this error, please report it to the package maintainer ",
    utils::maintainer("nordcansurvival")
  )
}



nordcan_survival_settings <- function(stata_exe_path) {
  dbc::assert_prod_input_is_one_of(
    stata_exe_path,
    funs = c("report_is_NULL", "report_file_exists")
  )
  
  survival_work_dir <- nordcancore::get_global_nordcan_settings()[["survival_work_dir"]]
  
  pkg_path <- system.file(package = "nordcansurvival")
  
  pkg_stata_script_dir <- paste0(pkg_path, "/stata/")
  if (!dir.exists(pkg_stata_script_dir)) {
    raise_internal_error(
      "no such directory: ", deparse(pkg_stata_script_dir)
    )
  }
  
  stata_path_cache_file_path <- paste0(pkg_path, "/stata/stata_path_cache.rds")
  if (is.null(stata_exe_path)) {
    if (file.exists(stata_path_cache_file_path)) {
      stata_exe_path <- readRDS(stata_path_cache_file_path)
    } else {
      stop("Please supply stata_exe_path.")
    }
  } else {
    if (!file.exists(stata_exe_path)) {
      stop("No such file: ", deparse(stata_exe_path))
    } else {
      saveRDS(stata_exe_path, file = stata_path_cache_file_path)
    }
  }
  
  entity_df_path <- paste0(pkg_path, "/stata/dta/NC_survival_entity_table.dta")
  if (!file.exists(entity_df_path)) {
    raise_internal_error(
      "no such file: ", deparse(entity_df_path)
    )
  }
  ado_dir <- paste0(pkg_path, "/stata/ado")
  if (!dir.exists(ado_dir)) {
    raise_internal_error(
      "no such dir: ", deparse(ado_dir)
    )
  }
  
  cancer_record_dataset_path <- paste0(
    survival_work_dir, "/cancer_record_dataset.csv"
  )
  national_population_life_table_path <- paste0(
    survival_work_dir, "/national_population_life_table.csv"
  )
  
  stata_output_file_path <- gsub(
    "\\..+$", "_Result.dta", basename(cancer_record_dataset_path)
  )
  
  mget(c("survival_work_dir", "stata_exe_path", "pkg_path",
         "entity_df_path", "ado_dir",
         "cancer_record_dataset_path", "national_population_life_table_path",
         "stata_output_file_path"))
}




