




nordcanstat_survival <- function(
  cancer_record_dataset,
  population_mortality_dataset,
  stata_exe_path,
  work_dir = tempdir()
) {
  # nordcancore::assert_is_processed_cancer_record_dataset(cancer_record_dataset)
  dbc::assert_file_exists(stata_exe_path)
  # nordcancore::assert_is_population_mortality_dataset(
  #   population_mortality_dataset
  # )
  dbc::assert_dir_exists(work_dir)

  # settings are hardcoded into nordcancore or into this package (can also
  # contain lookup tables from either package); object 'settings' will be a list
  # of lists, one list for each function called here
  settings <- nordcanstat_survival_settings(
    work_dir = work_dir,
    stata_exe_path = stata_exe_path
  )

  # any modification of data, including definition of follow-up time etc,,
  # if necessary; instead of having a function called `prep_settings`, I don't
  # mind if it has a different name or if there are actually multiple
  # functions called here.
  prep_settings <- settings[["prepare_survival_dataset"]]
  prep_arg_list <- c(list(cancer_record_dataset = cancer_record_dataset),
                     prep_settings)
  crd <- do.call(prepare_survival_dataset, prep_arg_list)

  # create a stata script for making the stata call
  stata_script_settings <- settings[["nordcanstat_survival_stata_script"]]
  do.call(nordcanstat_survival_stata_script, stata_script_settings)

  # copy the stata programme itself into the working directory to be used
  # by the just-generated script
  src_file_dir <- paste0(system.file(package = "nordcansurvival"), "/stata/")
  src_file_names <- dir(src_file_dir)
  src_file_paths <- dir(src_file_dir, full.names = TRUE)
  tgt_file_paths <- paste0(work_dir, "/", src_file_names)
  file.copy(src_file_paths, tgt_file_paths, overwrite = TRUE)

  # write files that the stata script needs
  stata_script_input_file_path <- stata_script_settings[["input_file_path"]]
  survival_cancer_record_dataset <- cancer_record_dataset[
    cancer_record_dataset[["excl_surv_total"]] == 0L,
    .SD,
    .SDcols = nordcancore::nordcan_metadata_column_name_set("column_name_set_survival")
  ]
  data.table::fwrite(
    x = survival_cancer_record_dataset,
    file = stata_script_input_file_path
  )
  stata_script_lifetable_file_path <- stata_script_settings[["lifetable_file_name"]]
  data.table::fwrite(
    x = population_mortality_dataset,
    file = stata_script_lifetable_file_path
  )

  # call the stata script
  call_settings <- settings[["call_stata_script"]]
  do.call(call_stata_script, call_settings)

  # the stata script has written its output into a new file. read it into R.
  results <- data.table::fread(
    file = call_settings[["output_file_path"]]
  )

  return(results)
}





