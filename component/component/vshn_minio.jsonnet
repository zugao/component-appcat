local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local comp = import 'lib/appcat-compositions.libsonnet';
local crossplane = import 'lib/crossplane.libsonnet';

local common = import 'common.libsonnet';
local prom = import 'prometheus.libsonnet';
local slos = import 'slos.libsonnet';
local xrds = import 'xrds.libsonnet';

local inv = kap.inventory();
local params = inv.parameters.appcat;
local minioParams = params.services.vshn.minio;

local isOpenshift = std.startsWith(inv.parameters.facts.distribution, 'openshift');

local serviceNameLabelKey = 'appcat.vshn.io/servicename';
local serviceNamespaceLabelKey = 'appcat.vshn.io/claim-namespace';

local connectionSecretKeys = [
  'MINIO_URL',
  'AWS_SECRET_ACCESS_KEY',
  'AWS_ACCESS_KEY_ID',
];

local promRuleMinioSLA = prom.PromRuleSLA(params.services.vshn.minio.sla, 'VSHNMinio');

local minioPlans = common.FilterDisabledParams(minioParams.plans);

local xrd = xrds.XRDFromCRD(
  'xvshnminios.vshn.appcat.vshn.io',
  xrds.LoadCRD('vshn.appcat.vshn.io_vshnminios.yaml', params.images.appcat.tag),
  defaultComposition='vshnminio.vshn.appcat.vshn.io',
  connectionSecretKeys=connectionSecretKeys,
) + xrds.WithPlanDefaults(minioPlans, minioParams.defaultPlan);

local composition =
  kube._Object('apiextensions.crossplane.io/v1', 'Composition', 'vshnminio.vshn.appcat.vshn.io') +
  common.SyncOptions +
  common.VshnMetaVshn('Minio', 'distributed', 'false', minioPlans) +
  {
    spec: {
      compositeTypeRef: comp.CompositeRef(xrd),
      writeConnectionSecretsToNamespace: minioParams.secretNamespace,
      mode: 'Pipeline',
      pipeline:
        [
          {
            step: 'minio-func',
            functionRef: {
              name: 'function-appcat',
            },
            input: kube.ConfigMap('xfn-config') + {
              metadata: {
                labels: {
                  name: 'xfn-config',
                },
                name: 'xfn-config',
              },
              data: {
                serviceName: 'minio',
                imageTag: common.GetAppCatImageTag(),
                minioChartRepository: params.charts.minio.source,
                minioChartVersion: params.charts.minio.version,
                plans: std.toString(minioPlans),
                defaultPlan: minioParams.defaultPlan,
                providerEnabled: std.toString(params.providers.minio.enabled),
                controlNamespace: params.services.controlNamespace,
                maintenanceSA: 'helm-based-service-maintenance',
                ownerKind: xrd.spec.names.kind,
                ownerGroup: xrd.spec.group,
                ownerVersion: xrd.spec.versions[0].name,
                isOpenshift: std.toString(isOpenshift),
                sliNamespace: params.slos.namespace,
              } + if minioParams.proxyFunction then {
                proxyEndpoint: minioParams.grpcEndpoint,
              } else {},
            },
          },
        ],
    },
  };


local instances = [
  kube._Object('vshn.appcat.vshn.io/v1', 'VSHNMinio', instance.name) +
  {
    metadata+: {
      namespace: instance.namespace,
      annotations+: common.ArgoCDAnnotations(),
    },
    spec+: instance.spec,
  } + common.SyncOptions + {
    metadata+: {
      annotations+: {
        'argocd.argoproj.io/sync-options': 'Prune=false,SkipDryRunOnMissingResource=true',
      },
    },
  }
  for instance in minioParams.instances
];

if params.services.vshn.enabled && minioParams.enabled then {
  '20_xrd_vshn_minio': xrd,
  '20_rbac_vshn_minio': xrds.CompositeClusterRoles(xrd),
  '21_composition_vshn_minio': composition,
  '22_prom_rule_sla_minio': promRuleMinioSLA,
  [if std.length(instances) != 0 then '22_minio_instances']: instances,
  [if params.services.vshn.enabled && params.services.vshn.minio.enabled then 'sli_exporter/90_slo_vshn_minio']: slos.Get('vshn-minio'),
  [if params.services.vshn.enabled && params.services.vshn.minio.enabled then 'sli_exporter/90_slo_vshn_minio_ha']: slos.Get('vshn-minio-ha'),
} else {}
