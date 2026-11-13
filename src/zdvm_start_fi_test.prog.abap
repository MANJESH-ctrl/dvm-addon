REPORT zdvm_start_fi_test.

PARAMETERS p_prog TYPE syrepid DEFAULT 'FI_DOCUMNT_WRI'.

START-OF-SELECTION.
  DATA lv_jobname  TYPE btcjob VALUE 'ZDVM_TEST_FI_DOCUMNT'.
  DATA lv_jobcount TYPE btcjobcnt.
  DATA lv_released TYPE btcchar1.

  " Test mode only: P_WRITST = X, production P_WRIPRD = space
  DATA(lt_params) = VALUE rsparams_tt(
    ( selname = 'P_WRITST' kind = 'P' low = 'X' )
    ( selname = 'P_WRIPRD' kind = 'P' low = ' ' )
    ( selname = 'P_COMENT' kind = 'P' low = 'DVM test-mode analysis' ) ).

  CALL FUNCTION 'JOB_OPEN'
    EXPORTING  jobname  = lv_jobname
    IMPORTING  jobcount = lv_jobcount
    EXCEPTIONS OTHERS   = 1.
  WRITE: / 'JOB_OPEN  rc =', sy-subrc, 'job count', lv_jobcount.
  IF lv_jobcount IS INITIAL.
    RETURN.
  ENDIF.

  SUBMIT (p_prog) WITH SELECTION-TABLE lt_params
    USER sy-uname
    VIA JOB lv_jobname NUMBER lv_jobcount
    AND RETURN.
  WRITE: / 'SUBMIT    rc =', sy-subrc, '(0 = step added)'.

  CALL FUNCTION 'JOB_CLOSE'
    EXPORTING
      jobcount             = lv_jobcount
      jobname              = lv_jobname
      strtimmed            = abap_true
    IMPORTING
      job_was_released     = lv_released
    EXCEPTIONS
      cant_start_immediate = 1
      job_nosteps          = 5
      OTHERS               = 10.
  WRITE: / 'JOB_CLOSE rc =', sy-subrc, '(0 = released, 1 = no free batch process, 5 = no step)',
         / 'Released:', lv_released.
  WRITE: / 'Next: wait 1-2 minutes, then run ZCL_DVM_RUN_FI_READ in Eclipse (F9).'.
