local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local comp = import 'lib/appcat-compositions.libsonnet';
local crossplane = import 'lib/crossplane.libsonnet';

local common = import 'common.libsonnet';
local xrds = import 'xrds.libsonnet';

local inv = kap.inventory();
local params = inv.parameters.appcat;
local minioParams = params.services.vshn.minio;

local serviceNameLabelKey = 'appcat.vshn.io/servicename';
local serviceNamespaceLabelKey = 'appcat.vshn.io/claim-namespace';

local connectionSecretKeys = [
  'MINIO_URL',
  'MINIO_USERNAME',
  'MINIO_PASSWORD',
];

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
  common.VshnMetaVshn('Minio', 'distributed', 'true', minioPlans) +
  {
    spec: {
      compositeTypeRef: comp.CompositeRef(xrd),
      writeConnectionSecretsToNamespace: minioParams.secretNamespace,
      functions:
        [
          {
            name: 'minio-func',
            type: 'Container',
            config: kube.ConfigMap('xfn-config') + {
              metadata: {
                labels: {
                  name: 'xfn-config',
                },
                name: 'xfn-config',
              },
              data: {
                imageTag: common.GetAppCatImageTag(),
                minioChartRepository: params.charts.minio.source,
                minioChartVersion: params.charts.minio.version,
                plans: std.toString(minioPlans),
                defaultPlan: minioParams.defaultPlan,
              },
            },
            container: {
              image: 'minio',
              imagePullPolicy: 'IfNotPresent',
              timeout: '20s',
              runner: {
                endpoint: minioParams.grpcEndpoint,
              },
            },
          },
        ],
    },
  };

if params.services.vshn.enabled && minioParams.enabled then {
  '20_xrd_vshn_minio': xrd,
  '20_rbac_vshn_minio': xrds.CompositeClusterRoles(xrd),
  '21_composition_vshn_minio': composition,
} else {}
