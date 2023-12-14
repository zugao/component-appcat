local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.appcat;

local labels = {
  'app.kubernetes.io/name': 'appuio-reporting',
  'app.kubernetes.io/managed-by': 'commodore',
  'app.kubernetes.io/part-of': 'syn',
};

local cronJob = function(name, scheduleName, jobSpec)
  local truncatedName = if std.length(name) < 52 then
    name
  else
    '%s-%s' % [ std.substr(name, 0, 36), std.substr(std.md5(name), 0, 15) ];
  local schedule = params.billing.vshn.schedule;
  kube._Object('batch/v1', 'CronJob', truncatedName) {
    metadata+: {
      namespace: params.namespace,
      labels+: labels,
    },
    spec: {
      // set startingDeadlineSeconds to ensure that new jobs will be scheduled
      // if the cronjob is unsuspended after a long period of being suspended.
      // This is required because any jobs that would have been scheduled
      // while the CronJob is suspended count as missed and without
      // startingDeadlineSeconds set, the CronJob controller will not schedule
      // new jobs if >100 jobs were missed. See the following upstream
      // documentation:
      // * https://kubernetes.io/docs/tasks/job/automated-tasks-with-cron-jobs/#suspend
      // * https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/#cron-job-limitations
      startingDeadlineSeconds: 180,
      schedule: schedule,
      successfulJobsHistoryLimit: 3,
      failedJobsHistoryLimit: 3,
      jobTemplate: {
        metadata: {
          labels+: labels {
            'cron-job-name': name,
          },
        },
        spec: {
          template: {
            metadata: {
              labels+: labels,
            },
            spec: {
              restartPolicy: 'OnFailure',
              initContainers: [],
              containers: [],
            } + jobSpec,
          },
        },
      },
    },
  };


{
  Labels: labels,
  CronJob: cronJob,
}
