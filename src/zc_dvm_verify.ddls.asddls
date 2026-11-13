@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'DVM predicted vs actual per table'
@Metadata.ignorePropagatedAnnotations: true
@UI.headerInfo: { typeName: 'Table result',
                  typeNamePlural: 'Predicted vs actual per table',
                  title:       { value: 'TableName' },
                  description: { value: 'Status' } }
@UI.presentationVariant: [{ sortOrder: [ { by: 'StatusCriticality', direction: #DESC },
                                         { by: 'PredMemMB',         direction: #DESC } ] }]
define view entity ZC_DVM_VERIFY
  as select from zdvm_ver as v
    inner join ZI_DVM_LATEST_VER as l on l.PredSnap = v.pred_snap
{
      @UI.facet: [
        { id: 'Main', purpose: #STANDARD, type: #IDENTIFICATION_REFERENCE,
          label: 'Result', position: 10 } ]
      @EndUserText.label: 'Table'
      @UI.lineItem:       [{ position: 10 }]
      @UI.identification: [{ position: 10 }]
      @UI.selectionField: [{ position: 10 }]
  key v.table_name as TableName,
      @UI.hidden: true
  key v.pred_snap  as PredictionSnapshot,

      @EndUserText.label: 'Cleanup action'
      @UI.lineItem:       [{ position: 20 }]
      @UI.identification: [{ position: 20 }]
      @UI.selectionField: [{ position: 20 }]
      v.group_key as CleanupAction,

      @EndUserText.label: 'Status'
      @UI.lineItem:       [{ position: 30, criticality: 'StatusCriticality' }]
      @UI.identification: [{ position: 30, criticality: 'StatusCriticality' }]
      @UI.selectionField: [{ position: 30 }]
      v.status as Status,

      @EndUserText.label: 'Cutoff date'
      @UI.identification: [{ position: 40 }]
      v.cutoff_date as CutoffDate,

      @EndUserText.label: 'Predicted rows (age source)'
      @UI.lineItem:       [{ position: 40 }]
      @UI.identification: [{ position: 50 }]
      v.pred_rows as PredRows,

      @EndUserText.label: 'Rows removed'
      @UI.lineItem:       [{ position: 50 }]
      @UI.identification: [{ position: 60 }]
      v.act_rows as ActRows,

      @EndUserText.label: 'Predicted memory (MB)'
      @UI.lineItem:       [{ position: 60 }]
      @UI.identification: [{ position: 70 }]
      division( cast( v.pred_mem_bytes as abap.dec(20,0) ), 1048576, 1 ) as PredMemMB,

      @EndUserText.label: 'Actual memory freed (MB)'
      @UI.lineItem:       [{ position: 70 }]
      @UI.identification: [{ position: 80 }]
      division( cast( v.act_mem_bytes as abap.dec(20,0) ), 1048576, 1 ) as ActMemMB,

      @EndUserText.label: 'Memory accuracy (%)'
      @UI.lineItem:       [{ position: 80, criticality: 'StatusCriticality' }]
      @UI.identification: [{ position: 90 }]
      v.mem_acc_pct as MemAccuracyPct,

      @EndUserText.label: 'Predicted disk (MB)'
      @UI.lineItem:       [{ position: 90 }]
      @UI.identification: [{ position: 100 }]
      division( cast( v.pred_disk_bytes as abap.dec(20,0) ), 1048576, 1 ) as PredDiskMB,

      @EndUserText.label: 'Actual disk freed (MB)'
      @UI.lineItem:       [{ position: 100 }]
      @UI.identification: [{ position: 110 }]
      division( cast( v.act_disk_bytes as abap.dec(20,0) ), 1048576, 1 ) as ActDiskMB,

      @EndUserText.label: 'Disk accuracy (%)'
      @UI.lineItem:       [{ position: 110, criticality: 'StatusCriticality' }]
      @UI.identification: [{ position: 120 }]
      v.disk_acc_pct as DiskAccuracyPct,

      @UI.hidden: true
      v.status_crit as StatusCriticality
}
