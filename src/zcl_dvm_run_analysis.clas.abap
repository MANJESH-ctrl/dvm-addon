CLASS zcl_dvm_run_analysis DEFINITION
  PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_dvm_run_analysis IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.

    " 1) Knowledge base up to date
    zcl_dvm_kb=>seed( ).

    " 2) Latest snapshot
    SELECT MAX( snap_id ) FROM zdvm_snap INTO @DATA(lv_snap).
    IF lv_snap IS INITIAL.
      out->write( 'No snapshot found. Run ZCL_DVM_RUN_COLLECTOR first.' ).
      RETURN.
    ENDIF.
    out->write( |Analysing snapshot { lv_snap }| ).

    " 3) Age profiles
    out->write( NEW zcl_dvm_age_profiler( )->run( lv_snap ) ).

    " 4) Memory by category + actionable tables
    DATA(lo_kb) = NEW zcl_dvm_kb( ).
    SELECT table_name, memory_bytes, disk_bytes FROM zdvm_snap_tab
      WHERE snap_id = @lv_snap
      INTO TABLE @DATA(lt_snap).

    TYPES: BEGIN OF ty_sum,
             category TYPE c LENGTH 12,
             tables   TYPE i,
             mem_gb   TYPE p LENGTH 10 DECIMALS 2,
             disk_gb  TYPE p LENGTH 10 DECIMALS 2,
           END OF ty_sum.
    DATA lt_sum TYPE SORTED TABLE OF ty_sum WITH UNIQUE KEY category.
    DATA ls_sum TYPE ty_sum.

    TYPES: BEGIN OF ty_act,
             table_name  TYPE c LENGTH 30,
             category    TYPE c LENGTH 12,
             method      TYPE c LENGTH 8,
             object_tool TYPE c LENGTH 40,
             risk        TYPE c LENGTH 6,
             signoff     TYPE c LENGTH 12,
             mem_mb      TYPE p LENGTH 12 DECIMALS 1,
             disk_mb     TYPE p LENGTH 12 DECIMALS 1,
           END OF ty_act.
    DATA lt_act TYPE STANDARD TABLE OF ty_act WITH EMPTY KEY.

    LOOP AT lt_snap INTO DATA(ls_snap).
      DATA(ls_kb) = lo_kb->find( ls_snap-table_name ).

      CLEAR ls_sum.
      ls_sum-category = COND #( WHEN ls_kb-category IS INITIAL
                                THEN 'UNCLASSIFIED' ELSE ls_kb-category ).
      ls_sum-tables  = 1.
      ls_sum-mem_gb  = CONV decfloat34( ls_snap-memory_bytes ) / 1073741824.
      ls_sum-disk_gb = CONV decfloat34( ls_snap-disk_bytes ) / 1073741824.
      COLLECT ls_sum INTO lt_sum.

      IF ls_kb-category = 'HOUSEKEEPING' OR ls_kb-category = 'ARCHIVING'.
        APPEND VALUE #(
          table_name  = ls_snap-table_name
          category    = ls_kb-category
          method      = ls_kb-method
          object_tool = COND #( WHEN ls_kb-arch_object IS NOT INITIAL
                                THEN |{ ls_kb-arch_object } / { ls_kb-cleanup_tool }|
                                ELSE ls_kb-cleanup_tool )
          risk        = ls_kb-risk
          signoff     = ls_kb-signoff
          mem_mb      = CONV decfloat34( ls_snap-memory_bytes ) / 1048576
          disk_mb     = CONV decfloat34( ls_snap-disk_bytes ) / 1048576 ) TO lt_act.
      ENDIF.
    ENDLOOP.

    out->write( '--- Memory and disk by category ---' ).
    out->write( lt_sum ).

    SORT lt_act BY mem_mb DESCENDING.
    IF lines( lt_act ) > 15.
      DELETE lt_act FROM 16.
    ENDIF.
    out->write( '--- Top actionable tables ---' ).
    out->write( lt_act ).

    " 5) Age profiles of key tables
    SELECT table_name, age_year, row_count FROM zdvm_age
      WHERE snap_id = @lv_snap
        AND table_name IN ( 'BALHDR', 'DBTABLOG', 'CDHDR', 'EDIDC', 'ACDOCA', 'MATDOC' )
      ORDER BY table_name, age_year
      INTO TABLE @DATA(lt_age).
    out->write( '--- Age profile: rows per year ---' ).
    out->write( lt_age ).

  ENDMETHOD.
ENDCLASS.
