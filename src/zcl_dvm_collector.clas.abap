CLASS zcl_dvm_collector DEFINITION
  PUBLIC FINAL CREATE PUBLIC.

  PUBLIC SECTION.
    TYPES ty_snap_id TYPE c LENGTH 14.

    "! Tables smaller than this in BOTH memory and disk are skipped (1 MB)
    CONSTANTS c_min_bytes TYPE int8 VALUE 1048576.

    "! Takes one snapshot of all relevant tables and stores it
    METHODS run
      RETURNING VALUE(rv_snap_id) TYPE ty_snap_id
      RAISING   cx_sql_exception.

  PRIVATE SECTION.
    TYPES: BEGIN OF ty_raw,
             schema_name  TYPE c LENGTH 256,
             table_name   TYPE c LENGTH 256,
             store_type   TYPE c LENGTH 10,
             record_count TYPE int8,
             memory_bytes TYPE int8,
             disk_bytes   TYPE int8,
             load_status  TYPE c LENGTH 10,
           END OF ty_raw,
           tt_raw TYPE STANDARD TABLE OF ty_raw WITH EMPTY KEY.

    METHODS read_hana_sizes
      RETURNING VALUE(rt_raw) TYPE tt_raw
      RAISING   cx_sql_exception.
ENDCLASS.


