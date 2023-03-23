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

local caCertificateSecretName = 'tls-ca-certificate';
local serverCertificateSecretName = 'tls-server-certificate';
local clientCertificateSecretName = 'tls-client-certificate';

local serviceNameLabelKey = 'appcat.vshn.io/servicename';
local serviceNamespaceLabelKey = 'appcat.vshn.io/claim-namespace';

local connectionSecretKeys = [
  'ca.crt',
  'tls.crt',
  'tls.key',
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
                                'appuio.io/no-rbac-creation': 'true',
                              },
                            },
                          },
                        },
                      },
                    };
  local selfSignedIssuer = comp.KubeObject('cert-manager.io/v1', 'Issuer') +
                           {
                             spec+: {
                               forProvider+: {
                                 manifest+: {
                                   metadata: {
                                     name: '',
                                     namespace: '',
                                   },
                                   spec: {
                                     selfSigned: {
                                       crlDistributionPoints: [],
                                     },
                                   },
                                 },
                               },
                             },
                           };
  local caCertificate = comp.KubeObject('cert-manager.io/v1', 'Certificate') +
                        {
                          spec+: {
                            forProvider+: {
                              manifest+: {
                                metadata: {
                                  name: '',
                                  namespace: '',
                                },
                                spec: {
                                  secretName: caCertificateSecretName,
                                  duration: '87600h',
                                  renewBefore: '2400h',
                                  subject: {
                                    organizations: [
                                      'vshn-appcat-ca',
                                    ],
                                  },
                                  isCA: true,
                                  privateKey: {
                                    algorithm: 'RSA',
                                    encoding: 'PKCS1',
                                    size: 4096,
                                  },
                                  dnsNames: [
                                    'vshn.appcat.vshn.ch',
                                  ],
                                  issuerRef: {
                                    name: '',
                                    kind: 'Issuer',
                                    group: 'cert-manager.io',
                                  },
                                },
                              },
                            },
                          },
                        };
  local caIssuer = comp.KubeObject('cert-manager.io/v1', 'Issuer') +
                   {
                     spec+: {
                       forProvider+: {
                         manifest+: {
                           metadata: {
                             name: '',
                             namespace: '',
                           },
                           spec: {
                             ca: {
                               secretName: caCertificateSecretName,
                             },
                           },
                         },
                       },
                     },
                   };
  local serverCertificate = comp.KubeObject('cert-manager.io/v1', 'Certificate') +
                            {
                              spec+: {
                                forProvider+: {
                                  manifest+: {
                                    metadata: {
                                      name: '',
                                      namespace: '',
                                    },
                                    spec: {
                                      secretName: serverCertificateSecretName,
                                      duration: '87600h',
                                      renewBefore: '2400h',
                                      subject: {
                                        organizations: [
                                          'vshn-appcat-server',
                                        ],
                                      },
                                      isCA: false,
                                      privateKey: {
                                        algorithm: 'RSA',
                                        encoding: 'PKCS1',
                                        size: 4096,
                                      },
                                      usages: [
                                        'server auth',
                                        'client auth',
                                      ],
                                      dnsNames: [
                                        'vshn.appcat.vshn.ch',
                                      ],
                                      issuerRef: {
                                        name: '',
                                        kind: 'Issuer',
                                        group: 'cert-manager.io',
                                      },
                                    },
                                  },
                                },
                              },
                            };
  local clientCertificate = comp.KubeObject('cert-manager.io/v1', 'Certificate') +
                            {
                              spec+: {
                                forProvider+: {
                                  manifest+: {
                                    metadata: {
                                      name: '',
                                      namespace: '',
                                    },
                                    spec: {
                                      secretName: clientCertificateSecretName,
                                      duration: '87600h',
                                      renewBefore: '2400h',
                                      subject: {
                                        organizations: [
                                          'vshn-appcat-client',
                                        ],
                                      },
                                      isCA: false,
                                      privateKey: {
                                        algorithm: 'RSA',
                                        encoding: 'PKCS1',
                                        size: 4096,
                                      },
                                      usages: [
                                        'client auth',
                                      ],
                                      dnsNames: [
                                        'vshn.appcat.vshn.ch',
                                      ],
                                      issuerRef: {
                                        name: '',
                                        kind: 'Issuer',
                                        group: 'cert-manager.io',
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
                       {
                         patchesFrom: {
                           apiVersion: 'v1',
                           kind: 'Secret',
                           name: clientCertificateSecretName,
                           namespace: '',
                           fieldPath: 'data[ca.crt]',
                         },
                         toFieldPath: 'data[ca.crt]',
                       },
                       {
                         patchesFrom: {
                           apiVersion: 'v1',
                           kind: 'Secret',
                           name: clientCertificateSecretName,
                           namespace: '',
                           fieldPath: 'data[tls.crt]',
                         },
                         toFieldPath: 'data[tls.crt]',
                       },
                       {
                         patchesFrom: {
                           apiVersion: 'v1',
                           kind: 'Secret',
                           name: clientCertificateSecretName,
                           namespace: '',
                           fieldPath: 'data[tls.key]',
                         },
                         toFieldPath: 'data[tls.key]',
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
            tls: {
              enabled: true,
              authClients: true,
              autoGenerated: false,
              existingSecret: serverCertificateSecretName,
              certFilename: 'tls.crt',
              certKeyFilename: 'tls.key',
              certCAFilename: 'ca.crt',
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
            comp.ToCompositeFieldPath('status.conditions', 'status.namespaceConditions'),
            comp.FromCompositeFieldPathWithTransformPrefix('metadata.labels[crossplane.io/composite]', 'metadata.name', 'vshn-redis'),
            comp.FromCompositeFieldPath('metadata.labels[crossplane.io/claim-namespace]', 'spec.forProvider.manifest.metadata.labels[%s]' % serviceNamespaceLabelKey),
            comp.FromCompositeFieldPath('metadata.labels[appuio.io/organization]', 'spec.forProvider.manifest.metadata.labels[appuio.io/organization]'),
            comp.ToCompositeFieldPath('metadata.name', 'status.instanceNamespace'),
          ],
        },
        comp.NamespacePermissions('vshn-redis'),
        {
          base: selfSignedIssuer,
          patches: [
            comp.ToCompositeFieldPath('status.conditions', 'status.selfSignedIssuerConditions'),
            comp.FromCompositeFieldPathWithTransformSuffix('metadata.labels[crossplane.io/composite]', 'metadata.name', 'selfsigned-issuer'),
            comp.FromCompositeFieldPathWithTransformSuffix('metadata.labels[crossplane.io/composite]', 'spec.forProvider.manifest.metadata.name', 'selfsigned-issuer'),
            comp.FromCompositeFieldPathWithTransformPrefix('metadata.labels[crossplane.io/composite]', 'spec.forProvider.manifest.metadata.namespace', 'vshn-redis'),
          ],
        },
        {
          base: caIssuer,
          patches: [
            comp.ToCompositeFieldPath('status.conditions', 'status.localCAConditions'),
            comp.FromCompositeFieldPathWithTransformSuffix('metadata.labels[crossplane.io/composite]', 'metadata.name', 'ca-issuer'),
            comp.FromCompositeFieldPathWithTransformSuffix('metadata.labels[crossplane.io/composite]', 'spec.forProvider.manifest.metadata.name', 'ca-issuer'),
            comp.FromCompositeFieldPathWithTransformPrefix('metadata.labels[crossplane.io/composite]', 'spec.forProvider.manifest.metadata.namespace', 'vshn-redis'),
          ],
        },
        {
          base: caCertificate,
          patches: [
            comp.ToCompositeFieldPath('status.conditions', 'status.caCertificateConditions'),
            comp.FromCompositeFieldPathWithTransformSuffix('metadata.labels[crossplane.io/composite]', 'metadata.name', 'ca-certificate'),
            comp.FromCompositeFieldPathWithTransformSuffix('metadata.labels[crossplane.io/composite]', 'spec.forProvider.manifest.metadata.name', 'ca'),
            comp.FromCompositeFieldPathWithTransformSuffix('metadata.labels[crossplane.io/composite]', 'spec.forProvider.manifest.spec.issuerRef.name', 'selfsigned-issuer'),
            comp.FromCompositeFieldPathWithTransformPrefix('metadata.labels[crossplane.io/composite]', 'spec.forProvider.manifest.metadata.namespace', 'vshn-redis'),
          ],
        },
        {
          base: serverCertificate,
          patches: [
            comp.ToCompositeFieldPath('status.conditions', 'status.serverCertificateConditions'),
            comp.FromCompositeFieldPathWithTransformSuffix('metadata.labels[crossplane.io/composite]', 'metadata.name', 'server-certificate'),
            comp.FromCompositeFieldPathWithTransformSuffix('metadata.labels[crossplane.io/composite]', 'spec.forProvider.manifest.metadata.name', 'server'),
            comp.FromCompositeFieldPathWithTransformSuffix('metadata.labels[crossplane.io/composite]', 'spec.forProvider.manifest.spec.issuerRef.name', 'ca-issuer'),
            comp.FromCompositeFieldPathWithTransformPrefix('metadata.labels[crossplane.io/composite]', 'spec.forProvider.manifest.metadata.namespace', 'vshn-redis'),
          ],
        },
        {
          base: clientCertificate,
          patches: [
            comp.ToCompositeFieldPath('status.conditions', 'status.clientCertificateConditions'),
            comp.FromCompositeFieldPathWithTransformSuffix('metadata.labels[crossplane.io/composite]', 'metadata.name', 'client-certificate'),
            comp.FromCompositeFieldPathWithTransformSuffix('metadata.labels[crossplane.io/composite]', 'spec.forProvider.manifest.metadata.name', 'client'),
            comp.FromCompositeFieldPathWithTransformSuffix('metadata.labels[crossplane.io/composite]', 'spec.forProvider.manifest.spec.issuerRef.name', 'ca-issuer'),
            comp.FromCompositeFieldPathWithTransformPrefix('metadata.labels[crossplane.io/composite]', 'spec.forProvider.manifest.metadata.namespace', 'vshn-redis'),
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
            comp.FromCompositeFieldPathWithTransformPrefix('metadata.labels[crossplane.io/composite]', 'spec.references[1].patchesFrom.namespace', 'vshn-redis'),
            comp.FromCompositeFieldPathWithTransformPrefix('metadata.labels[crossplane.io/composite]', 'spec.references[2].patchesFrom.namespace', 'vshn-redis'),
            comp.FromCompositeFieldPathWithTransformPrefix('metadata.labels[crossplane.io/composite]', 'spec.references[3].patchesFrom.namespace', 'vshn-redis'),
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
            comp.FromCompositeFieldPath('spec.parameters.tls.enabled', 'spec.forProvider.values.tls.enabled'),
            comp.FromCompositeFieldPath('spec.parameters.tls.authClients', 'spec.forProvider.values.tls.authClients'),


            comp.FromCompositeFieldPath('spec.parameters.scheduling.nodeSelector', 'spec.forProvider.values.master.nodeSelector'),
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
