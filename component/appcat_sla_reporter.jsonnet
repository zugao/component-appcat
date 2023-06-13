local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';


local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.appcat;
local sla_reporter_params = params.slos.sla_reporter;
local common = import 'common.libsonnet';

local CronJob = kube.CronJob('appcat-sla-reporter') {
  metadata+: {
    namespace: params.slos.namespace,
  },
  spec+: {
    schedule: sla_reporter_params.schedule,
    failedJobsHistoryLimit: 3,
    successfulJobsHistoryLimit: 0,
    jobTemplate+: {
      spec+: {
        template+: {
          spec+: {
            containers: [
              {
                name: 'sla-reporter',
                image: common.GetAppCatImageString(),
                resources: sla_reporter_params.resources,
                args: [
                  'slareport',
                  '--previousmonth',
                  '--mimirorg',
                  sla_reporter_params.mimir_organization,
                ],
                envFrom: [
                  {
                    secretRef: {
                      name: 'appcat-sla-reports-creds',
                    },
                  },
                ],
                env: [
                  {
                    name: 'PROM_URL',
                    value: sla_reporter_params.slo_mimir_endpoint,
                  },
                ],
              },
            ],
          },
        },
      },
    },
  },
};

local ObjectStorage = kube._Object('appcat.vshn.io/v1', 'ObjectBucket', 'appcat-sla-reports') {
  metadata: {
    namespace: params.slos.namespace,
    name: 'appcat-sla-reports',
    annotations: {
      // Our current ArgoCD configuration can't handle the claim -> composite
      // relationship
      'argocd.argoproj.io/compare-options': 'IgnoreExtraneous',
      'argocd.argoproj.io/sync-options': 'Prune=false',
    },
  },
  spec: {
    parameters: {
      bucketName: 'appcat-sla-reports',
      region: sla_reporter_params.bucket_region,
    },
    writeConnectionSecretToRef: {
      name: 'appcat-sla-reports-creds',
    },
  },
};

if sla_reporter_params.enabled == true then {
  '01_cronjob': CronJob,
  '02_object_bucket': ObjectStorage,
} else {}
