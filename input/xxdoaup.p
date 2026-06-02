{us/mf/mfdtitle.i}
{us/bbi/gplabel.i}

define variable ipc_ruletype as character format "x(15)" no-undo.
define variable ipc_code     as character no-undo.
define variable ipc_route    as character no-undo.
define variable ipc_aprcode  as character no-undo.
define variable ipc_email    as character format "x(100)" no-undo.
define variable ipc_status   as character format "x(17)" no-undo.

form 
    ipc_ruletype colon 25 label "Rule Type"
    ipc_code     colon 25 label "Code"
    ipc_route    colon 25 label "Route Code"
    ipc_aprcode  colon 25 label "Approver Code"
    ipc_email    colon 25 label "Current Approver"  view-as fill-in size 50 by 1
    ipc_status   colon 25 label "Approver Status"
with frame a side-label.

update 
    ipc_ruletype
    ipc_code
    ipc_route   
    ipc_aprcode 
    ipc_email  
    ipc_status 
with frame a.

IF ipc_ruletype EQ "SupplierCreate" OR 
   ipc_ruletype EQ "SupplierModify" OR 
   ipc_ruletype EQ "CustomerCreate" OR 
   ipc_ruletype EQ "CustomerModify"
THEN DO:
    find first mdm_mstr where mdm_domain = global_domain 
        and mdm_MasterType = ipc_ruletype
        and mdm_BusinessRelationCode = ipc_code exclusive-lock no-error.
    if available mdm_mstr then do:
        if ipc_route <> "" then 
            mdm_Route =  ipc_route.
        if ipc_aprcode <> "" then
            mdm_appcode = ipc_aprcode.
        if ipc_email <> "" then
            mdm_Currappr = ipc_email.
        if ipc_status <> "" then
            mdm_Staus = ipc_status.
    end.
    release mdm_mstr.
end.
if ipc_ruletype EQ "SPAREL" then do:
    find first qo_mstr where qo_domain = global_domain
        and qo_nbr = ipc_code exclusive-lock no-error.
    if available qo_mstr then do:
        if ipc_route <> "" then 
            qo__chr04 =  ipc_route.
        if ipc_aprcode <> "" then
            qo__chr05 = ipc_aprcode.
        if ipc_email <> "" then
            qo__chr07 = ipc_email.
        if ipc_status <> "" then
            qo__chr06 = ipc_status.
    end.
    release qo_mstr.
end.
if ipc_ruletype EQ "DCREL" then do:
    find first xxrtdc_mstr where xxrtdc_domain = global_domain
        and xxrtdc_nbr = ipc_code exclusive-lock no-error.
    if available xxrtdc_mstr then do:
        if ipc_route <> "" then 
            xxrtdc_chr07 =  ipc_route.
        if ipc_aprcode <> "" then
            xxrtdc_chr06 = ipc_aprcode.
        if ipc_email <> "" then
            xxrtdc_chr09 = ipc_email.
        if ipc_status <> "" then
            xxrtdc_chr08 = ipc_status.
    end.
    release xxrtdc_mstr.
end.
