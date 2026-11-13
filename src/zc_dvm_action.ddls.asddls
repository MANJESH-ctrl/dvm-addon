@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'DVM cleanup actions'
@Metadata.ignorePropagatedAnnotations: true
@UI.headerInfo: { typeName: 'Cleanup action',
                  typeNamePlural: 'Cleanup actions',
                  title:       { value: 'CleanupAction' },
                  description: { value: 'Tool' } }
@UI.presentationVariant: [{ sortOrder: [{ by: 'SaveMemMB', direction: #DESC }] }]
define view entity ZC_DVM_ACTION
  as select from zdvm_rec as r
    inner join ZI_DVM_LATEST as l on l.SnapId = r.snap_id
{
      @UI.facet: [
        { id: 'HdrSave',  purpose: #HEADER, type: #DATAPOINT_REFERENCE, targetQualifier: 'SaveMem',  position: 10 },
        { id: 'HdrDisk',  purpose: #HEADER, type: #DATAPOINT_REFERENCE, targetQualifier: 'SaveDisk', position: 20 },
        { id: 'HdrBlock', purpose: #HEADER, type: #DATAPOINT_REFERENCE, targetQualifier: 'BlockMem', position: 30 },
        { id: 'HdrRisk',  purpose: #HEADER, type: #DATAPOINT_REFERENCE, targetQualifier: 'Risk',     position: 40 },
        { id: 'Details', purpose: #STANDARD, type: #FIELDGROUP_REFERENCE, targetQualifier: 'Details',
          label: 'How to execute', position: 10 } ]
      @EndUserText.label: 'Cleanup action'
      @UI.lineItem:       [{ position: 10 }]
      @UI.selectionField: [{ position: 10 }]
  key r.group_key as CleanupAction,
      @UI.hidden: true
  key r.snap_id   as SnapId,

      @EndUserText.label: 'Method'
      @UI.lineItem:       [{ position: 20 }]
      @UI.selectionField: [{ position: 20 }]
      @UI.fieldGroup:     [{ qualifier: 'Details', position: 10 }]
      max( r.method )   as Method,

      @EndUserText.label: 'SAP tool / archiving object'
      @UI.lineItem:       [{ position: 30 }]
      @UI.fieldGroup:     [{ qualifier: 'Details', position: 20 }]
      max( r.tool )     as Tool,

      @EndUserText.label: 'Retention (days)'
      @UI.fieldGroup:     [{ qualifier: 'Details', position: 30 }]
      max( r.ret_days ) as RetentionDays,

      @EndUserText.label: 'Tables affected'
      @UI.lineItem:       [{ position: 40 }]
      @UI.fieldGroup:     [{ qualifier: 'Details', position: 40 }]
      count(*)          as TablesAffected,

      @EndUserText.label: 'Memory saving (MB)'
      @UI.lineItem:       [{ position: 50 }]
      @UI.dataPoint:      { qualifier: 'SaveMem', title: 'Memory saving (MB)' }
      sum( division( cast( r.save_mem_bytes as abap.dec(20,0) ), 1048576, 1 ) )    as SaveMemMB,

      @EndUserText.label: 'Disk saving (MB)'
      @UI.lineItem:       [{ position: 60 }]
      @UI.dataPoint:      { qualifier: 'SaveDisk', title: 'Disk saving (MB)' }
      sum( division( cast( r.save_disk_bytes as abap.dec(20,0) ), 1048576, 1 ) )   as SaveDiskMB,

      @EndUserText.label: 'Memory blocked (MB)'
      @UI.lineItem:       [{ position: 70 }]
      @UI.dataPoint:      { qualifier: 'BlockMem', title: 'Memory blocked (MB)' }
      sum( division( cast( r.blocked_mem_bytes as abap.dec(20,0) ), 1048576, 1 ) ) as BlockedMemMB,

      @EndUserText.label: 'Risk'
      @UI.lineItem:       [{ position: 80, criticality: 'RiskCriticality' }]
      @UI.selectionField: [{ position: 30 }]
      @UI.dataPoint:      { qualifier: 'Risk', title: 'Risk', criticality: 'RiskCriticality' }
      max( r.risk )     as Risk,

      @EndUserText.label: 'Sign-off by'
      @UI.lineItem:       [{ position: 90 }]
      @UI.fieldGroup:     [{ qualifier: 'Details', position: 50 }]
      max( r.signoff )  as Signoff,

      @UI.hidden: true
      max( case r.risk when 'HIGH'   then 1
                       when 'MEDIUM' then 2
                       else 3 end ) as RiskCriticality
}
group by r.group_key, r.snap_id
