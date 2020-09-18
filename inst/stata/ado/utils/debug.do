
/*

if template generated do file fails

open the do file in Stata

then add the following above the command to be debuged

The log file will have a lot of code, at som point a error will
cause the program to stop, this will return a return code

The error codes are documented, run the following command and
open the pdf help for error which have a full description

help error

*/

set trace on
set tracesep on 
set traceindent on 
set tracenumber on 

set tracedepth 5
set tracehilite "assert"