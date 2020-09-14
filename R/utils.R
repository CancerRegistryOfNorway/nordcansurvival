

call_stata_script <- function(
  stata_exe_path,
  stata_script_path
) {
  dbc::assert_prod_input_file_exists(stata_exe_path)
  dbc::assert_prod_input_file_exists(stata_script_path)
  
  os <- .Platform$OS.type[1] == "windows"
  flag <- ifelse(os, "/e", "-b")
  settings <- nordcan_survival_settings(stata_exe_path = stata_exe_path)
  
  # changing work directory appears to be necessary to ensure that results 
  # appear in the intended folder; we set the wd temporarily to that of the
  # survival results for robustness
  old_wd <- getwd()
  on.exit({
    setwd(old_wd)
  })
  setwd(settings[["survival_work_dir"]])
  
  dir_of_stata_script <- dirname(stata_script_path)
  # protect in case of whitespaces in path
  stata_exe_path <- normalizePath(settings[["stata_exe_path"]])
  stata_exe_path <- paste0("\"", stata_exe_path, "\"")
  # protect in case of whitespaces in path
  stata_script_path <- normalizePath(stata_script_path)
  stata_script_path <- paste0("\"", stata_script_path, "\"")
  
  CMD <- sprintf(
    "%s %s %s",  stata_exe_path, flag , stata_script_path
  )
  system(CMD, wait = TRUE)
}



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
  
  survival_output_file_path <- gsub(
    "\\..+$", "_Result.dta", basename(cancer_record_dataset_path)
  )
  
  survival_work_dir <- normalizePath(survival_work_dir, mustWork = TRUE)
  stata_exe_path <- normalizePath(stata_exe_path, mustWork = TRUE)
  pkg_path <- normalizePath(pkg_path, mustWork = TRUE)
  entity_df_path <- normalizePath(entity_df_path, mustWork = TRUE)
  ado_dir <- normalizePath(ado_dir, mustWork = TRUE)
  cancer_record_dataset_path <- normalizePath(cancer_record_dataset_path, mustWork = FALSE)
  national_population_life_table_path <- normalizePath(national_population_life_table_path, mustWork = FALSE)
  survival_output_file_path <- normalizePath(survival_output_file_path, mustWork = FALSE)
  
  mget(c("survival_work_dir", "stata_exe_path", "pkg_path",
         "entity_df_path", "ado_dir",
         "cancer_record_dataset_path", "national_population_life_table_path",
         "survival_output_file_path"))
}




