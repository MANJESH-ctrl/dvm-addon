CLASS zcl_dvm_run_collector DEFINITION
  PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_dvm_run_collector IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.

    TRY.
        DATA(lv_id) = NEW zcl_dvm_collector( )->run( ).
      CATCH cx_root INTO DATA(lx_err).
        out->write( |Collector failed: { lx_err->get_text( ) }| ).
        RETURN.
    ENDTRY.

    SELECT SINGLE * FROM zdvm_snap
      WHERE snap_id = @lv_id
      INTO @DATA(ls_hdr).

    DATA(lv_mem_gb)  = CONV decfloat34( ls_hdr-total_mem_bytes )  / 1073741824.
    DATA(lv_disk_gb) = CONV decfloat34( ls_hdr-total_disk_bytes ) / 1073741824.

    out->write( |Snapshot { lv_id }: { ls_hdr-table_count } tables, | &&
                |memory { lv_mem_gb DECIMALS = 2 } GB, | &&
                |disk { lv_disk_gb DECIMALS = 2 } GB, | &&
                |runtime { ls_hdr-runtime_ms } ms| ).

    SELECT table_name, app_component, store_type, load_status,
           record_count, memory_bytes, disk_bytes
      FROM zdvm_snap_tab
      WHERE snap_id = @lv_id
      ORDER BY memory_bytes DESCENDING
      INTO TABLE @DATA(lt_top)
      UP TO 20 ROWS.

    TYPES: BEGIN OF ty_out,
             table_name TYPE c LENGTH 30,
             component  TYPE c LENGTH 24,
             store      TYPE c LENGTH 6,
             loaded     TYPE c LENGTH 10,
             rows       TYPE int8,
             mem_mb     TYPE p LENGTH 12 DECIMALS 1,
             disk_mb    TYPE p LENGTH 12 DECIMALS 1,
           END OF ty_out.
    DATA lt_out TYPE STANDARD TABLE OF ty_out WITH EMPTY KEY.

    LOOP AT lt_top INTO DATA(ls_top).
      APPEND VALUE #(
        table_name = ls_top-table_name
        component  = ls_top-app_component
        store      = ls_top-store_type
        loaded     = ls_top-load_status
        rows       = ls_top-record_count
        mem_mb     = CONV decfloat34( ls_top-memory_bytes ) / 1048576
        disk_mb    = CONV decfloat34( ls_top-disk_bytes ) / 1048576 ) TO lt_out.
    ENDLOOP.

    out->write( lt_out ).

  ENDMETHOD.
ENDCLASS.
