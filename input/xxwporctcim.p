/**************************************************************************************************************/
/*Program Name- 	xxporcvd.p                                                                                */
/*Created By- 		JKT                                                                                       */ 
/*Created Date- 	19-Novemeber-2019                                                                         */
/*Called Procedure- 	                                                                                      */
/*Called By Procedure-  xxporcvd.p                                                                            */
/*References(ECO)-	xxwporctcim.p - 5.13.1 (po receipt)                                                       */
/*                                                                                                            */
/*                                                                                                            */
/**************************************************************************************************************/


{us/mf/mfdtitle.i}
DEFINE VARIABLE m_po LIKE po_mstr.po_nbr NO-UNDO.
DEFINE VARIABLE m_pck AS CHARACTER NO-UNDO LABEL "Packing Slip".
DEFINE VARIABLE m_rcvr LIKE prh_hist.prh_receiver NO-UNDO.
DEFINE VARIABLE m_line LIKE pod_det.pod_line NO-UNDO.
DEFINE VARIABLE m_dline AS CHARACTER  NO-UNDO.
DEFINE VARIABLE m_dqty AS CHARACTER  NO-UNDO.
DEFINE VARIABLE m_dcost AS CHARACTER  NO-UNDO.
DEFINE VARIABLE m_dpart LIKE pod_det.pod_part NO-UNDO.
DEFINE VARIABLE m_qty  LIKE pod_det.pod_qty_rcvd NO-UNDO.
DEFINE VARIABLE m_site LIKE si_mstr.si_site NO-UNDO.
DEFINE VARIABLE m_loc  LIKE loc_mstr.loc_loc NO-UNDO.
DEFINE VARIABLE m_lot  LIKE ld_det.ld_lot NO-UNDO.
DEFINE VARIABLE m_itm_stat AS CHARACTER NO-UNDO.
DEFINE VARIABLE ip_str AS CHARACTER NO-UNDO.
DEFINE VARIABLE m_err AS CHARACTER NO-UNDO.
DEFINE VARIABLE l_msg AS CHARACTER NO-UNDO.
DEFINE VARIABLE first_ps_call AS LOGICAL INIT TRUE NO-UNDO.
DEFINE VARIABLE work_recno AS RECID NO-UNDO.
DEFINE VARIABLE l_cnf AS LOGICAL.
define variable l_mail as char no-undo.
DEFINE VARIABLE l_user as char no-undo.
define variable l_site like pod_site no-undo.

DEFINE TEMP-TABLE tt_po
  FIELD tt_po       LIKE po_mstr.po_nbr
  FIELD tt_part     LIKE pod_det.pod_part
  FIELD tt_line     LIKE pod_det.pod_line
  FIELD tt_ord_qty  LIKE pod_det.pod_qty_ord
  FIELD tt_opn_qty  LIKE pod_det.pod_qty_rcvd
  FIELD tt_cost     LIKE pod_det.pod_pur_cost
  FIELD tt_qty      LIKE pod_det.pod_qty_rcvd
  FIELD tt_site     LIKE si_mstr.si_site
  FIELD tt_loc      LIKE loc_mstr.loc_loc
  FIELD tt_lot      LIKE ld_det.ld_lot
  FIELD tt_lotc     AS LOGICAL
  FIELD tt_cnf      AS CHARACTER LABEL "CNF" format "x(3)"
  FIELD tt_add      AS LOGICAL LABEL "Sel" INITIAL NO
  field tt_chr02    AS CHARACTER LABEL "Dead"
  field tt_chr07    like pod_det.pod__chr07.
  
FORM 
  m_po COLON 20
  m_pck COLON 60
  m_rcvr COLON 20
  WITH FRAME hdr WIDTH 80 SIDE-LABELS.
  
