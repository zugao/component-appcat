local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local comp = import 'lib/appcat-compositions.libsonnet';
local crossplane = import 'lib/crossplane.libsonnet';

local rbac = import 'rbac.libsonnet';

local inv = kap.inventory();
local facts = inv.parameters.facts;
local params = inv.parameters.appcat;

local exoscaleZones = [ 'de-fra-1', 'de-muc-1', 'at-vie-1', 'ch-gva-2', 'ch-dk-2', 'bg-sof-1' ];
local cloudscaleZones = [ 'lpg', 'rma' ];

local strExoscaleZones = std.join(', ', exoscaleZones);
local strCloudscaleZones = std.join(', ', cloudscaleZones);

local syncOptions = {
  metadata+: {
    annotations+: {
      'argocd.argoproj.io/sync-options': 'SkipDryRunOnMissingResource=true',
      'argocd.argoproj.io/sync-wave': '10',
    },
  },
};

local vshnMetaDBaaSExoscale(dbname) = {
  metadata+: {
    annotations+: {
      'metadata.appcat.vshn.io/displayname': 'Exoscale ' + dbname,
      'metadata.appcat.vshn.io/description': dbname + ' DBaaS instances by Exoscale',
      'metadata.appcat.vshn.io/end-user-docs-url': 'https://vs.hn/exo-' + std.asciiLower(dbname),
      'metadata.appcat.vshn.io/zone': strExoscaleZones,
      'metadata.appcat.vshn.io/product-description': 'https://products.docs.vshn.ch/products/appcat/exoscale_dbaas.html',
    },
    labels+: {
      'metadata.appcat.vshn.io/offered': 'true',
      'metadata.appcat.vshn.io/serviceID': 'exoscale-' + std.asciiLower(dbname),
    },
  },
};

local vshnMetaVshn(servicename, flavor, offered, plans) = {
  metadata+: {
    annotations+: {
      'metadata.appcat.vshn.io/displayname': servicename + ' by VSHN',
      'metadata.appcat.vshn.io/description': servicename + ' instances by VSHN',
      'metadata.appcat.vshn.io/end-user-docs-url': 'https://vs.hn/vshn-' + std.asciiLower(servicename),
      'metadata.appcat.vshn.io/flavor': flavor,
      'metadata.appcat.vshn.io/plans': std.manifestJsonMinified(plans),
      'metadata.appcat.vshn.io/product-description': 'https://products.docs.vshn.ch/products/appcat/' + std.asciiLower(servicename) + '.html',
    },
    labels+: {
      'metadata.appcat.vshn.io/offered': offered,
      'metadata.appcat.vshn.io/serviceID': 'vshn-' + std.asciiLower(servicename),
    },
  },
};

local vshnMetaVshnDBaas(dbname, flavor, offered, plans) = vshnMetaVshn(dbname, flavor, offered, plans) + {
  metadata+: {
    annotations+: {
      'metadata.appcat.vshn.io/zone': facts.region,
    },
  },
};

local providerZones(provider) =
  if provider == 'Exoscale' then strExoscaleZones
  else if provider == 'cloudscale.ch' then strCloudscaleZones
  else 'default';

local vshnMetaObjectStorage(provider) = {
  metadata+: {
    annotations+: {
      'metadata.appcat.vshn.io/displayname': provider + ' Object Storage',
      'metadata.appcat.vshn.io/description': 'S3 compatible object storage hosted by ' + provider,
      'metadata.appcat.vshn.io/end-user-docs-url': 'https://vs.hn/objstor',
      'metadata.appcat.vshn.io/zone': providerZones(provider),
      'metadata.appcat.vshn.io/product-description': 'https://products.docs.vshn.ch/products/appcat/objectstorage.html',
    },
    labels+: {
      'metadata.appcat.vshn.io/offered': 'true',
      'metadata.appcat.vshn.io/serviceID': std.asciiLower(std.rstripChars(provider, '.ch')) + '-objectbucket',
    },
  },
};

local mergeArgs(args, additional) =
  local foldFn =
    function(acc, arg)
      local ap = std.splitLimit(arg, '=', 1);
      acc { [ap[0]]: ap[1] };
  local base = std.foldl(foldFn, args, {});
  local final = std.foldl(foldFn, additional, base);
  [ '%s=%s' % [ k, final[k] ] for k in std.objectFields(final) ];


