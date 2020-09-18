# 
# library(nordcansurvival)
# 
# setwd("P:/Dataflyt/nordcan/test2")
# 
# get_stata_info(stata = "S:/Prog64/STATA/Stata16MP/StataMP-64.exe")
# get_stata_info()
# 
# 
# extract_define_survival_data("P:/Dataflyt/nordcan/NCI/INC_prostate.csv",
#                              stata = "S:/Prog64/STATA/Stata16MP/StataMP-64.exe")
# # extract_define_survival_data("P:/Dataflyt/nordcan/NCI/nordcan_incidence_dataset_NOR_2018.RData", stata = "S:/Prog64/STATA/Stata16MP/StataMP-64.exe")
# # extract_define_survival_data("P:/Dataflyt/nordcan/NCI/INC.dta", stata = "S:/Prog64/STATA/Stata16MP/StataMP-64.exe")
# #
# #
# infile <-  "P:/Dataflyt/nordcan/test2/survival_file_analysis.dta"
# lifetable <- paste0(system.file(package = "nordcansurvival"), "/Stata/demo/NO_2018_lifetable.dta")
# #
# survival_statistics(infile = infile , lifetable = lifetable)
