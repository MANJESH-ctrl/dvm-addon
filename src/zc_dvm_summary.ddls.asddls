@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'DVM business case'
@Metadata.ignorePropagatedAnnotations: true
@UI.headerInfo: { typeName: 'Business case', typeNamePlural: 'Business case',
                  title: { value: 'SnapId' },
                  description: { value: 'SnapshotDate' } }
define view entity ZC_DVM_SUMMARY
  as select from zdvm_rec as r
    inner join ZI_DVM_LATEST as l on l.SnapId = r.snap_id
    inner join zdvm_snap     as s on s.snap_id = r.snap_id
{
      @UI.facet: [
        { id: 'HdrMem',  purpose: #HEADER, type: #DATAPOINT_REFERENCE, targetQualifier: 'SaveMem',  position: 10 },
        { id: 'HdrPct',  purpose: #HEADER, type: #DATAPOINT_REFERENCE, targetQualifier: 'SavePct',  position: 20 },
        { id: 'HdrDisk', purpose: #HEADER, type: #DATAPOINT_REFERENCE, targetQualifier: 'SaveDisk', position: 30 },
        { id: 'HdrMoney',purpose: #HEADER, type: #DATAPOINT_REFERENCE, targetQualifier: 'Money',    position: 40 },
        { id: 'System',  purpose: #STANDARD, type: #FIELDGROUP_REFERENCE, targetQualifier: 'System',
          label: 'System today', position: 10 },
        { id: 'Savings', purpose: #STANDARD, type: #FIELDGROUP_REFERENCE, targetQualifier: 'Savings',
          label: 'Reducible volume', position: 20 },
        { id: 'Money',   purpose: #STANDARD, type: #FIELDGROUP_REFERENCE, targetQualifier: 'Money',
          label: 'Money (example: RAM = 2 x data, 25 per GB per month)', position: 30 } ]
      @EndUserText.label: 'Snapshot'
      @UI.lineItem: [{ position: 10 }]
  key r.snap_id as SnapId,

      @EndUserText.label: 'Snapshot date'
      @UI.lineItem:   [{ position: 20 }]
      @UI.fieldGroup: [{ qualifier: 'System', position: 10 }]
      max( s.snap_date ) as SnapshotDate,

      @EndUserText.label: 'Total memory (GB)'
      @UI.lineItem:   [{ position: 30 }]
      @UI.fieldGroup: [{ qualifier: 'System', position: 20 }]
      max( division( cast( s.total_mem_bytes as abap.dec(20,0) ), 1073741824, 2 ) )  as TotalMemGB,

      @EndUserText.label: 'Total disk (GB)'
      @UI.fieldGroup: [{ qualifier: 'System', position: 30 }]
      max( division( cast( s.total_disk_bytes as abap.dec(20,0) ), 1073741824, 2 ) ) as TotalDiskGB,

      @EndUserText.label: 'Tables with a recommendation'
      @UI.fieldGroup: [{ qualifier: 'System', position: 40 }]
      count(*) as Recommendations,

      @EndUserText.label: 'Memory reducible (GB)'
      @UI.lineItem:   [{ position: 40 }]
      @UI.fieldGroup: [{ qualifier: 'Savings', position: 10 }]
      @UI.dataPoint:  { qualifier: 'SaveMem', title: 'Memory reducible (GB)' }
      sum( division( cast( r.save_mem_bytes as abap.dec(20,0) ), 1073741824, 4 ) ) as SaveMemGB,

      @EndUserText.label: 'Share of memory (%)'
      @UI.lineItem:   [{ position: 50 }]
      @UI.fieldGroup: [{ qualifier: 'Savings', position: 20 }]
      @UI.dataPoint:  { qualifier: 'SavePct', title: 'Share of memory (%)' }
      sum( division( cast( r.save_mem_bytes as abap.dec(20,0) ) * 100,
                     cast( s.total_mem_bytes as abap.dec(20,0) ), 4 ) ) as SavePct,

      @EndUserText.label: 'Disk reducible (GB)'
      @UI.lineItem:   [{ position: 60 }]
      @UI.fieldGroup: [{ qualifier: 'Savings', position: 30 }]
      @UI.dataPoint:  { qualifier: 'SaveDisk', title: 'Disk reducible (GB)' }
      sum( division( cast( r.save_disk_bytes as abap.dec(20,0) ), 1073741824, 4 ) ) as SaveDiskGB,

      @EndUserText.label: 'Memory stuck behind blockers (GB)'
      @UI.fieldGroup: [{ qualifier: 'Savings', position: 40 }]
      sum( division( cast( r.blocked_mem_bytes as abap.dec(20,0) ), 1073741824, 4 ) ) as BlockedMemGB,

      @EndUserText.label: 'Annual saving (example)'
      @UI.lineItem:   [{ position: 70 }]
      @UI.fieldGroup: [{ qualifier: 'Money', position: 10 }]
      @UI.dataPoint:  { qualifier: 'Money', title: 'Annual saving (example)' }
      sum( division( cast( r.save_mem_bytes as abap.dec(20,0) ), 1073741824, 4 ) * 600 ) as AnnualSavingExample
}
group by r.snap_id
