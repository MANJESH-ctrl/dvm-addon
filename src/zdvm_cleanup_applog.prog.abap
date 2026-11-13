REPORT zdvm_cleanup_applog.

" Same rule as the DVM prediction:
" older than p_days AND NOT ( 'do not delete before expiry' AND expiry in future )
PARAMETERS: p_days TYPE i DEFAULT 90,
            p_pack TYPE i DEFAULT 5000,
            p_test AS CHECKBOX DEFAULT 'X'.

START-OF-SELECTION.
  DATA lt_logs  TYPE balhdr_t.
  DATA lv_cnt   TYPE i.
  DATA lv_done  TYPE i.
  DATA lv_total TYPE i.
  DATA(lv_cutoff) = CONV d( sy-datum - p_days ).

  SELECT mandt FROM t000 INTO TABLE @DATA(lt_clients).

  LOOP AT lt_clients INTO DATA(ls_client).
    CLEAR: lv_cnt, lv_done.

    SELECT COUNT(*) FROM balhdr USING CLIENT @ls_client-mandt
      WHERE aldate <  @lv_cutoff
        AND aldate <> '00000000'
        AND ( del_before <> 'X' OR aldate_del <= @sy-datum )
      INTO @lv_cnt.

    IF p_test = abap_false AND lv_cnt > 0.
      " Loop in packages; the iteration limit protects against endless loops
      DO ( lv_cnt DIV p_pack ) + 2 TIMES.
        CLEAR lt_logs.
        SELECT * FROM balhdr USING CLIENT @ls_client-mandt
          WHERE aldate <  @lv_cutoff
            AND aldate <> '00000000'
            AND ( del_before <> 'X' OR aldate_del <= @sy-datum )
          INTO TABLE @lt_logs
          UP TO @p_pack ROWS.
        IF lt_logs IS INITIAL.
          EXIT.
        ENDIF.

        CALL FUNCTION 'BAL_DB_DELETE'
          EXPORTING
            i_t_logs_to_delete = lt_logs
            i_client           = ls_client-mandt
            i_with_commit_work = abap_true
          EXCEPTIONS
            OTHERS             = 1.
        IF sy-subrc <> 0.
          WRITE: / 'BAL_DB_DELETE failed in client', ls_client-mandt.
          EXIT.
        ENDIF.
        lv_done = lv_done + lines( lt_logs ).
      ENDDO.
    ENDIF.

    WRITE: / 'Client', ls_client-mandt,
             'eligible:', lv_cnt,
             'deleted:', lv_done.
    lv_total = lv_total + lv_cnt.
  ENDLOOP.

  WRITE: / 'Total eligible logs (all clients):', lv_total.
  IF p_test = abap_true.
    WRITE: / 'TEST MODE - nothing deleted'.
  ENDIF.
