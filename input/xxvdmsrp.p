/*********************************************************
* xxvdmsrp.p - Supplier Master Report
*  hdt#   who         when      what
*  ----   ---         --------  ----------------
*  537    Sameera.F   21/10/20  Supplier Master Report 
*  ********************************************************/
/*DISPLAY TITLE*/
{us/mf/mfdtitle.i}
{us/px/pxmaint.i}
.
DEFINE VARIABLE l_oldformat AS CHARACTER NO-UNDO.
DEFINE VARIABLE supp       LIKE vd_addr.
DEFINE VARIABLE supp1      LIKE vd_addr.
DEFINE VARIABLE added      LIKE ad_date.
DEFINE VARIABLE added1     LIKE ad_date.
DEFINE VARIABLE moddate    LIKE ad_date.
DEFINE VARIABLE moddate1   LIKE ad_date.
DEFINE VARIABLE email_csv  AS LOGICAL    LABEL "Email" NO-UNDO.
DEFINE VARIABLE email_id   AS CHARACTER  LABEL "Email Id" FORMAT "x(30)" NO-UNDO.
DEFINE VARIABLE file1      AS CHARACTER  FORMAT "x(24)" NO-UNDO.
DEFINE VARIABLE i-subject  AS CHARACTER  NO-UNDO.
DEFINE VARIABLE l_delimit  AS CHARACTER  NO-UNDO.
DEFINE VARIABLE l_date     AS CHARACTER  NO-UNDO.
DEFINE VARIABLE l_name     AS CHARACTER  NO-UNDO.
DEFINE VARIABLE l_site     AS CHARACTER  NO-UNDO.
DEFINE VARIABLE l_panno    AS CHARACTER  NO-UNDO.
DEFINE VARIABLE l_gstno    AS CHARACTER  NO-UNDO.
DEFINE VARIABLE l_crtms    AS CHARACTER  NO-UNDO.
DEFINE VARIABLE l_moddate  AS date       NO-UNDO.
DEFINE VARIABLE l_invdate  AS date       NO-UNDO.
DEFINE VARIABLE l_cemail   AS CHARACTER EXTENT 6 NO-UNDO.
DEFINE VARIABLE i          AS INTEGER    NO-UNDO.
DEFINE STREAM excel .
define variable lv_mail_cmd as character no-undo.

l_oldformat = SESSION:DATE-FORMAT.

DEFINE TEMP-TABLE ttsupprp  NO-UNDO
FIELD tt_supp                LIKE creditor.creditorcode
FIELD tt_sname               LIKE businessrelation.BusinessRelationName1
FIELD tt_supclbal            LIKE cbalance.cbalancetc 
FIELD tt_spanno              AS   CHARACTER FORMAT "X(15)"
FIELD tt_sgstno              AS   CHARACTER FORMAT "X(24)"
FIELD tt_scity               LIKE ad_city
FIELD tt_sstate              LIKE ad_state
FIELD tt_saddr               AS   CHARACTER FORMAT "X(100)"
FIELD tt_lastmoddate         LIKE creditor.lastmodifieddate
FIELD tt_addeddate           LIKE creditor.creditorbirthdate
FIELD tt_email               LIKE contact.ContactEmail EXTENT 6
FIELD tt_email1              LIKE contact.ContactEmail EXTENT 6.

FORM
  supp               COLON 20
  supp1              LABEL "To" COLON 45 SKIP
  added              COLON 20   LABEL "Creation Date"
  added1             LABEL "To" COLON 45 SKIP
  moddate            COLON 20   LABEL "Modified Date"
  moddate1           LABEL "To" COLON 45 SKIP
  email_csv          COLON 20   LABEL "Email CSV file?"
  email_id           COLON 20   LABEL "Email Id"
 WITH FRAME a SIDE-LABELS WIDTH 80 ATTR-SPACE.

  setFrameLabels(FRAME a:HANDLE).
