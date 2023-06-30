local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local slos = import 'slos.libsonnet';


local inv = kap.inventory();
local params = inv.parameters.appcat;
local pgParams = params.services.vshn.postgres;

local xrdBrowseRole = kube.ClusterRole('appcat:browse') + {
  metadata+: {
    labels: {
      'rbac.authorization.k8s.io/aggregate-to-view': 'true',
      'rbac.authorization.k8s.io/aggregate-to-edit': 'true',
      'rbac.authorization.k8s.io/aggregate-to-admin': 'true',
    },
  },
  rules+: [
    {
      apiGroups: [ 'apiextensions.crossplane.io' ],
      resources: [
        'compositions',
        'compositionrevisions',
        'compositeresourcedefinitions',
      ],
      verbs: [ 'get', 'list', 'watch' ],
    },
  ],
};


local isOpenshift = std.startsWith(inv.parameters.facts.distribution, 'openshift');
local finalizerRole = kube.ClusterRole('crossplane:appcat:finalizer') {
  metadata+: {
    labels: {
      'rbac.crossplane.io/aggregate-to-crossplane': 'true',
    },
  },
  rules+: [
    {
      apiGroups: [
        'appcat.vshn.io',
        'vshn.appcat.vshn.io',
        'exoscale.appcat.vshn.io',
      ],
      resources: [
        '*/finalizers',
      ],
      verbs: [ '*' ],
    },
  ],

};

local readServices = kube.ClusterRole('appcat:services:read') + {
  rules+: [
    {
      apiGroups: [ '' ],
      resources: [ 'pods', 'pods/log', 'pods/status', 'events', 'services' ],
      verbs: [ 'get', 'list', 'watch' ],
    },
    {
      apiGroups: [ '' ],
      resources: [ 'pods/portforward' ],
      verbs: [ 'get', 'list', 'create' ],
    },
  ],
};

// adding namespace for syn-appcat
local ns = kube.Namespace(params.namespace) {
  metadata+: {
    labels+: params.namespaceLabels,
    annotations+: params.namespaceAnnotations,
  },
};

local emailSecret = kube.Secret(params.services.vshn.emailAlerting.secretName) {
  metadata+: {
    namespace: params.services.vshn.emailAlerting.secretNamespace,
  },
  stringData: {
    password: params.services.vshn.emailAlerting.smtpPassword,
  },
};

// Orignal query
// INSERT INTO products(source, target, unit, during, amount)
// SELECT 'appcat_postgresql:vshn:*:*:noeffort', '2', 'instances', '[-infinity,infinity)', 1
// WHERE
// NOT EXISTS (
// 	SELECT id
// 	FROM products
// 	WHERE
// 		source = 'appcat_postgresql:vshn:*:*:noeffort' AND
// 		target = '2' AND
// 		unit = 'instances' AND
// 		during = '[-infinity,infinity)' AND
// 		amount = 1
// );

local arrayToSQL(products) =
  local outer(arr, index) =
    // Insert part of the query
    local insert = 'INSERT INTO products(source, target, amount, unit, during)\n';

    // building the select part of the query
    local select = "SELECT '"
                   + arr[index].source + "', '"
                   + arr[index].target + "', "
                   + arr[index].amount + ", '"
                   + arr[index].unit + "', '"
                   + arr[index].during + "'\n";

    // building where not part
    local whereNot = 'WHERE\n'
                     + 'NOT EXISTS (\n'
                     + 'SELECT id\n'
                     + 'FROM products\n'
                     + 'WHERE\n'
                     + "source = '" + arr[index].source + "' AND\n"
                     + "target = '" + arr[index].target + "' AND\n"
                     + "unit = '" + arr[index].unit + "' AND\n"
                     + "during = '" + arr[index].during + "' AND\n"
                     + 'amount = ' + arr[index].amount
                     + ');\n';

    if index == std.length(arr) - 1 then
      insert
      + select
      + whereNot
    else
      insert
      + select
      + whereNot
      + outer(arr, index + 1)
  ;
  outer(products, 0);

local billingData = kube.CronJob('ensure-product-data') {
  metadata+: {
    namespace: params.namespace,
  },
  spec+: {
    schedule: '* * * * *',
    failedJobsHistoryLimit: 3,
    successfulJobsHistoryLimit: 0,
    jobTemplate+: {
      spec+: {
        template+: {
          spec+: {
            containers: [
              {
                name: 'ensure-product-data',
                image: 'postgres',
                args: [
                  'psql',
                  '${PSQL_URL}',
                  '-f',
                  'products.sql',
                  'TBD',
                ],
                env: [
                  {
                    name: 'PSQL_URL',
                    value: 'postgresql://postgres:$password@localhost',
                  },
                  {
                    name: 'SELECTS',
                    value: arrayToSQL(params.products),
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

{
  '10_clusterrole_view': xrdBrowseRole,
  [if isOpenshift then '10_clusterrole_finalizer']: finalizerRole,
  '10_clusterrole_services_read': readServices,
  '10_appcat_namespace': ns,
  [if params.services.vshn.enabled && params.services.vshn.emailAlerting.enabled then '10_mailgun_secret']: emailSecret,
  [if params.manageBillingProducts then '10_ensure_products']: billingData,

} + if params.slos.enabled then {
  [if params.services.vshn.enabled && params.services.vshn.postgres.enabled then 'sli_exporter/90_slo_vshn_postgresql']: slos.Get('vshn-postgresql'),
}
else {}
