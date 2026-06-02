{us/bbi/mfdeclre.i}

define variable lvc_file            as character format "x(40)" label "Filename" .
define variable lvc_log01           as logical format "Ouput/Screen".
define variable lvc_out   				as character 	no-undo.

update 
lvc_file 
lvc_log01 
with frame a.

if lvc_log01 then do:
lvc_out = lvc_file + ".out".
batchrun = yes.
output to value (lvc_out).
input from value (lvc_file).  
{us/bbi/gprun.i ""sqqomt.p""}   
input close.
output close.
batchrun = no. 
end.

else do:
batchrun = yes.
input from value (lvc_file).  
{us/bbi/gprun.i ""sqqomt.p""}   
input close.
batchrun = no. 
end.