local filterDisabledParams(params) = std.foldl(
  function(ps, key)
    local p = params[key];
    local enabled = p != null && p != {} && std.get(p, 'enabled', true);
    ps {
      [if enabled then key]: p,
    },
  std.objectFields(params),
  {}
);

local openShiftTemplate(name, displayName, description, iconClass, tags, message, provider, docs)
      = kube._Object('template.openshift.io/v1', 'Template', name) + {
  metadata+: {
    annotations: {
      'openshift.io/display-name': displayName,
      description: description,
      iconClass: iconClass,
      tags: tags,
      'openshift.io/provider-display-name': provider,
      'openshift.io/documentation-url': docs,
      'openshift.io/support-url': 'https://www.vshn.ch/en/contact/',
    },
    namespace: 'openshift',
  },
  message: message,
};

local getAppCatImageTag() = std.strReplace(params.images.appcat.tag, '/', '_');

local getApiserverImageTag() = std.strReplace(params.images.apiserver.tag, '/', '_');

local getAppCatImageString() = params.images.appcat.registry + '/' + params.images.appcat.repository + ':' + getAppCatImageTag();

local getApiserverImageString() = params.images.apiserver.registry + '/' + params.images.apiserver.repository + ':' + getApiserverImageTag();

local promRuleSLA(value, service) = kube._Object('monitoring.coreos.com/v1', 'PrometheusRule', 'vshn-' + std.asciiLower(service) + '-sla') {
  metadata+: {
    labels: {
      name: 'vshn-' + std.asciiLower(service) + '-sla',
    },
    namespace: params.slos.namespace,
  },
  spec: {
    groups: [
      {
        name: 'appcat-' + std.asciiLower(service) + '-sla-target',
        rules: [
          {
            expr: 'vector(' + value + ')',
            labels: {
              service: service,
            },
            record: 'sla:objective:ratio',
          },
        ],
      },
    ],
  },
};

local removeField(obj, name) = {
  // We don't want the name field in the actual providerConfig
  [k]: obj[k]
  for k in std.objectFieldsAll(obj)
  if k != name
};

local argoCDAnnotations() = {
  // Our current ArgoCD configuration can't handle the claim -> composite
  // relationship
  'argocd.argoproj.io/compare-options': 'IgnoreExtraneous',
  'argocd.argoproj.io/sync-options': 'Prune=false',
};

local bottomPod(query) = 'label_replace( bottomk(1, %(query)s) * on(namespace) group_left(label_appcat_vshn_io_claim_namespace) kube_namespace_labels, "name", "$1", "namespace", "vshn-replacemeplease-(.+)-.+")' % query;
local topPod(query) = 'label_replace( topk(1, %(query)s) * on(namespace) group_left(label_appcat_vshn_io_claim_namespace) kube_namespace_labels, "name", "$1", "namespace", "vshn-replacemeplease-(.+)-.+")' % query;

