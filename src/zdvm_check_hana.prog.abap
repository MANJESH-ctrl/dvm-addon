REPORT zdvm_check_hana.

TYPES: BEGIN OF ty_row,
         schema_name TYPE c LENGTH 256,
         table_name  TYPE c LENGTH 256,
         record_cnt  TYPE int8,
         memory_byte TYPE int8,
         loaded      TYPE c LENGTH 10,
       END OF ty_row.
DATA lt_rows TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY.

TRY.
    DATA(lo_result) = NEW cl_sql_statement( )->execute_query(
      `SELECT TOP 25 SCHEMA_NAME, TABLE_NAME, RECORD_COUNT, ` &&
      `MEMORY_SIZE_IN_TOTAL, LOADED ` &&
      `FROM M_CS_TABLES ORDER BY MEMORY_SIZE_IN_TOTAL DESC` ).
    lo_result->set_param_table( REF #( lt_rows ) ).
    lo_result->next_package( ).
    lo_result->close( ).
    cl_demo_output=>display( lt_rows ).
  CATCH cx_sql_exception INTO DATA(lx_sql).
    WRITE: / 'SQL error:', lx_sql->get_text( ).
ENDTRY.
