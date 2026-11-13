CLASS zcl_dvm_run_fi_test DEFINITION
  PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_dvm_run_fi_test IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.

    CONSTANTS lc_prog TYPE syrepid VALUE 'FI_DOCUMNT_WRI'.
    DATA lv_jobname  TYPE btcjob VALUE 'ZDVM_TEST_FI_DOCUMNT'.
    DATA lv_jobcount TYPE btcjobcnt.
    DATA lv_released TYPE btcchar1.

    " Test mode: P_WRITST = X, production P_WRIPRD = space
    DATA(lt_params) = VALUE rsparams_tt(
      ( selname = 'P_WRITST' kind = 'P' low = 'X' )
      ( selname = 'P_WRIPRD' kind = 'P' low = ' ' )
      ( selname = 'P_COMENT' kind = 'P' low = 'DVM test-mode analysis' ) ).

    " 1) Create job
    CALL FUNCTION 'JOB_OPEN'
      EXPORTING  jobname  = lv_jobname
      IMPORTING  jobcount = lv_jobcount
      EXCEPTIONS OTHERS   = 1.
    out->write( |JOB_OPEN sy-subrc = { sy-subrc } (0 = ok), job count { lv_jobcount }| ).
    IF lv_jobcount IS INITIAL.
      RETURN.
    ENDIF.

    " 2) Add SAP's write program as job step (test mode)
    SUBMIT (lc_prog) WITH SELECTION-TABLE lt_params
      USER sy-uname
      VIA JOB lv_jobname NUMBER lv_jobcount
      AND RETURN.
    out->write( |SUBMIT sy-subrc = { sy-subrc } (0 = step added)| ).

    " 3) Release the job to start immediately
    CALL FUNCTION 'JOB_CLOSE'
      EXPORTING
        jobcount             = lv_jobcount
        jobname              = lv_jobname
        strtimmed            = abap_true
      IMPORTING
        job_was_released     = lv_released
      EXCEPTIONS
        cant_start_immediate = 1
        invalid_startdate    = 2
        jobname_missing      = 3
        job_close_failed     = 4
        job_nosteps          = 5
        job_notex            = 6
        lock_failed          = 7
        invalid_target       = 8
        invalid_time_zone    = 9
        OTHERS               = 10.
    DATA(lv_rc) = sy-subrc.

    DATA(lv_text) = SWITCH string( lv_rc
      WHEN 0  THEN `OK - job released`
      WHEN 1  THEN `CANT_START_IMMEDIATE - no free background work process`
      WHEN 2  THEN `INVALID_STARTDATE`
      WHEN 3  THEN `JOBNAME_MISSING`
      WHEN 4  THEN `JOB_CLOSE_FAILED`
      WHEN 5  THEN `JOB_NOSTEPS - the SUBMIT did not add a step`
      WHEN 6  THEN `JOB_NOTEX - job does not exist`
      WHEN 7  THEN `LOCK_FAILED`
      WHEN 8  THEN `INVALID_TARGET`
      WHEN 9  THEN `INVALID_TIME_ZONE`
      ELSE         `OTHER error` ).

    out->write( |JOB_CLOSE sy-subrc = { lv_rc }: { lv_text }, released = { lv_released }| ).
    out->write( 'Now wait 1-2 minutes and run ZCL_DVM_RUN_FI_READ (F9).' ).

  ENDMETHOD.
ENDCLASS.
