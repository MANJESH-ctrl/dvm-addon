@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'DVM latest verification'
define view entity ZI_DVM_LATEST_VER
  as select from zdvm_verg
{
  max( pred_snap ) as PredSnap
}
