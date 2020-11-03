#' @title get_stata_info
#' @description
#' Retrieve Stata version, session, and other information for debugging.
#' 
#' This function is for use locally by the user to get informations on Stata installation
#' and settings , to report in debugging.
#' 
#' The file includes path information and should probably not be distributed outside your local setting.
#' 
#' @param stata_exe_path Path to Stata executable. In NORDAN taken from the settings by default.
#' 
#' @return Return Stata information to terminal and save as a log file. 
#' 
#' @export
#' @return
#' 
get_stata_info <- function(stata_exe_path) {
  ## make template for Stata commad file
  dofile_template <-
    "
    cd \"%s\"          // set current working directory
    adopath ++ \"%s\"        // add path to Stata programs
    adopath ++ \"%s/utils\"  // add path to Stata programs
    adopath ++ \"%s/1\"      // add path to Stata programs
    adopath ++ \"%s/2\"      // add path to Stata programs

    stata_code_head, function(get_stata_info)

    get_stata_info

    stata_code_tail, function(get_stata_info)  // cleaning up etc

    "

  ## Check STATA/files exist or not;
  settings <- nordcan_survival_settings(
    stata_exe_path = stata_exe_path
  )
  ado_dir <- settings[["ado_dir"]]

  dofile <- sprintf(
    dofile_template, settings[["survival_work_dir"]], ado_dir, ado_dir, ado_dir, ado_dir
  )
  
  dofile_name <-  paste0(settings[["survival_work_dir"]], "/get_stata_info.do")
  cat(dofile, file = dofile_name )
  
  ## Run command
  call_stata_script(
    stata_exe_path = settings[["stata_exe_path"]], 
    stata_script_path = dofile_name
  )
  
  ## Find the output, and print it to console.
  info_path <- paste0(settings[["survival_work_dir"]], "/get_stata_info.log")
  for (i in 1:10) {
    if (file.exists(info_path)) {
      stata_info_output <- readLines(info_path)
      break()
    }
    Sys.sleep(0.5)
  }
  if (!exists("stata_info_output")) {
    raise_internal_error(
      "could not create info_path = ", deparse(info_path)
    )
  }

  return(stata_info_output)
}