FORM 
  tt_po.tt_po   COLON 20
  tt_po.tt_line COLON 20
  tt_po.tt_qty  COLON 20
  tt_po.tt_site COLON 50 
  tt_po.tt_loc  COLON 20
  tt_po.tt_lot  COLON 50
  WITH FRAME lne WIDTH 80 SIDE-LABELS.

FUNCTION getdeaditem returns CHARACTER (input i_part as char) :
   
   DEFINE VARIABLE l_deaditem AS char.
   DEFINE VARIABLE l_deadso AS char.
   DEFINE VARIABLE l_deadship AS char.
   DEFINE VARIABLE l_deadstatus AS char.
               
   l_deadstatus = "".
   l_deadso = "".
   FIND LAST tr_hist WHERE tr_domain = global_domain AND tr_type = "ISS-SO" 
      AND tr_part = i_part  NO-LOCK NO-ERROR.   
   IF AVAILABLE tr_hist THEN DO:
      IF tr_effdate > today - 364 then
         l_deadstatus = "NODEADITEM" .
      else do:
          for each sod_det no-lock where sod_domain = global_domain and sod_part = i_part
                          and (sod_qty_ord - sod_qty_ship) > 0 :
              find first so_mstr WHERE so_domain = sod_domain AND so_nbr = sod_nbr NO-LOCK NO-ERROR.
              if avail so_mstr then do:
                 if so_ord_date > (today - 364) then do:
                    assign 
                       l_deadstatus = "NODEADITEM" 
                       l_deadso = "NODEADSO".
                    leave.
                 end.       
              end.       
          end.
          if l_deadso <> "NODEADSO" then do:
             find first pt_mstr NO-LOCK WHERE pt_domain = global_domain AND pt_part = i_part AND pt_added < (TODAY - 364) NO-ERROR.
             IF AVAILABLE  pt_mstr THEN
                l_deadstatus = "DEADITEM" .
             else
                l_deadstatus = "NODEADITEM" .
          end.
      end.
   end.       
   else do:
       for each sod_det no-lock where sod_domain = global_domain and sod_part = i_part
                       and (sod_qty_ord - sod_qty_ship) > 0 :
          find first so_mstr WHERE so_domain = sod_domain AND so_nbr = sod_nbr NO-LOCK NO-ERROR.
          if avail so_mstr then do:
             if so_ord_date > (today - 364) then do:
               assign 
                  l_deadstatus = "NODEADITEM" 
                  l_deadso = "NODEADSO".
               leave.
             end.       
          end.       
       end.
       if l_deadso <> "NODEADSO" then do:
          find first pt_mstr NO-LOCK WHERE pt_domain = "INDIA" AND pt_part = i_part AND pt_added < (TODAY - 364) NO-ERROR.
          IF AVAILABLE  pt_mstr THEN
             l_deadstatus = "DEADITEM" .
          else
             l_deadstatus = "NODEADITEM" .
       end.
   end.     
   RETURN l_deadstatus.   
END FUNCTION.

