local common = import 'common.libsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.appcat;
local cms = params.clusterManagementSystem;

local isSingleCluster = cms.controlPlaneCluster && cms.serviceCluster;
local isControlPlane = cms.controlPlaneCluster && !cms.serviceCluster;
local isServiceCluster = !cms.controlPlaneCluster && cms.serviceCluster;

{
  isServiceCluster: isServiceCluster,
  isControlPlane: isControlPlane,
  isSingleCluster: isSingleCluster,
  isCMSValid: cms.controlPlaneCluster || cms.serviceCluster,
  isSingleOrControlPlaneCluster: isSingleCluster || isControlPlane,
  isSingleOrServiceCluster: isSingleCluster || isServiceCluster,
}
