

stata_info <- function(stata_exe_path, work_dir) {
  ## make template for Stata commad file
  dofile_template <-
    "
    cd %s          // set current working directory
    adopath ++ %s        // add path to Stata programs
    adopath ++ %s/utils  // add path to Stata programs
    adopath ++ %s/1      // add path to Stata programs
    adopath ++ %s/2      // add path to Stata programs

    stata_code_head, function(get_stata_info)

    get_stata_info

    stata_code_tail, function(get_stata_info)  // cleaning up etc

    "

  ## Check STATA/files exist or not;

  settings <- nordcan_survival_settings(
    stata_exe_path = stata_exe_path, work_dir = work_dir
  )
  ado_dir <- settings[["ado_dir"]]

  dofile <- sprintf(
    dofile_template, settings[["work_dir"]], ado_dir, ado_dir, ado_dir, ado_dir
  )
  
  dofile_name <-  paste0(settings[["work_dir"]], "/get_stata_info.do")
  cat(dofile, file = dofile_name )

  ## comand line to run STATA on Windows or Linux OS;
  flag <- ifelse(.Platform$OS.type[1] == "windows", "/e", "-b")
  CMD <- sprintf("%s %s %s", stata_exe_path, flag , dofile_name)

  ## Run command
  system(CMD, wait = TRUE)

  ## Find the output, and print it to console.
  info_path <- paste0(settings[["work_dir"]], "/get_stata_info.log")
  for (i in 1 :100) {
    if (file.exists(info_path)) {
      stata_info <- readLines(info_path)
      break()
    }
    Sys.sleep(0.5)
  }

  return(stata_info)
}



