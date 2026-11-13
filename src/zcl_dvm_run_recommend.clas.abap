CLASS zcl_dvm_run_recommend DEFINITION
  PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_dvm_run_recommend IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.

    zcl_dvm_kb=>seed( ).

    SELECT MAX( snap_id ) FROM zdvm_snap INTO @DATA(lv_snap).
    IF lv_snap IS INITIAL.
      out->write( 'No snapshot found. Run ZCL_DVM_RUN_COLLECTOR first.' ).
      RETURN.
    ENDIF.

    SELECT SINGLE total_mem_bytes, total_disk_bytes FROM zdvm_snap
      WHERE snap_id = @lv_snap
      INTO @DATA(ls_hdr).

    out->write( NEW zcl_dvm_recommender( )->run( lv_snap ) ).

    " ---- EXAMPLE customer inputs (the real product asks the customer) ----
    DATA(lv_mem_factor)  = CONV decfloat34( 2 ).    " HANA RAM per GB of data
    DATA(lv_price_month) = CONV decfloat34( 25 ).   " currency per GB RAM per month

    SELECT * FROM zdvm_rec
      WHERE snap_id = @lv_snap
      ORDER BY save_mem_bytes DESCENDING
      INTO TABLE @DATA(lt_rec).

    TYPES: BEGIN OF ty_out,
             table_name TYPE c LENGTH 14,
             group_key  TYPE c LENGTH 10,
             method     TYPE c LENGTH 8,
             ret_days   TYPE i,
             elig_pct   TYPE p LENGTH 5 DECIMALS 1,
             blocked    TYPE int8,
             save_mb    TYPE p LENGTH 12 DECIMALS 1,
             save_dk_mb TYPE p LENGTH 12 DECIMALS 1,
             block_mb   TYPE p LENGTH 12 DECIMALS 1,
             risk       TYPE c LENGTH 6,
             signoff    TYPE c LENGTH 12,
           END OF ty_out.
    DATA lt_out TYPE STANDARD TABLE OF ty_out WITH EMPTY KEY.

    TYPES: BEGIN OF ty_grp,
             group_key  TYPE c LENGTH 30,
             method     TYPE c LENGTH 8,
             risk       TYPE c LENGTH 6,
             signoff    TYPE c LENGTH 12,
             save_gb    TYPE p LENGTH 10 DECIMALS 2,
             save_dk_gb TYPE p LENGTH 10 DECIMALS 2,
             block_gb   TYPE p LENGTH 10 DECIMALS 2,
           END OF ty_grp.
    DATA lt_grp TYPE SORTED TABLE OF ty_grp
      WITH UNIQUE KEY group_key method risk signoff.
    DATA ls_grp TYPE ty_grp.

    DATA lv_save_mem   TYPE decfloat34.
    DATA lv_save_disk  TYPE decfloat34.
    DATA lv_block_mem  TYPE decfloat34.

    LOOP AT lt_rec INTO DATA(ls_rec).
      APPEND VALUE #(
        table_name = ls_rec-table_name
        group_key  = ls_rec-group_key
        method     = ls_rec-method
        ret_days   = ls_rec-ret_days
        elig_pct   = COND #( WHEN ls_rec-total_rows > 0
                             THEN CONV decfloat34( ls_rec-eligible_rows ) * 100 / ls_rec-total_rows )
        blocked    = ls_rec-blocked_rows
        save_mb    = CONV decfloat34( ls_rec-save_mem_bytes ) / 1048576
        save_dk_mb = CONV decfloat34( ls_rec-save_disk_bytes ) / 1048576
        block_mb   = CONV decfloat34( ls_rec-blocked_mem_bytes ) / 1048576
        risk       = ls_rec-risk
        signoff    = ls_rec-signoff ) TO lt_out.

      CLEAR ls_grp.
      ls_grp-group_key  = ls_rec-group_key.
      ls_grp-method     = ls_rec-method.
      ls_grp-risk       = ls_rec-risk.
      ls_grp-signoff    = ls_rec-signoff.
      ls_grp-save_gb    = CONV decfloat34( ls_rec-save_mem_bytes ) / 1073741824.
      ls_grp-save_dk_gb = CONV decfloat34( ls_rec-save_disk_bytes ) / 1073741824.
      ls_grp-block_gb   = CONV decfloat34( ls_rec-blocked_mem_bytes ) / 1073741824.
      COLLECT ls_grp INTO lt_grp.

      lv_save_mem  = lv_save_mem  + ls_rec-save_mem_bytes.
      lv_save_disk = lv_save_disk + ls_rec-save_disk_bytes.
      lv_block_mem = lv_block_mem + ls_rec-blocked_mem_bytes.
    ENDLOOP.

    out->write( '--- Recommendations per table ---' ).
    out->write( lt_out ).
    out->write( '--- Per cleanup action ---' ).
    out->write( lt_grp ).

    DATA(lv_save_mem_gb)  = lv_save_mem / 1073741824.
    DATA(lv_save_disk_gb) = lv_save_disk / 1073741824.
    DATA(lv_block_gb)     = lv_block_mem / 1073741824.
    DATA(lv_total_gb)     = CONV decfloat34( ls_hdr-total_mem_bytes ) / 1073741824.
    DATA(lv_pct)          = COND decfloat34( WHEN lv_total_gb > 0
                                             THEN lv_save_mem_gb * 100 / lv_total_gb ).
    DATA(lv_ram_gb)       = lv_save_mem_gb * lv_mem_factor.
    DATA(lv_annual)       = lv_ram_gb * lv_price_month * 12.

    out->write( '--- Business case (example inputs) ---' ).
    out->write( |Data in memory reducible : { lv_save_mem_gb DECIMALS = 2 } GB | &&
                |({ lv_pct DECIMALS = 1 } % of { lv_total_gb DECIMALS = 2 } GB)| ).
    out->write( |Disk reducible           : { lv_save_disk_gb DECIMALS = 2 } GB| ).
    out->write( |Stuck behind blockers    : { lv_block_gb DECIMALS = 2 } GB in memory| ).
    out->write( |HANA RAM avoided (x{ lv_mem_factor }) : { lv_ram_gb DECIMALS = 2 } GB| ).
    out->write( |Annual saving at { lv_price_month } per GB/month: { lv_annual DECIMALS = 0 }| ).

  ENDMETHOD.
ENDCLASS.
