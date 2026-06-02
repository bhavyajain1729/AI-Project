{us/mf/mfdtitle.i}

define variable lvc_nbr  as character no-undo.
define variable lvc_lot  as character no-undo.
define variable lvc_comp as character no-undo.
define variable lvc_line as integer no-undo.
define variable lvc_spa  as character format "X(10)" no-undo.
define variable lvc_date as date no-undo.
define variable lvc_disc as decimal no-undo.
define variable lvc_pgc  as character no-undo.

define buffer woddet for wod_det.

form 
    lvc_line label "SPA Line"
    lvc_spa  label "SPA No" 
with frame bm1 overlay centered Title "SPA Data".

pause 0.
on go anywhere do:
    
    IF FRAME-NAME  = "a"  And FRAME-FIELD = "wod_part"  THEN DO:
        RUN GetFieldsData(INPUT "a" , INPUT "wo_nbr",OUTPUT lvc_nbr).
        RUN GetFieldsData(INPUT "a" , INPUT "wo_lot",OUTPUT lvc_lot).
        RUN GetFieldsData(INPUT "a" , INPUT "wod_part",OUTPUT lvc_comp). 

        assign 
        lvc_line = 0
        lvc_spa = "".

        find first pt_mstr where pt_domain = global_domain
            and pt_part = lvc_comp no-lock no-error.
        if available pt_mstr then 
        lvc_pgc = pt_mstr.pt_dsgn_grp.
   
        spaloop:
        repeat:
            update 
                lvc_line 
                lvc_spa 
            with frame bm1.

            if lvc_spa <> "" then do:
                find first xxspad_det where xxspad_domain = global_domain
                    and xxspad_nbr = lvc_spa
                    and xxspad_line = lvc_line 
                    and (xxspad_part = lvc_comp or xxspad_part = lvc_pgc ) no-lock no-error.
                if not available xxspad_det then do:
                    {us/bbi/pxmsg.i &MSGTEXT='"Invalid SPA details.Please Re-enter"' &ERRORLEVEL=3}
		        	undo spaloop, retry spaloop.
                end.
                else do:
                    if xxspad__date05 < today then do:
                        {us/bbi/pxmsg.i &MSGTEXT='"SPA line is expired.Please Re-enter"' &ERRORLEVEL=3}
		        	    undo spaloop, retry spaloop.
                    end.
                    find first xxspa_mstr where xxspa_mstr.xxspa_domain = global_domain
                        and xxspa_mstr.xxspa_nbr = xxspad_det.xxspad_nbr no-lock no-error.

                    find first woddet where woddet.wod_domain = global_domain
                        and woddet.wod_nbr = lvc_nbr
                        and woddet.wod_lot = lvc_lot exclusive-lock no-error.
                    if available woddet then 
                    assign 
                        woddet.wod__chr01 = lvc_spa 
                        woddet.wod__dec01 = dec(lvc_line)
                        woddet.wod__dec02 = xxspad_det.xxspad_spa_disc
                        woddet.wod__dte01 = if available xxspa_mstr then xxspa__date05 else ?.
                end.
            end.
        end.
        hide frame bm1.
    end.
end.
{us/bbi/gprun.i ""wowamt.p""}

PROCEDURE GetFieldsData:

    DEFINE INPUT PARAMETER i-frame-name   AS CHAR.
    DEFINE INPUT PARAMETER i-field-name   AS CHAR.
    DEFINE OUTPUT PARAMETER o-field-value AS CHAR.
    DEFINE VARIABLE window-hndl AS HANDLE NO-UNDO.
    DEFINE VARIABLE frame-hndl  AS HANDLE NO-UNDO.
    DEFINE VARIABLE group-hndl  AS HANDLE NO-UNDO.
    DEFINE VARIABLE field-hndl  AS HANDLE NO-UNDO.
    DEFINE VARIABLE tab-cnt     AS INT NO-UNDO.

    window-hndl = SESSION:FIRST-CHILD NO-ERROR.
    _window-loop:
      REPEAT WHILE VALID-HANDLE(window-hndl):

        frame-hndl = window-hndl:FIRST-CHILD NO-ERROR.
    
        _frame-loop:
        REPEAT WHILE VALID-HANDLE(frame-hndl):
    
            IF frame-hndl:NAME = i-frame-name AND frame-hndl:VISIBLE THEN DO:
            
                group-hndl = frame-hndl:FIRST-CHILD NO-ERROR.
                _group-loop:
                REPEAT WHILE VALID-HANDLE(group-hndl):
              
                    IF group-hndl:type = "field-group" THEN DO:
                
                        DO tab-cnt = 1 TO group-hndl:NUM-TABS:
                            field-hndl = group-hndl:GET-TAB-ITEM(tab-cnt)
                            NO-ERROR.
                            IF field-hndl:name = i-field-name THEN DO:
                        
                               o-field-value = field-hndl:SCREEN-VALUE.
                                RETURN.
                            END.
                        END. /* tab-cnt = 1 to NUM-TABS */
                    END. /* type = field-group */
                    IF group-hndl = frame-hndl:LAST-CHILD then
                        LEAVE _group-loop.
                         
                    group-hndl = group-hndl:NEXT-SIBLING NO-ERROR.
                END. /* REPEAT group-loop */
            END.
            IF frame-hndl = window-hndl:LAST-CHILD then LEAVE _frame-loop.
    
            frame-hndl = frame-hndl:NEXT-SIBLING NO-ERROR.
         
        END. /* REPEAT - frame-loop */
    
        window-hndl = window-hndl:NEXT-SIBLING NO-ERROR.
         
    END. /* REPEAT - window-loop */
  
END PROCEDURE. /*GetFieldsData*/