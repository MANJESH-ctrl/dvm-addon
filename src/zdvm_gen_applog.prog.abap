REPORT zdvm_gen_applog.

PARAMETERS: p_logs  TYPE i DEFAULT 100000,      " number of logs
            p_msgs  TYPE i DEFAULT 20,          " messages per log
            p_block TYPE i DEFAULT 15,          " % blocked (no deletion before 2099)
            p_from  TYPE n LENGTH 4 DEFAULT '2016',
            p_to    TYPE n LENGTH 4 DEFAULT '2025'.

DATA gt_handles TYPE bal_t_logh.
DATA gv_created TYPE i.

START-OF-SELECTION.
  " Sandbox only: register our own log object ZDVM (normally done in SLG0)
  MODIFY balobj  FROM @( VALUE balobj( object = 'ZDVM' ) ).
  MODIFY balobjt FROM @( VALUE balobjt( spras = sy-langu object = 'ZDVM'
                                        objtxt = 'DVM test logs' ) ).
  COMMIT WORK.

  DATA(go_year)  = cl_abap_random_int=>create( seed = 42 min = CONV i( p_from ) max = CONV i( p_to ) ).
  DATA(go_month) = cl_abap_random_int=>create( seed = 7  min = 1 max = 12 ).
  DATA(go_day)   = cl_abap_random_int=>create( seed = 9  min = 1 max = 28 ).
  DATA(go_pct)   = cl_abap_random_int=>create( seed = 11 min = 1 max = 100 ).

  DO p_logs TIMES.
    DATA(lv_no) = sy-index.
    DATA(lv_date) = CONV d(
      |{ go_year->get_next( )  WIDTH = 4 ALIGN = RIGHT PAD = '0' }| &&
      |{ go_month->get_next( ) WIDTH = 2 ALIGN = RIGHT PAD = '0' }| &&
      |{ go_day->get_next( )   WIDTH = 2 ALIGN = RIGHT PAD = '0' }| ).

    DATA(ls_log) = VALUE bal_s_log( object    = 'ZDVM'
                                    extnumber = |DVM-{ lv_no }|
                                    aldate    = lv_date
                                    altime    = '120000'
                                    aluser    = sy-uname
                                    alprog    = sy-repid ).

    IF go_pct->get_next( ) <= p_block.
      " Blocker: may not be deleted before expiry in 2099
      ls_log-aldate_del = '20991231'.
      ls_log-del_before = abap_true.
    ELSE.
      " Normal: expired 30 days after creation, deletable
      ls_log-aldate_del = lv_date + 30.
      ls_log-del_before = abap_false.
    ENDIF.

    DATA lv_handle TYPE balloghndl.
    CALL FUNCTION 'BAL_LOG_CREATE'
      EXPORTING i_s_log      = ls_log
      IMPORTING e_log_handle = lv_handle
      EXCEPTIONS OTHERS      = 1.
    IF sy-subrc <> 0.
      MESSAGE 'BAL_LOG_CREATE failed (log object ZDVM?)' TYPE 'E'.
    ENDIF.

    DO p_msgs TIMES.
      DATA(ls_msg) = VALUE bal_s_msg( msgty = 'I' msgid = '00' msgno = '001'
                                      msgv1 = 'DVM test message'
                                      msgv2 = |{ sy-index }|
                                      msgv3 = |{ lv_date }| ).
      CALL FUNCTION 'BAL_LOG_MSG_ADD'
        EXPORTING i_log_handle = lv_handle
                  i_s_msg      = ls_msg
        EXCEPTIONS OTHERS      = 1.
    ENDDO.

    APPEND lv_handle TO gt_handles.
    IF lines( gt_handles ) >= 500.
      PERFORM save_batch.
    ENDIF.
  ENDDO.

  PERFORM save_batch.
  MESSAGE |{ gv_created } application logs created| TYPE 'S'.


FORM save_batch.
  CHECK gt_handles IS NOT INITIAL.
  CALL FUNCTION 'BAL_DB_SAVE'
    EXPORTING i_t_log_handle = gt_handles
    EXCEPTIONS OTHERS        = 1.
  COMMIT WORK.
  LOOP AT gt_handles INTO DATA(lv_h).
    CALL FUNCTION 'BAL_LOG_REFRESH'
      EXPORTING i_log_handle = lv_h
      EXCEPTIONS OTHERS      = 1.
  ENDLOOP.
  gv_created = gv_created + lines( gt_handles ).
  CLEAR gt_handles.
ENDFORM.
