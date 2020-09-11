#
# library(nordcansurvival)
#
# #
# survival_statistics(infile = "P:/filkopi/HUTI/from_BAA_O1/nordcansurvival/inst/stata/test/NC_NO_2018_test_data_entity_406_41_210.dta",
#                     # outfile = NULL,
#                     lifetable = "S:/Prog64/Stata/krgdata/CRN_lifetable_Norway_2018_national_general_population.dta")
#

#
#
# survival_statistics(stata = "S:/Prog64/STATA/Stata16MP/StataMP-64.exe",
#                     infile = "P:/filkopi/HUTI/from_BAA_O1/nordcansurvival/inst/stata/test/NC_NO_2018_test_data_entity_406_41_210.dta",
#                     # outfile = NULL,
#                     lifetable = "S:/Prog64/Stata/krgdata/CRN_lifetable_Norway_2018_national_general_population.dta")
#
#
#
#
# survival_statistics(infile = "P:/filkopi/HUTI/from_BAA_O1/nordcansurvival/inst/stata/test/NC_NO_2018_test_data_entity_406_41_210.dta",
#                     # outfile = NULL,
#                     lifetable = "S:/Prog64/Stata/krgdata/CRN_lifetable_Norway_2018_national_general_population.dta")
#
# get_stata_info()
# #
#
 library(nordcansurvival)

 setwd("P:/Dataflyt/nordcan/test")
extract_define_survival_data("P:/Dataflyt/nordcan/NCI/INC.csv", stata = "S:/Prog64/STATA/Stata16MP/StataMP-64.exe")

get_stata_info("S:/Prog64/STATA/Stata16MP/StataMP-64.exe")

# infile <-  paste0(system.file(package = "nordcansurvival"), "/Stata/demo/NCS_NOR_example_data.dta")
infile <-  "P:/Dataflyt/nordcan/NCI/INC_for_survival.csv"
lifetable <- paste0(system.file(package = "nordcansurvival"), "/Stata/demo/NO_2018_lifetable.dta")

survival_statistics(infile = infile , lifetable = lifetable)

