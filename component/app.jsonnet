local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.appcat;
local argocd = import 'lib/argocd.libjsonnet';
local on_openshift4 = std.member([ 'openshift4', 'oke' ], inv.parameters.facts.distribution);

local ignore_diff_sa = {
  group: '',
  kind: 'ServiceAccount',
  name: '',
  jsonPointers: [ '/imagePullSecrets' ],
};

local ignore_diff_cr = {
  group: 'rbac.authorization.k8s.io',
  kind: 'ClusterRole',
  name: 'crossplane',
  jsonPointers: [ '/rules' ],
};

local ignore_diff_s = {
  group: '',
  jsonPointers: [
    '/data',
  ],
  kind: 'Secret',
  name: 'github-ci-secret',
  namespace: 'appcat-e2e',
};

local ignore_diff_n = {
  group: '',
  jsonPointers: [
    '/metadata/annotations',
  ],
  kind: 'Namespace',
};

local app = argocd.App('appcat', '') + (
  if params.services.vshn.e2eTests then {
    spec+: {
      ignoreDifferences+: [
        ignore_diff_s,
        ignore_diff_n,
        ignore_diff_cr,
        if on_openshift4 then
          ignore_diff_sa
        else
          {},
      ],
    },
  } else {}
) + (
  {
    spec+: {
      ignoreDifferences+: [
        {
          group: 'admissionregistration.k8s.io',
          kind: 'ValidatingWebhookConfiguration',
          jqPathExpressions: [
            '.webhooks[]?.clientConfig.caBundle',
          ],
        },
      ],
      syncPolicy: {
        automated: {
          prune: true,
          selfHeal: true,
        },
        syncOptions: [
          'ServerSideApply=true',
        ],
      },
    },
  }
);

{
  appcat: app,
}
