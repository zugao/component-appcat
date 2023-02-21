local common = import 'common.libsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local com = import 'lib/commodore.libjsonnet';
local params = inv.parameters.appcat;
local apiserverParams = params.apiserver;

local image = params.images.apiserver;
local loadManifest(manifest) = std.parseJson(kap.yaml_load('appcat/manifests/' + image.tag + '/' + manifest));

local namespace = loadManifest('namespace.yaml') {
  metadata+: {
    name: apiserverParams.namespace,
  },
};

local serviceAccount = loadManifest('service-account.yaml') {
  metadata+: {
    namespace: apiserverParams.namespace,
  },
};

local clusterRole = loadManifest('cluster-role.yaml');

local clusterRoleBinding = kube.ClusterRoleBinding(clusterRole.metadata.name) {
  roleRef: {
    kind: 'ClusterRole',
    apiGroup: 'rbac.authorization.k8s.io',
    name: clusterRole.metadata.name,
  },
  subjects: [
    {
      kind: 'ServiceAccount',
      name: serviceAccount.metadata.name,
      namespace: serviceAccount.metadata.namespace,
    },
  ],
};

local certSecret =
  if apiserverParams.tls.certSecretName != null && apiserverParams.enabled == true then
    assert std.length(apiserverParams.tls.serverCert) > 0 : 'apiserver.tls.serverCert is required';
    assert std.length(apiserverParams.tls.serverKey) > 0 : 'apiserver.tls.serverKey is required';
    kube.Secret(apiserverParams.tls.certSecretName) {
      metadata+: {
        namespace: apiserverParams.namespace,
      },
      stringData: {
        'tls.key': apiserverParams.tls.serverKey,
        'tls.crt': apiserverParams.tls.serverCert,
      },
    }
  else
    null;

local extraDeploymentArgs =
  if certSecret != null then
    [
      '--tls-cert-file=/apiserver.local.config/certificates/tls.crt',
      '--tls-private-key-file=/apiserver.local.config/certificates/tls.key',
    ]
  else
    []
;

local apiserver = loadManifest('aggregated-apiserver.yaml') {
  metadata+: {
    namespace: apiserverParams.namespace,
  },
  spec+: {
    template+: {
      spec+: {
        containers: [
          if c.name == 'apiserver' then
            c {
              image: '%(registry)s/%(repository)s:%(tag)s' % params.images.apiserver,
              args: [ super.args[0] ] + common.MergeArgs(common.MergeArgs(super.args[1:], extraDeploymentArgs), apiserverParams.extraArgs),
              env+: com.envList(apiserverParams.extraEnv),
            }
          else
            c
          for c in super.containers
        ],
      } + if certSecret != null then
        {
          volumes: [
            {
              name: 'apiserver-certs',
              secret: {
                secretName: certSecret.metadata.name,
              },
            },
          ],
        }
      else {},
    },
  },
};

local service = loadManifest('service.yaml') {
  metadata+: {
    namespace: apiserverParams.namespace,
  },
};


local apiService = loadManifest('apiservice.yaml') {
  spec+:
    {
      service: {
        name: service.metadata.name,
        namespace: service.metadata.namespace,
      },
    }
    +
    (
      if apiserverParams.tls.serverCert != null
         && apiserverParams.tls.serverCert != ''
         && apiserverParams.apiservice.insecureSkipTLSVerify == false
      then
        { caBundle: std.base64(params.apiserver.tls.serverCert) }
      else
        {}
    )
    +
    apiserverParams.apiservice,
};


{
  'apiserver/10_namespace': namespace,
  'apiserver/10_cluster_role': clusterRole,
  'apiserver/10_cluster_role_binding': clusterRoleBinding,
  'apiserver/20_service_account': serviceAccount,
  [if certSecret != null then 'apiserver/20_certs']: certSecret,
  'apiserver/30_deployment': apiserver,
  'apiserver/30_service': service,
  'apiserver/30_api_service': apiService,
}
