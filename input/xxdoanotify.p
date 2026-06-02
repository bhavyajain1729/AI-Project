/* PSC: xxdoanotify.p - DOA Email Notification							*/
/*                                                                      */
/* CREATED: 01 Jun 2023   BY: NILESH                                    */
/*----------------------------------------------------------------------*/			

USING PROGRESS.Json.ObjectModel.*.

{us/bbi/mfdeclre.i}
DEFINE INPUT 	PARAMETER 	ipc_ruletype 		    AS CHARACTER 	NO-UNDO.
DEFINE INPUT 	PARAMETER 	ipr_recid    		    AS RECID     	NO-UNDO.
DEFINE INPUT 	PARAMETER 	ipc_nextapprover	    AS CHARACTER	NO-UNDO.
DEFINE OUTPUT 	PARAMETER 	opc_errorMsg 		    AS CHARACTER	NO-UNDO.

DEFINE VARIABLE l_msgfilename           AS CHARACTER	NO-UNDO.
DEFINE VARIABLE lvc_notifyEmailID       AS CHARACTER	NO-UNDO.
DEFINE VARIABLE lvc_oscommand      	    AS CHARACTER	NO-UNDO.
DEFINE VARIABLE lvc_mailsubject    	    AS CHARACTER	NO-UNDO.
DEFINE VARIABLE lvc_flowtriggerSubject  AS CHARACTER	NO-UNDO.
DEFINE VARIABLE EmailBodyJson    	    AS JsonObject	NO-UNDO.
DEFINE VARIABLE EmailBodyTextData 	    AS JsonObject	NO-UNDO.

define variable lvc_requestor           as character    no-undo.
define variable lvc_attachment          as character    no-undo.
define variable lvc_dir                 as character    no-undo.
define variable lvc_filename            as character    no-undo.
define variable lvc_zip_cmmd            as character    no-undo.
define variable lvc_copy                as character    no-undo.
define variable lvc_branchname          as character    no-undo.
define variable lvc_filename1           as character  	initial 	"Emailbody_"  		no-undo.
define variable lvc_filename2           as character  	initial 	"Notificationbody_" no-undo.
define variable lvi_count               as integer 		initial 	0 					no-undo.
define variable lvc_header              as character 	no-undo.
define variable lvc_name                as character.
define variable lvc_payterm             as character.
define variable lvc_slsname             as character.
define variable lvc_ccemail             as character.
define variable lvc_ccsubject           as character.

define variable lvd_cost                as decimal.
define variable lvd_costtot             as decimal.
define variable lvd_pricetot            as decimal.

/*CVC0463-41 - Start*/
DEFINE VARIABLE lvd_totavgcost		AS DECIMAL NO-UNDO.
DEFINE VARIABLE lvd_tmpavgcost		AS DECIMAL NO-UNDO.
DEFINE VARIABLE lvd_totrxlpurcost 	AS DECIMAL NO-UNDO.
DEFINE VARIABLE lvd_avgcostmargin	AS DECIMAL NO-UNDO.
/*CVC0463-41 - End*/

define temp-table ttDInvoice no-undo
field DInvoiceDueDate       like DInvoice.DInvoiceDueDate
field DebtorCode            like Debtor.DebtorCode
field OverDue           as integer
field CurrentVal        as decimal
field D1_30             as decimal format "->>,>>>,>>9.99"
field D31_60            as decimal format "->>,>>>,>>9.99"
field D61_90            as decimal
field D91_180           as decimal
field D181_270          as decimal
field D271_365          as decimal
field over365           as decimal
field Ret               as decimal
field OpenItem          as decimal
field TotalPD           as decimal
field TCGSTAmt          as decimal
.
define temp-table ttsummary
field ttsummary_debtor   as character 
field ttsummary_current  as decimal 
field ttsummary_D1_30    as decimal format "->>,>>>,>>9.99"
field ttsummary_D31_60   as decimal
field ttsummary_D61_90   as decimal
field ttsummary_D91_180  as decimal 
field ttsummary_openItem as decimal.

empty temp-table ttDInvoice.
empty temp-table ttsummary.

define buffer busrw_wkfl for usrw_wkfl.

DEFINE STREAM strm1.

ASSIGN 
    l_msgfilename       = "MailBody.txt"
    EmailBodyJson       = NEW JsonObject()
    EmailBodyTextData   = New JsonObject()
    ipc_nextapprover    = replace(ipc_nextapprover,",",";").
    
EmailBodyJson:ADD('ToEmailID',ipc_nextapprover). 
EmailBodyJson:ADD('ApprovalType',ipc_ruletype).   

IF ipc_ruletype EQ "SupplierCreate" OR 
   ipc_ruletype EQ "SupplierModify" OR 
   ipc_ruletype EQ "CustomerCreate" OR 
   ipc_ruletype EQ "CustomerModify"
