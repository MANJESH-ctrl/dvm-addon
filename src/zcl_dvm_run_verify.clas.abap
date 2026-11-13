CLASS zcl_dvm_run_verify DEFINITION
  PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_dvm_run_verify IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.

    " 1) Snapshot holding the predictions
    SELECT MAX( snap_id ) FROM zdvm_rec INTO @DATA(lv_prev).
    IF lv_prev IS INITIAL.
      out->write( 'No recommendations found. Run ZCL_DVM_RUN_RECOMMEND first.' ).
      RETURN.
    ENDIF.

    " 2) Delta merge so freed space becomes visible
    DATA(lt_merge) = VALUE string_table( ( `BALHDR` ) ( `BALDAT` ) ( `DBTABLOG` ) ).
    LOOP AT lt_merge INTO DATA(lv_tab).
      TRY.
          NEW cl_sql_statement( )->execute_ddl( |MERGE DELTA OF "{ lv_tab }"| ).
          out->write( |Delta merge done: { lv_tab }| ).
        CATCH cx_sql_exception INTO DATA(lx_sql).
          out->write( |Delta merge { lv_tab } failed: { lx_sql->get_text( ) }| ).
      ENDTRY.
    ENDLOOP.

    " 3) New measurement
    TRY.
        DATA(lv_new) = NEW zcl_dvm_collector( )->run( ).
      CATCH cx_root INTO DATA(lx_err).
        out->write( |Collector failed: { lx_err->get_text( ) }| ).
        RETURN.
    ENDTRY.
    out->write( |Predicted in snapshot { lv_prev }, measured in snapshot { lv_new }| ).

    " 4) Compare
    SELECT * FROM zdvm_rec WHERE snap_id = @lv_prev INTO TABLE @DATA(lt_rec).
    SELECT table_name, record_count, memory_bytes, disk_bytes FROM zdvm_snap_tab
      WHERE snap_id = @lv_prev INTO TABLE @DATA(lt_old).
    SELECT table_name, record_count, memory_bytes, disk_bytes FROM zdvm_snap_tab
      WHERE snap_id = @lv_new INTO TABLE @DATA(lt_cur).
    SORT lt_old BY table_name.
    SORT lt_cur BY table_name.

    TYPES: BEGIN OF ty_cmp,
             table_name  TYPE c LENGTH 12,
             group_key   TYPE c LENGTH 10,
             cutoff      TYPE d,
             pred_rows   TYPE int8,
             act_rows    TYPE int8,
             pred_mem_mb TYPE p LENGTH 12 DECIMALS 1,
             act_mem_mb  TYPE p LENGTH 12 DECIMALS 1,
             pred_dsk_mb TYPE p LENGTH 12 DECIMALS 1,
             act_dsk_mb  TYPE p LENGTH 12 DECIMALS 1,
           END OF ty_cmp.
    DATA lt_cmp TYPE STANDARD TABLE OF ty_cmp WITH EMPTY KEY.

    TYPES: BEGIN OF ty_grp,
             group_key   TYPE c LENGTH 30,
             pred_mem_mb TYPE p LENGTH 12 DECIMALS 1,
             act_mem_mb  TYPE p LENGTH 12 DECIMALS 1,
             pred_dsk_mb TYPE p LENGTH 12 DECIMALS 1,
             act_dsk_mb  TYPE p LENGTH 12 DECIMALS 1,
             mem_acc_pct TYPE p LENGTH 8 DECIMALS 1,
             dsk_acc_pct TYPE p LENGTH 8 DECIMALS 1,
           END OF ty_grp.
    DATA lt_grp TYPE SORTED TABLE OF ty_grp WITH UNIQUE KEY group_key.
    DATA ls_grp TYPE ty_grp.

    LOOP AT lt_rec INTO DATA(ls_rec) WHERE save_mem_bytes > 0.
      READ TABLE lt_old INTO DATA(ls_old)
        WITH KEY table_name = ls_rec-table_name BINARY SEARCH.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      READ TABLE lt_cur INTO DATA(ls_cur)
        WITH KEY table_name = ls_rec-table_name BINARY SEARCH.
      IF sy-subrc <> 0.
        CLEAR ls_cur.     " dropped below 1 MB: treat as ~0
      ENDIF.

      DATA(lv_act_mem)  = CONV decfloat34( ls_old-memory_bytes - ls_cur-memory_bytes ).
      DATA(lv_act_disk) = CONV decfloat34( ls_old-disk_bytes - ls_cur-disk_bytes ).

      APPEND VALUE #(
        table_name  = ls_rec-table_name
        group_key   = ls_rec-group_key
        cutoff      = ls_rec-cutoff_date
        pred_rows   = ls_rec-eligible_rows
        act_rows    = ls_old-record_count - ls_cur-record_count
        pred_mem_mb = CONV decfloat34( ls_rec-save_mem_bytes ) / 1048576
        act_mem_mb  = lv_act_mem / 1048576
        pred_dsk_mb = CONV decfloat34( ls_rec-save_disk_bytes ) / 1048576
        act_dsk_mb  = lv_act_disk / 1048576 ) TO lt_cmp.

      CLEAR ls_grp.
      ls_grp-group_key   = ls_rec-group_key.
      ls_grp-pred_mem_mb = CONV decfloat34( ls_rec-save_mem_bytes ) / 1048576.
      ls_grp-act_mem_mb  = lv_act_mem / 1048576.
      ls_grp-pred_dsk_mb = CONV decfloat34( ls_rec-save_disk_bytes ) / 1048576.
      ls_grp-act_dsk_mb  = lv_act_disk / 1048576.
      COLLECT ls_grp INTO lt_grp.
    ENDLOOP.

    LOOP AT lt_grp ASSIGNING FIELD-SYMBOL(<g>).
      IF <g>-pred_mem_mb > 0.
        <g>-mem_acc_pct = <g>-act_mem_mb * 100 / <g>-pred_mem_mb.
      ENDIF.
      IF <g>-pred_dsk_mb > 0.
        <g>-dsk_acc_pct = <g>-act_dsk_mb * 100 / <g>-pred_dsk_mb.
      ENDIF.
    ENDLOOP.

    out->write( '--- Per table: predicted vs actual ---' ).
    out->write( lt_cmp ).
    out->write( '--- Per cleanup action: accuracy (actual / predicted) ---' ).
    out->write( lt_grp ).
    out->write( 'Groups not cleaned yet show actual ~0 - expected.' ).

  ENDMETHOD.
ENDCLASS.
