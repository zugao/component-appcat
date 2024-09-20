local kap = import 'lib/kapitan.libjsonnet';

local inv = kap.inventory();
local params = inv.parameters.appcat;


local genGenericAlertingRule(serviceName) = {
  apiVersion: 'monitoring.coreos.com/v1',
  kind: 'PrometheusRule',
  metadata: {
    name: 'vshn-' + std.asciiLower(serviceName) + '-opsgenie',
    namespace: params.slos.namespace,
  },
  spec: {
    groups: [
      {
        name: 'appcat-' + std.asciiLower(serviceName) + '-sla-target',
        rules: [
          {
            alert: 'vshn-' + std.asciiLower(serviceName) + '-opsgenie',
            // this query can be read as: if the rate of probes that are not successful is higher than 0.2 in the last 5 minutes and in the last minute, then alert
            // rate works on per second basis, so 0.2 means 20% of the probes are failing, which for 5 minutes is 1 minute and for 1 minute is 12 seconds
            expr: 'rate(appcat_probes_seconds_count{reason!="success", service="' + serviceName + '", ha="false", maintenance="false"}[5m]) > 0.2 and rate(appcat_probes_seconds_count{reason!="success", service="' + serviceName + '", ha="false", maintenance="false"}[1m]) > 0.2',
            labels: {
              service: serviceName,
              severity: 'warning',
              OnCall: 'true',
            },
          },
          {
            alert: 'vshn-' + std.asciiLower(serviceName) + '-opsgenie-ha',
            // this query can be read as: if the rate of probes that are not successful is higher than 0.2 in the last 5 minutes and in the last minute, then alert
            // rate works on per second basis, so 0.2 means 20% of the probes are failing, which for 5 minutes is 1 minute and for 1 minute is 12 seconds
            expr: 'rate(appcat_probes_seconds_count{reason!="success", service="' + serviceName + '", ha="true", maintenance="false"}[5m]) > 0.2 and rate(appcat_probes_seconds_count{reason!="success", service="' + serviceName + '", ha="true", maintenance="false"}[1m]) > 0.2',
            labels: {
              service: serviceName,
              severity: 'warning',
              OnCall: 'true',
            },
          },
        ],
      },
    ],
  },
};


{
  GenGenericAlertingRule: genGenericAlertingRule,
}