THEN DO:
	FIND FIRST mdm_mstr 					 
		 WHERE RECID(mdm_mstr) EQ ipr_recid
	NO-LOCK NO-ERROR.
	IF AVAILABLE mdm_mstr
	THEN DO:
        IF ipc_ruletype EQ "SupplierCreate" THEN 
           lvc_header = "New Supplier creation is requested as below.".
        IF ipc_ruletype EQ "SupplierModify" THEN 
           lvc_header = "Supplier '" + mdm_BusinessRelationName3 + "' is modified.".
        IF ipc_ruletype EQ "CustomerCreate" THEN
           lvc_header = "New Customer creation is requested as below.".
        IF ipc_ruletype EQ "CustomerModify" THEN
           lvc_header = "Customer '" + mdm_BusinessRelationName3 + "' is modified.".
        
        lvc_filename1 = lvc_filename1 + mdm_BusinessRelationCode + ".txt".
        lvc_filename2 = lvc_filename2 + mdm_BusinessRelationCode + ".txt".

      for first ad_mstr where ad_domain = global_domain
        and ad_addr = mdm_cm_slspsn1 no-lock,
        first businessrelation where businessrelation.businessrelationcode = ad_bus_rel no-lock,
        first address of businessrelation no-lock:
         assign 
            lvc_requestor = ad_mstr.ad_name + "-" + Address.Addressemail
            lvc_ccemail =  Address.Addressemail.
      end.
     
      for each code_mstr where code_domain = global_domain
        and code_fldname = "mdm_attachments" no-lock:
         if lvc_dir = "" then 
            lvc_dir = code_cmmt.
         else
            lvc_dir =  lvc_dir + code_cmmt.
      end.
      if lvc_dir <> "" then do:
         lvc_filename = mdm_BusinessRelationCode + ".zip".

        for each docd_det where docd_app_id = "mfg" and docd_context = "INDIA" + "_" and (docd_program = "Supplier_" or docd_program = "Customer_") 
           and docd_field_value begins mdm_BusinessRelationCode no-lock,
           each doc_mstr where doc_mstr.oid_doc_mstr = docd_det.oid_doc_mstr no-lock:
             if lvc_attachment = "" then 
                lvc_attachment =  '"' + doc_filename + '"'.
             else 
                lvc_attachment = lvc_attachment + ' "' + doc_filename + '"'.
             
             lvc_copy = 'cp "' + lvc_dir + doc_location + "/" + doc_filename + '" .'.      
             OS-COMMAND SILENT value (lvc_copy).   
        end.
      end.

      if lvc_attachment <> "" then do:
        lvc_zip_cmmd = "zip -m " + lvc_filename + " " + lvc_attachment. 
        OS-COMMAND SILENT value(lvc_zip_cmmd).  
      end.
      find first si_mstr where si_domain = global_domain
         and si_site = mdm_site no-lock no-error.
      if available si_mstr then 
         lvc_branchname = si_desc.
      else 
         lvc_branchname = mdm_site.

      if mdm_CorporateGroupCode <> "" then do:
         for first corporategroup where corporategroupcode = mdm_CorporateGroupCode no-lock,
            each businessrelation of corporategroup no-lock:
            lvi_count = lvi_count + 1.
         end.
      end.
      else 
      lvi_count = 1.
       output to value (lvc_filename2).
       put unformatted
       lvc_header skip
       "- Code:" mdm_BusinessRelationCode skip
       "- Name:" mdm_BusinessRelationName3 skip
       "- PAN:" mdm_AddressTaxIDState skip
       "- Customer Count Code In:" lvi_count skip
       "- Business Line:" mdm_short6 skip
       "- Payment Term:" mdm_CreditTerm skip
       "- Parent Code:" mdm_CorporateGroupCode skip
       "- Customer Category:" mdm_class skip
       "- Credit Limit:" mdm_CrLimitReq skip
       "- First Billing Value:" mdm_Decimal1 skip
       "- Requestor:" lvc_requestor skip(1)
	   "**Approval History**" skip(1).
	   for each xxdoah_hist where xxdoah_domain = global_domain and xxdoah_nbr = mdm_BusinessRelationCode no-lock break by xxdoah_DateTime descending:
	   put unformatted
	   "- " upper(trim(substring(xxdoah_currappr,1,(index(xxdoah_currappr,".") - 1))))  + " " + Upper(trim(substring(xxdoah_currappr,index(xxdoah_currappr,".") + 1, index(xxdoah_currappr,"@") - index(xxdoah_currappr,".") - 1))) + " | " 
	   +  trim(xxdoah_DateTime) + " | " + trim(xxdoah_Comment) skip.
	   end.	
       output close.
       output to value (lvc_filename1).
         /* Table stytling */
         put unformatted
         "<head>
          <style>
          table, th, td ~{
          border: 1px solid black;
          color:Black;
          background:LightGrey;
          ~}
          .buttonGreen ~{
            background-color: Green;
            border: none;
            color: white;
            padding: 15px 32px;
            text-align: center;
            text-decoration: none;
            display: inline-block;
            font-size: 16px;
            margin: 4px 2px;
            cursor: pointer;
          ~}
          .buttonRed ~{
            background-color: Red;
            border: none;
            color: white;
            padding: 15px 32px;
            text-align: center;
            text-decoration: none;
            display: inline-block;
            font-size: 16px;
            margin: 4px 2px;
            cursor: pointer;
          ~}
		  .buttonOrange ~{
            background-color: Orange;
            border: none;
            color: white;
            padding: 15px 32px;
            text-align: center;
            text-decoration: none;
            display: inline-block;
            font-size: 16px;
            margin: 4px 2px;
            cursor: pointer;
          ~}
         </style>
         </head>".
         
         /* MDM Details */
         put unformatted
         "<p>" lvc_header "</p><br>"
         "<table style='width:100%'>
          <tr>
          <td>Code</td>
          <td>" mdm_BusinessRelationCode "</td>
          </tr>"
          "<tr>
          <td>Name</td>
          <td>" mdm_BusinessRelationName3 "</td>
          </tr>"
          "<tr>
          <td>PAN</td>
          <td>" mdm_AddressTaxIDState "</td>
          </tr>"
          "<tr>
          <td>Customer Count Code In QAD</td>
          <td>" lvi_count "</td>
          </tr>"
          "<tr>
          <td>Business Line</td>
          <td>" mdm_short6 "</td>
          </tr>"
          "<tr>
          <td>Site</td>
          <td>" lvc_branchname "</td>
          </tr>"
          "<tr>
          <td>Payment Term</td>
          <td>" mdm_CreditTerm "</td>
          </tr>".

         put unformatted
          "<tr>
          <td>Parent Code</td>
          <td>" mdm_CorporateGroupCode "</td>
          </tr>"
          "<tr>
          <td>Customer Category</td>
          <td>" mdm_class "</td>
          </tr>"
          "<tr>
          <td>Credit Limit</td>
          <td>" mdm_CrLimitReq "</td>
          </tr>"
          "<tr>
          <td>First Billing Value</td>
          <td>" mdm_Decimal1 "</td>
          </tr>"
          "<tr>
          <td>Requestor</td>
          <td>" lvc_requestor "</td>
          </tr>".
          put unformatted
          "</table>".
         put unformatted
         "<h3>Approval Summary:</h3><br>"
         "<table style='width:100%'>
           <tr>
           <th>Action</th>
           <th>User Email</th>
           <th>Date Time</th>
           <th>Remarks</th>
           </tr>".

            for each xxdoah_hist where xxdoah_domain = global_domain and xxdoah_nbr = mdm_BusinessRelationCode no-lock break by xxdoah_DateTime descending:
               
               put unformatted
               "<tr>
               <td>"
               trim(xxdoah_Action)
               "</td><td>"
               upper(trim(substring(xxdoah_currappr,1,(index(xxdoah_currappr,".") - 1))))  + " " + Upper(trim(substring(xxdoah_currappr,index(xxdoah_currappr,".") + 1, index(xxdoah_currappr,"@") - index(xxdoah_currappr,".") - 1)))
               "</td><td>"
               trim(xxdoah_DateTime)
               "</td><td>"
               trim(xxdoah_Comment)
               "</td></tr>".
            end.
            put unformatted
            "</table>".
         output close.
   
		  EmailBodyJson:ADD('ApprovalDocument',mdm_BusinessRelationCode). 
        EmailBodyJson:ADD('CCEmail',lvc_ccemail).
        
        ASSIGN 
            lvc_mailsubject = IF ipc_ruletype BEGINS "Supplier" THEN ("Supplier Create/Modify Approval " + mdm_BusinessRelationCode)  
                                 ELSE IF ipc_ruletype BEGINS "Customer" THEN ("Customer Create/Modify Approval " + mdm_BusinessRelationCode) 
                                 ELSE ""
            lvc_ccsubject   = IF ipc_ruletype BEGINS "Supplier" THEN ("Supplier " + mdm_BusinessRelationCode + " Create/Modify is in approval process")  
               ELSE IF ipc_ruletype BEGINS "Customer" THEN ("Customer " + mdm_BusinessRelationCode + " Create/Modify is in approval process") 
               ELSE "". 
                              
	END.
	ELSE DO:
        DELETE OBJECT EmailBodyJson NO-ERROR.
        DELETE OBJECT EmailBodyTextData NO-ERROR.
        
		ASSIGN opc_errorMsg = "Record Not Found".
		RETURN.
	END.
