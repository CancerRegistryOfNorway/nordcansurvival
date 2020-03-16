




generate_stnet_script_contents <- function(
  ...,
  input_file_path = "stnet_input.csv",
  output_file_path = "stnet_output.csv"
) {
  c(
    generate_csv_import_command(input_file_path),
    generate_stnet_command(...),
    generate_csv_export_command(output_file_path)
  )
}


generate_csv_import_command <- function(input_file_path) {
  # TODO
}
generate_csv_export_command <- function(output_file_path) {
  # TODO
}

generate_stnet_command <- function(
  stratum_col_nms = c("sex", "area"),
  genpop_dataset_path = "genpop_dataset.csv",
  genpop_dataset_stratum_col_nms = c("sex", "year", "agegroup")
) {
  paste0(
    "stnet\n",
    "  using ", genpop_dataset_path, "\n",
    "  by(", paste0(stratum_col_nms, collapse = ", "), ")\n",
    "  mergeby(", paste0(genpop_dataset_stratum_col_nms, collapse = ", "), ")\n"
  )
}


call_stnet <- function(
  ...,
  genpop_dataset
) {

  genpop_dataset_path <- tempfile(fileext = ".csv")
  input_path <- tempfile(fileext = ".csv")
  output_path <- tempfile(fileext = ".csv")
  data.table::fwrite(genpop_dataset, genpop_dataset_path)

  stnet_script_arg_list <- c(
    list(...), mget(c("input_path", "output_path", "genpop_dataset_path"))
  )
  cmd <- do.call(generate_stnet_script_contents, stnet_script_arg_list)

  script_path <- tempfile(fileext = ".do")
  writeLines(cmd, script_path)

  call_stata_script(script_path = script_path)

  data.table::fread(output_path)
}