mainloop:
REPEAT:
  
  EMPTY TEMP-TABLE ttsupprp.
  ASSIGN l_delimit = "|".
  
  IF supp1    = hi_char  THEN supp1      = "".
  IF added    = low_date THEN added      = ?.
  IF added1   = hi_date  THEN added1     = ?.
  IF moddate  = low_date THEN moddate    = ?.
  IF moddate1 = hi_date  THEN moddate1   = ?.
  
  IF c-application-mode <> 'web' THEN
  UPDATE
      supp supp1
      added added1
      moddate moddate1
      email_csv
    WITH FRAME a.
    
  IF NOT email_csv THEN email_id = ''.
  DISP email_id WITH FRAME a.
  SESSION:date-format = "dmy" .
  {us/wb/wbrp06.i &COMMAND = UPDATE
  &FIELDS = "
      supp
      supp1
      added
      added1
      moddate
      moddate1
      email_csv
      email_id"
  &frm = "a"}
  IF (c-application-mode <> 'web') OR
     (c-application-mode  = 'web') THEN
    DO:
      bcdparm = "".
      {us/mf/mfquoter.i supp     }
      {us/mf/mfquoter.i supp1    }
      {us/mf/mfquoter.i added    }
      {us/mf/mfquoter.i added1   }
      {us/mf/mfquoter.i moddate  }
      {us/mf/mfquoter.i moddate1 }
      {us/mf/mfquoter.i email_csv}
      {us/mf/mfquoter.i email_id }
    
    IF supp1    = "" THEN supp1    = hi_char.
    IF added    = ?  THEN added    = low_date.
    IF added1   = ?  THEN added1   = hi_date.
    IF moddate  = ?  THEN moddate  = low_date.
    IF moddate1 = ?  THEN moddate1 = hi_date.
   END. /*(c-application-mode <> 'web') */
  
  FOR FIRST usr_mstr NO-LOCK WHERE usr_userid = global_userid:
      email_id = usr_mail_address.
  END.
  
  ASSIGN l_date = STRING(TODAY)
         l_date = REPLACE(l_date,"/","")
         file1  =  global_userid + l_date + STRING(TIME,"HH:MM:SS")  + ".csv".
  
  IF email_csv THEN
    DO:
      UPDATE email_id WITH FRAME a.
    END.
    
  {us/gp/gpselout.i &printType = "printer"
  &printWidth = 132
  &pagedFlag = " "
  &STREAM = " "
  &appendToFile = " "
  &streamedOutputToTerminal = " "
  &withBatchOption = "yes"
  &displayStatementType = 1
  &withCancelMessage = "yes"
  &pageBottomMargin = 6
  &withEmail = "yes"
  &withWinprint = "yes"
  &defineVariables = "yes"}
  {us/bbi/mfphead.i}
  
  PUT UNFORMATTED
      "Supplier Code"              AT 1
      "Supplier Name"              AT 16
      "Supplier Cl Bal"            AT 60
      "Supplier Pan No"            AT 100
      "Supplier GST No"            AT 120
      "City"                       AT 141
      "State"                      AT 159 
      "Supplier Address"           AT 179
      "Last Modified Date"         AT 290
      "Added Date"                 AT 310
      "Email_ID_1"                 AT 534
      "Email_ID_2"                 AT 577
      "Email_ID_3"                 AT 620
      "Email_ID_4"                 AT 663
      "Email_ID_5"                 AT 706
      "Email_ID_6"                 AT 749 skip
   FILL("-",845) FORMAT "x(845)" AT 1 SKIP.
      
  IF email_csv = YES THEN
    DO:
      OUTPUT STREAM excel TO VALUE(file1).
      PUT STREAM excel UNFORMATTED
	  "Supplier Code"              l_delimit
      "Supplier Name"              l_delimit
      "Supplier Cl Bal"            l_delimit
      "Supplier Pan No"            l_delimit
      "Supplier GST No"            l_delimit
      "City"                       l_delimit
      "State"                      l_delimit
      "Supplier Address"           l_delimit
      "Last Modified Date"         l_delimit
      "Added Date"                 l_delimit
      "Email_ID_1"                 l_delimit
      "Email_ID_2"                 l_delimit
      "Email_ID_3"                 l_delimit
      "Email_ID_4"                 l_delimit
      "Email_ID_5"                 l_delimit
      "Email_ID_6"                 l_delimit SKIP.
   END. /*IF email_csv = YES*/
  
    FOR EACH creditor NO-LOCK WHERE creditor.creditorcode >= supp
                              AND creditor.creditorcode <= supp1,
        EACH ad_mstr NO-LOCK WHERE ad_domain = global_domain
                                AND ad_addr  = creditor.creditorcode
                                AND ad_date >= added AND ad_date <= added1,
        EACH businessrelation NO-LOCK
                  WHERE  businessrelation.businessrelation_ID = creditor.businessrelation_ID
                    AND  businessrelation.LastModifiedDate   >= moddate 
                    AND  businessrelation.LastModifiedDate   <= moddate1,
		each address no-lock
             where address.businessrelation_id = Businessrelation.Businessrelation_ID,

			 first addresstype no-lock
			 where addresstype.addresstype_id = address.addresstype_id
			   and addresstypecode = "HEADOFFICE":
			
    
              ASSIGN 
                  l_name    = TRIM(BusinessRelationName1)
                  l_panno   = TRIM(Address.AddressTaxIDState)
                  l_gstno   = TRIM(Address.AddressTaxIDFederal).
   
   CREATE ttsupprp.
    ASSIGN  
	  tt_supp                = trim(creditor.creditorcode)
      tt_sname               = TRIM(l_name)
      tt_spanno              = trim(l_panno)     
      tt_sgstno              = trim(l_gstno)
      tt_scity               = trim(ad_city)
      tt_sstate              = trim(ad_state)
      tt_saddr               = trim(ad_line1) + trim(ad_line2) + trim(ad_line3)
	  tt_lastmoddate         = creditor.lastmodifieddate
	  tt_addeddate           = ad_date.
      
    FOR first cbalance NO-LOCK where cbalance.creditor_id = creditor.creditor_id :
                    ASSIGN tt_supclbal = cbalance.cbalancetc.
    END. /*cbalance*/	  
      
   ASSIGN i = 0.  
    FOR EACH code_mstr NO-LOCK WHERE code_domain = global_domain
                                AND CODE_fldname =  Creditor.CreditorCode + "_email"  :
      
            ASSIGN i = i + 1.
            IF i <= 6 THEN
              DO:
                  ASSIGN tt_email[i]   = code_value 
                         tt_email1[i]  = code_cmmt .  
                
              END.
      END. /*FOR EACH code_mstr*/
    END. /* for each debtor */
  
  
  FOR EACH ttsupprp  NO-LOCK BREAK BY tt_supp:
   
    PUT  UNFORMATTED
      tt_supp            AT 1
      tt_sname           AT 16
      tt_supclbal        AT 60
      tt_spanno          AT 100
      tt_sgstno          AT 120   
      tt_scity           AT 141
      tt_sstate          AT 159 
      tt_saddr           AT 179 
      tt_lastmoddate     AT 290
      tt_addeddate       AT 310
      tt_email1[1]       AT 534 FORMAT "x(40)"
      tt_email1[2]       AT 577 FORMAT "x(40)"
      tt_email1[3]       AT 620 FORMAT "x(40)" 
      tt_email1[4]       AT 663 FORMAT "x(40)"
      tt_email1[5]       AT 706 FORMAT "x(40)" 
      tt_email1[6]       AT 749 FORMAT "x(40)" SKIP.
     
   IF email_csv = YES AND email_id <> '' THEN
      DO:
        PUT STREAM excel 
        tt_supp                   l_delimit
        tt_sname                  l_delimit
 STRING(tt_supclbal)              l_delimit 
        tt_spanno                 l_delimit
        tt_sgstno                 l_delimit
        tt_scity                  l_delimit
        tt_sstate                 l_delimit
        tt_saddr                  l_delimit
		tt_lastmoddate            l_delimit
		tt_addeddate              l_delimit
		tt_email1[1]              l_delimit
        tt_email1[2]              l_delimit
        tt_email1[3]              l_delimit 
        tt_email1[4]              l_delimit 
        tt_email1[5]              l_delimit 
        tt_email1[6]              l_delimit SKIP.
       
      END. /*IF email_csv = YES*/
       IF PAGE-SIZE - LINE-COUNTER < 4 THEN
      DO:
      
        PAGE.
        PUT "Supplier Code"              AT 1
            "Supplier Name"              AT 16   
            "Supplier Cl Bal"            AT 60
            "Supplier Pan No"            AT 100
            "Supplier GST No"            AT 120
            "City"                       AT 141
            "State"                      AT 159 
            "Supplier Address"           AT 179
	    "Last Modified Date"         AT 290
	    "Added Date"                 AT 310
            "Email_ID_1"                 AT 534
            "Email_ID_2"                 AT 577
            "Email_ID_3"                 AT 620
            "Email_ID_4"                 AT 663
            "Email_ID_5"                 AT 706
            "Email_ID_6"                 AT 749 SKIP
   FILL("-",845) FORMAT "x(845)" AT 1 SKIP.
      END.
  
    END. /*FOR EACH ttsupprp*/
  
  
  /* REPORT TRAILER  */
  {us/mf/mfrtrail.i}
   
  OUTPUT STREAM excel CLOSE.
      IF email_csv = TRUE AND email_id <> '' THEN DO:
        FIND FIRST dom_mstr NO-LOCK WHERE dom_domain = global_domain NO-ERROR.
        ASSIGN i-subject = '"Supplier Master Report     '
          + (IF AVAIL dom_mstr THEN "(" + dom_name + ")" ELSE "" ) + '"'.
        
        //OS-COMMAND SILENT  ECHO ""  | mailx -s VALUE(i-subject) -a VALUE(file1) VALUE(email_id).
        lv_mail_cmd = "mailx -s '" + i-subject + "' -a " + file1 + " " + email_id + " < /dev/null > /dev/null".
        unix silent value(lv_mail_cmd).

        OS-DELETE VALUE(email_id).
      END. /*IF email_csv = TRUE*/
 SESSION:date-format = l_oldformat .
 END. /*Repeat*/
