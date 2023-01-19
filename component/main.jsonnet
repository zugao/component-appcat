local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.appcat;

local xrdBrowseRole = kube.ClusterRole('appcat:browse') + {
  metadata+: {
    labels: {
      'rbac.authorization.k8s.io/aggregate-to-view': 'true',
      'rbac.authorization.k8s.io/aggregate-to-edit': 'true',
      'rbac.authorization.k8s.io/aggregate-to-admin': 'true',
    },
  },
  rules+: [
    {
      apiGroups: [ 'apiextensions.crossplane.io' ],
      resources: [
        'compositions',
        'compositionrevisions',
        'compositeresourcedefinitions',
      ],
      verbs: [ 'get', 'list', 'watch' ],
    },
  ],
};


local isOpenshift = std.startsWith(inv.parameters.facts.distribution, 'openshift');
local finalizerRole = kube.ClusterRole('crossplane:appcat:finalizer') {
  metadata+: {
    labels: {
      'rbac.crossplane.io/aggregate-to-crossplane': 'true',
    },
  },
  rules+: [
    {
      apiGroups: [
        'appcat.vshn.io',
        'vshn.appcat.vshn.io',
        'exoscale.appcat.vshn.io',
      ],
      resources: [
        '*/finalizers',
      ],
      verbs: [ '*' ],
    },
  ],

};

{
  '10_clusterrole_view': xrdBrowseRole,
  [if isOpenshift then '10_clusterrole_finalizer']: finalizerRole,
}
