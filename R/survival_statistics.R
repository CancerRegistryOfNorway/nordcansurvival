
#' Title
#'
#' @param stata_exe_path
#' @param cancer_record_dataset_path
#' @param output_file_path
#' @param national_population_life_table_path
#' @param estimand
#'
#' @return
#' @export
#'
#' @examples
#'

survival_statistics <- function(
  stata_exe_path = NULL,
  cancer_record_dataset_path,
  work_dir,
  output_file_path = NULL,
  national_population_life_table_path,
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

  settings <- nordcan_survival_settings(
    stata_exe_path = stata_exe_path,
    work_dir = work_dir
  )
  
  ## Check STATA/files exist or not;
  path_stata <- paste0(system.file(package = "nordcansurvival"), "/stata/path_stata.RData")

  if (is.null(stata_exe_path)) {
    if (file.exists(path_stata)) {
      load(path_stata)
    } else {
      stop("User must give the path of STATA")
    }
  } else {
    if (!file.exists(stata_exe_path)) {
      stop(sprintf("Can not find Stata software: %s!", stata_exe_path))
    } else {
      # save the path of stata to installed package, so  user don't need to specify it everytime.
      save(stata_exe_path, file = path_stata)
    }
  }


  if (!file.exists(cancer_record_dataset_path)) {
    stop(sprintf("Can not find 'cancer_record_dataset_path': %s !", cancer_record_dataset_path))
  }
  if (!file.exists(national_population_life_table_path)) {
    stop(sprintf("Can not find 'national_population_life_table_path': %s !", national_population_life_table_path))
  }
  
  output_file_path <- gsub(".dta", "_Result.dta", basename(cancer_record_dataset_path))

  dir_ado <- paste0(system.file(package = "nordcansurvival"), "/stata/ado")

  ## build do file based on 'dofile_template';
  dofile_contents <- sprintf( dofile_template,
                              work_dir,
                              dir_ado,dir_ado,dir_ado,dir_ado,
                              cancer_record_dataset_path,
                              output_file_path,
                              national_population_life_table_path,
                              estimand
  )
  
  ## save the  do file
  dofile_name <- paste0(work_dir, "/survival_statistics.do")
  cat(dofile_contents, file = dofile_name)

  ## comand line to run STATA on Windows or Linux OS;
  flag <- ifelse(.Platform$OS.type[1] == "windows", "/e", "-b")
  CMD <- sprintf("%s %s %s", stata_exe_path, flag , dofile_name)

  ## Run command
  system(CMD,  wait = TRUE)
}




