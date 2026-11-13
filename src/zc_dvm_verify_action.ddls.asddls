@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'DVM predicted vs actual'
@Metadata.ignorePropagatedAnnotations: true
@UI.headerInfo: { typeName: 'Predicted vs actual',
                  typeNamePlural: 'Predicted vs actual per cleanup action',
                  title:       { value: 'CleanupAction' },
                  description: { value: 'Status' } }
@UI.presentationVariant: [{ sortOrder: [ { by: 'StatusCriticality', direction: #DESC },
                                         { by: 'PredMemMB',         direction: #DESC } ] }]
define view entity ZC_DVM_VERIFY_ACTION
  as select from zdvm_verg as g
    inner join ZI_DVM_LATEST_VER as l on l.PredSnap = g.pred_snap
{
      @UI.facet: [
        { id: 'HdrPredM', purpose: #HEADER, type: #DATAPOINT_REFERENCE, targetQualifier: 'PredMem', position: 10 },
        { id: 'HdrActM',  purpose: #HEADER, type: #DATAPOINT_REFERENCE, targetQualifier: 'ActMem',  position: 20 },
        { id: 'HdrAccM',  purpose: #HEADER, type: #DATAPOINT_REFERENCE, targetQualifier: 'AccMem',  position: 30 },
        { id: 'HdrAccD',  purpose: #HEADER, type: #DATAPOINT_REFERENCE, targetQualifier: 'AccDisk', position: 40 },
        { id: 'Memory', purpose: #STANDARD, type: #FIELDGROUP_REFERENCE, targetQualifier: 'Memory',
          label: 'Memory', position: 10 },
        { id: 'Disk',   purpose: #STANDARD, type: #FIELDGROUP_REFERENCE, targetQualifier: 'Disk',
          label: 'Disk', position: 20 },
        { id: 'Snap',   purpose: #STANDARD, type: #FIELDGROUP_REFERENCE, targetQualifier: 'Snap',
          label: 'Measurement', position: 30 } ]
      @EndUserText.label: 'Cleanup action'
      @UI.lineItem:       [{ position: 10 }]
      @UI.selectionField: [{ position: 10 }]
  key g.group_key as CleanupAction,
      @EndUserText.label: 'Prediction snapshot'
      @UI.fieldGroup: [{ qualifier: 'Snap', position: 10 }]
  key g.pred_snap as PredictionSnapshot,

      @EndUserText.label: 'Measured snapshot'
      @UI.fieldGroup: [{ qualifier: 'Snap', position: 20 }]
      g.meas_snap as MeasuredSnapshot,

      @EndUserText.label: 'Method'
      @UI.lineItem:   [{ position: 20 }]
      @UI.fieldGroup: [{ qualifier: 'Snap', position: 30 }]
      g.method as Method,

      @EndUserText.label: 'Status'
      @UI.lineItem:       [{ position: 30, criticality: 'StatusCriticality' }]
      @UI.selectionField: [{ position: 20 }]
      g.status as Status,

      @EndUserText.label: 'Predicted memory (MB)'
      @UI.lineItem:   [{ position: 40 }]
      @UI.fieldGroup: [{ qualifier: 'Memory', position: 10 }]
      @UI.dataPoint:  { qualifier: 'PredMem', title: 'Predicted memory (MB)' }
      division( cast( g.pred_mem_bytes as abap.dec(20,0) ), 1048576, 1 ) as PredMemMB,

      @EndUserText.label: 'Actual memory freed (MB)'
      @UI.lineItem:   [{ position: 50 }]
      @UI.fieldGroup: [{ qualifier: 'Memory', position: 20 }]
      @UI.dataPoint:  { qualifier: 'ActMem', title: 'Actual memory freed (MB)' }
      division( cast( g.act_mem_bytes as abap.dec(20,0) ), 1048576, 1 ) as ActMemMB,

      @EndUserText.label: 'Memory accuracy (%)'
      @UI.lineItem:   [{ position: 60, criticality: 'StatusCriticality' }]
      @UI.fieldGroup: [{ qualifier: 'Memory', position: 30 }]
      @UI.dataPoint:  { qualifier: 'AccMem', title: 'Memory accuracy (%)', criticality: 'StatusCriticality' }
      g.mem_acc_pct as MemAccuracyPct,

      @EndUserText.label: 'Predicted disk (MB)'
      @UI.lineItem:   [{ position: 70 }]
      @UI.fieldGroup: [{ qualifier: 'Disk', position: 10 }]
      division( cast( g.pred_disk_bytes as abap.dec(20,0) ), 1048576, 1 ) as PredDiskMB,

      @EndUserText.label: 'Actual disk freed (MB)'
      @UI.lineItem:   [{ position: 80 }]
      @UI.fieldGroup: [{ qualifier: 'Disk', position: 20 }]
      division( cast( g.act_disk_bytes as abap.dec(20,0) ), 1048576, 1 ) as ActDiskMB,

      @EndUserText.label: 'Disk accuracy (%)'
      @UI.lineItem:   [{ position: 90, criticality: 'StatusCriticality' }]
      @UI.fieldGroup: [{ qualifier: 'Disk', position: 30 }]
      @UI.dataPoint:  { qualifier: 'AccDisk', title: 'Disk accuracy (%)', criticality: 'StatusCriticality' }
      g.disk_acc_pct as DiskAccuracyPct,

      @UI.hidden: true
      g.status_crit as StatusCriticality
}
