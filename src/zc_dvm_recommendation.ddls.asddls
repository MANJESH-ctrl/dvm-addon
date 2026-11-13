@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'DVM recommendations'
@Metadata.ignorePropagatedAnnotations: true
@UI.headerInfo: { typeName: 'Recommendation',
                  typeNamePlural: 'Recommendations per table',
                  title:       { value: 'TableName' },
                  description: { value: 'Note' } }
@UI.presentationVariant: [{ sortOrder: [{ by: 'SaveMemMB', direction: #DESC }] }]
define view entity ZC_DVM_RECOMMENDATION
  as select from zdvm_rec as r
    inner join ZI_DVM_LATEST as l on l.SnapId = r.snap_id
{
      @UI.facet: [
        { id: 'HdrSave',  purpose: #HEADER, type: #DATAPOINT_REFERENCE, targetQualifier: 'SaveMem',  position: 10 },
        { id: 'HdrDisk',  purpose: #HEADER, type: #DATAPOINT_REFERENCE, targetQualifier: 'SaveDisk', position: 20 },
        { id: 'HdrBlock', purpose: #HEADER, type: #DATAPOINT_REFERENCE, targetQualifier: 'Blocked',  position: 30 },
        { id: 'HdrRisk',  purpose: #HEADER, type: #DATAPOINT_REFERENCE, targetQualifier: 'Risk',     position: 40 },
        { id: 'Action', purpose: #STANDARD, type: #FIELDGROUP_REFERENCE, targetQualifier: 'Action',
          label: 'Cleanup action', position: 10 },
        { id: 'Policy', purpose: #STANDARD, type: #FIELDGROUP_REFERENCE, targetQualifier: 'Policy',
          label: 'Retention policy', position: 20 },
        { id: 'Volume', purpose: #STANDARD, type: #FIELDGROUP_REFERENCE, targetQualifier: 'Volume',
          label: 'Volume and savings', position: 30 } ]
      @EndUserText.label: 'Table'
      @UI.lineItem:       [{ position: 10 }]
      @UI.selectionField: [{ position: 10 }]
  key r.table_name as TableName,
      @UI.hidden: true
  key r.snap_id    as SnapId,

      @EndUserText.label: 'Cleanup action'
      @UI.lineItem:       [{ position: 20 }]
      @UI.selectionField: [{ position: 20 }]
      @UI.fieldGroup:     [{ qualifier: 'Action', position: 10 }]
      r.group_key  as CleanupAction,

      @EndUserText.label: 'Method'
      @UI.lineItem:       [{ position: 30 }]
      @UI.selectionField: [{ position: 30 }]
      @UI.fieldGroup:     [{ qualifier: 'Action', position: 20 }]
      r.method     as Method,

      @EndUserText.label: 'SAP tool'
      @UI.fieldGroup:     [{ qualifier: 'Action', position: 30 }]
      r.tool       as Tool,

      @EndUserText.label: 'Sign-off by'
      @UI.lineItem:       [{ position: 110 }]
      @UI.fieldGroup:     [{ qualifier: 'Action', position: 40 }]
      r.signoff    as Signoff,

      @EndUserText.label: 'Retention (days)'
      @UI.lineItem:       [{ position: 40 }]
      @UI.fieldGroup:     [{ qualifier: 'Policy', position: 10 }]
      r.ret_days   as RetentionDays,

      @EndUserText.label: 'Cutoff date'
      @UI.fieldGroup:     [{ qualifier: 'Policy', position: 20 }]
      r.cutoff_date as CutoffDate,

      @EndUserText.label: 'Explanation'
      @UI.fieldGroup:     [{ qualifier: 'Policy', position: 30 }]
      r.note       as Note,

      @EndUserText.label: 'Rows checked'
      @UI.fieldGroup:     [{ qualifier: 'Volume', position: 10 }]
      r.total_rows as TotalRows,

      @EndUserText.label: 'Eligible rows'
      @UI.lineItem:       [{ position: 50 }]
      @UI.fieldGroup:     [{ qualifier: 'Volume', position: 20 }]
      r.eligible_rows as EligibleRows,

      @EndUserText.label: 'Blocked rows'
      @UI.lineItem:       [{ position: 60, criticality: 'BlockedCriticality' }]
      @UI.fieldGroup:     [{ qualifier: 'Volume', position: 30, criticality: 'BlockedCriticality' }]
      @UI.dataPoint:      { qualifier: 'Blocked', title: 'Blocked rows', criticality: 'BlockedCriticality' }
      r.blocked_rows as BlockedRows,

      @EndUserText.label: 'Memory saving (MB)'
      @UI.lineItem:       [{ position: 70 }]
      @UI.fieldGroup:     [{ qualifier: 'Volume', position: 40 }]
      @UI.dataPoint:      { qualifier: 'SaveMem', title: 'Memory saving (MB)' }
      division( cast( r.save_mem_bytes as abap.dec(20,0) ), 1048576, 1 ) as SaveMemMB,

      @EndUserText.label: 'Disk saving (MB)'
      @UI.lineItem:       [{ position: 80 }]
      @UI.fieldGroup:     [{ qualifier: 'Volume', position: 50 }]
      @UI.dataPoint:      { qualifier: 'SaveDisk', title: 'Disk saving (MB)' }
      division( cast( r.save_disk_bytes as abap.dec(20,0) ), 1048576, 1 ) as SaveDiskMB,

      @EndUserText.label: 'Memory blocked (MB)'
      @UI.lineItem:       [{ position: 90 }]
      @UI.fieldGroup:     [{ qualifier: 'Volume', position: 60 }]
      division( cast( r.blocked_mem_bytes as abap.dec(20,0) ), 1048576, 1 ) as BlockedMemMB,

      @EndUserText.label: 'Risk'
      @UI.lineItem:       [{ position: 100, criticality: 'RiskCriticality' }]
      @UI.selectionField: [{ position: 40 }]
      @UI.dataPoint:      { qualifier: 'Risk', title: 'Risk', criticality: 'RiskCriticality' }
      r.risk       as Risk,

      @UI.hidden: true
      case r.risk when 'HIGH'   then 1
                  when 'MEDIUM' then 2
                  else 3 end as RiskCriticality,

      @UI.hidden: true
      case when r.blocked_rows > 0 then 2 else 0 end as BlockedCriticality
}