END.
ELSE 	/* CRIPL-179 */
IF ipc_ruletype EQ "SPAREL" 
THEN DO:
	assign 
	lvc_name = ""
	lvc_payterm = "".

	FIND FIRST qo_mstr					 
		 WHERE RECID(qo_mstr) EQ ipr_recid
	NO-LOCK NO-ERROR.
	IF AVAILABLE qo_mstr
	THEN DO:
	
     /*CVC0463-41 - Start*/
	 ASSIGN 
		lvd_totavgcost 	 	= 0
		lvd_totrxlpurcost   = 0
		lvd_avgcostmargin   = 0.
	  
     FOR EACH qod_det
		WHERE qod_domain = qo_domain
		AND   qod_nbr    = qo_nbr 
		NO-LOCK:
		ASSIGN lvd_tmpavgcost = 0.
		
		FOR FIRST sct_det
			WHERE sct_domain = qod_domain 	AND
				  sct_sim    = "Average"	AND
				  sct_part	 = qod_part		AND
				  sct_site	 = qod_site
			NO-LOCK:
			ASSIGN lvd_tmpavgcost = sct_det.sct_cst_tot.
		END.
				
		ASSIGN 
			lvd_totavgcost 		= lvd_totavgcost 	+ ROUND(lvd_tmpavgcost * qod_det.qod_qty_quot,2)
			lvd_totrxlpurcost 	= lvd_totrxlpurcost + ROUND(qod_det.qod__dec02 * qod_det.qod_qty_quot,2).
	 END.
	 
	 ASSIGN lvd_avgcostmargin = ROUND((((DECIMAL(qo_mstr.qo__chr09) - lvd_totavgcost) / DECIMAL(qo_mstr.qo__chr09)) * 100),2).
	 /*CVC0463-41 - End*/
		
	 IF ipc_ruletype EQ "SPAREL" THEN
		lvc_header = "New Quote is created.".

	 for each code_mstr where code_domain = global_domain
		and code_fldname = "mdm_attachments" no-lock:
		if lvc_dir = "" then 
		   lvc_dir = code_cmmt.
		else
		   lvc_dir =  lvc_dir + code_cmmt.
	 end.
	 if lvc_dir <> "" then do:
		lvc_filename = qo_nbr + ".zip".

	   for each docd_det where docd_app_id = "mfg" and docd_context = "INDIA" + "_" and (docd_program = "salesquote_" or docd_program = "sqqomt.p_") 
		  and docd_field_value begins qo_nbr no-lock,
		  each doc_mstr where doc_mstr.oid_doc_mstr = docd_det.oid_doc_mstr no-lock:
		   if lvc_attachment = "" then 
			   lvc_attachment =  '"' + doc_filename + '"'.
		   else 
			   lvc_attachment = lvc_attachment + ' "' + doc_filename + '"'.
		 
		   lvc_copy = 'cp "' + lvc_dir + doc_location + "/" + doc_filename + '" .'.      
		   OS-COMMAND SILENT value (lvc_copy).   
	   end.
	 end.

	 if lvc_attachment <> "" then do:
	   lvc_zip_cmmd = "zip -m " + lvc_filename + " " + lvc_attachment. 
	   OS-COMMAND SILENT value(lvc_zip_cmmd).  
	 end.

		lvc_filename1 = lvc_filename1 + qo_nbr + ".txt".
	 lvc_filename2 = lvc_filename2 + qo_nbr + ".txt".
		run getsummary (input qo_mstr.qo_cust).
	 find first debtor where debtor.debtorcode = qo_cust no-lock no-error.
		if available debtor then do:
			find first ad_mstr where ad_domain = global_domain
			   and ad_addr = debtor.debtorcode no-lock no-error.
			if available ad_mstr then 
			lvc_name = ad_name.
			find first PaymentCondition where PaymentCondition_ID = debtor.NormalPaymentCondition_ID no-lock no-error.
			if available PaymentCondition then 
			assign 
			  lvc_payterm = PaymentCondition.PaymentConditionCode + "(" + PaymentCondition.PaymentConditionDesc + ")".
		end.
	 for first ad_mstr where ad_domain = global_domain
		and ad_addr = qo_slspsn[1] no-lock,
		first businessrelation where businessrelation.businessrelationcode = ad_bus_rel no-lock,
		first address of businessrelation no-lock:
		assign
		   lvc_slsname = ad_mstr.ad_name /* + "-" + Address.Addressemail */
		   lvc_ccemail = Address.Addressemail.
	 end. 

	 find first genfldd_det where genfldd_det.oid_owning_record = qo_mstr.oid_qo_mstr
		and  genfldd_det.genfldd_tablename = "qo_mstr" no-lock no-error.
	 if available genfldd_det then do:
		if lvc_ccemail = "" then 
		lvc_ccemail = genfldd_det.genfldd_charvalues[3].
		else 
		lvc_ccemail = lvc_ccemail + ";" + replace(genfldd_det.genfldd_charvalues[3],"," ,";").
	 end. 
	 
	 /*CVC0463-66-Start*/
	 FIND FIRST usr_mstr
		 WHERE usr_userid = qo_mstr.qo_userid
	 NO-LOCK NO-ERROR.
	 IF AVAILABLE usr_mstr AND TRIM(usr_mstr.usr_mail_address) <> ""
	 THEN DO:
		if lvc_ccemail = "" then 
			lvc_ccemail = usr_mstr.usr_mail_address.
		else 
			lvc_ccemail = lvc_ccemail + ";" + usr_mstr.usr_mail_address.
	 END.
	 /*CVC0463-66-End*/

  output to value (lvc_filename2).
   put unformatted
   lvc_header skip
   "- Sales Quote Number:" qo_mstr.qo_nbr skip
   "- Customer Name:" lvc_name skip
   "- Total Customer Price:" qo_mstr.qo__chr09 SKIP
   "- Total Rexel Purchase Cost:" STRING(lvd_totrxlpurcost) skip										/*CVC0463-41*/
   "- Margin based on Purchase Cost - INR:" STRING(DECIMAL(qo_mstr.qo__chr09) - lvd_totrxlpurcost) skip	/*CVC0463-119*/
   "- Margin based on Purchase Cost - %:" qo_mstr.qo__chr10 "%" skip									/*CVC0463-41*/
   "- Total Average Cost:" STRING(lvd_totavgcost) skip													/*CVC0463-41*/
   "- Margin based on Average Cost - INR:" STRING(DECIMAL(qo_mstr.qo__chr09) - lvd_totavgcost) skip		/*CVC0463-119*/
   "- Margin based on Average Cost - %:" STRING(lvd_avgcostmargin) "%" skip								/*CVC0463-41*/
   "- Credit Term:" lvc_payterm skip
   "- Business Line:" qo_mstr.qo_project skip
   "- Sales Person Name:" lvc_slsname skip 
   "- Site:" qo_mstr.qo_site skip(1) .

   find first ttsummary no-lock no-error.
   if available ttsummary then do:
	   put unformatted
	   "**Credit Information**" skip(1)
       "- Current Outstanding:" ttsummary_current skip
       "- 1-30 Days Outstanding:" ttsummary_D1_30 skip
       "- 31-60 Days Outstanding:" ttsummary_D31_60 skip
       "- 61-90 Days Outstanding:" ttsummary_D61_90 skip
       "- 91-180 Days Outstanding:" ttsummary_D91_180 skip
       "- Total Outstanding:" ttsummary_openItem skip(1).
   end.
   put unformatted
   "**Approval History**" skip(1).
   for each xxdoah_hist where xxdoah_domain = global_domain and xxdoah_nbr = qo_nbr no-lock break by xxdoah_DateTime descending:
   put unformatted
   "- " upper(trim(substring(xxdoah_currappr,1,(index(xxdoah_currappr,".") - 1))))  + " " + Upper(trim(substring(xxdoah_currappr,index(xxdoah_currappr,".") + 1, index(xxdoah_currappr,"@") - index(xxdoah_currappr,".") - 1))) + " | " 
   +  trim(xxdoah_DateTime) + " | " + trim(xxdoah_Comment) skip.
   end.	
   output close.
   

		output to value (lvc_filename1).
	 /* Table stytling */
	 put unformatted
	 "<head>
	  <style>
	  table, th, td ~{
	  border: 1px solid black;
	  color:Black;	
	  background:LightGrey;
	  ~}
	  .buttonGreen ~{
		background-color: Green;
		border: none;
		color: white;
		padding: 15px 32px;
		text-align: center;
		text-decoration: none;
		display: inline-block;
		font-size: 16px;
		margin: 4px 2px;
		cursor: pointer;
	  ~}
	  .buttonRed ~{
		background-color: Red;
		border: none;
		color: white;
		padding: 15px 32px;
		text-align: center;
		text-decoration: none;
		display: inline-block;
		font-size: 16px;
		margin: 4px 2px;
		cursor: pointer;
	  ~}
	  .buttonOrange ~{
            background-color: Orange;
            border: none;
            color: white;
            padding: 15px 32px;
            text-align: center;
            text-decoration: none;
            display: inline-block;
            font-size: 16px;
            margin: 4px 2px;
            cursor: pointer;
          ~}
	 </style>
	 </head>".
  
	put unformatted
	 "<h3>Quotation Details:</h3><br>"
	 "<table style='width:100%'>"
	  .
	put unformatted
	"<tr>
	<td>Sales Quote Number</td><td>"
	qo_mstr.qo_nbr
	"</td></tr><tr><td>Customer Name</td><td>"
	lvc_name
	"</td></tr><tr><td>Total Customer Price</td><td>"
	qo_mstr.qo__chr09
	"</td></tr><tr><td>Total Rexel Purchase Cost</td><td>"				/*CVC0463-41*/
	STRING(lvd_totrxlpurcost)											/*CVC0463-41*/
	"</td></tr><tr><td>Margin based on Purchase Cost - INR</td><td>"	/*CVC0463-119*/
	STRING(DECIMAL(qo_mstr.qo__chr09) - lvd_totrxlpurcost)				/*CVC0463-119*/
	"</td></tr><tr><td>Margin based on Purchase Cost - %</td><td>"		/*CVC0463-41*/
	qo_mstr.qo__chr10 + " %"											/*CVC0463-41*/
	"</td></tr><tr><td>Total Average Cost</td><td>"						/*CVC0463-41*/
	STRING(lvd_totavgcost)												/*CVC0463-41*/
	"</td></tr><tr><td>Margin based on Average Cost - INR</td><td>"		/*CVC0463-119*/
	STRING(DECIMAL(qo_mstr.qo__chr09) - lvd_totavgcost)					/*CVC0463-119*/
	"</td></tr><tr><td>Margin based on Average Cost - %</td><td>"		/*CVC0463-41*/
	STRING(lvd_avgcostmargin) + " %"									/*CVC0463-41*/
	"</td></tr><tr><td>Credit Terms</td><td>"
	lvc_payterm
	"</td></tr><tr><td>Business Line</td><td>"
    qo_mstr.qo_project
    "</td></tr><tr><td>Sales Person Name</td><td>"
    lvc_slsname
	"</td></tr><tr><td>Site</td><td>"
	qo_mstr.qo_site
    "</td></tr>"
	"</table>".

	 put unformatted
	 "<h3>Additional Remarks:</h3><br>"
	 "<table style='width:100%'>
	   <tr>
	   <th>Current Outstanding</th>
	   <th>1-30 Days Outstanding</th>
	   <th>31-60 Days Outstanding</th>
	   <th>61-90 Days Outstanding</th>
	   <th>91-180 Days Outstanding</th>
	   <th>Total Outstanding</th>
	   </tr>".
	for each ttsummary :
	  put unformatted
	  "<tr>
	  <td>"
	  string(ttsummary_current) 
	  "</td><td>"
	  string(ttsummary_D1_30)
	  "</td><td>"
	  string(ttsummary_D31_60)
	  "</td><td>"
	  string(ttsummary_D61_90)
	  "</td><td>"
	  string(ttsummary_D91_180)
	  "</td><td>"
	  string(ttsummary_openItem)
	  "</td></tr>".
	end.  
	put unformatted
		"</table>".
	 put unformatted
	 "<h3>Approval Summary:</h3><br>"
	 "<table style='width:100%'>
	   <tr>
	   <th>Action</th>
	   <th>User Email</th>
	   <th>Date Time</th>
	   <th>Remarks</th>
	   </tr>".

		for each xxdoah_hist where xxdoah_domain = global_domain and xxdoah_nbr = qo_nbr no-lock break by xxdoah_DateTime descending:
		   
		   put unformatted
		   "<tr>
		   <td>"
		   trim(xxdoah_Action)
		   "</td><td>"
		   upper(trim(substring(xxdoah_currappr,1,(index(xxdoah_currappr,".") - 1))))  + " " + Upper(trim(substring(xxdoah_currappr,index(xxdoah_currappr,".") + 1, index(xxdoah_currappr,"@") - index(xxdoah_currappr,".") - 1)))
		   "</td><td>"
		   trim(xxdoah_DateTime)
		   "</td><td>"
		   trim(xxdoah_Comment)
		   "</td></tr>".
		end.
		put unformatted
		"</table>".
		output close.
		
		EmailBodyJson:ADD('ApprovalDocument',qo_mstr.qo_nbr). 
	 EmailBodyJson:ADD('CCEmail',lvc_ccemail). 
	
		ASSIGN 
		lvc_mailsubject = IF ipc_ruletype BEGINS "SPAREL" THEN ("Quotation Created For Approval " + qo_mstr.qo_nbr) Else ""
		lvc_ccsubject = IF ipc_ruletype BEGINS "SPAREL" THEN ("Quotation " + qo_mstr.qo_nbr + " is in approval process") Else "".
	END.
	ELSE DO:
		DELETE OBJECT EmailBodyJson NO-ERROR.
		DELETE OBJECT EmailBodyTextData NO-ERROR.
		
		ASSIGN opc_errorMsg = "Record Not Found".
		RETURN.
	END.
