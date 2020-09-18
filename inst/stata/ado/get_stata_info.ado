capt prog drop get_stata_info
prog define get_stata_info , nclass

quietly {
	
	noi di as text "The following should be reported if any problems:"
	
	noi di _n _dup(72) "-"
 	noi di "working directory" 	_col(20) c(pwd)
	noi di "OS temporary dir"   _col(20) c(tmpdir)
	noi di "current_date" 		_col(20) c(current_date)
	noi di "current_time" 		_col(20) c(current_time)
	noi di "os"					_col(20) c(os) 
	noi di "machine_type"		_col(20) c(machine_type)
	noi di "stata_version"		_col(20) c(stata_version)
	noi di "born_date"			_col(20) c(born_date)
	noi query compilenumber
	noi di "N processors" 		_col(20) c(processors)
	noi di "default data type"	_col(20) c(type) 
	noi di _n _dup(72) "-" 		
	noi sysdir
	noi di _n _n _dup(72) "-" 	
	
	noi query memory

	noi di _n _dup(72) "-" _n  	

	noi adopath
	
	noi di _n _n _dup(72) "-" _n  
	
	capt noi which extract_define_survival_data
	capt noi which survival_statistics 
	capt noi which stnet
	
	noi di _n _dup(72) "-" 	
	
	capt noi which stset
	capt noi which import
	capt noi which export
	
	capt noi di fre
	
	noi di _n _dup(72) "-" 	
}

end

exit