
#' Title
#'
#' @param stata
#' @param infile
#' @param outfile
#' @param lifetable
#' @param estimand
#'
#' @return
#' @export
#'
#' @examples
#'

survival_statistics <- function(

  stata = NULL,
  infile,
  outfile = NULL,
  lifetable,
  estimand = "netsurvival"

) {

  ## make template for Stata commad file
  dofile_template <-
    "
    cd %s                // set current working directory
    adopath ++ %s        // add path to Stata programs
    adopath ++ %s/utils  // add path to Stata programs
    adopath ++ %s/1      // add path to Stata programs
    adopath ++ %s/2      // add path to Stata programs

    stata_code_head, function(survival_statistics)

    survival_statistics ,	  /// Stata cmd defined in survival_statistics.ado
    	infile(%s) 		        /// NC S dataset (dta)
    	outfile(%s) 	        /// detailed ressults (dta)
    	lifetable(%s) 	      /// National lifetable file (dta)
    	estimand(%s)          /// What to estimate

    stata_code_tail, function(survival_statistics)  // cleaning up etc

    "

  ## Check STATA/files exist or not;
  path_stata <- paste0(system.file(package = "nordcansurvival"), "/Stata/path_stata.RData")

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


  if (!file.exists(infile)) {
    stop(sprintf("Can not find 'infile': %s !", infile))
  }
  if (!file.exists(lifetable)) {
    stop(sprintf("Can not find 'lifetable': %s !", lifetable))
  }
  if (!is.null(outfile)) {
    if (!dir.exists(outfile)) {
      stop(sprintf("Directory %s is not exist!", outfile))
    }
  }

  ## set work directory;
  # if (is.null(outfile)) {
  #   wd <- dirname(infile)
  #   outfile <- gsub(".dta", "_Result.dta", basename(infile))
  # } else {
  #   wd <- dirname(outfile)
  # }
  wd <- getwd()
  outfile <- gsub(".dta", "_Result.dta", basename(infile))

  dir_ado <- paste0(system.file(package = "nordcansurvival"), "/Stata/ado")

  ## build do file based on 'dofile_template';

  dofile <- sprintf( dofile_template,
                     wd,
                     dir_ado,dir_ado,dir_ado,dir_ado,
                     infile,
                     outfile,
                     lifetable,
                     estimand
  )


  ## save the  do file

  dofile_name <- paste0(wd, "/survival_statistics.do")
  cat(dofile, file = dofile_name)

  ## comand line to run STATA on Windows or Linux OS;
  flag <- ifelse(.Platform$OS.type[1] == "windows", "/e", "-b")
  CMD <- sprintf("%s %s %s", stata, flag , dofile_name)

  ## Run command
  system(CMD,  wait = TRUE)
}