END.
Else 
IF ipc_ruletype EQ "SOAMMEND" 
THEN DO:
	assign 
	lvc_name = ""
	lvc_payterm = "".

	FIND FIRST usrw_wkfl					 
		 WHERE RECID(usrw_wkfl) EQ ipr_recid
	NO-LOCK NO-ERROR.
	IF AVAILABLE usrw_wkfl
	THEN DO:
	
     /*CVC0463-41 - Start*/
	 ASSIGN 
		lvd_totavgcost 	 	= 0
		lvd_totrxlpurcost   = 0
		lvd_avgcostmargin   = 0.
	  
     FOR EACH busrw_wkfl
		WHERE busrw_wkfl.usrw_domain  = global_domain
		AND   busrw_wkfl.usrw_key1    = "SO_AMMEND_Line"
		and   usrw_wkfl.usrw_key3     = usrw_wkfl.usrw_key2
		NO-LOCK:
		ASSIGN lvd_tmpavgcost = 0.
		
		FOR FIRST sct_det
			WHERE sct_domain = global_domain 	AND
				  sct_sim    = "Average"	AND
				  sct_part	 = busrw_wkfl.usrw_charfld[2]		AND
				  sct_site	 = usrw_wkfl.usrw_charfld[4]
			NO-LOCK:
			ASSIGN lvd_tmpavgcost = sct_det.sct_cst_tot.
		END.
				
		ASSIGN 
			lvd_totavgcost 		= lvd_totavgcost 	+ ROUND(lvd_tmpavgcost * busrw_wkfl.usrw_decfld[1] ,2)
			lvd_totrxlpurcost 	= lvd_totrxlpurcost + ROUND(busrw_wkfl.usrw_decfld[5] * busrw_wkfl.usrw_decfld[1] ,2).
	 END.
	 
	 ASSIGN lvd_avgcostmargin = ROUND((((DECIMAL(usrw_wkfl.usrw_charfld[9]) - lvd_totavgcost) / DECIMAL(usrw_wkfl.usrw_charfld[9])) * 100),2).
	 /*CVC0463-41 - End*/
	
 	 lvc_filename1 = lvc_filename1 + usrw_wkfl.usrw_key2 + ".txt".
	 lvc_filename2 = lvc_filename2 + usrw_wkfl.usrw_key2 + ".txt".
		run getsummary (usrw_wkfl.usrw_charfld[1]).
	 find first debtor where debtor.debtorcode = usrw_wkfl.usrw_charfld[1] no-lock no-error.
		if available debtor then do:
			find first ad_mstr where ad_domain = global_domain
			   and ad_addr = debtor.debtorcode no-lock no-error.
			if available ad_mstr then 
			lvc_name = ad_name.
			find first PaymentCondition where PaymentCondition_ID = debtor.NormalPaymentCondition_ID no-lock no-error.
			if available PaymentCondition then 
			assign 
			  lvc_payterm = PaymentCondition.PaymentConditionCode + "(" + PaymentCondition.PaymentConditionDesc + ")".
		end.
	 for first ad_mstr where ad_domain = global_domain
		and ad_addr = usrw_wkfl.usrw_charfld[13]  no-lock,
		first businessrelation where businessrelation.businessrelationcode = ad_bus_rel no-lock,
		first address of businessrelation no-lock:
		assign
		   lvc_slsname = ad_mstr.ad_name /* + "-" + Address.Addressemail */
		   lvc_ccemail = Address.Addressemail.
	 end. 

	 
	 /*CVC0463-66-Start*/
	 FIND FIRST usr_mstr
		 WHERE usr_userid = usrw_wkfl.usrw_charfld[12]
	 NO-LOCK NO-ERROR.
	 IF AVAILABLE usr_mstr AND TRIM(usr_mstr.usr_mail_address) <> ""
	 THEN DO:
		if lvc_ccemail = "" then 
			lvc_ccemail = usr_mstr.usr_mail_address.
		else 
			lvc_ccemail = lvc_ccemail + ";" + usr_mstr.usr_mail_address.
	 END.
	 /*CVC0463-66-End*/

  output to value (lvc_filename2).
   put unformatted
   lvc_header skip
   "- Sales Order Number:" usrw_wkfl.usrw_key2  skip
   "- Customer Name:" lvc_name skip
   "- Total Customer Price:" usrw_wkfl.usrw_charfld[9] SKIP
   "- Total Rexel Purchase Cost:" STRING(lvd_totrxlpurcost) skip												/*CVC0463-41*/
   "- Margin based on Purchase Cost - INR:" STRING(DECIMAL(usrw_wkfl.usrw_charfld[9]) - lvd_totrxlpurcost) skip	/*CVC0463-119*/
   "- Margin based on Purchase Cost - %:" usrw_wkfl.usrw_charfld[10] "%" skip									/*CVC0463-41*/
   "- Total Average Cost:" STRING(lvd_totavgcost) skip															/*CVC0463-41*/
   "- Margin based on Average Cost - INR:" STRING(DECIMAL(usrw_wkfl.usrw_charfld[9]) - lvd_totavgcost) skip		/*CVC0463-119*/
   "- Margin based on Average Cost - %:" STRING(lvd_avgcostmargin) "%" skip										/*CVC0463-41*/
   "- Credit Term:" lvc_payterm skip
   "- Business Line:" usrw_wkfl.usrw_charfld[3] skip
   "- Sales Person Name:" lvc_slsname skip 
   "- Site:" usrw_wkfl.usrw_charfld[4] skip(1) .

   find first ttsummary no-lock no-error.
   if available ttsummary then do:
	   put unformatted
	   "**Credit Information**" skip(1)
       "- Current Outstanding:" ttsummary_current skip
       "- 1-30 Days Outstanding:" ttsummary_D1_30 skip
       "- 31-60 Days Outstanding:" ttsummary_D31_60 skip
       "- 61-90 Days Outstanding:" ttsummary_D61_90 skip
       "- 91-180 Days Outstanding:" ttsummary_D91_180 skip
       "- Total Outstanding:" ttsummary_openItem skip(1).
   end.
   put unformatted
   "**Approval History**" skip(1).
   for each xxdoah_hist where xxdoah_domain = global_domain and xxdoah_nbr = usrw_wkfl.usrw_key2 no-lock break by xxdoah_DateTime descending:
   put unformatted
   "- " upper(trim(substring(xxdoah_currappr,1,(index(xxdoah_currappr,".") - 1))))  + " " + Upper(trim(substring(xxdoah_currappr,index(xxdoah_currappr,".") + 1, index(xxdoah_currappr,"@") - index(xxdoah_currappr,".") - 1))) + " | " 
   +  trim(xxdoah_DateTime) + " | " + trim(xxdoah_Comment) skip.
   end.	
   output close.
   

		output to value (lvc_filename1).
	 /* Table stytling */
	 put unformatted
	 "<head>
	  <style>
	  table, th, td ~{
	  border: 1px solid black;
	  color:Black;	
	  background:LightGrey;
	  ~}
	  .buttonGreen ~{
		background-color: Green;
		border: none;
		color: white;
		padding: 15px 32px;
		text-align: center;
		text-decoration: none;
		display: inline-block;
		font-size: 16px;
		margin: 4px 2px;
		cursor: pointer;
	  ~}
	  .buttonRed ~{
		background-color: Red;
		border: none;
		color: white;
		padding: 15px 32px;
		text-align: center;
		text-decoration: none;
		display: inline-block;
		font-size: 16px;
		margin: 4px 2px;
		cursor: pointer;
	  ~}
	  .buttonOrange ~{
            background-color: Orange;
            border: none;
            color: white;
            padding: 15px 32px;
            text-align: center;
            text-decoration: none;
            display: inline-block;
            font-size: 16px;
            margin: 4px 2px;
            cursor: pointer;
          ~}
	 </style>
	 </head>".
  
	put unformatted
	 "<h3>Quotation Details:</h3><br>"
	 "<table style='width:100%'>"
	  .
	put unformatted
	"<tr>
	<td>Sales Order Number</td><td>"
	usrw_wkfl.usrw_key2
	"</td></tr><tr><td>Customer Name</td><td>"
	lvc_name
	"</td></tr><tr><td>Total Customer Price</td><td>"
	usrw_wkfl.usrw_charfld[9]
	"</td></tr><tr><td>Total Rexel Purchase Cost</td><td>"						/*CVC0463-41*/
	STRING(lvd_totrxlpurcost)													/*CVC0463-41*/
	"</td></tr><tr><td>Margin based on Purchase Cost - INR</td><td>"			/*CVC0463-119*/
	STRING(DECIMAL(usrw_wkfl.usrw_charfld[9]) - lvd_totrxlpurcost)				/*CVC0463-119*/
	"</td></tr><tr><td>Margin based on Purchase Cost - %</td><td>"				/*CVC0463-41*/
	usrw_wkfl.usrw_charfld[10] + " %"											/*CVC0463-41*/
	"</td></tr><tr><td>Total Average Cost</td><td>"								/*CVC0463-41*/
	STRING(lvd_totavgcost)														/*CVC0463-41*/
	"</td></tr><tr><td>Margin based on Average Cost - INR</td><td>"				/*CVC0463-119*/
	STRING(DECIMAL(usrw_wkfl.usrw_charfld[9]) - lvd_totavgcost)					/*CVC0463-119*/
	"</td></tr><tr><td>Margin based on Average Cost - %</td><td>"				/*CVC0463-41*/
	STRING(lvd_avgcostmargin) + " %"											/*CVC0463-41*/
	"</td></tr><tr><td>Credit Terms</td><td>"
	lvc_payterm
	"</td></tr><tr><td>Business Line</td><td>"
    usrw_wkfl.usrw_charfld[3]
    "</td></tr><tr><td>Sales Person Name</td><td>"
    lvc_slsname
	"</td></tr><tr><td>Site</td><td>"
	usrw_wkfl.usrw_charfld[4]
    "</td></tr>"
	"</table>".

	 put unformatted
	 "<h3>Additional Remarks:</h3><br>"
	 "<table style='width:100%'>
	   <tr>
	   <th>Current Outstanding</th>
	   <th>1-30 Days Outstanding</th>
	   <th>31-60 Days Outstanding</th>
	   <th>61-90 Days Outstanding</th>
	   <th>91-180 Days Outstanding</th>
	   <th>Total Outstanding</th>
	   </tr>".
	for each ttsummary :
	  put unformatted
	  "<tr>
	  <td>"
	  string(ttsummary_current) 
	  "</td><td>"
	  string(ttsummary_D1_30)
	  "</td><td>"
	  string(ttsummary_D31_60)
	  "</td><td>"
	  string(ttsummary_D61_90)
	  "</td><td>"
	  string(ttsummary_D91_180)
	  "</td><td>"
	  string(ttsummary_openItem)
	  "</td></tr>".
	end.  
	put unformatted
		"</table>".
	 put unformatted
	 "<h3>Approval Summary:</h3><br>"
	 "<table style='width:100%'>
	   <tr>
	   <th>Action</th>
	   <th>User Email</th>
	   <th>Date Time</th>
	   <th>Remarks</th>
	   </tr>".

		for each xxdoah_hist where xxdoah_domain = global_domain and xxdoah_nbr = usrw_wkfl.usrw_key2 no-lock break by xxdoah_DateTime descending:
		   
		   put unformatted
		   "<tr>
		   <td>"
		   trim(xxdoah_Action)
		   "</td><td>"
		   upper(trim(substring(xxdoah_currappr,1,(index(xxdoah_currappr,".") - 1))))  + " " + Upper(trim(substring(xxdoah_currappr,index(xxdoah_currappr,".") + 1, index(xxdoah_currappr,"@") - index(xxdoah_currappr,".") - 1)))
		   "</td><td>"
		   trim(xxdoah_DateTime)
		   "</td><td>"
		   trim(xxdoah_Comment)
		   "</td></tr>".
		end.
		put unformatted
		"</table>".
		output close.
		
		EmailBodyJson:ADD('ApprovalDocument',usrw_wkfl.usrw_key2). 
	 EmailBodyJson:ADD('CCEmail',lvc_ccemail). 
	
		ASSIGN 
		lvc_mailsubject = IF ipc_ruletype BEGINS "SOAMMEND" THEN ("Sales Order Modification Is Created For Approval " + usrw_wkfl.usrw_key2) Else ""
		lvc_ccsubject = IF ipc_ruletype BEGINS "SOAMMEND" THEN ("Sales Order " + usrw_wkfl.usrw_key2 + " is in approval process") Else "".
	END.
	ELSE DO:
		DELETE OBJECT EmailBodyJson NO-ERROR.
		DELETE OBJECT EmailBodyTextData NO-ERROR.
		
		ASSIGN opc_errorMsg = "Record Not Found".
		RETURN.
	END.
