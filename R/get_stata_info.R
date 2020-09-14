get_stata_info <- function(stata = NULL) {
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
  path_stata <- paste0(system.file(package = "nordcansurvival"), "/stata/path_stata.RData")

  if (is.null(stata)) {
    if (file.exists(path_stata)) {
      load(path_stata)
    } else {
      stop("User must give the path of STATA")
    }
  } else {
    if (!file.exists(stata)) {
      stop(sprintf("Can not find Stata software: %s!", stata))
    } else {
      # save the path of stata to installed package, so  user don't need to specify it everytime.
      save(stata, file = path_stata)
    }
  }


  wd <- getwd()
  dir_ado <- paste0(system.file(package = "nordcansurvival"), "/stata/ado")

  dofile <- sprintf( dofile_template, wd, dir_ado, dir_ado, dir_ado, dir_ado)

  dofile_name <-  paste0(wd, "/get_stata_info.do")
  cat(dofile, file = dofile_name )

  ## comand line to run STATA on Windows or Linux OS;
  flag <- ifelse(.Platform$OS.type[1] == "windows", "/e", "-b")
  CMD <- sprintf("%s %s %s", stata, flag , dofile_name)

  ## Run command
  system(CMD, wait = TRUE)

  ## Find the output, and print it to console.
  tmp_info <- paste0(wd, "/get_stata_info.log")
  for (i in 1 :100) {
    if (file.exists(tmp_info)) {
      tmp_info_R <- readLines(tmp_info)
      print(tmp_info_R)
      break
    }
    Sys.sleep(0.5)
  }

}



