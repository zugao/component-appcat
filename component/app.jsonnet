local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.appcat;
local argocd = import 'lib/argocd.libjsonnet';

local app = argocd.App('appcat', '') + (
  if params.services.vshn.e2eTests then {
    spec+: {
      ignoreDifferences+: [
        {
          group: '',
          jsonPointers: [
            '/data',
          ],
          kind: 'Secret',
          name: 'github-ci-secret',
          namespace: 'appcat-e2e',
        },
        {
          group: '',
          jsonPointers: [
            '/metadata/annotations',
          ],
          kind: 'Namespace',
        },
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
