@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'DVM database tables'
@Metadata.ignorePropagatedAnnotations: true
@UI.headerInfo: { typeName: 'Database table', typeNamePlural: 'Database tables (largest first)',
                  title: { value: 'TableName' }, description: { value: 'Component' } }
@UI.presentationVariant: [{ sortOrder: [{ by: 'MemoryMB', direction: #DESC }] }]
define view entity ZC_DVM_TABLE
  as select from zdvm_snap_tab as t
    inner join ZI_DVM_LATEST as l on l.SnapId = t.snap_id
{
      @UI.facet: [
        { id: 'HdrMem',  purpose: #HEADER, type: #DATAPOINT_REFERENCE, targetQualifier: 'Mem',  position: 10 },
        { id: 'HdrDisk', purpose: #HEADER, type: #DATAPOINT_REFERENCE, targetQualifier: 'Disk', position: 20 },
        { id: 'Main', purpose: #STANDARD, type: #IDENTIFICATION_REFERENCE,
          label: 'Table details', position: 10 } ]
      @EndUserText.label: 'Table'
      @UI.lineItem:       [{ position: 10 }]
      @UI.identification: [{ position: 10 }]
      @UI.selectionField: [{ position: 10 }]
  key t.table_name as TableName,
      @UI.hidden: true
  key t.snap_id    as SnapId,

      @EndUserText.label: 'Application component'
      @UI.lineItem:       [{ position: 20 }]
      @UI.identification: [{ position: 20 }]
      @UI.selectionField: [{ position: 20 }]
      t.app_component as Component,

      @EndUserText.label: 'Package'
      @UI.identification: [{ position: 30 }]
      t.devclass as DevPackage,

      @EndUserText.label: 'Store'
      @UI.lineItem:       [{ position: 30 }]
      @UI.identification: [{ position: 40 }]
      t.store_type as StoreType,

      @EndUserText.label: 'Load status'
      @UI.lineItem:       [{ position: 40 }]
      @UI.identification: [{ position: 50 }]
      t.load_status as LoadStatus,

      @EndUserText.label: 'Rows'
      @UI.lineItem:       [{ position: 50 }]
      @UI.identification: [{ position: 60 }]
      t.record_count as RecordCount,

      @EndUserText.label: 'Memory (MB)'
      @UI.lineItem:       [{ position: 60 }]
      @UI.dataPoint:      { qualifier: 'Mem', title: 'Memory (MB)' }
      division( cast( t.memory_bytes as abap.dec(20,0) ), 1048576, 1 ) as MemoryMB,

      @EndUserText.label: 'Disk (MB)'
      @UI.lineItem:       [{ position: 70 }]
      @UI.dataPoint:      { qualifier: 'Disk', title: 'Disk (MB)' }
      division( cast( t.disk_bytes as abap.dec(20,0) ), 1048576, 1 ) as DiskMB
}
