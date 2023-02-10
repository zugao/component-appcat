local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local comp = import 'lib/appcat-compositions.libsonnet';
local crossplane = import 'lib/crossplane.libsonnet';

local common = import 'common.libsonnet';
local xrds = import 'xrds.libsonnet';

local inv = kap.inventory();
local params = inv.parameters.appcat;
local redisParams = params.services.vshn.redis;

local defaultUser = 'default';
local defaultPort = '6379';

local serviceNameLabelKey = 'appcat.vshn.io/servicename';
local serviceNamespaceLabelKey = 'appcat.vshn.io/claim-namespace';

local connectionSecretKeys = [
  'REDIS_HOST',
  'REDIS_PORT',
  'REDIS_USERNAME',
  'REDIS_PASSWORD',
  'REDIS_URL',
];

local isOpenshift = std.startsWith(inv.parameters.facts.distribution, 'openshift');
local securityContext = if isOpenshift then false else true;

local xrd = xrds.XRDFromCRD(
  'xvshnredis.vshn.appcat.vshn.io',
  xrds.LoadCRD('vshn.appcat.vshn.io_vshnredis.yaml'),
  defaultComposition='vshnredis.vshn.appcat.vshn.io',
  connectionSecretKeys=connectionSecretKeys,
);
local composition =
  local namespace = comp.KubeObject('v1', 'Namespace') +
                    {
                      spec+: {
                        forProvider+: {
                          manifest+: {
                            metadata: {
                              name: '',
                              labels: {
                                [serviceNameLabelKey]: 'redis-standalone',
                                [serviceNamespaceLabelKey]: '',
                              },
                            },
                          },
                        },
                      },
                    };

  local secret = comp.KubeObject('v1', 'Secret') +
                 {
                   spec+: {
                     forProvider+: {
                       manifest+: {
                         metadata: {},
                         stringData: {
                           REDIS_USERNAME: defaultUser,
                           REDIS_PORT: defaultPort,
                           REDIS_HOST: '',
                         },
                       },
                     },
                     references: [
                       {
                         patchesFrom: {
                           apiVersion: 'v1',
                           kind: 'Secret',
                           namespace: '',
                           name: 'redis',
                           fieldPath: 'data.redis-password',
                         },
                         toFieldPath: 'data.REDIS_PASSWORD',
                       },
                     ],
                     // Make crossplane aware of the connection secret we are creating in this object
                     writeConnectionSecretToRef: {
                       name: 'redis',
                       namespace: '',
                     },
                   },
                 };

  local redisHelmChart =
    {
      apiVersion: 'helm.crossplane.io/v1beta1',
      kind: 'Release',
      spec+: {
        forProvider+: {
          chart: {
            name: 'redis',
            repository: params.charts.redis.source,
            version: redisParams.helmChartVersion,
          },
          values: {
            fullnameOverride: 'redis',
            global: {
              imageRegistry: redisParams.imageRegistry,
            },
            image: {
              repository: 'bitnami/redis',
              tag: '',
            },
            commonConfiguration: '',
            networkPolicy: {
              enabled: redisParams.enableNetworkPolicy,
              allowExternal: false,
              ingressNSMatchLabels: {
                'kubernetes.io/metadata.name': '',
              },
            },
            master: {
              persistence: {
                size: '',
              },
              podSecurityContext: {
                enabled: securityContext,
              },
              containerSecurityContext: {
                enabled: securityContext,
              },
              resources: {
                requests: {
                  cpu: '',
                  memory: '',
                },
                limits: {
                  cpu: '',
                  memory: '',
                },
              },
            },
            architecture: 'standalone',
          },
        },
        providerConfigRef: {
          name: 'helm',
        },
      },
    };

  kube._Object('apiextensions.crossplane.io/v1', 'Composition', 'vshnredis.vshn.appcat.vshn.io') +
  common.SyncOptions +
  common.VshnMetaVshn('Redis', 'standalone') +
  {
    spec: {
      compositeTypeRef: comp.CompositeRef(xrd),
      writeConnectionSecretsToNamespace: redisParams.secretNamespace,
      resources: [
        {
          base: namespace {
            spec+: {
              managementPolicy: 'Observe',
            },
          },
          patches: [
            comp.FromCompositeFieldPathWithTransformPrefix('metadata.labels[crossplane.io/composite]', 'metadata.name', 'ns-observer'),
            comp.FromCompositeFieldPath('metadata.labels[crossplane.io/claim-namespace]', 'spec.forProvider.manifest.metadata.name'),
            comp.ToCompositeFieldPath('status.atProvider.manifest.metadata.labels[appuio.io/organization]', 'metadata.labels[appuio.io/organization]'),
          ],
        },
        {
          base: namespace,
          patches: [
            comp.FromCompositeFieldPathWithTransformPrefix('metadata.labels[crossplane.io/composite]', 'metadata.name', 'vshn-redis'),
            comp.FromCompositeFieldPath('metadata.labels[crossplane.io/claim-namespace]', 'spec.forProvider.manifest.metadata.labels[%s]' % serviceNamespaceLabelKey),
            comp.FromCompositeFieldPath('metadata.labels[appuio.io/organization]', 'spec.forProvider.manifest.metadata.labels[appuio.io/organization]'),
          ],
        },
        {
          base: secret,
          connectionDetails: comp.conn.AllFromSecretKeys(connectionSecretKeys),
          patches: [
            comp.FromCompositeFieldPathWithTransformSuffix('metadata.labels[crossplane.io/composite]', 'metadata.name', 'connection'),
            comp.FromCompositeFieldPathWithTransformPrefix('metadata.labels[crossplane.io/composite]', 'spec.forProvider.manifest.metadata.namespace', 'vshn-redis'),
            comp.FromCompositeFieldPathWithTransformSuffix('metadata.labels[crossplane.io/composite]', 'spec.forProvider.manifest.metadata.name', 'connection'),

            comp.CombineCompositeFromOneFieldPath('metadata.labels[crossplane.io/composite]', 'spec.forProvider.manifest.stringData.REDIS_HOST', 'redis-headless.vshn-redis-%s.svc.cluster.local'),
            comp.FromCompositeFieldPathWithTransformPrefix('metadata.labels[crossplane.io/composite]', 'spec.references[0].patchesFrom.namespace', 'vshn-redis'),
            comp.FromCompositeFieldPathWithTransformPrefix('metadata.labels[crossplane.io/composite]', 'spec.writeConnectionSecretToRef.namespace', 'vshn-redis'),
            comp.FromCompositeFieldPathWithTransformSuffix('metadata.labels[crossplane.io/composite]', 'spec.writeConnectionSecretToRef.name', 'connection'),
          ],
        },
        {
          base: redisHelmChart,
          patches: [
            comp.FromCompositeFieldPath('metadata.labels[crossplane.io/composite]', 'metadata.name'),
            comp.FromCompositeFieldPathWithTransformPrefix('metadata.labels[crossplane.io/composite]', 'spec.forProvider.namespace', 'vshn-redis'),
            comp.FromCompositeFieldPathWithTransformPrefix('metadata.labels[crossplane.io/composite]', 'spec.forProvider.manifest.metadata.namespace', 'vshn-redis'),
            comp.FromCompositeFieldPath('metadata.labels[crossplane.io/composite]', 'spec.forProvider.manifest.metadata.name'),
            comp.FromCompositeFieldPath('metadata.labels[crossplane.io/claim-namespace]', 'spec.forProvider.values.networkPolicy.ingressNSMatchLabels[kubernetes.io/metadata.name]'),

            comp.FromCompositeFieldPath('spec.parameters.size.memoryRequests', 'spec.forProvider.values.master.resources.requests.memory'),
            comp.FromCompositeFieldPath('spec.parameters.size.memoryLimits', 'spec.forProvider.values.master.resources.limits.memory'),
            comp.FromCompositeFieldPath('spec.parameters.size.cpuRequests', 'spec.forProvider.values.master.resources.requests.cpu'),
            comp.FromCompositeFieldPath('spec.parameters.size.cpuLimits', 'spec.forProvider.values.master.resources.limits.cpu'),
            comp.FromCompositeFieldPath('spec.parameters.size.disk', 'spec.forProvider.values.master.persistence.size'),

            comp.FromCompositeFieldPath('spec.parameters.service.version', 'spec.forProvider.values.image.tag'),
            comp.FromCompositeFieldPath('spec.parameters.service.redisSettings', 'spec.forProvider.values.commonConfiguration'),
          ],
        },
      ],
    },
  };


if params.services.vshn.enabled && redisParams.enabled then {
  '20_xrd_vshn_redis': xrd,
  '20_rbac_vshn_redis': xrds.CompositeClusterRoles(xrd),
  '21_composition_vshn_redis': composition,
} else {}