mainloop:  
REPEAT:
  ASSIGN 
    m_po = ""
    m_pck = ""
    m_rcvr = ""
    m_dpart = ""
    m_dline = ""
    m_dcost = ""
    m_dqty = ""
    m_itm_stat = ""
    l_user = ""
    l_site = "".
    
  EMPTY TEMP-TABLE tt_po.
  CLEAR FRAME lne ALL .
  HIDE FRAME lne.
  CLEAR FRAME b1 ALL .
  HIDE FRAME b1.
  
  UPDATE m_po VALIDATE(CAN-FIND(FIRST po_mstr WHERE po_domain = global_domain AND po_nbr = m_po NO-LOCK), "ERROR: Invalid PO Number. Please re-enter")
  WITH FRAME hdr WIDTH 80 SIDE-LABELS.
  m_rcvr = "".
  UPDATE m_pck 
  WITH FRAME hdr WIDTH 80 SIDE-LABELS.
  
  FOR EACH pod_det WHERE pod_domain = global_domain AND pod_nbr = m_po NO-LOCK:
    l_site = pod_site.
      CREATE tt_po.
      ASSIGN 
         tt_po      = pod_nbr
         tt_part    = pod_part
         tt_line    = pod_line
         tt_ord_qty = pod_qty_ord
         tt_opn_qty = (pod_qty_rcvd )
         tt_cost = pod_pur_cost
         tt_qty     = 0.0
         tt_site    = pod_site
         tt_loc     = pod_loc
         tt_lot     = ""
         tt_chr02   = pod__chr09
         tt_chr07   = pod__chr07.
      
      FIND FIRST pt_mstr WHERE pt_domain = global_domain AND pt_part = tt_part NO-LOCK NO-ERROR.
      IF AVAILABLE pt_mstr THEN
      DO:
          FIND FIRST si_mstr WHERE si_domain = global_domain AND si_site = tt_site NO-LOCK NO-ERROR.
          IF AVAILABLE si_mstr THEN
          DO:
              FIND FIRST pti_det WHERE pti_det.oid_pt_mstr = pt_mstr.oid_pt_mstr AND pti_det.oid_si_mstr = si_mstr.oid_si_mstr NO-LOCK NO-ERROR.
              IF AVAILABLE pti_det THEN
              DO:
                  IF pti_det.pti_lot_ser = 'l'THEN tt_lotc = YES.
                  ELSE tt_lotc = NO.
              END.
              ELSE
              DO:
                  IF pt_lot_ser = 'l'THEN tt_lotc = YES.
                  ELSE tt_lotc = NO.
              END.
          END.
      END.
      
  END.
  
  mainloop1:
  REPEAT ON ENDKEY UNDO, LEAVE mainloop1 : 
     {us/xx/xxatwsel.i
              &detfile      = tt_po
              &scroll-field = STRING(tt_po.tt_line)
              &framename    = "b1"
              &framesize    = 10
              &sel_on       = ""*""
              &sel_off      = """"
              &display1     = tt_po.tt_cnf
              &display2     = tt_po.tt_line
              &display3     = tt_po.tt_part
              &display4     = tt_po.tt_ord_qty
              &display5     = tt_po.tt_opn_qty
              &display6     = tt_po.tt_chr02
              &display7     = tt_po.tt_add
              &exitlabel    = mainloop1
              &exit-flag    = first_ps_call
              &record-id    = work_recno
          }  
     
     
     IF KEYFUNCTION(lastkey) = "GO" THEN DO:
        FOR EACH tt_po WHERE tt_cnf = "*" :
            IF tt_opn_qty = tt_ord_qty THEN
            DO:
                DISPLAY 
                  tt_po.tt_line
                  tt_po.tt_qty
                  tt_po.tt_site
                  tt_po.tt_loc
                  tt_po.tt_lot WITH FRAME lne WIDTH 80 SIDE-LABELS.
                tt_cnf = "".
                l_msg = "Line is closed for receiving".
                  {us/bbi/pxmsg.i 
                  &MSGNUM=2685
                  &MSGARG1=l_msg
                  &ERRORLEVEL = 3
                  }
                UNDO mainloop1, RETRY mainloop1.
                
            END.
                  
                  
                  
            DISPLAY 
                tt_po.tt_po
                tt_po.tt_line 
                tt_part WITH FRAME lne WIDTH 80 SIDE-LABELS.
            UPDATE     
                tt_po.tt_qty validate(can-find(first pod_det where pod_domain = global_domain 
                                                  and pod_nbr = tt_po.tt_po and pod_line = tt_po.tt_line
                                                  and (pod_qty_ord - pod_qty_rcvd) >= tt_po.tt_qty) and tt_po.tt_qty <> 0, 
                                                  "Qty can't zero or more than Qty ordered on Line" + " " + string(tt_line) + " " + ", Please re-enter")
                tt_po.tt_site VALIDATE(CAN-FIND(FIRST pod_det WHERE pod_domain = global_domain 
                                                    AND pod_nbr = tt_po.tt_po AND pod_line = tt_po.tt_line
                                                    AND pod_site = tt_po.tt_site), "ERROR: Invalid Site for the PO. Please re-enter")
                tt_po.tt_loc
                tt_po.tt_lot  VALIDATE(tt_lotc = NO OR tt_lot <> "" , "Lot/Serial number required.  Please re-enter." )
                WITH FRAME lne WIDTH 80 SIDE-LABELS.
             
             FIND FIRST pod_det WHERE pod_domain = global_domain AND pod_nbr =  tt_po.tt_po AND pod_line = tt_po.tt_line AND pod_site = tt_po.tt_site AND pod_loc = tt_po.tt_loc NO-LOCK NO-ERROR.
             IF NOT AVAILABLE pod_det THEN
             DO:
                FIND FIRST loc_mstr WHERE loc_domain = global_domain AND loc_site = tt_po.tt_site AND loc_loc = tt_po.tt_loc NO-LOCK NO-ERROR.
                IF NOT AVAILABLE loc_mstr THEN
                DO:
                    ASSIGN 
                      tt_cnf = "" 
                      tt_add = NO
                      tt_po.tt_loc = "".
                    l_msg = "Invalid site/location combination for line " + STRING(tt_po.tt_line).
                    {us/bbi/pxmsg.i 
                    &MSGNUM=2685
                    &MSGARG1=l_msg
                    &ERRORLEVEL = 3
                    }
                END.
                ELSE 
                   ASSIGN 
                    tt_cnf = "" 
                    tt_add = YES.
             END.
             ELSE
                  ASSIGN 
                    tt_cnf = "" 
                    tt_add = YES.
               
             
        END.
        IF KEYFUNCTION(LASTKEY) = "END-ERROR" THEN UNDO mainloop1, RETRY mainloop1.
     END.  
     IF KEYFUNCTION(LASTKEY) = "END-ERROR" THEN
     DO:
        l_msg = 'Is all information correct?'.
        {us/bbi/pxmsg.i 
            &MSGNUM=2685
            &CONFIRM=l_cnf
            &MSGARG1=l_msg
            &CONFIRM-TYPE='LOGICAL'
        }
        IF l_cnf THEN
        DO:
           FOR EACH tt_po no-LOCK WHERE tt_add = YES BREAK BY tt_add:
             m_itm_stat = getdeaditem(tt_part).
             IF m_itm_stat = "DEADITEM" AND (tt_chr02 = "YES" or date(entry(2,tt_chr07 ,"|")) <> today)  THEN
             DO:
                    if date(entry(2,tt_chr07 ,"|")) <> today then do:
                      find first pod_det exclusive-lock where pod_domain = global_domain 
                        and pod_nbr = tt_po.tt_po and pod_line = tt_line no-error.
                        if available pod_det then do:
                                                   
                            assign
                                pod__chr09 = "YES".
                               
                        END.  /*if available pod_det then do:*/
                                
                  end.  /*if date(entry(2,tt_chr07 ,"|")) <> today then do:*/
                 IF m_dpart = "" THEN
                   m_dpart = tt_part.
                 ELSE 
                   m_dpart = m_dpart + "," + tt_part. 
                   
                 IF m_dline = "" THEN
                   m_dline = STRING(tt_line).
                 ELSE 
                   m_dline = m_dline + "," + STRING(tt_line).
                 
                 IF m_dqty = "" THEN
                   m_dqty = STRING(tt_ord_qty).
                 ELSE 
                   m_dqty = m_dqty + "," + STRING(tt_ord_qty).
                 
                 IF m_dcost = "" THEN
                   m_dcost = STRING(tt_cost).
                 ELSE 
                   m_dcost = m_dcost + "," + STRING(tt_cost).
                 
             END.
             ELSE
             DO:
                 IF FIRST-OF(tt_add) THEN
                   ip_str = m_po + "|" + m_pck + "|".
                 
                 ip_str = ip_str + STRING(tt_line) + "|" + STRING(tt_qty) + "|" + "|" + "|" + "|" + "|" + "|" + tt_site + "|" + tt_loc + "|" + tt_lot + "|" + "|" + "|" + "|" + "|" + "|". 
             END.
             IF LAST-OF(tt_add) THEN
             DO:
               IF m_dpart <> ""  THEN
               DO:
                
                 
                   RUN mailx(INPUT tt_po, INPUT m_dline, INPUT m_dpart, INPUT m_dqty, INPUT m_dcost).
                   
                        l_msg = "Selection contains dead item.Kindly follow the approval process".
                     {us/bbi/pxmsg.i 
                     &MSGNUM=2685
                     &MSGARG1=l_msg
                     &ERRORLEVEL = 4
                     }
                     
                  //UNDO mainloop, RETRY mainloop.
                 
               END.
               ELSE 
               DO:   
                  {us/bbi/gprun.i ""xxwporct1a.p"" "(input ip_str , output m_err)"}
                   
                   IF ENTRY(1,m_err,"|") = "S" THEN
                   DO:
                       m_rcvr = ENTRY(2,m_err,"|").
                       HIDE FRAME lne.
                       CLEAR FRAME lne.
                       DISPLAY m_rcvr WITH FRAME hdr WIDTH 80 SIDE-LABELS.
                       NEXT mainloop.
                   END.
                   ELSE 
                   DO:
                     l_msg = ENTRY(2,m_err,"|").
                     {us/bbi/pxmsg.i 
                     &MSGNUM=2685
                     &MSGARG1=l_msg
                     &ERRORLEVEL = 3
                     }
                     UNDO mainloop, RETRY mainloop.
                   END.
               END.
             END.
           END.
        END.
        NEXT mainloop.
     END.
  END.    
END.

PROCEDURE mailx:
  DEFINE INPUT PARAMETER l_po AS CHARACTER.
  DEFINE INPUT PARAMETER l_podline AS CHARACTER.
  DEFINE INPUT PARAMETER l_part AS CHARACTER.
  DEFINE INPUT PARAMETER l_qty AS CHARACTER.
  DEFINE INPUT PARAMETER l_cost AS CHARACTER.
  
  define var a as char.
  l_mail = 'Please_approve_to_receive/create_GRN_against_Purchase_order_No._' + m_po + '_for_Dead_items'.
  find first po_mstr no-LOCK where po_domain = global_domain
                    and po_nbr = m_po no-error.
                    if available po_mstr then do:
    FIND FIRST usr_mstr no-lock where 
        usr_userid = po_user_id no-error.
        if available usr_mstr then do:
            l_user = usr_name.
        end.
        end.
  OUTPUT TO "confirmationemail.txt".
  PUT UNFORMATTED 
  "Dear Sir," SKIP(1) 
  "Please approve to receive/create GRN against Purchase Order for Dead Items. Details are as under" SKIP(1)
  "Dead Item No.:" +  l_part  SKIP(1)
  "Purchase Order:" +  l_po SKIP(1)
  "PO Line :" +  STRING(l_podline)  SKIP(1)
  "PO Qty : " + STRING(l_qty) SKIP(1)
  "PO Cost : " + STRING(l_cost) SKIP(1)
  "PO Site : " + l_site skip(2)
  "With Regards," SKIP(1)
  l_user SKIP(1).  
  
  OUTPUT CLOSE. 
  for each code_mstr no-LOCK where code_domain = global_domain
          and code_fldname = "DEAD ITEM"
          and code_value <> ""
          and code_cmmt = "PO_APPROVAL":
          if a = "" then do:
          a = code_value.
          end.
          else do:
          a = a + "," + code_value . 
          end.
              
  end. /*for each code_mstr no-LOCK*/
     OS-COMMAND SILENT  mail -s value(l_mail) value(a) < confirmationemail.txt.
  a = "".
end.