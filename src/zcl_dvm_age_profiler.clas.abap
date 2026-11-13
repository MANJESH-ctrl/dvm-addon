CLASS zcl_dvm_age_profiler DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    "! Builds rows-per-year profiles for all KB tables in the snapshot
    METHODS run
      IMPORTING iv_snap_id    TYPE zcl_dvm_collector=>ty_snap_id
      RETURNING VALUE(rt_log) TYPE string_table.

  PRIVATE SECTION.
    TYPES: BEGIN OF ty_year,
             yr  TYPE c LENGTH 4,
             cnt TYPE int8,
           END OF ty_year,
           tt_year TYPE STANDARD TABLE OF ty_year WITH EMPTY KEY,
           BEGIN OF ty_cache,
             src   TYPE string,
             ok    TYPE abap_bool,
             years TYPE tt_year,
           END OF ty_cache.

    DATA mt_cache TYPE HASHED TABLE OF ty_cache WITH UNIQUE KEY src.

    METHODS count_by_year
      IMPORTING iv_table TYPE csequence
                iv_field TYPE csequence
      EXPORTING et_years TYPE tt_year
      RAISING   cx_sql_exception.
ENDCLASS.


CLASS zcl_dvm_age_profiler IMPLEMENTATION.

  METHOD run.
    DATA(lo_kb) = NEW zcl_dvm_kb( ).
    DATA lt_age TYPE STANDARD TABLE OF zdvm_age WITH EMPTY KEY.
    DATA lv_exists TYPE abap_bool.

    SELECT table_name FROM zdvm_snap_tab
      WHERE snap_id = @iv_snap_id
      INTO TABLE @DATA(lt_snap).

    LOOP AT lt_snap INTO DATA(ls_snap).
      DATA(ls_kb) = lo_kb->find( ls_snap-table_name ).
      IF ls_kb-age_table IS INITIAL OR ls_kb-age_field IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA(lv_src) = |{ ls_kb-age_table }.{ ls_kb-age_field }|.
      READ TABLE mt_cache INTO DATA(ls_cache) WITH TABLE KEY src = lv_src.

      IF sy-subrc <> 0.
        " Not counted yet: check the field exists, then count once
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
              count_by_year( EXPORTING iv_table = ls_kb-age_table
                                       iv_field = ls_kb-age_field
                             IMPORTING et_years = ls_cache-years ).
              ls_cache-ok = abap_true.
              APPEND |Age profile { lv_src }: { lines( ls_cache-years ) } distinct years| TO rt_log.
            CATCH cx_sql_exception INTO DATA(lx_sql).
              APPEND |Age profile { lv_src } failed: { lx_sql->get_text( ) }| TO rt_log.
          ENDTRY.
        ELSE.
          APPEND |Age profile { lv_src } skipped: field not in dictionary| TO rt_log.
        ENDIF.
        INSERT ls_cache INTO TABLE mt_cache.
      ENDIF.

      IF ls_cache-ok = abap_true.
        LOOP AT ls_cache-years INTO DATA(ls_year).
          APPEND VALUE #( snap_id    = iv_snap_id
                          table_name = ls_snap-table_name
                          age_year   = ls_year-yr
                          age_table  = ls_kb-age_table
                          row_count  = ls_year-cnt ) TO lt_age.
        ENDLOOP.
      ENDIF.
    ENDLOOP.

    DELETE FROM zdvm_age WHERE snap_id = @iv_snap_id.
    INSERT zdvm_age FROM TABLE @lt_age.
    COMMIT WORK.
  ENDMETHOD.


  METHOD count_by_year.
    CLEAR et_years.
    " Counts all clients on purpose: memory figures are also for all clients
    DATA(lv_sql) =
      |SELECT LEFT("{ iv_field }", 4) AS YR, COUNT(*) AS CNT | &&
      |FROM "{ iv_table }" GROUP BY LEFT("{ iv_field }", 4)|.

    DATA(lo_result) = NEW cl_sql_statement( )->execute_query( lv_sql ).
    lo_result->set_param_table( REF #( et_years ) ).
    lo_result->next_package( ).
    lo_result->close( ).
  ENDMETHOD.

ENDCLASS.