END.

ELSE 
IF ipc_ruletype EQ "DCREL" 
THEN DO:
	assign 
	lvc_name = ""
	lvc_payterm = "".

	FIND FIRST xxrtdc_mstr					 
		 WHERE RECID(xxrtdc_mstr) EQ ipr_recid
	NO-LOCK NO-ERROR.
	IF AVAILABLE xxrtdc_mstr
	THEN DO:
	 IF ipc_ruletype EQ "DCREL" THEN
		lvc_header = "New Delivery Challan is created.".

	 for each code_mstr where code_domain = global_domain
		and code_fldname = "mdm_attachments" no-lock:
		if lvc_dir = "" then 
		   lvc_dir = code_cmmt.
		else
		   lvc_dir =  lvc_dir + code_cmmt.
	 end.
	 if lvc_dir <> "" then do:
		lvc_filename = xxrtdc_mstr.xxrtdc_nbr + ".zip".

	   for each docd_det where docd_app_id = "mfg" and docd_context = "INDIA" + "_" and (docd_program = "rtdc_" or docd_program = "xxrtdcmt.p_") 
		  and docd_field_value begins "l_dc_no" no-lock,
		  each doc_mstr where doc_mstr.oid_doc_mstr = docd_det.oid_doc_mstr no-lock:
		   if lvc_attachment = "" then 
			   lvc_attachment =  '"' + doc_filename + '"'.
		   else 
			   lvc_attachment = lvc_attachment + ' "' + doc_filename + '"'.
		 
		   lvc_copy = 'cp "' + lvc_dir + doc_location + "/" + doc_filename + '" .'.      
		   OS-COMMAND SILENT value (lvc_copy).   
	   end.
	 end.

	 if lvc_attachment <> "" then do:
	   lvc_zip_cmmd = "zip -m " + lvc_filename + " " + lvc_attachment. 
	   OS-COMMAND SILENT value(lvc_zip_cmmd).  
	 end.

	 lvc_filename1 = lvc_filename1 + xxrtdc_nbr + ".txt".
	 lvc_filename2 = lvc_filename2 + xxrtdc_nbr + ".txt".
	
	find first ad_mstr where ad_domain = global_domain
		and ad_addr = xxrtdc_mstr.xxrtdc_cust no-lock no-error.
	if available ad_mstr then 
	lvc_name = ad_name.

	for first ad_mstr where ad_domain = global_domain
        and ad_addr = xxrtdc_mstr.xxrtdc_sp no-lock,
        first businessrelation where businessrelation.businessrelationcode = ad_bus_rel no-lock,
        first address of businessrelation no-lock:
         assign
		    lvc_requestor = ad_mstr.ad_name + "-" + Address.Addressemail 
            lvc_ccemail =  Address.Addressemail .
    end.
    if xxrtdc_mstr.xxrtdc_chr02 <> "" then do:
		if lvc_ccemail = "" then 
		lvc_ccemail = xxrtdc_mstr.xxrtdc_chr02 .
		else 
		lvc_ccemail = lvc_ccemail + "," + xxrtdc_mstr.xxrtdc_chr02 .
	end.
	find first usr_mstr where usr_mstr.usr_userid = xxrtdc_mstr.xxrtdc_chr05 no-lock no-error.
	if available usr_mstr and usr_mstr.usr_mail_address <> "" then do:
		if lvc_ccemail = "" then 
		lvc_ccemail = usr_mstr.usr_mail_address .
		else 
		lvc_ccemail = lvc_ccemail + "," + usr_mstr.usr_mail_address .
	end.
    assign 
		lvd_costtot = 0
		lvd_cost = 0
		lvd_pricetot = 0.
	for each xxrtdcd_det where xxrtdcd_domain = global_domain
	and xxrtdcd_nbr = xxrtdc_nbr no-lock:
		find first sct_det where sct_domain = global_domain
		   and sct_sim = "Average"
		   and sct_part = xxrtdcd_part
		   and sct_site = xxrtdc_site no-lock no-error.
		if available sct_det then do:
			lvd_costtot = lvd_costtot + (sct_cst_tot * xxrtdcd_qty).
		end.
		lvd_pricetot = lvd_pricetot + (xxrtdcd_lprice * xxrtdcd_qty).
	end.

  	output to value (lvc_filename2).
   	put unformatted
   	lvc_header skip
   	"- Challan Number:" xxrtdc_mstr.xxrtdc_nbr skip
   	"- Customer Name:" lvc_name skip
   	"- Business Line:" xxrtdc_mstr.xxrtdc_chr10 skip
   	"- Sales Person Name:" lvc_requestor skip
	"- Cost Total:" lvd_costtot skip
	"- DC Total:" lvd_pricetot skip 
   	"- Site:" xxrtdc_mstr.xxrtdc_site skip(1) .
	put unformatted
	   "**Detail Information**" skip(1).
       
   for each xxrtdcd_det where xxrtdcd_domain = global_domain
   	and xxrtdcd_nbr = xxrtdc_nbr no-lock:
		lvd_cost = 0.
		find first sct_det where sct_domain = global_domain
		   and sct_sim = "Average"
		   and sct_part = xxrtdcd_part
		   and sct_site = xxrtdc_site no-lock no-error.
		if available sct_det then
			lvd_cost = sct_cst_tot.
		else 
			lvd_cost  = 0.

	   put unformatted
	   "- Item Number:" xxrtdcd_part skip
       "- Quantity:" xxrtdcd_qty skip
       "- Due Date:" xxrtdcd_dudt skip
	   "- Expected Return Date:" xxrtdcd_dt03 skip
       "- DC Price:" xxrtdcd_lprice skip
	   "- Item Cost:" lvd_cost skip
	   "- Purpose Of DC:" xxrtdcd_purpose skip.
   end.
   put unformatted
   "**Approval History**" skip(1).
   for each xxdoah_hist where xxdoah_domain = global_domain and xxdoah_nbr = xxrtdc_nbr no-lock break by xxdoah_DateTime descending:
   put unformatted
   "- " upper(trim(substring(xxdoah_currappr,1,(index(xxdoah_currappr,".") - 1))))  + " " + Upper(trim(substring(xxdoah_currappr,index(xxdoah_currappr,".") + 1, index(xxdoah_currappr,"@") - index(xxdoah_currappr,".") - 1))) + " | " 
   +  trim(xxdoah_DateTime) + " | " + trim(xxdoah_Comment) skip.
   end.	
   output close.
   

	output to value (lvc_filename1).
	 /* Table stytling */
	 put unformatted
	 "<head>
	  <style>
	  table, th, td ~{
	  border: 1px solid black;
	  color:Black;	
	  background:LightGrey;
	  ~}
	  .buttonGreen ~{
		background-color: Green;
		border: none;
		color: white;
		padding: 15px 32px;
		text-align: center;
		text-decoration: none;
		display: inline-block;
		font-size: 16px;
		margin: 4px 2px;
		cursor: pointer;
	  ~}
	  .buttonRed ~{
		background-color: Red;
		border: none;
		color: white;
		padding: 15px 32px;
		text-align: center;
		text-decoration: none;
		display: inline-block;
		font-size: 16px;
		margin: 4px 2px;
		cursor: pointer;
	  ~}
	  .buttonOrange ~{
            background-color: Orange;
            border: none;
            color: white;
            padding: 15px 32px;
            text-align: center;
            text-decoration: none;
            display: inline-block;
            font-size: 16px;
            margin: 4px 2px;
            cursor: pointer;
          ~}
	 </style>
	 </head>".
  
	put unformatted
	 "<h3>Challan Details:</h3><br>"
	 "<table style='width:100%'>
	  <tr>
	  <th>Challan Number</th>
	  <th>Customer Name</th>
	  <th>Business Line</th>
	  <th>Sales Person</th>
	  <th>Site</th>
	  <th>Cost Total</th>
	  <th>DC Total</th>
	  </tr>"
	  .
	put unformatted
		"<tr>
		<td>"
		trim(xxrtdc_mstr.xxrtdc_nbr)
		"</td><td>"
		upper(trim(lvc_name)) 
		"</td><td>"
		trim(xxrtdc_mstr.xxrtdc_chr10)
		"</td><td>"
		trim(lvc_requestor)
		"</td><td>"
		trim(xxrtdc_mstr.xxrtdc_site)
		"</td><td>"
		lvd_costtot
		"</td><td>"
		lvd_pricetot
		"</td></tr>"
		"</table>".

	put unformatted
		"<h3>Challan Line Detail:</h3><br>"
		"<table style='width:100%'>
		  <tr>
		  <th>Item Number</th>
		  <th>Quantity</th>
		  <th>DC Unit Price</th>
		  <th>Item Cost</th>
		  <th>Due Date</th>
		  <th>Expected Return Date</th>
		  <th>Purpose Of DC </th>
		  </tr>".
	
	for each xxrtdcd_det where xxrtdcd_domain = global_domain
	and xxrtdcd_nbr = xxrtdc_nbr no-lock:
		lvd_cost = 0.
		find first sct_det where sct_domain = global_domain
		   and sct_sim = "Average"
		   and sct_part = xxrtdcd_part
		   and sct_site = xxrtdc_site no-lock no-error.
		if available sct_det then
			lvd_cost = sct_cst_tot.
		else 
			lvd_cost  = 0.
		put unformatted
		   "<tr>
		   <td>"
		   trim(xxrtdcd_part)
		   "</td><td>"
		   xxrtdcd_qty
		   "</td><td>"
		   xxrtdcd_lprice
		   "</td><td>"
		   lvd_cost
		   "</td><td>"
		   xxrtdcd_dudt
		   "</td><td>"
		   xxrtdcd_dt03
		   "</td><td>"
		   xxrtdcd_purpose
		   "</td></tr>".
	end .
	put unformatted
	"</table>".
	 put unformatted
	 "<h3>Approval Summary:</h3><br>"
	 "<table style='width:100%'>
	   <tr>
	   <th>Action</th>
	   <th>User Email</th>
	   <th>Date Time</th>
	   <th>Remarks</th>
	   </tr>".

		for each xxdoah_hist where xxdoah_domain = global_domain and xxdoah_nbr = xxrtdc_nbr no-lock break by xxdoah_DateTime descending:
		   
		   put unformatted
		   "<tr>
		   <td>"
		   trim(xxdoah_Action)
		   "</td><td>"
		   upper(trim(substring(xxdoah_currappr,1,(index(xxdoah_currappr,".") - 1))))  + " " + Upper(trim(substring(xxdoah_currappr,index(xxdoah_currappr,".") + 1, index(xxdoah_currappr,"@") - index(xxdoah_currappr,".") - 1)))
		   "</td><td>"
		   trim(xxdoah_DateTime)
		   "</td><td>"
		   trim(xxdoah_Comment)
		   "</td></tr>".
		end.
		put unformatted
		"</table>".
		output close.
		
		EmailBodyJson:ADD('ApprovalDocument',xxrtdc_nbr). 
		EmailBodyJson:ADD('CCEmail',lvc_ccemail). 
	
		ASSIGN 
		lvc_mailsubject = IF ipc_ruletype BEGINS "DCREL" THEN ("Delivery Challan Created For Approval " + xxrtdc_nbr) Else ""
		lvc_ccsubject = IF ipc_ruletype BEGINS "DCREL" THEN ("Delivery Challan " + xxrtdc_nbr + " is in approval process") Else "".
	END.
	ELSE DO:
		DELETE OBJECT EmailBodyJson NO-ERROR.
		DELETE OBJECT EmailBodyTextData NO-ERROR.
		
		ASSIGN opc_errorMsg = "Record Not Found".
		RETURN.
	END.
