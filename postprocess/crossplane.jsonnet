/**
 * Remove generated crossplane manifests if not required
 */
local com = import 'lib/commodore.libjsonnet';

local inv = com.inventory();
local params = inv.parameters.appcat;
local cms = params.clusterManagementSystem;
local file_extension = '.yaml';

local isSingleCluster = cms.controlPlaneCluster && cms.serviceCluster;
local isControlPlane = cms.controlPlaneCluster && !cms.serviceCluster;
local isSingleOrControlPlaneCluster = isSingleCluster || isControlPlane;

local dir_path = std.extVar('output_path');
local files_in_dir = std.native('list_dir')(dir_path, true);

/* Remove file_extension from file list */
local files = [ std.strReplace(file, file_extension, '') for file in files_in_dir ];
{
  [file]:
    if isSingleOrControlPlaneCluster
    then com.yaml_load_all(std.extVar('output_path') + '/' + file + file_extension)
    else []
  for file in files
}
