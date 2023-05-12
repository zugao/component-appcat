local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local comp = import 'lib/appcat-compositions.libsonnet';
local crossplane = import 'lib/crossplane.libsonnet';

local common = import '../component/common.libsonnet';
local xrds = import '../component/xrds.libsonnet';

local inv = kap.inventory();
local params = inv.parameters.appcat;
local objStoParams = params.services.generic.objectstorage;

local xrd = xrds.XRDFromCRD(
  'xobjectbuckets.appcat.vshn.io',
  xrds.LoadCRD('appcat.vshn.io_objectbuckets.yaml', params.images.apiserver.tag),
  defaultComposition='%s.objectbuckets.appcat.vshn.io' % objStoParams.defaultComposition,
  connectionSecretKeys=[
    'AWS_ACCESS_KEY_ID',
    'AWS_SECRET_ACCESS_KEY',
    'AWS_REGION',
    'ENDPOINT',
    'ENDPOINT_URL',
    'BUCKET_NAME',
  ]
);

local minioRbac =
  local provider = params.providers.helm;

  local sa = kube.ServiceAccount(provider.controllerConfig.serviceAccountName) {
    metadata+: {
      namespace: provider.namespace,
    },
  };
  local role = kube.ClusterRole('crossplane:provider:provider-helm:system:dev') {
    rules: [
      {
        apiGroups: [ '' ],
        resources: [ 'persistentvolumeclaims', 'deployments' ],
        verbs: [ 'get', 'list', 'watch', 'create', 'watch', 'patch', 'update', 'delete' ],
      },
      {
        apiGroups: [ 'apps' ],
        resources: [ 'deployments' ],
        verbs: [ 'get', 'list', 'watch', 'create', 'watch', 'patch', 'update', 'delete' ],
      },
      {
        apiGroups: [ 'batch' ],
        resources: [ 'jobs' ],
        verbs: [ 'get', 'list', 'watch', 'create', 'watch', 'patch', 'update', 'delete' ],
      },
    ],
  };
  local rolebinding = kube.ClusterRoleBinding('crossplane:provider:provider-helm:system:dev') {
    roleRef_: role,
    subjects_: [ sa ],
  };

  [
    role,
    rolebinding,
  ];

local compositionMinioDev =

  local namespace = comp.KubeObject('v1', 'Namespace');

  local devMinioHelmChart =
    {
      apiVersion: 'helm.crossplane.io/v1beta1',
      kind: 'Release',
      spec+: {
        deletionPolicy: 'Delete',
        rollbackLimit: 3,
        connectionDetails: [
          {
            apiVersion: 'v1',
            kind: 'Service',
            name: 'minio-server',
            fieldPath: 'spec.clusterIP',
            toConnectionSecretKey: 'ENDPOINT_URL',
            namespace: 'minio',
          },
          {
            apiVersion: 'v1',
            kind: 'Secret',
            name: 'minio-server',
            fieldPath: 'data.rootUser',
            toConnectionSecretKey: 'AWS_ACCESS_KEY_ID',
            namespace: 'minio',
          },
          {
            apiVersion: 'v1',
            kind: 'Secret',
            name: 'minio-server',
            fieldPath: 'data.rootPassword',
            toConnectionSecretKey: 'AWS_SECRET_ACCESS_KEY',
            namespace: 'minio',
          },
        ],
        writeConnectionSecretToRef: {
          name: '',
          namespace: 'syn-crossplane',
        },
        forProvider+: {
          namespace: 'minio',
          chart: {
            name: 'minio',
            repository: 'https://charts.min.io/',
            version: '5.0.7',
          },
          set: [
            {
              name: 'rootUser',
              value: 'minioadmin',
            },
            {
              name: 'rootPassword',
              value: 'minioadmin',
            },
          ],
          values: {
            fullnameOverride: 'minio-server',
            replicas: 1,
            resources: {
              requests: {
                memory: '128Mi',
              },
            },
            persistence: {
              size: '1Gi',
            },
            mode: 'standalone',
            buckets: [
              {
                name: '',
                policy: 'none',
              },
            ],
          },
        },
        providerConfigRef: {
          name: 'helm',
        },
      },
    };

  kube._Object('apiextensions.crossplane.io/v1', 'Composition', 'dev.objectbuckets.appcat.vshn.io') +
  common.SyncOptions +
  {
    spec: {
      compositeTypeRef: comp.CompositeRef(xrd),
      writeConnectionSecretsToNamespace: 'syn-crossplane',
      resources: [
        {
          base: namespace,
          patches: [
            comp.FromCompositeFieldPath('metadata.labels[crossplane.io/composite]', 'spec.forProvider.manifest.metadata.name'),
          ],
        },
        {
          base: devMinioHelmChart,
          connectionDetails: [
            { fromConnectionSecretKey: 'AWS_SECRET_ACCESS_KEY' },
            { fromConnectionSecretKey: 'ENDPOINT_URL' },
            { fromConnectionSecretKey: 'AWS_ACCESS_KEY_ID' },
          ],
          patches: [
            comp.FromCompositeFieldPath('metadata.labels[crossplane.io/composite]', 'spec.forProvider.values.buckets[0].name'),
            comp.FromCompositeFieldPath('metadata.labels[crossplane.io/composite]', 'spec.writeConnectionSecretToRef.name'),
          ],
        },
      ],
    },
  };

if objStoParams.enabled then {
  '20_rbac_helm_provider_dev': minioRbac,
  '21_composition_objectstorage_minio_dev': compositionMinioDev,
} else {}