END.

ELSE DO:
    DELETE OBJECT EmailBodyJson NO-ERROR.
    DELETE OBJECT EmailBodyTextData NO-ERROR.
    
    ASSIGN opc_errorMsg = "Email config for rule type '" + ipc_ruletype + "' is not defined".
    RETURN.
END.

EmailBodyJson:ADD('EmailSubject',lvc_mailsubject).
EmailBodyJson:ADD('EmailCCSubject',lvc_ccsubject).

EmailBodyJson:WriteFile(l_msgfilename,TRUE,"UTF-8").

ASSIGN lvc_notifyEmailID = "".

FOR EACH code_mstr 
    WHERE code_domain  EQ global_domain      AND
          code_fldname EQ "DOA_NOTIFICATION" AND
          code_value   NE ""
    NO-LOCK:
    IF code_value EQ "FLOW_EMAILID" 
    THEN
        ASSIGN lvc_notifyEmailID = TRIM(code_cmmt).
    ELSE
    IF code_value EQ "FLOW_EMAIL_TRIGGER_SUBJECT"  
    THEN
        ASSIGN lvc_flowtriggerSubject = TRIM(code_cmmt).
END.

if search(lvc_filename) <> ? then do:
    ASSIGN lvc_oscommand = "mailx -s '" + lvc_flowtriggerSubject + "' -a " + lvc_filename + " -a " + lvc_filename1 + " -a " + lvc_filename2 + " -r '" + lvc_notifyEmailID + "' " + lvc_notifyEmailID + " < " + l_msgfilename.
