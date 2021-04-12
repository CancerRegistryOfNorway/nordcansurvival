
survival_statistics ,	  /// Stata cmd defined in survival_statistics.ado
	infile("survival_file_analysis_5_10.dta") /// NC S dataset (dta)
	outfile("survival_statistics_period_5_10_dataset") /// detailed ressults (dta)
	lifetable("national_population_life_table.dta") /// National lifetable file (dta)
	estimand(netsurvival)          /// What to estimate
	country("Norway")       ///
	by(entity sex period_5) ///
	standstrata(agegroup_ICSS_5) ///  
	iweight(weights_ICSS_5)  ///
	breaks(0(0.08333333)10) 

survival_statistics ,	  /// Stata cmd defined in survival_statistics.ado
	infile("survival_file_analysis_10_10.dta") /// NC S dataset (dta)
	outfile("survival_statistics_period_10_10_dataset") /// detailed ressults (dta)
	lifetable("national_population_life_table.dta") /// National lifetable file (dta)
	estimand(netsurvival)          /// What to estimate
	country("Norway")       ///
	by(entity sex period_10) ///
	standstrata(agegroup_ICSS_3) ///  
	iweight(weights_ICSS_3)  ///
	breaks(0(0.08333333)10)  
		 	