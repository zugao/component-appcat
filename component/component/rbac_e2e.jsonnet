local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.appcat;

local e2eNs = kube.Namespace('appcat-e2e') + {
  metadata+: {
    labels+: {
      'appuio.io/organization': 'vshn-e2e-tests',
    },
  },
};

local e2eSA = kube.ServiceAccount('appcat-e2e') + {
  metadata+: {
    namespace: 'appcat-e2e',
  },
};

local e2eRoleBinding = kube.RoleBinding('appcat-e2e') + {
  metadata+: {
    namespace: 'appcat-e2e',
  },
  roleRef_: kube.ClusterRole('admin'),
  subjects_: [ e2eSA ],
};

local e2eSAToken = kube.Secret('appcat-e2e-github') + {
  metadata+: {
    namespace: 'appcat-e2e',
    annotations+: {
      'kubernetes.io/service-account.name': 'appcat-e2e',
      'argocd.argoproj.io/compare-options': 'IgnoreExtraneous',
    },
  },
  type: 'kubernetes.io/service-account-token',
};

if params.services.vshn.e2eTests then {
  '20_rbac_vshn_e2e_tests': [ e2eNs, e2eSA, e2eRoleBinding, e2eSAToken ],
} else {}
