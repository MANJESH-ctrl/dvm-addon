CLASS zcl_dvm_kb DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES tt_kb TYPE STANDARD TABLE OF zdvm_kb WITH EMPTY KEY.

    "! Writes the shipped knowledge base entries (safe to run repeatedly)
    CLASS-METHODS seed.

    "! Default retention days + blocker rules (example policy)
    CLASS-METHODS seed_policies.

    METHODS constructor.

    "! Returns the KB entry for a table (exact name first, then wildcard patterns)
    METHODS find
      IMPORTING iv_table     TYPE csequence
      RETURNING VALUE(rs_kb) TYPE zdvm_kb.

  PRIVATE SECTION.
    DATA mt_exact   TYPE HASHED TABLE OF zdvm_kb WITH UNIQUE KEY table_name.
    DATA mt_pattern TYPE tt_kb.
ENDCLASS.


CLASS zcl_dvm_kb IMPLEMENTATION.

  METHOD seed.
    DATA(lt_kb) = VALUE tt_kb(
      " ---------- Housekeeping: technical data ----------
      ( table_name = 'BALHDR' category = 'HOUSEKEEPING' method = 'DELETE'
        arch_object = 'BC_SBAL' cleanup_tool = 'SLG2 / report SBAL_DELETE'
        age_table = 'BALHDR' age_field = 'ALDATE' risk = 'LOW' signoff = 'BASIS'
        note_ref = '2388483' description = 'Application log: header' )
      ( table_name = 'BALDAT' category = 'HOUSEKEEPING' method = 'DELETE'
        arch_object = 'BC_SBAL' cleanup_tool = 'SLG2 / report SBAL_DELETE'
        age_table = 'BALHDR' age_field = 'ALDATE' risk = 'LOW' signoff = 'BASIS'
        note_ref = '2388483' description = 'Application log: message data' )
      ( table_name = 'DBTABLOG' category = 'HOUSEKEEPING' method = 'DELETE'
        arch_object = 'BC_DBLOGS' cleanup_tool = 'SCU3_DEL or archive BC_DBLOGS'
        age_table = 'DBTABLOG' age_field = 'LOGDATE' risk = 'MEDIUM' signoff = 'BASIS+AUDIT'
        note_ref = '2388483' description = 'Table change logs (audit relevant)' )
      ( table_name = 'APQI' category = 'HOUSEKEEPING' method = 'DELETE'
        cleanup_tool = 'RSBDCREO (SAP_REORG_BATCHINPUT)'
        age_table = 'APQI' age_field = 'CREDATE' risk = 'LOW' signoff = 'BASIS'
        note_ref = '2388483' description = 'Batch input sessions' )
      ( table_name = 'APQD' category = 'HOUSEKEEPING' method = 'DELETE'
        cleanup_tool = 'RSBDCREO (SAP_REORG_BATCHINPUT)'
        age_table = 'APQI' age_field = 'CREDATE' risk = 'LOW' signoff = 'BASIS'
        note_ref = '2388483' description = 'Batch input data' )
      ( table_name = 'SNAP' category = 'HOUSEKEEPING' method = 'DELETE'
        cleanup_tool = 'RSSNAPDL (SAP_REORG_ABAPDUMPS)'
        age_table = 'SNAP' age_field = 'DATUM' risk = 'LOW' signoff = 'BASIS'
        note_ref = '2388483' description = 'ABAP short dumps' )
      ( table_name = 'TBTCO' category = 'HOUSEKEEPING' method = 'DELETE'
        cleanup_tool = 'RSBTCDEL2 (SAP_REORG_JOBS)'
        age_table = 'TBTCO' age_field = 'SDLSTRTDT' risk = 'LOW' signoff = 'BASIS'
        note_ref = '2388483' description = 'Background job headers' )
      ( table_name = 'TST03' category = 'HOUSEKEEPING' method = 'DELETE'
        cleanup_tool = 'RSPO1041 (SAP_REORG_SPOOL)'
        risk = 'LOW' signoff = 'BASIS' note_ref = '2388483'
        description = 'Spool data' )
      " ---------- Archiving: IDocs, change docs, workflow ----------
      ( table_name = 'EDIDC' category = 'ARCHIVING' method = 'ARCHIVE'
        arch_object = 'IDOC' cleanup_tool = 'WE47 status + SARA IDOC'
        age_table = 'EDIDC' age_field = 'CREDAT' risk = 'LOW' signoff = 'INTEGRATION'
        note_ref = '2388483' description = 'IDoc control records' )
      ( table_name = 'EDID4' category = 'ARCHIVING' method = 'ARCHIVE'
        arch_object = 'IDOC' cleanup_tool = 'WE47 status + SARA IDOC'
        age_table = 'EDIDC' age_field = 'CREDAT' risk = 'LOW' signoff = 'INTEGRATION'
        note_ref = '2388483' description = 'IDoc data records' )
      ( table_name = 'EDIDS' category = 'ARCHIVING' method = 'ARCHIVE'
        arch_object = 'IDOC' cleanup_tool = 'WE47 status + SARA IDOC'
        age_table = 'EDIDC' age_field = 'CREDAT' risk = 'LOW' signoff = 'INTEGRATION'
        note_ref = '2388483' description = 'IDoc status records' )
      ( table_name = 'CDHDR' category = 'ARCHIVING' method = 'ARCHIVE'
        arch_object = 'CHANGEDOCU' cleanup_tool = 'SARA CHANGEDOCU'
        age_table = 'CDHDR' age_field = 'UDATE' risk = 'MEDIUM' signoff = 'AUDIT'
        description = 'Change documents: header' )
      ( table_name = 'CDPOS' category = 'ARCHIVING' method = 'ARCHIVE'
        arch_object = 'CHANGEDOCU' cleanup_tool = 'SARA CHANGEDOCU'
        age_table = 'CDHDR' age_field = 'UDATE' risk = 'MEDIUM' signoff = 'AUDIT'
        description = 'Change documents: items' )
      ( table_name = 'SWWWIHEAD' category = 'ARCHIVING' method = 'ARCHIVE'
        arch_object = 'WORKITEM' cleanup_tool = 'SARA WORKITEM'
        age_table = 'SWWWIHEAD' age_field = 'WI_CD' risk = 'MEDIUM' signoff = 'BUSINESS'
        description = 'Workflow work items' )
      " ---------- Archiving: business documents ----------
      ( table_name = 'ACDOCA' category = 'ARCHIVING' method = 'ARCHIVE'
        arch_object = 'FI_DOCUMNT' cleanup_tool = 'SARA FI_DOCUMNT'
        age_table = 'ACDOCA' age_field = 'BUDAT' risk = 'HIGH' signoff = 'FINANCE'
        description = 'Universal Journal line items' )
      ( table_name = 'BKPF' category = 'ARCHIVING' method = 'ARCHIVE'
        arch_object = 'FI_DOCUMNT' cleanup_tool = 'SARA FI_DOCUMNT'
        age_table = 'BKPF' age_field = 'BUDAT' risk = 'HIGH' signoff = 'FINANCE'
        description = 'Accounting document header' )
      ( table_name = 'BSEG' category = 'ARCHIVING' method = 'ARCHIVE'
        arch_object = 'FI_DOCUMNT' cleanup_tool = 'SARA FI_DOCUMNT'
        age_table = 'BKPF' age_field = 'BUDAT' risk = 'HIGH' signoff = 'FINANCE'
        description = 'Accounting document line items' )
      ( table_name = 'MATDOC' category = 'ARCHIVING' method = 'ARCHIVE'
        arch_object = 'MM_MATBEL' cleanup_tool = 'SARA MM_MATBEL'
        age_table = 'MATDOC' age_field = 'BUDAT' risk = 'MEDIUM' signoff = 'LOGISTICS'
        description = 'Material documents' )
      ( table_name = 'VBAK' category = 'ARCHIVING' method = 'ARCHIVE'
        arch_object = 'SD_VBAK' cleanup_tool = 'SARA SD_VBAK'
        age_table = 'VBAK' age_field = 'ERDAT' risk = 'MEDIUM' signoff = 'SALES'
        description = 'Sales document header' )
      ( table_name = 'VBAP' category = 'ARCHIVING' method = 'ARCHIVE'
        arch_object = 'SD_VBAK' cleanup_tool = 'SARA SD_VBAK'
        age_table = 'VBAK' age_field = 'ERDAT' risk = 'MEDIUM' signoff = 'SALES'
        description = 'Sales document items' )
      ( table_name = 'VBRK' category = 'ARCHIVING' method = 'ARCHIVE'
        arch_object = 'SD_VBRK' cleanup_tool = 'SARA SD_VBRK'
        age_table = 'VBRK' age_field = 'FKDAT' risk = 'MEDIUM' signoff = 'SALES'
        description = 'Billing document header' )
      ( table_name = 'VBRP' category = 'ARCHIVING' method = 'ARCHIVE'
        arch_object = 'SD_VBRK' cleanup_tool = 'SARA SD_VBRK'
        age_table = 'VBRK' age_field = 'FKDAT' risk = 'MEDIUM' signoff = 'SALES'
        description = 'Billing document items' )
      ( table_name = 'LIKP' category = 'ARCHIVING' method = 'ARCHIVE'
        arch_object = 'RV_LIKP' cleanup_tool = 'SARA RV_LIKP'
        age_table = 'LIKP' age_field = 'ERDAT' risk = 'MEDIUM' signoff = 'LOGISTICS'
        description = 'Delivery header' )
      ( table_name = 'LIPS' category = 'ARCHIVING' method = 'ARCHIVE'
        arch_object = 'RV_LIKP' cleanup_tool = 'SARA RV_LIKP'
        age_table = 'LIKP' age_field = 'ERDAT' risk = 'MEDIUM' signoff = 'LOGISTICS'
        description = 'Delivery items' )
      ( table_name = 'EKKO' category = 'ARCHIVING' method = 'ARCHIVE'
        arch_object = 'MM_EKKO' cleanup_tool = 'SARA MM_EKKO'
        age_table = 'EKKO' age_field = 'BEDAT' risk = 'MEDIUM' signoff = 'PURCHASING'
        description = 'Purchase order header' )
      ( table_name = 'EKPO' category = 'ARCHIVING' method = 'ARCHIVE'
        arch_object = 'MM_EKKO' cleanup_tool = 'SARA MM_EKKO'
        age_table = 'EKKO' age_field = 'BEDAT' risk = 'MEDIUM' signoff = 'PURCHASING'
        description = 'Purchase order items' )
      ( table_name = 'PRCD_ELEMENTS' category = 'ARCHIVING' method = 'ARCHIVE'
        arch_object = 'SD_VBAK' cleanup_tool = 'Archived with SD/MM documents'
        risk = 'MEDIUM' signoff = 'SALES'
        description = 'Pricing conditions' )
      " ---------- SAP system content: keep ----------
      ( table_name = 'E071'       category = 'SYSTEM' method = 'NONE' description = 'Transport request object lists' )
      ( table_name = 'E071K'      category = 'SYSTEM' method = 'NONE' description = 'Transport request key entries' )
      ( table_name = 'SCPRVALS'   category = 'SYSTEM' method = 'NONE' description = 'BC Set content' )
      ( table_name = 'SCPRVALL'   category = 'SYSTEM' method = 'NONE' description = 'BC Set content' )
      ( table_name = 'SCPRRECA'   category = 'SYSTEM' method = 'NONE' description = 'BC Set content' )
      ( table_name = 'REPOSRC'    category = 'SYSTEM' method = 'NONE' description = 'ABAP source code' )
      ( table_name = 'REPOTEXT'   category = 'SYSTEM' method = 'NONE' description = 'ABAP text elements' )
      ( table_name = 'T100'       category = 'SYSTEM' method = 'NONE' description = 'Message texts' )
      ( table_name = 'RSMPTEXTS'  category = 'SYSTEM' method = 'NONE' description = 'GUI status texts' )
      ( table_name = 'WBCROSSGT'  category = 'SYSTEM' method = 'NONE' description = 'Where-used index' )
      ( table_name = 'DD07T'      category = 'SYSTEM' method = 'NONE' description = 'Dictionary domain texts' )
      ( table_name = 'DDNTT'      category = 'SYSTEM' method = 'NONE' description = 'Dictionary nametab' )
      ( table_name = 'AGR_HIERT'  category = 'SYSTEM' method = 'NONE' description = 'Role menu texts' )
      ( table_name = 'SMIMCONT1'  category = 'SYSTEM' method = 'NONE' description = 'MIME repository' )
      ( table_name = 'SEOSUBCODF' category = 'SYSTEM' method = 'NONE' description = 'Class component definitions' )
      ( table_name = 'SEOSUBCOTX' category = 'SYSTEM' method = 'NONE' description = 'Class component texts' )
      ( table_name = '/SMB/*'     category = 'SYSTEM' method = 'NONE' description = 'SAP Best Practices content' )
      ( table_name = 'EHFNDD_*'   category = 'SYSTEM' method = 'NONE' description = 'EHS foundation content' ) ).

    MODIFY zdvm_kb FROM TABLE @lt_kb.
    COMMIT WORK.
    seed_policies( ).
  ENDMETHOD.

  METHOD seed_policies.
    " Example retention defaults. In the product the customer adjusts these.
    TYPES: BEGIN OF ty_pol,
             table_name  TYPE zdvm_kb-table_name,
             ret_days    TYPE i,
             blocker_sql TYPE zdvm_kb-blocker_sql,
           END OF ty_pol,
           tt_pol TYPE STANDARD TABLE OF ty_pol WITH EMPTY KEY.

    " SAP rule: log may not be deleted before its expiry date
    CONSTANTS lc_bal_block TYPE string
      VALUE `DEL_BEFORE = 'X' AND ALDATE_DEL > '{TODAY}'`.

    DATA(lt_pol) = VALUE tt_pol(
      ( table_name = 'BALHDR'    ret_days = 90   blocker_sql = lc_bal_block )
      ( table_name = 'BALDAT'    ret_days = 90   blocker_sql = lc_bal_block )
      ( table_name = 'DBTABLOG'  ret_days = 730 )
      ( table_name = 'APQI'      ret_days = 30 )
      ( table_name = 'APQD'      ret_days = 30 )
      ( table_name = 'SNAP'      ret_days = 14 )
      ( table_name = 'TBTCO'     ret_days = 30 )
      ( table_name = 'EDIDC'     ret_days = 180 )
      ( table_name = 'EDID4'     ret_days = 180 )
      ( table_name = 'EDIDS'     ret_days = 180 )
      ( table_name = 'CDHDR'     ret_days = 1825 )
      ( table_name = 'CDPOS'     ret_days = 1825 )
      ( table_name = 'SWWWIHEAD' ret_days = 365 )
      ( table_name = 'ACDOCA'    ret_days = 3650 )
      ( table_name = 'BKPF'      ret_days = 3650 )
      ( table_name = 'BSEG'      ret_days = 3650 )
      ( table_name = 'MATDOC'    ret_days = 1825 )
      ( table_name = 'VBAK'      ret_days = 1825 )
      ( table_name = 'VBAP'      ret_days = 1825 )
      ( table_name = 'VBRK'      ret_days = 1825 )
      ( table_name = 'VBRP'      ret_days = 1825 )
      ( table_name = 'LIKP'      ret_days = 1825 )
      ( table_name = 'LIPS'      ret_days = 1825 )
      ( table_name = 'EKKO'      ret_days = 1825 )
      ( table_name = 'EKPO'      ret_days = 1825 ) ).

    LOOP AT lt_pol INTO DATA(ls_pol).
      UPDATE zdvm_kb
        SET ret_days    = @ls_pol-ret_days,
            blocker_sql = @ls_pol-blocker_sql
        WHERE table_name = @ls_pol-table_name.
    ENDLOOP.
    COMMIT WORK.
  ENDMETHOD.

  METHOD constructor.
    SELECT * FROM zdvm_kb INTO TABLE @DATA(lt_all).
    LOOP AT lt_all INTO DATA(ls_kb).
      IF ls_kb-table_name CA '*'.
        APPEND ls_kb TO mt_pattern.
      ELSE.
        INSERT ls_kb INTO TABLE mt_exact.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.


  METHOD find.
    READ TABLE mt_exact INTO rs_kb WITH TABLE KEY table_name = iv_table.
    IF sy-subrc = 0.
      RETURN.
    ENDIF.
    LOOP AT mt_pattern INTO DATA(ls_pattern).
      IF iv_table CP ls_pattern-table_name.
        rs_kb = ls_pattern.
        RETURN.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
