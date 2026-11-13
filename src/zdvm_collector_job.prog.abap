REPORT zdvm_collector_job.

START-OF-SELECTION.
  TRY.
      DATA(lv_id) = NEW zcl_dvm_collector( )->run( ).
      MESSAGE |DVM snapshot { lv_id } stored| TYPE 'S'.
    CATCH cx_root INTO DATA(lx_err).
      MESSAGE lx_err->get_text( ) TYPE 'E'.
  ENDTRY.