local generatePrometheusNonSLORules(serviceName, memoryContainerName, additionalAlertsRuleGroup) = {
  // standardized lowercase regardless of what came as input
  local serviceNameLower = std.asciiLower(serviceName),
  local toReplace = 'vshn-replacemeplease',
  local queries = {
    availableStorage: 'kubelet_volume_stats_available_bytes{job="kubelet", metrics_path="/metrics"}',
    availablePercent: '(%s / kubelet_volume_stats_capacity_bytes{job="kubelet", metrics_path="/metrics"})' % queries.availableStorage,
    usedStorage: 'kubelet_volume_stats_used_bytes{job="kubelet", metrics_path="/metrics"}',
    unlessExcluded: 'unless on(namespace, persistentvolumeclaim) kube_persistentvolumeclaim_access_mode{ access_mode="ReadOnlyMany"} == 1 unless on(namespace, persistentvolumeclaim) kube_persistentvolumeclaim_labels{label_excluded_from_alerts="true"} == 1',
  },
  name: 'prometheusrule',
  base: {

    apiVersion: 'kubernetes.crossplane.io/v1alpha1',
    kind: 'Object',
    metadata: {
      name: 'prometheusrule',
    },
    spec: {
      providerConfigRef: {
        name: 'kubernetes',
      },
      forProvider+: {
        manifest+: {
          metadata: {
            apiVersion: 'monitoring.coreos.com/v1',
            kind: 'PrometheusRule',
            name: '%s-rules' % serviceNameLower,
          },
          spec: {
            groups: [
              {
                name: '%s-general-alerts' % serviceNameLower,
                rules: [
                  {
                    name: '%s-storage' % serviceNameLower,
                    alert: serviceName + 'PersistentVolumeFillingUp',
                    annotations: {
                      description: 'The volume claimed by the instance {{ $labels.name }} in namespace {{ $labels.label_appcat_vshn_io_claim_namespace }} is only {{ $value | humanizePercentage }} free.',
                      runbook_url: 'https://runbooks.prometheus-operator.dev/runbooks/kubernetes/kubepersistentvolumefillingup',
                      summary: 'PersistentVolume is filling up.',
                    },
                    expr: std.strReplace(bottomPod('%(availablePercent)s < 0.03 and %(usedStorage)s > 0 %(unlessExcluded)s' % queries), toReplace, 'vshn-' + serviceNameLower),
                    'for': '1m',
                    labels: {
                      severity: 'critical',
                      syn_team: 'schedar',
                    },
                  },
                  {
                    alert: serviceName + 'PersistentVolumeFillingUp',
                    annotations: {
                      description: 'Based on recent sampling, the volume claimed by the instance {{ $labels.name }} in namespace {{ $labels.label_appcat_vshn_io_claim_namespace }} is expected to fill up within four days. Currently {{ $value | humanizePercentage }} is available.',
                      runbook_url: 'https://runbooks.prometheus-operator.dev/runbooks/kubernetes/kubepersistentvolumefillingup',
                      summary: 'PersistentVolume is filling up.',
                    },
                    expr: std.strReplace(bottomPod('%(availablePercent)s < 0.15 and %(usedStorage)s > 0 and predict_linear(%(availableStorage)s[6h], 4 * 24 * 3600) < 0  %(unlessExcluded)s' % queries), toReplace, 'vshn-' + serviceNameLower),
                    'for': '1h',
                    labels: {
                      severity: 'warning',
                    },
                  },
                  {
                    alert: serviceName + 'MemoryCritical',
                    name: std.asciiLower(serviceName) + '-memory',
                    annotations: {
                      description: 'The memory claimed by the instance {{ $labels.name }} in namespace {{ $labels.label_appcat_vshn_io_claim_namespace }} has been over 90% for 2 hours.\n  Please reducde the load of this instance, or increase the memory.',
                      // runbook_url: 'TBD',
                      summary: 'Memory usage critical',
                    },
                    expr: std.strReplace(topPod('(container_memory_working_set_bytes{container="%s"}  / on(container,pod,namespace)  kube_pod_container_resource_limits{resource="memory"} * 100) > 90') % memoryContainerName, toReplace, 'vshn-' + serviceNameLower),
                    'for': '120m',
                    labels: {
                      severity: 'warning',
                      syn_team: 'schedar',
                    },
                  },
                ],
              },
            ] + additionalAlertsRuleGroup,
          },
        },
      },
    },
  },
};


{
  SyncOptions: syncOptions,
  VshnMetaDBaaSExoscale(dbname):
    vshnMetaDBaaSExoscale(dbname),
  VshnMetaObjectStorage(provider):
    vshnMetaObjectStorage(provider),
  MergeArgs(args, additional):
    mergeArgs(args, additional),
  VshnMetaVshn(servicename, flavor, offered='true', plans):
    vshnMetaVshn(servicename, flavor, offered, plans),
  vshnMetaVshnDBaas(dbname, flavor, offered='true', plans):
    vshnMetaVshnDBaas(dbname, flavor, offered, plans),
  FilterDisabledParams(params):
    filterDisabledParams(params),
  OpenShiftTemplate(name, displayName, description, iconClass, tags, message, provider, docs):
    openShiftTemplate(name, displayName, description, iconClass, tags, message, provider, docs),
  GetAppCatImageString():
    getAppCatImageString(),
  GetAppCatImageTag():
    getAppCatImageTag(),
  GetApiserverImageTag():
    getApiserverImageTag(),
  GetApiserverImageString():
    getApiserverImageString(),
  PromRuleSLA(value, service):
    promRuleSLA(value, service),
  RemoveField(obj, name):
    removeField(obj, name),
  ArgoCDAnnotations():
    argoCDAnnotations(),
  GeneratePrometheusNonSLORules(serviceName, memoryContainerName, additionalAlertsRuleGroup):
    generatePrometheusNonSLORules(serviceName, memoryContainerName, additionalAlertsRuleGroup),
  topPod(query):
    topPod(query),
  bottomPod(query):
    bottomPod(query),
}
