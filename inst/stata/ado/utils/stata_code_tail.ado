capt prog drop stata_code_tail 
prog define stata_code_tail

syntax , function(string) [timer(integer 0)] [data(string)]

if ( `timer'==0 ) exit // not any timer 

qui {
    
	noi display as result _n "Finished running `function'"
	
	if ( "`timer'" != "" ) {
		
		timer list `timer'
		
		local s = r(t`timer') // seconds
				
		local HH : di %02.0f int(`s'/60^2)		
		local MM : di %02.0f int(mod(`s'/60), 60)
        local SS : di %02.0f int(mod(`s', 60))  
		
        local s = round(`s')
		
		noi di as result _column(5) ///
			"time used: `HH':`MM':`SS' (`s' seconds)"
			
	    timer clear `timer'			
	}
}

end

exit  // test below

stata_code_tail , function(survival_statistics)  
timer on 1
sleep 1000
timer off 1
stata_code_tail , function(survival_statistics) timer(1)

	Finished running survival_statistics
		time used: 00:00:01 (1 seconds)



