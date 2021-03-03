



normalize_path <- function(x) {
  x <- normalizePath(
    path = x, winslash = "/", mustWork = FALSE
  )
  gsub("[/\\]+", "/", x)
}




call_stata_script <- function(
  stata_exe_path,
  stata_script_path
) {
  dbc::assert_prod_input_file_exists(stata_exe_path)
  dbc::assert_prod_input_file_exists(stata_script_path)
  
  os <- .Platform$OS.type[1] == "windows"
  flag <- ifelse(os, " /e /i ", " -b ")
  settings <- nordcan_survival_settings(stata_exe_path = stata_exe_path)
  
  # changing work directory appears to be necessary to ensure that results 
  # appear in the intended folder; we set the wd temporarily to that of the
  # survival results for robustness
  old_wd <- getwd()
  on.exit({
    setwd_stubbornly(old_wd)
  })
  setwd_stubbornly(settings[["survival_work_dir"]])
  
  dir_of_stata_script <- dirname(stata_script_path)
  # protect in case of whitespaces in path
  stata_exe_path <- normalize_path(settings[["stata_exe_path"]])
  stata_exe_path <- paste0("\"", stata_exe_path, "\"")
  # protect in case of whitespaces in path
  stata_script_path <- normalize_path(stata_script_path)
  stata_script_path <- paste0("\"", stata_script_path, "\"")
  
  CMD <- sprintf(
    "%s %s %s",  stata_exe_path, flag , stata_script_path
  )
  system(CMD, wait = TRUE)
}



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
  
  entity_table_dir <- paste0(pkg_path, "/stata/")
  if (!dir.exists(entity_table_dir)) {
    raise_internal_error(
      "no such file: ", deparse(entity_table_dir)
    )
  }
  ado_dir <- paste0(pkg_path, "/stata/ado")
  if (!dir.exists(ado_dir)) {
    raise_internal_error(
      "no such dir: ", deparse(ado_dir)
    )
  }
  
  infile <- paste0(
    survival_work_dir, "/cancer_record_dataset.csv"
  )
  lifetable <- paste0(
    survival_work_dir, "/national_population_life_table.csv"
  )
  
  survival_output_file_path <- paste0(
    survival_work_dir, "/survival_statistics_output.dta"
  )
  
  survival_work_dir <- normalize_path(survival_work_dir)
  stata_exe_path <- normalize_path(stata_exe_path)
  pkg_path <- normalize_path(pkg_path)
  entity_table_dir <- normalize_path(entity_table_dir)
  ado_dir <- normalize_path(ado_dir)
  infile <- normalize_path(infile)
  lifetable <- normalize_path(lifetable)
  survival_output_file_path <- normalize_path(survival_output_file_path)
  pkg_stata_script_dir <- normalize_path(pkg_stata_script_dir)
  survival_file_analysis_path <- normalize_path(
    paste0(survival_work_dir, "/survival_file_analysis.dta")
  )  
  survival_file_analysis_path_5 <- normalize_path(
    paste0(survival_work_dir, "/survival_file_analysis_5.dta")
  )
  survival_file_analysis_path_10 <- normalize_path(
    paste0(survival_work_dir, "/survival_file_analysis_10.dta")
  )
  
  survival_file_base_path <- normalize_path(
    paste0(survival_work_dir, "/survival_file_base.dta")
  )
  
  mget(c("survival_work_dir", "stata_exe_path", "pkg_path",
         "entity_table_dir", "ado_dir",
         "infile", "lifetable",
         "survival_file_analysis_path", 
         "survival_file_analysis_path_5", 
         "survival_file_analysis_path_10",
         "survival_file_base_path",
         "survival_output_file_path", "pkg_stata_script_dir"))
}




setwd_stubbornly <- function(
  dir, 
  n_max_tries = 100L, 
  wait_seconds = 2.0 / n_max_tries
) {
  dbc::assert_is_character_nonNA_atom(dir)
  dbc::assert_is_integer_nonNA_gtzero_atom(n_max_tries)
  dbc::assert_is_number_nonNA_gtzero_atom(wait_seconds)
  normal_dir <- normalizePath(dir, mustWork = FALSE)
  
  for (try_no in 1:n_max_tries) {
    tryCatch(
      setwd(dir = dir),
      error = function(e) e,
      warning = function(w) w
    )
    if (normalizePath(getwd()) == normal_dir) {
      break
    } else {
      Sys.sleep(wait_seconds)
    }
  }
  if (try_no == n_max_tries) {
    stop("setwd_stubbornly could not set working directory to ",
         deparse(dir), " after ", n_max_tries, " tries; does that directory ",
         "exist?")
  }
  
  return(invisible(getwd()))
}