end.
else
   ASSIGN lvc_oscommand = "mailx -s '" + lvc_flowtriggerSubject + "' -a " + lvc_filename1 + " -a " + lvc_filename2 + " -r '" + lvc_notifyEmailID + "' " + lvc_notifyEmailID + " < " + l_msgfilename.  

OS-COMMAND SILENT VALUE(lvc_oscommand).	

OS-DELETE value (lvc_filename) no-error.
OS-DELETE VALUE(l_msgfilename) NO-ERROR.
OS-DELETE value (lvc_filename1) no-error.
OS-DELETE value (lvc_filename2) no-error.

DELETE OBJECT EmailBodyJson NO-ERROR.

procedure getsummary:
	define input parameter ip_cust  as character no-undo.
	define variable invamt          as decimal format "->>,>>>,>>9.99".
	define variable payamt          as decimal format "->>,>>>,>>9.99".
	define variable vatamt          as decimal format "->>,>>>,>>9.99".      
	define variable c_companycode   as character init "REXELIND".
	define variable c_selectedDate  as date init today.
	define variable c_toGLYear      as integer .
	define variable c_toGLPeriod    as integer.
	define variable c_toGLDate      as date.
	define variable c_AgePrepayment as logical initial yes.
	define variable l_current as decimal initial 0.
	define variable l_openitem as decimal initial 0.
	define variable l_D1_30 as decimal initial 0 format "->>,>>>,>>9.99".
	define variable l_D31_60 as decimal initial 0.
	define variable l_D61_90 as decimal initial 0.
	define variable l_D91_180 as decimal initial 0.
	define variable emonth as character initial "".
	define variable eyear as character initial "".

	if month(today) = 12 then 
	assign 
	   emonth = "01"
	   eyear = string(year(today) + 1).
    else 
	assign
	   emonth = string(month(today) + 1)
	   eyear = string(year(today)).
	/*   
	find first period where periodstartdate >= date(string(month(today)) + "/01/" + string(year(today)))
	   and periodenddate < date(emonth + "/01/" + eyear) no-lock.
	if available period then
	assign
	   c_toGLPeriod = period.periodperiod
	   c_toGLYear = period.periodyear.
    */
	assign
	   c_toGLPeriod = month(today)
	   c_toGLYear = year(today).
	if c_toGLPeriod = 12 then
		c_toGLDate = date(c_toGLPeriod,31,c_toGLYear) no-error.
	else
		c_toGLDate = date(c_toGLPeriod + 1,01,c_toGLYear) - 1 no-error.
	
	find first Debtor where Debtor.Debtorcode = ip_cust no-lock no-error.
	
	for each company where company.companycode = c_companycode no-lock,
	   each Dinvoice of company where Dinvoice.Debtor_ID = Debtor.Debtor_ID 
	   and DInvoice.DInvoiceClosingDate > c_selectedDate
	   and DInvoice.DInvoicePostingDate <= c_selectedDate no-lock:
	
	   find first journal of Dinvoice no-lock no-error.
	   Create ttDInvoice.
	   assign
		   ttDInvoice.DebtorCode     = Debtor.DebtorCode 
		   ttDInvoice.OverDue        = c_selecteddate - DInvoice.DinvoiceDueDate.
		  
		payamt = 0.
		vatamt = 0.
	
	
		for each DInvoiceMovement no-lock of DInvoice
		, each PostingLine no-lock of DinvoiceMovement where DInvoiceMovementType <> "Initial"
		and PostingLine.PostingDate <= c_toGLDate:
		
			payamt = payamt + PostingLineCreditTC - PostingLineDebitTC.
			vatamt = vatamt + ((PostingLineCreditTC - PostingLineDebitTC)
				  * (DInvoice.DInvoiceVatCreditTC - DInvoice.DInvoiceVatDebitTC)
				  / (DInvoice.DInvoiceOriginalDebitTC - DInvoice.DInvoiceOriginalCreditTC)).
		end.
		invamt = (DInvoice.DInvoiceOriginalDebitTC - DInvoice.DInvoiceOriginalCreditTC)
				- payamt.
				
		ttDInvoice.TCGSTAmt = (DInvoice.DInvoiceVatCreditTC
				- DInvoice.DInvoiceVatDebitTC) - vatamt.
	
		if c_AgePrePayment = no and
			(DInvoice.DInvoiceType = "PREPAYMENT" or
			DInvoice.DInvoiceType = "ADJUSTMENT") then do:
			ttDInvoice.CurrentVal = invamt.
		end.
		else do:
			if journal.journalcode <> "RET" then do:
				if ttDInvoice.OverDue <= 0 then
				ttDInvoice.CurrentVal = invamt.
				else if ttDInvoice.OverDue <= 30 then
				ttDInvoice.D1_30      = invamt.
				else if ttDInvoice.OverDue <= 60 then
				ttDInvoice.D31_60     = invamt.
				else if ttDInvoice.OverDue <= 90 then
				ttDInvoice.D61_90     = invamt.
				else if ttDInvoice.OverDue <= 180 then
				ttDInvoice.D91_180    = invamt.
				else if ttDInvoice.OverDue <= 270 then
				ttDInvoice.D181_270   = invamt.
				else if ttDInvoice.OverDue <= 365 then
				ttDInvoice.D271_365   = invamt.
				else
				ttDInvoice.over365   = invamt.
			end. /* journalCode <> RET */
			else do:
				ttDInvoice.Ret = invamt.
			end.
		end.
		assign
			ttDInvoice.OpenItem   = invamt.
			ttDInvoice.TotalPD = ttDInvoice.OpenItem - ttDInvoice.CurrentVal - ttDInvoice.Ret.
	end.
	for each ttDInvoice break by ttDinvoice.DebtorCode:
	 
	   assign
		   l_current    = l_current  + ttDinvoice.CurrentVal
		   l_openitem   = l_openitem +  ttDinvoice.OpenItem
		   l_D1_30      = l_D1_30  + ttDinvoice.D1_30
		   l_D31_60     = l_D31_60 + ttDinvoice.D31_60
		   l_D61_90     = l_D61_90 + ttDinvoice.D61_90
		   l_D91_180    = l_D91_180 +  ttDinvoice.D91_180. 
	
	    if last-of(ttDinvoice.DebtorCode) then do:
	    	
	       create ttsummary.
	       assign
	    	  ttsummary_current   = l_current 
	    	  ttsummary_D1_30    = l_D1_30
	    	  ttsummary_D31_60   = l_D31_60   
	    	  ttsummary_D61_90   = l_D61_90  
	    	  ttsummary_D91_180  = l_D91_180 
	    	  ttsummary_openItem = l_openitem .
	    end.
	
	end.
	end procedure.
	
	
	