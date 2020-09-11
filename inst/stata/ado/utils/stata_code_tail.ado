
capt prog drop stata_code_tail 
prog define stata_code_tail

syntax , function(string)

qui {
    

	noi display " Goodby - `function' - FROM stata_code_tail ! "
}

end

exit  // test below

stata_code_tail , function(survival_statistics)