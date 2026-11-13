@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'DVM latest analysed snapshot'
define view entity ZI_DVM_LATEST
  as select from zdvm_rec
{
  max( snap_id ) as SnapId
}
