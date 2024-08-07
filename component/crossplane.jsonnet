local crossplane = import 'lib/appcat-crossplane.libsonnet';
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local prometheus = import 'lib/prometheus.libsonnet';
local inv = kap.inventory();

local params = inv.parameters.appcat.crossplane;
local on_openshift4 = std.member([ 'openshift4', 'oke' ], inv.parameters.facts.distribution);
local has_service_account(provider) = std.count(std.objectFields(params.serviceAccounts), provider) > 0;
local has_any_service = std.length(std.filter(function(x) std.objectHas(params.serviceAccounts, x), std.objectFields(params.providers))) > 0;
local missing_controller(provider_name) = !std.objectHas(params.controllerConfigs, provider_name);

local controller_config_ref(controller_config_name) = {
  controllerConfigRef: {
    name: controller_config_name,
  },
};

local merge_config_for_openshift =
  (if on_openshift4 then {
     spec+: {
       podSecurityContext: {},
       securityContext: {},
     },
   }
   else {});

local merge_service_account_from_resource(name) =
  if has_service_account(name) then {
    spec+: {
      serviceAccountName: name,
    },
  }
  else {};

local service_accounts = com.generateResources(params.serviceAccounts, kube.ServiceAccount);
local cluster_roles = com.generateResources(params.clusterRoles, kube.ClusterRole);
local cluster_role_bindings = com.generateResources(params.clusterRoleBindings, kube.ClusterRoleBinding);

local provider_configs = [
  // apiVersion is a required field for each ProviderConfig
  assert provider_config.apiVersion != '' : 'apiVersion is mandatory in ProviderConfig ' + provider_config.metadata.name;
  provider_config
  for provider_config in com.generateResources(params.providerConfigs, crossplane.ProviderConfig)
];

local controller_configs =
  /* ControllerConfig resources generated from params.controllerConfigs adjusted by facts.distribution and
   params.serviceAccounts
   In case params.serviceAccount.name is different from a matched controller's serviceAccountName then
   params.serviceAccount.name takes precedence
   */
  [
    com.makeMergeable(controller_config) +
    merge_config_for_openshift +
    merge_service_account_from_resource(controller_config.metadata.name)
    for controller_config in com.generateResources(params.controllerConfigs, crossplane.ControllerConfig)
  ] +
  // Non defined ControllerConfig resources generated based on facts.distribution and params.serviceAccounts when
  // params.providers are being used
  [
    crossplane.ControllerConfig(provider) +
    merge_config_for_openshift +
    merge_service_account_from_resource(provider)
    for provider in std.objectFields(params.providers)
    if missing_controller(provider) && (on_openshift4 || has_any_service)
  ];

local providers = [
  crossplane.Provider(provider) {
    spec+: params.providers[provider] +
           if on_openshift4 || has_service_account(provider) then controller_config_ref(provider) else {},
  }
  for provider in std.objectFields(params.providers)
];

local rbacFinalizerRole = kube.ClusterRole('crossplane-rbac-manager:finalizer') {
  rules+: [
    {
      apiGroups: [
        'pkg.crossplane.io',
        'apiextensions.crossplane.io',
      ],
      resources: [
        '*/finalizers',
      ],
      verbs: [ '*' ],
    },
  ],

};
local rbacFinalizerRoleBinding = kube.ClusterRoleBinding('crossplane-rbac-manager:finalizer') {
  roleRef_: rbacFinalizerRole,
  subjects: [
    {
      kind: 'ServiceAccount',
      name: 'rbac-manager',
      namespace: params.namespace,
    },
  ],
};

local namespace =
  if params.monitoring.enabled && std.member(inv.applications, 'prometheus') then
    if params.monitoring.instance != null then
      prometheus.RegisterNamespace(kube.Namespace(params.namespace), params.monitoring.instance)
    else
      prometheus.RegisterNamespace(kube.Namespace(params.namespace))
  else
    kube.Namespace(params.namespace)
;

local name = 'crossplane';
local labels = {
  'app.kubernetes.io/name': name,
  'app.kubernetes.io/managed-by': 'commodore',
};
local monitoring =
  [
    kube.Service(name + '-metrics') {
      metadata+: {
        namespace: params.namespace,
        labels+: labels,
      },
      spec+: {
        selector: {
          release: 'crossplane',
        },
        ports: [ {
          name: 'metrics',
          port: 8080,
        } ],
      },
    },
    kube._Object('monitoring.coreos.com/v1', 'ServiceMonitor', name) {
      metadata+: {
        namespace: params.namespace,
        labels+: labels,
      },
      spec: {
        endpoints: [ {
          port: 'metrics',
          path: '/metrics',
        } ],
        selector: {
          matchLabels: labels,
        },
      },
    },
    kube._Object('monitoring.coreos.com/v1', 'PrometheusRule', name) {
      metadata+: {
        namespace: params.namespace,
        labels+: labels {
          role: 'alert-rules',
        } + params.monitoring.prometheus_rule_labels,
      },
      spec: {
        groups: [
          {
            name: 'crossplane.rules',
            rules: [
              {
                alert: 'CrossplaneDown',
                expr: 'up{namespace="' + params.namespace + '", job=~"^crossplane-.+$"} != 1',
                'for': '10m',
                labels: {
                  severity: 'critical',
                  syn: 'true',
                },
                annotations: {
                  summary: 'Crossplane controller is down',
                  description: 'Crossplane pod {{ $labels.pod }} in namespace {{ $labels.namespace }} is down',
                },
              },
            ],
          },
        ],
      },
    },
  ];

{
  '00_namespace': namespace {
    metadata+: {
      labels+: params.namespaceLabels,
      annotations+: params.namespaceAnnotations,
    },
  },
  '01_rbac_finalizer_clusterrole': rbacFinalizerRole,
  '01_rbac_finalizer_clusterrolebinding': rbacFinalizerRoleBinding,
  [if std.length(providers) > 0 then '10_providers']: providers,
  [if params.monitoring.enabled then '20_monitoring']: monitoring,
  [if std.length(controller_configs) > 0 then '30_controller_configs']: controller_configs,
  [if std.length(service_accounts) > 0 then '40_service_accounts']: service_accounts,
  [if std.length(cluster_roles) > 0 then '50_cluster_roles']: cluster_roles,
  [if std.length(cluster_role_bindings) > 0 then '60_cluster_role_bindings']: cluster_role_bindings,
  [if std.length(provider_configs) > 0 then '70_provider_configs']: provider_configs,
}
