CLASS zcl_dvm_run_safety DEFINITION
  PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_dvm_run_safety IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.

    TYPES: BEGIN OF ty_disk,
             usage_type TYPE c LENGTH 32,
             total_size TYPE int8,
             used_size  TYPE int8,
           END OF ty_disk.
    DATA lt_disk TYPE STANDARD TABLE OF ty_disk WITH EMPTY KEY.

    TYPES: BEGIN OF ty_out,
             usage_type TYPE c LENGTH 32,
             total_gb   TYPE p LENGTH 10 DECIMALS 1,
             used_gb    TYPE p LENGTH 10 DECIMALS 1,
             free_gb    TYPE p LENGTH 10 DECIMALS 1,
           END OF ty_out.
    DATA lt_out TYPE STANDARD TABLE OF ty_out WITH EMPTY KEY.

    TYPES: BEGIN OF ty_ini,
             layer_name TYPE c LENGTH 16,
             value      TYPE c LENGTH 64,
           END OF ty_ini.
    DATA lt_ini TYPE STANDARD TABLE OF ty_ini WITH EMPTY KEY.

    TRY.
        DATA(lo_r1) = NEW cl_sql_statement( )->execute_query(
          `SELECT USAGE_TYPE, MAX(TOTAL_SIZE), MAX(USED_SIZE) ` &&
          `FROM M_DISKS GROUP BY USAGE_TYPE` ).
        lo_r1->set_param_table( REF #( lt_disk ) ).
        lo_r1->next_package( ).
        lo_r1->close( ).
        LOOP AT lt_disk INTO DATA(ls_disk).
          APPEND VALUE #(
            usage_type = ls_disk-usage_type
            total_gb   = CONV decfloat34( ls_disk-total_size ) / 1073741824
            used_gb    = CONV decfloat34( ls_disk-used_size ) / 1073741824
            free_gb    = CONV decfloat34( ls_disk-total_size - ls_disk-used_size ) / 1073741824 )
            TO lt_out.
        ENDLOOP.
        out->write( '--- Disk space per usage type ---' ).
        out->write( lt_out ).
      CATCH cx_sql_exception INTO DATA(lx1).
        out->write( |Disk check failed: { lx1->get_text( ) }| ).
    ENDTRY.

    TRY.
        DATA(lo_r2) = NEW cl_sql_statement( )->execute_query(
          `SELECT LAYER_NAME, VALUE FROM M_INIFILE_CONTENTS ` &&
          `WHERE FILE_NAME = 'global.ini' AND SECTION = 'persistence' ` &&
          `AND KEY = 'log_mode'` ).
        lo_r2->set_param_table( REF #( lt_ini ) ).
        lo_r2->next_package( ).
        lo_r2->close( ).
        out->write( '--- HANA log_mode (overwrite = log space is reused) ---' ).
        out->write( lt_ini ).
      CATCH cx_sql_exception INTO DATA(lx2).
        out->write( |log_mode check failed: { lx2->get_text( ) }| ).
    ENDTRY.

  ENDMETHOD.
ENDCLASS.
