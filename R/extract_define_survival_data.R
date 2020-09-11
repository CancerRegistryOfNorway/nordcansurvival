
extract_define_survival_data <- function(incidence_data, surv_entities = NULL, stata = NULL) {
  
  ## make template for Stata commad file
  dofile_template <-
    "
    cd %s                // set current working directory
    adopath ++ %s        // add path to Stata programs
    adopath ++ %s/utils  // add path to Stata programs
    adopath ++ %s/1      // add path to Stata programs
    adopath ++ %s/2      // add path to Stata programs

    stata_code_head, function(extract_define_survival_data)

    extract_define_survival_data , ///
    	incidence_data(%s)             ///
    	survival_file_base(%s)      /// 
    	survival_file_analysis(%s)  /// 
    	survival_entities(%s)

    stata_code_tail, function(extract_define_survival_data)  // cleaning up etc

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
  
  
  if (!file.exists(incidence_data)) {
    stop(sprintf("Can not find 'incidence_data': %s !", incidence_data))
  }
  
  
  if (grepl(".csv$", incidence_data)) {
    incidence_data_survival <- data.table::fread(incidence_data)
    incidence_data_survival_columns <- nordcancore::nordcan_metadata_column_name_set("column_name_set_survival")
    incidence_data_survival <- incidence_data_survival[incidence_data_survival[["excl_surv_total"]] == 0L, 
                                                       incidence_data_survival_columns, with = FALSE] 
    incidence_data <- gsub(".csv$", "_for_survival.csv", incidence_data)
    data.table::fwrite(x = incidence_data_survival,  file = incidence_data, sep = ";")
  } else if (grepl(".RData$", incidence_data)) {
    load(incidence_data)
    incidence_data_survival_columns <- nordcancore::nordcan_metadata_column_name_set("column_name_set_survival")
    incidence_data_survival <- incidence_data_survival[incidence_data_survival[["excl_surv_total"]] == 0L, 
                                                       incidence_data_survival_columns, with = FALSE] 
    incidence_data <- gsub(".RData$", "_for_survival.csv", incidence_data)
    data.table::fwrite(x = incidence_data_survival,  file = incidence_data, sep = ";")
  } else if (grepl(".dta$", incidence_data)) {
    ## User the dta file directly
  } else {
    stop("incidence_data must in .csv or .dta format. ")
  }

  

    
  
  surv_entities <- paste0(system.file(package = "nordcansurvival"), "/Stata/dta/NC_survival_entity_table.dta")
  if (!file.exists(surv_entities)) {
    stop(sprintf("Can not find 'surv_entities': %s !", surv_entities))
  }

  wd <- getwd()
  
  dir_ado <- paste0(system.file(package = "nordcansurvival"), "/Stata/ado")
  
  survival_file_base <- paste0(wd, "/survival_file_base.dta")
  survival_file_analysis <- paste0(wd, "/survival_file_analysis.dta")
  
  ## build do file based on 'dofile_template';
  dofile <- sprintf( dofile_template,
                     wd,
                     dir_ado,dir_ado,dir_ado,dir_ado,
                     incidence_data,
                     survival_file_base,
                     survival_file_analysis,
                     surv_entities
  )
  
  
  ## save the  do file
  
  dofile_name <- paste0(wd, "/extract_define_survival_data.do")
  cat(dofile, file = dofile_name)
  
  ## comand line to run STATA on Windows or Linux OS;
  flag <- ifelse(.Platform$OS.type[1] == "windows", "/e", "-b")
  CMD <- sprintf("%s %s %s", stata, flag , dofile_name)
  
  ## Run command
  system(CMD,  wait = TRUE)
}


