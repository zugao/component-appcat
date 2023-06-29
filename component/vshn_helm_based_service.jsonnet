local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local comp = import 'lib/appcat-compositions.libsonnet';
local crossplane = import 'lib/crossplane.libsonnet';

local common = import 'common.libsonnet';
local xrds = import 'xrds.libsonnet';

local inv = kap.inventory();
local params = inv.parameters.appcat;

local controlNamespace = kube.Namespace(params.services.controlNamespace);

local maintenanceServiceAccount = kube.ServiceAccount('helm-based-service-maintenance') + {
  metadata+: {
    namespace: params.services.controlNamespace,
  },
};

local maintenanceRoleName = 'crossplane:appcat:job:helm:maintenance';
local maintenanceRole = kube.ClusterRole(maintenanceRoleName) {
  rules: [
    {
      apiGroups: [ 'helm.crossplane.io' ],
      resources: [ 'releases' ],
      verbs: [ 'patch', 'get', 'list', 'watch' ],
    },
  ],
};

local maintenanceClusterRoleBinding = kube.ClusterRoleBinding('crossplane:appcat:job:helm:maintenance') + {
  roleRef_: maintenanceRole,
  subjects_: [ maintenanceServiceAccount ],
};

{
  '10_rbac_helm_service_maintenance_sa': maintenanceServiceAccount,
  '10_rbac_helm_service_maintenance_cluster_role': maintenanceRole,
  '10_rbac_helm_service_maintenance_cluster_role_binding': maintenanceClusterRoleBinding,
}
