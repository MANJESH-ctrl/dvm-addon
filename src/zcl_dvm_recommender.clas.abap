CLASS zcl_dvm_recommender DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    "! Computes eligible / blocked rows and savings per actionable table
    METHODS run
      IMPORTING iv_snap_id    TYPE zcl_dvm_collector=>ty_snap_id
      RETURNING VALUE(rt_log) TYPE string_table.

  PRIVATE SECTION.
    TYPES: BEGIN OF ty_cnt,
             total    TYPE int8,
             old_rows TYPE int8,
             blocked  TYPE int8,
           END OF ty_cnt,
           tt_cnt TYPE STANDARD TABLE OF ty_cnt WITH EMPTY KEY,
           BEGIN OF ty_cache,
             src TYPE string,
             ok  TYPE abap_bool,
             cnt TYPE ty_cnt,
           END OF ty_cache.

    DATA mt_cache TYPE HASHED TABLE OF ty_cache WITH UNIQUE KEY src.

    METHODS count_rows
      IMPORTING iv_table      TYPE csequence
                iv_field      TYPE csequence
                iv_cutoff     TYPE d
                iv_blocker    TYPE csequence
      RETURNING VALUE(rs_cnt) TYPE ty_cnt
      RAISING   cx_sql_exception.
ENDCLASS.


CLASS zcl_dvm_recommender IMPLEMENTATION.

  METHOD run.
    DATA(lo_kb) = NEW zcl_dvm_kb( ).
    DATA lt_rec    TYPE STANDARD TABLE OF zdvm_rec WITH EMPTY KEY.
    DATA lv_exists TYPE abap_bool.

    SELECT table_name, memory_bytes, disk_bytes FROM zdvm_snap_tab
      WHERE snap_id = @iv_snap_id
      INTO TABLE @DATA(lt_snap).

    LOOP AT lt_snap INTO DATA(ls_snap).
      DATA(ls_kb) = lo_kb->find( ls_snap-table_name ).
      IF ls_kb-category <> 'HOUSEKEEPING' AND ls_kb-category <> 'ARCHIVING'.
        CONTINUE.
      ENDIF.

      DATA(ls_rec) = VALUE zdvm_rec(
        snap_id    = iv_snap_id
        table_name = ls_snap-table_name
        group_key  = COND #( WHEN ls_kb-arch_object IS NOT INITIAL
                             THEN ls_kb-arch_object ELSE ls_kb-table_name )
        category   = ls_kb-category
        method     = ls_kb-method
        tool       = ls_kb-cleanup_tool
        risk       = ls_kb-risk
        signoff    = ls_kb-signoff
        ret_days   = ls_kb-ret_days
        mem_bytes  = ls_snap-memory_bytes
        disk_bytes = ls_snap-disk_bytes ).

      IF ls_kb-age_table IS INITIAL OR ls_kb-age_field IS INITIAL OR ls_kb-ret_days <= 0.
        ls_rec-note = 'No age rule - manual review'.
        APPEND ls_rec TO lt_rec.
        CONTINUE.
      ENDIF.

      ls_rec-cutoff_date = sy-datum - ls_kb-ret_days.
      DATA(lv_blocker) = replace( val  = CONV string( ls_kb-blocker_sql )
                                  sub  = '{TODAY}'
                                  with = CONV string( sy-datum )
                                  occ  = 0 ).
      DATA(lv_src) = |{ ls_kb-age_table }/{ ls_kb-age_field }/{ ls_rec-cutoff_date }/{ lv_blocker }|.

      READ TABLE mt_cache INTO DATA(ls_cache) WITH TABLE KEY src = lv_src.
      IF sy-subrc <> 0.
        CLEAR ls_cache.
        ls_cache-src = lv_src.
        CLEAR lv_exists.
        SELECT SINGLE @abap_true FROM dd03l
          WHERE tabname   = @ls_kb-age_table
            AND fieldname = @ls_kb-age_field
            AND as4local  = 'A'
          INTO @lv_exists.
        IF lv_exists = abap_true.
          TRY.
              ls_cache-cnt = count_rows( iv_table   = ls_kb-age_table
                                         iv_field   = ls_kb-age_field
                                         iv_cutoff  = ls_rec-cutoff_date
                                         iv_blocker = lv_blocker ).
              ls_cache-ok = abap_true.
            CATCH cx_sql_exception INTO DATA(lx_sql).
              APPEND |Count { lv_src } failed: { lx_sql->get_text( ) }| TO rt_log.
          ENDTRY.
        ENDIF.
        INSERT ls_cache INTO TABLE mt_cache.
      ENDIF.

      IF ls_cache-ok = abap_true AND ls_cache-cnt-total > 0.
        ls_rec-total_rows    = ls_cache-cnt-total.
        ls_rec-blocked_rows  = ls_cache-cnt-blocked.
        ls_rec-eligible_rows = ls_cache-cnt-old_rows - ls_cache-cnt-blocked.

        DATA(lv_ratio_save)  = CONV decfloat34( ls_rec-eligible_rows ) / ls_rec-total_rows.
        DATA(lv_ratio_block) = CONV decfloat34( ls_rec-blocked_rows ) / ls_rec-total_rows.

        ls_rec-save_mem_bytes    = ls_snap-memory_bytes * lv_ratio_save.
        ls_rec-save_disk_bytes   = ls_snap-disk_bytes   * lv_ratio_save.
        ls_rec-blocked_mem_bytes = ls_snap-memory_bytes * lv_ratio_block.
        ls_rec-note = |{ ls_rec-eligible_rows } of { ls_rec-total_rows } rows ({ ls_kb-age_table }) beyond { ls_kb-ret_days } days|.
      ELSE.
        ls_rec-note = 'Age count not available'.
      ENDIF.

      APPEND ls_rec TO lt_rec.
    ENDLOOP.

    DELETE FROM zdvm_rec WHERE snap_id = @iv_snap_id.
    INSERT zdvm_rec FROM TABLE @lt_rec.
    COMMIT WORK.
    APPEND |{ lines( lt_rec ) } recommendations stored for snapshot { iv_snap_id }| TO rt_log.
  ENDMETHOD.


  METHOD count_rows.
    DATA lt_cnt TYPE tt_cnt.

    DATA(lv_old) = |"{ iv_field }" < '{ iv_cutoff }' AND "{ iv_field }" <> '00000000'|.
    DATA(lv_blk) = COND string( WHEN iv_blocker IS INITIAL THEN `1 = 0`
                                ELSE iv_blocker ).

    DATA(lv_sql) =
      |SELECT COUNT(*) AS TOTAL, | &&
      |SUM(CASE WHEN { lv_old } THEN 1 ELSE 0 END) AS OLD_ROWS, | &&
      |SUM(CASE WHEN { lv_old } AND ({ lv_blk }) THEN 1 ELSE 0 END) AS BLOCKED | &&
      |FROM "{ iv_table }"|.

    DATA(lo_result) = NEW cl_sql_statement( )->execute_query( lv_sql ).
    lo_result->set_param_table( REF #( lt_cnt ) ).
    lo_result->next_package( ).
    lo_result->close( ).
    rs_cnt = VALUE #( lt_cnt[ 1 ] OPTIONAL ).
  ENDMETHOD.

ENDCLASS.
