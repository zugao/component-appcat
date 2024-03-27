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
      ],
    },
  } else {}
);

{
  appcat: app,
}
