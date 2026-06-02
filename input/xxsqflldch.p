{us/mf/mfdtitle.i}

DEFINE VARIABLE lvc_path  	as CHARACTER  	NO-UNDO FORMAT "x(200)" VIEW-AS FILL-IN SIZE 50 BY 1.
DEFINE VARIABLE lvc_file  	as CHARACTER  	NO-UNDO FORMAT "x(200)" VIEW-AS FILL-IN SIZE 50 BY 1.
DEFINE VARIABLE lvc_EmailID	as CHARACTER  	NO-UNDO FORMAT "x(200)" VIEW-AS FILL-IN SIZE 40 BY 1.

form 
	lvc_path 		COLON 20 LABEL "File Path"
	lvc_file 		COLON 20 LABEL "File Name"
	lvc_EmailID 	COLON 20 LABEL "Email ID"
WITH FRAME a SIDE-LABEL.

mainloop:
REPEAT:
	ASSIGN
		lvc_path 	= ""
        lvc_file 	= ""
		lvc_EmailID = "".
		
	FOR EACH code_mstr 
		WHERE code_domain = global_domain
		AND code_fldname  = "xxsqrpa_path" 
		NO-LOCK:
		IF lvc_path = "" 
		THEN 
			lvc_path = TRIM(code_cmmt).
		ELSE 
			lvc_path = lvc_path + TRIM(code_cmmt).
	END.
	
	FOR EACH code_mstr 
		WHERE code_domain = global_domain
		AND code_fldname  = "xxsqrpa_email_chennai" 
		NO-LOCK:
		IF lvc_EmailID = "" 
		THEN 
			lvc_EmailID = TRIM(code_cmmt).
		ELSE 
			lvc_EmailID = lvc_EmailID + "," + TRIM(code_cmmt).
	END.
	
	UPDATE 
		lvc_path
		lvc_file
		lvc_EmailID
	WITH FRAME a.
	
	{us/bbi/gprun.i ""xxsqloadch.p""
					"(INPUT lvc_path,
					  INPUT lvc_file,
					  INPUT lvc_EmailID)"}
	
END. /*mainloop*/