CLASS zcl_dvm_collector IMPLEMENTATION.

  METHOD read_hana_sizes.
    " Column store: sum partitions per table.
    " Row store: used fixed + variable part.
    " Disk: persistence statistics, summed per table.
    DATA(lv_sql) =
      `SELECT t.SCHEMA_NAME, t.TABLE_NAME, t.STORE_TYPE, t.RECORD_COUNT, ` &&
      `       t.MEMORY_BYTES, COALESCE(p.DISK_BYTES, 0) AS DISK_BYTES, t.LOADED ` &&
      `FROM ( ` &&
      `  SELECT SCHEMA_NAME, TABLE_NAME, 'COLUMN' AS STORE_TYPE, ` &&
      `         SUM(RECORD_COUNT) AS RECORD_COUNT, ` &&
      `         SUM(MEMORY_SIZE_IN_TOTAL) AS MEMORY_BYTES, ` &&
      `         CASE WHEN COUNT(DISTINCT LOADED) > 1 THEN 'MIXED' ` &&
      `              ELSE MAX(LOADED) END AS LOADED ` &&
      `  FROM M_CS_TABLES WHERE SCHEMA_NAME = CURRENT_SCHEMA ` &&
      `  GROUP BY SCHEMA_NAME, TABLE_NAME ` &&
      `  UNION ALL ` &&
      `  SELECT SCHEMA_NAME, TABLE_NAME, 'ROW' AS STORE_TYPE, RECORD_COUNT, ` &&
      `         USED_FIXED_PART_SIZE + USED_VARIABLE_PART_SIZE AS MEMORY_BYTES, ` &&
      `         'FULL' AS LOADED ` &&
      `  FROM M_RS_TABLES WHERE SCHEMA_NAME = CURRENT_SCHEMA ` &&
      `) t ` &&
      `LEFT OUTER JOIN ( ` &&
      `  SELECT SCHEMA_NAME, TABLE_NAME, SUM(DISK_SIZE) AS DISK_BYTES ` &&
      `  FROM M_TABLE_PERSISTENCE_STATISTICS WHERE SCHEMA_NAME = CURRENT_SCHEMA ` &&
      `  GROUP BY SCHEMA_NAME, TABLE_NAME ` &&
      `) p ON p.SCHEMA_NAME = t.SCHEMA_NAME AND p.TABLE_NAME = t.TABLE_NAME ` &&
      |WHERE t.MEMORY_BYTES >= { c_min_bytes } | &&
      |   OR COALESCE(p.DISK_BYTES, 0) >= { c_min_bytes }|.

    DATA(lo_result) = NEW cl_sql_statement( )->execute_query( lv_sql ).
    lo_result->set_param_table( REF #( rt_raw ) ).
    lo_result->next_package( ).
    lo_result->close( ).
  ENDMETHOD.


  METHOD run.
    GET RUN TIME FIELD DATA(lv_t0).
    rv_snap_id = |{ sy-datum }{ sy-uzeit }|.

    " 1) Sizes from HANA
    DATA(lt_raw) = read_hana_sizes( ).

    " 2) Labels from the ABAP dictionary
    TYPES: BEGIN OF ty_name,
             tabname  TYPE tabname,
             obj_name TYPE sobj_name,
           END OF ty_name.
    DATA lt_names TYPE STANDARD TABLE OF ty_name WITH EMPTY KEY.

    LOOP AT lt_raw INTO DATA(ls_raw).
      IF strlen( ls_raw-table_name ) <= 30.
        APPEND VALUE #( tabname  = ls_raw-table_name
                        obj_name = ls_raw-table_name ) TO lt_names.
      ENDIF.
    ENDLOOP.

    IF lt_names IS NOT INITIAL.
      SELECT tabname, tabclass
        FROM dd02l
        FOR ALL ENTRIES IN @lt_names
        WHERE tabname  = @lt_names-tabname
          AND as4local = 'A'
          AND as4vers  = '0000'
        INTO TABLE @DATA(lt_dd02l).

      SELECT obj_name, devclass
        FROM tadir
        FOR ALL ENTRIES IN @lt_names
        WHERE pgmid    = 'R3TR'
          AND object   = 'TABL'
          AND obj_name = @lt_names-obj_name
        INTO TABLE @DATA(lt_tadir).
    ENDIF.

    IF lt_tadir IS NOT INITIAL.
      SELECT t~devclass, d~ps_posid
        FROM tdevc AS t
        INNER JOIN df14l AS d ON d~fctr_id = t~component
        FOR ALL ENTRIES IN @lt_tadir
        WHERE t~devclass = @lt_tadir-devclass
          AND d~as4local = 'A'
        INTO TABLE @DATA(lt_comp).
    ENDIF.

    SORT lt_dd02l BY tabname.
    SORT lt_tadir BY obj_name.
    SORT lt_comp  BY devclass.
    DELETE ADJACENT DUPLICATES FROM lt_comp COMPARING devclass.

    " 3) Build snapshot rows
    DATA lt_tab TYPE STANDARD TABLE OF zdvm_snap_tab WITH EMPTY KEY.
    DATA ls_hdr TYPE zdvm_snap.

    LOOP AT lt_raw INTO ls_raw.
      DATA(ls_row) = VALUE zdvm_snap_tab(
        client       = sy-mandt
        snap_id      = rv_snap_id
        table_name   = ls_raw-table_name
        store_type   = ls_raw-store_type
        record_count = ls_raw-record_count
        memory_bytes = ls_raw-memory_bytes
        disk_bytes   = ls_raw-disk_bytes
        load_status  = ls_raw-load_status ).

      IF strlen( ls_raw-table_name ) <= 30.
        READ TABLE lt_dd02l INTO DATA(ls_dd)
          WITH KEY tabname = ls_raw-table_name BINARY SEARCH.
        IF sy-subrc = 0.
          ls_row-tab_class = ls_dd-tabclass.
        ENDIF.

        READ TABLE lt_tadir INTO DATA(ls_tadir)
          WITH KEY obj_name = ls_raw-table_name BINARY SEARCH.
        IF sy-subrc = 0.
          ls_row-devclass = ls_tadir-devclass.
          READ TABLE lt_comp INTO DATA(ls_comp)
            WITH KEY devclass = ls_tadir-devclass BINARY SEARCH.
          IF sy-subrc = 0.
            ls_row-app_component = ls_comp-ps_posid.
          ENDIF.
        ENDIF.
      ENDIF.

      APPEND ls_row TO lt_tab.
      ls_hdr-total_mem_bytes  += ls_raw-memory_bytes.
      ls_hdr-total_disk_bytes += ls_raw-disk_bytes.
    ENDLOOP.

    SORT lt_tab BY table_name.
    DELETE ADJACENT DUPLICATES FROM lt_tab COMPARING table_name.

    " 4) Header + save
    GET RUN TIME FIELD DATA(lv_t1).
    ls_hdr-client      = sy-mandt.
    ls_hdr-snap_id     = rv_snap_id.
    ls_hdr-snap_date   = sy-datum.
    ls_hdr-snap_time   = sy-uzeit.
    ls_hdr-db_schema   = VALUE #( lt_raw[ 1 ]-schema_name OPTIONAL ).
    ls_hdr-table_count = lines( lt_tab ).
    ls_hdr-runtime_ms  = ( lv_t1 - lv_t0 ) / 1000.

    INSERT zdvm_snap FROM @ls_hdr.
    INSERT zdvm_snap_tab FROM TABLE @lt_tab.
    COMMIT WORK.
  ENDMETHOD.

ENDCLASS.
