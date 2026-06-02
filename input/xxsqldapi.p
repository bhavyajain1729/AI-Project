{us/bbi/mfdeclre.i}

/* INPUT DATASET */
DEFINE TEMP-TABLE  sqldInTbl 			NO-UNDO
		FIELD  	   file_content  		AS 	BLOB 
		FIELD      file_path   			AS  CHARACTER
		FIELD      file_name    		AS  CHARACTER
		FIELD      email_id  			AS  CHARACTER.

DEFINE DATASET     dsSQldIn				FOR sqldInTbl.

/* OUTPUT DATASET */
DEFINE TEMP-TABLE  sqldOutTbl  			NO-UNDO
		FIELD      processing_result  	AS 	CHARACTER
		FIELD      file_path   			AS  CHARACTER
		FIELD      file_name    		AS  CHARACTER.

DEFINE DATASET 	   dsSQldOut    		FOR sqldOutTbl.

{us/bu/bussvc.i &DATASET1 = dsSQldIn
                &DATASET2 = dsSQldOut}

PROCEDURE loadData:

   DEFINE INPUT      PARAMETER  DATASET   FOR dsSQldIn.
   DEFINE OUTPUT     PARAMETER  DATASET   FOR dsSQldOut.
  
   EMPTY TEMP-TABLE  sqldOutTbl.

   FOR EACH sqldInTbl
      NO-LOCK:	  
	  COPY-LOB sqldInTbl.file_content TO FILE (sqldInTbl.file_path + sqldInTbl.file_name) NO-CONVERT NO-ERROR.
	  
	  CREATE sqldOutTbl.
	  ASSIGN 
		 sqldOutTbl.file_path = sqldInTbl.file_path
		 sqldOutTbl.file_name = sqldInTbl.file_name.
			 
	  IF SEARCH(sqldInTbl.file_path + sqldInTbl.file_name) NE ? 
	  THEN DO:
		  {us/bbi/gprun.i ""xxsqload.p""
						"(INPUT sqldInTbl.file_path,
						  INPUT sqldInTbl.file_name,
						  INPUT sqldInTbl.email_id)"}
							
		  ASSIGN sqldOutTbl.processing_result = "Processing Completed".
	  END.
	  ELSE 
		  ASSIGN sqldOutTbl.processing_result = "Not Processed. File not created.".
	  
	  RELEASE sqldOutTbl NO-ERROR.
   END. /* FOR FIRST sqldInTbl */

END PROCEDURE. /* loadData */