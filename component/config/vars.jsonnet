local common = import 'common.libsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.appcat;
local cms = params.clusterManagementSystem;
local vshnServices = params.services.vshn;

local isSingleCluster = cms.controlPlaneCluster && cms.serviceCluster;
local isControlPlane = cms.controlPlaneCluster && !cms.serviceCluster;
local isServiceCluster = !cms.controlPlaneCluster && cms.serviceCluster;
local getEnabledVSHNServiceNames() = [
  key
  for key in std.objectFields(vshnServices)
  if std.type(vshnServices[key]) == 'object' && std.objectHas(vshnServices[key], 'enabled') && vshnServices[key].enabled == true
];

{
  isServiceCluster: isServiceCluster,
  isControlPlane: isControlPlane,
  isSingleCluster: isSingleCluster,
  isCMSValid: cms.controlPlaneCluster || cms.serviceCluster,
  isSingleOrControlPlaneCluster: isSingleCluster || isControlPlane,
  isSingleOrServiceCluster: isSingleCluster || isServiceCluster,
  isExoscale: inv.parameters.facts.cloud == 'exoscale',
  GetEnabledVSHNServiceNames(): getEnabledVSHNServiceNames(),
  assert (cms.controlPlaneKubeconfig == '' && isSingleCluster) || !isSingleCluster : 'clusterManagementSystem.controlPlaneKubeconfig should be empty for converged clusters',
  assert (cms.controlPlaneKubeconfig != '' && isServiceCluster) || (isSingleCluster || isControlPlane) : 'clusterManagementSystem.controlPlaneKubeconfig should not be empty for service clusters',
}
