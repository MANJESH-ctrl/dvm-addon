CLASS zcl_dvm_run_save_verify DEFINITION
  PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
  PRIVATE SECTION.
    METHODS evaluate
      IMPORTING iv_pred_mem  TYPE int8
                iv_act_mem   TYPE int8
                iv_pred_disk TYPE int8
                iv_act_disk  TYPE int8
      EXPORTING ev_mem_acc   TYPE zdvm_ver-mem_acc_pct
                ev_disk_acc  TYPE zdvm_ver-disk_acc_pct
                ev_status    TYPE zdvm_ver-status
                ev_crit      TYPE zdvm_ver-status_crit.
ENDCLASS.


CLASS zcl_dvm_run_save_verify IMPLEMENTATION.

  METHOD if_oo_adt_classrun~main.

    " Measured = newest snapshot; prediction = latest recommendations before it
    SELECT MAX( snap_id ) FROM zdvm_snap INTO @DATA(lv_meas).
    SELECT MAX( snap_id ) FROM zdvm_rec WHERE snap_id < @lv_meas INTO @DATA(lv_pred).
    IF lv_pred IS INITIAL.
      out->write( 'No prediction snapshot older than the latest measurement.' ).
      RETURN.
    ENDIF.

    SELECT * FROM zdvm_rec WHERE snap_id = @lv_pred INTO TABLE @DATA(lt_rec).
    SELECT table_name, record_count, memory_bytes, disk_bytes FROM zdvm_snap_tab
      WHERE snap_id = @lv_pred INTO TABLE @DATA(lt_old).
    SELECT table_name, record_count, memory_bytes, disk_bytes FROM zdvm_snap_tab
      WHERE snap_id = @lv_meas INTO TABLE @DATA(lt_cur).
    SORT lt_old BY table_name.
    SORT lt_cur BY table_name.

    DATA lt_ver TYPE STANDARD TABLE OF zdvm_ver  WITH EMPTY KEY.
    DATA lt_grp TYPE STANDARD TABLE OF zdvm_verg WITH EMPTY KEY.

    LOOP AT lt_rec INTO DATA(ls_rec)
         WHERE save_mem_bytes > 0 OR save_disk_bytes > 0.

      READ TABLE lt_old INTO DATA(ls_old)
        WITH KEY table_name = ls_rec-table_name BINARY SEARCH.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      READ TABLE lt_cur INTO DATA(ls_cur)
        WITH KEY table_name = ls_rec-table_name BINARY SEARCH.
      IF sy-subrc <> 0.
        CLEAR ls_cur.            " dropped below 1 MB: treat as ~0
      ENDIF.

      APPEND VALUE #(
        pred_snap       = lv_pred
        table_name      = ls_rec-table_name
        meas_snap       = lv_meas
        group_key       = ls_rec-group_key
        method          = ls_rec-method
        cutoff_date     = ls_rec-cutoff_date
        pred_rows       = ls_rec-eligible_rows
        act_rows        = ls_old-record_count - ls_cur-record_count
        pred_mem_bytes  = ls_rec-save_mem_bytes
        act_mem_bytes   = ls_old-memory_bytes - ls_cur-memory_bytes
        pred_disk_bytes = ls_rec-save_disk_bytes
        act_disk_bytes  = ls_old-disk_bytes - ls_cur-disk_bytes ) TO lt_ver.

      READ TABLE lt_grp ASSIGNING FIELD-SYMBOL(<g>)
        WITH KEY group_key = ls_rec-group_key.
      IF sy-subrc <> 0.
        APPEND VALUE #( pred_snap = lv_pred
                        group_key = ls_rec-group_key
                        meas_snap = lv_meas
                        method    = ls_rec-method ) TO lt_grp ASSIGNING <g>.
      ENDIF.
      <g>-pred_mem_bytes  = <g>-pred_mem_bytes  + ls_rec-save_mem_bytes.
      <g>-act_mem_bytes   = <g>-act_mem_bytes   + ( ls_old-memory_bytes - ls_cur-memory_bytes ).
      <g>-pred_disk_bytes = <g>-pred_disk_bytes + ls_rec-save_disk_bytes.
      <g>-act_disk_bytes  = <g>-act_disk_bytes  + ( ls_old-disk_bytes - ls_cur-disk_bytes ).
    ENDLOOP.

    LOOP AT lt_ver ASSIGNING FIELD-SYMBOL(<v>).
      evaluate( EXPORTING iv_pred_mem  = <v>-pred_mem_bytes
                          iv_act_mem   = <v>-act_mem_bytes
                          iv_pred_disk = <v>-pred_disk_bytes
                          iv_act_disk  = <v>-act_disk_bytes
                IMPORTING ev_mem_acc   = <v>-mem_acc_pct
                          ev_disk_acc  = <v>-disk_acc_pct
                          ev_status    = <v>-status
                          ev_crit      = <v>-status_crit ).
    ENDLOOP.

    LOOP AT lt_grp ASSIGNING <g>.
      evaluate( EXPORTING iv_pred_mem  = <g>-pred_mem_bytes
                          iv_act_mem   = <g>-act_mem_bytes
                          iv_pred_disk = <g>-pred_disk_bytes
                          iv_act_disk  = <g>-act_disk_bytes
                IMPORTING ev_mem_acc   = <g>-mem_acc_pct
                          ev_disk_acc  = <g>-disk_acc_pct
                          ev_status    = <g>-status
                          ev_crit      = <g>-status_crit ).
    ENDLOOP.

    DELETE FROM zdvm_ver  WHERE pred_snap = @lv_pred.
    DELETE FROM zdvm_verg WHERE pred_snap = @lv_pred.
    INSERT zdvm_ver  FROM TABLE @lt_ver.
    INSERT zdvm_verg FROM TABLE @lt_grp.
    COMMIT WORK.

    out->write( |Stored: prediction { lv_pred } vs measurement { lv_meas }| ).
    out->write( |{ lines( lt_ver ) } tables, { lines( lt_grp ) } cleanup actions| ).
    out->write( lt_grp ).

  ENDMETHOD.


  METHOD evaluate.
    CLEAR: ev_mem_acc, ev_disk_acc, ev_status, ev_crit.

    IF iv_pred_mem > 0.
      DATA(lv_m) = CONV decfloat34( iv_act_mem ) * 100 / iv_pred_mem.
      ev_mem_acc = nmax( val1 = -9999 val2 = nmin( val1 = 9999 val2 = lv_m ) ).
    ENDIF.
    IF iv_pred_disk > 0.
      DATA(lv_d) = CONV decfloat34( iv_act_disk ) * 100 / iv_pred_disk.
      ev_disk_acc = nmax( val1 = -9999 val2 = nmin( val1 = 9999 val2 = lv_d ) ).
    ENDIF.

    " Executed = at least 1 MB disk freed and at least 10 % of the prediction
    IF iv_act_disk > 1048576 AND iv_act_disk * 10 >= iv_pred_disk.
      ev_status = 'EXECUTED'.
      ev_crit = COND #( WHEN ev_disk_acc BETWEEN 80 AND 120 THEN 3     " green
                        WHEN ev_disk_acc BETWEEN 50 AND 150 THEN 2     " orange
                        ELSE 1 ).                                      " red
    ELSE.
      ev_status = 'PENDING'.
      ev_crit   = 0.                                                   " neutral
    ENDIF.
  ENDMETHOD.

ENDCLASS.
