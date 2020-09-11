capt prog drop stata_code_head
prog define stata_code_head

syntax , function(string)

qui {
	
	set type double
	set varabbrev off
	set logtype text
	set more off
	set level 95 
	set update_query off
	set searchdefault local
	set timeout1 1
	set timeout2 1
	set dp period 
	set trace off
}

end

exit  // test below

stata_code_head , function(survival_statistics)