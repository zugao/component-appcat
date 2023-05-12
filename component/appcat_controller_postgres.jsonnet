local common = import 'common.libsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local com = import 'lib/commodore.libjsonnet';
local params = inv.parameters.appcat;
local controllersParams = params.controller;
local postgresControllerParams = controllersParams.postgres;

local image = params.images.apiserver;
local loadManifest(manifest) = std.parseJson(kap.yaml_load('appcat/manifests/apiserver/' + image.tag + '/config/controller/' + manifest));

local namespace = loadManifest('namespace.yaml') {
  metadata+: {
    name: controllersParams.namespace,
  },
};

local serviceAccount = loadManifest('service-account.yaml') {
  metadata+: {
    namespace: controllersParams.namespace,
  },
};

local roleLeaderElection = loadManifest('role-leader-election.yaml') {
  metadata+: {
    namespace: controllersParams.namespace,
  },
};

local roleBindingLeaderElection = loadManifest('role-binding-leader-election.yaml') {
  metadata+: {
    namespace: controllersParams.namespace,
  },
  subjects: [
    super.subjects[0] {
      namespace: controllersParams.namespace,
    },
  ],
};

local clusterRole = loadManifest('cluster-role.yaml');

local clusterRoleBinding = loadManifest('cluster-role-binding.yaml') {
  subjects: [
    super.subjects[0] {
      namespace: controllersParams.namespace,
    },
  ],
};

local controller = loadManifest('deployment.yaml') {
  metadata+: {
    namespace: controllersParams.namespace,
  },
  spec+: {
    template+: {
      spec+: {
        containers: [
          if c.name == 'manager' then
            c {
              image: '%(registry)s/%(repository)s:%(tag)s' % params.images.apiserver,
              args+: postgresControllerParams.extraArgs,
              env+: com.envList(postgresControllerParams.extraEnv),
              resources: postgresControllerParams.resources,
            }
          else
            c
          for c in super.containers
        ],
      },
    },
  },
};


if controllersParams.enabled == true && postgresControllerParams.enabled == true then {
  'controllers/postgres/10_namespace': namespace,
  'controllers/postgres/10_role_leader_election': roleLeaderElection,
  'controllers/postgres/10_cluster_role': clusterRole,
  'controllers/postgres/10_role_binding_leader_election': roleBindingLeaderElection,
  'controllers/postgres/10_cluster_role_binding': clusterRoleBinding,
  'controllers/postgres/20_service_account': serviceAccount,
  'controllers/postgres/30_deployment': controller,
} else {}
