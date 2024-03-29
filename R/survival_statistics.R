#' @title survival_statistics
#' @description
#' Provides non-parametric estimate of marginal relative survival, which under assumptions can be 
#' interpreted as marginal net survival. survival_statistics() is calling the Stata stnet program, 
#' using the Pohar Perme estimator with Brenner weighting to estimate age-standardized net survival.
#' 
#' Detailed documentation is available at \url{https://github.com/CancerRegistryOfNorway/NORDCAN/wiki/nordcansurvival}
#'
#' @param stata_exe_path This is set in the NORDCAN settings by default
#' @param infile path to a dataset of cancer records
#' @param lifetable (mandatory, default by NORDCAN system)
#' @param outfile path where to write result file. The outfile must be a set of 
#'   \itemize{
#'     \item \emph{survival_statistics_agestandardised_survivaltime_05_period_05}
#'     \item \emph{survival_statistics_agestandardised_survivaltime_05_period_10}
#'     \item \emph{survival_statistics_agestandardised_survivaltime_10_period_05}
#'     \item \emph{survival_statistics_agestandardised_survivaltime_10_period_10}
#'     \item \emph{survival_statistics_agespecific_survivaltime_05_period_05}
#'     \item \emph{survival_statistics_agespecific_survivaltime_05_period_10}
#'     \item \emph{survival_statistics_agespecific_survivaltime_10_period_05}
#'     \item \emph{survival_statistics_agespecific_survivaltime_10_period_10} 
#'   }
#'     and it was set up by the option \emph{output_objects} of \emph{nordcanepistats::nordcan_statistics_tables}

#' @param estimand defaults to \emph{netsurvival} the only option so far
#' 
#' 
#' 
#' @return survival analysis output in \emph{.csv} (UTF-8) and \emph{.dta} format.
#'
#'
#' @export
#'
#'
survival_statistics <- function(
    stata_exe_path = NULL,
    infile,
    lifetable,
    outfile = "survival_statistics",
    estimand = "netsurvival"
) {
  dbc::assert_prod_input_file_exists(infile)
  dbc::assert_prod_input_file_exists(lifetable)
  # dbc::assert_is_character_nonNA_vector(by)
  # dbc::assert_is_character_nonNA_atom(standstrata)
  # dbc::assert_is_character_nonNA_atom(iweight)
  settings <- nordcan_survival_settings(
    stata_exe_path = stata_exe_path
  )
  if (!file.exists(infile)) {
    stop(sprintf("Can not find 'infile': %s !",  infile))
  }
  if (!file.exists(lifetable)) {
    stop(sprintf("Can not find 'lifetable': %s !", lifetable))
  }
  survival_work_dir <- settings[["survival_work_dir"]]
  ado_dir <- settings[["ado_dir"]]
  ##
  survival_type <- ifelse(grepl("agestandardised",    outfile), "agestandardised", "agespecific")
  survival_time <- ifelse(grepl("survivaltime_05", outfile), "05", "10")
  period_based  <- ifelse(grepl("period_05",       outfile), "05", "10")
  by = c("entity", "sex")
  if (period_based == "05") {
    by  <- c(by, "period_5")
    iweight <- "weights_ICSS_5"
    standstrata <- "agegroup_ICSS_5"
  } else if (period_based == "10") {
    by <- c(by, "period_10")
    iweight <- "weights_ICSS_3"
    standstrata <- "agegroup_ICSS_3"
  }
  if (survival_type == "agespecific") {
    if (period_based == "05") {
      by <-  c(by, "agegroup_ICSS_5_str")
    } else if (period_based == "10") {
      by <-  c(by, "agegroup_ICSS_3_str")
    }
    
  }
  if (survival_time == "05") {
    # breaks <- "0(.08333333)5.08333333"
    breaks <- "0(`=1/12')5"
  } else if (survival_time == "10") {
    # breaks <- "0(0.08333333)11"
    breaks <- "0(`=1/12')10.083"
  }

  

  if (survival_type == "agespecific") {
    dofile_template <-
      "
cd \"%s\"                // set current working directory
adopath ++ \"%s\"        // add path to Stata programs
adopath ++ \"%s/utils\"  // add path to Stata programs
adopath ++ \"%s/1\"      // add path to Stata programs
adopath ++ \"%s/2\"      // add path to Stata programs
adopath ++ \"%s\"        // survival entities look-up file
      
stata_code_head, function(survival_statistics)
      
survival_statistics ,	  /// Stata cmd defined in survival_statistics.ado
  infile(\"%s\") 		    /// NC S dataset (dta)
  outfile(\"%s\") 	    /// detailed ressults (dta)
  lifetable(\"%s\") 	  /// National lifetable file (dta)
  estimand(%s)          /// What to estimate
  country(\"%s\")       ///
  by(%s)                ///
  breaks(%s)            


"
    ## build do file based on 'dofile_template';
    dofile_contents <- sprintf(dofile_template,
                               survival_work_dir,
                               ado_dir, ado_dir, ado_dir, ado_dir,
                               settings[["entity_table_dir"]],
                               infile,
                               outfile,
                               lifetable,
                               estimand,
                               nordcancore::get_global_nordcan_settings()$participant_name,
                               paste0(by, collapse = " "),
                               breaks)
    
  } else {
    dofile_template <-
      "
cd \"%s\"                // set current working directory
adopath ++ \"%s\"        // add path to Stata programs
adopath ++ \"%s/utils\"  // add path to Stata programs
adopath ++ \"%s/1\"      // add path to Stata programs
adopath ++ \"%s/2\"      // add path to Stata programs
adopath ++ \"%s\"        // survival entities look-up file
    
stata_code_head, function(survival_statistics)
    
survival_statistics ,	  /// Stata cmd defined in survival_statistics.ado
  infile(\"%s\") 		    /// NC S dataset (dta)
  outfile(\"%s\") 	    /// detailed ressults (dta)
  lifetable(\"%s\") 	  /// National lifetable file (dta)
  estimand(%s)          /// What to estimate
  country(\"%s\")       ///
  by(%s)                ///
  standstrata(%s)       ///
  iweight(%s)           ///
  breaks(%s)            


"
    
    ## build do file based on 'dofile_template';
    dofile_contents <- sprintf(dofile_template,
                               survival_work_dir,
                               ado_dir, ado_dir, ado_dir, ado_dir,
                               settings[["entity_table_dir"]],
                               infile,
                               outfile,
                               lifetable,
                               estimand,
                               nordcancore::get_global_nordcan_settings()$participant_name,
                               paste0(by, collapse = " "),
                               standstrata,
                               iweight,
                               breaks)    
    
  }

  ## save the  do file
  dofile_name <- paste0(survival_work_dir, "/survival_statistics.do")
  cat(dofile_contents, file = dofile_name)
  ## Run command
  call_stata_script(
    stata_exe_path = settings[["stata_exe_path"]],
    stata_script_path = dofile_name
  )
}