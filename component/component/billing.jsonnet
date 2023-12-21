// main template for appuio-reporting
local alerts = import 'billing_alerts.libsonnet';
local common = import 'billing_cronjob.libsonnet';
local netPol = import 'billing_netpol.libsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.appcat;

local formatImage = function(ref) '%(registry)s/%(repository)s:%(tag)s' % ref;

// escape any non-valid characters and replace them with -
local escape = function(str)
  std.join('',
           std.map(
             function(c)
               if ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9')) then c else '-'
             , str
           ));

local odooSecret = kube.Secret('odoo-credentials') {
  metadata+: {
    namespace: params.billing.namespace,
    labels+: common.Labels,
  },
  stringData: {
    client_id: params.billing.odoo.oauth.clientID,
    client_secret: params.billing.odoo.oauth.clientSecret,
    token_endpoint: params.billing.odoo.oauth.url,
  },
};

local commonEnv = std.prune([
  {
    name: 'AR_ODOO_OAUTH_TOKEN_URL',
    valueFrom: {
      secretKeyRef: {
        name: odooSecret.metadata.name,
        key: 'token_endpoint',
      },
    },
  },
  {
    name: 'AR_ODOO_OAUTH_CLIENT_ID',
    valueFrom: {
      secretKeyRef: {
        name: odooSecret.metadata.name,
        key: 'client_id',
      },
    },
  },
  {
    name: 'AR_ODOO_OAUTH_CLIENT_SECRET',
    valueFrom: {
      secretKeyRef: {
        name: odooSecret.metadata.name,
        key: 'client_secret',
      },
    },
  },
  {
    name: 'AR_ODOO_URL',
    value: params.billing.odoo.url,
  },
  {
    name: 'AR_PROM_URL',
    value: params.billing.prometheus.url,
  },
  if params.billing.prometheus.org_id != null then {
    name: 'AR_ORG_ID',
    value: params.billing.prometheus.org_id,
  },
]);

local backfillCJ = function(name, query, sla, type)

  local nameSLA = name + ' by VSHN ' + sla;

  local itemDescJsonnet = 'local labels = std.extVar("labels"); "%s" %% labels' % nameSLA;

  local clusterID = if params.billing.enableMockOrgInfo then 'kind' else '%(cluster_id)s';

  local itemGroupDesc = nameSLA + ' - Zone: ' + clusterID + ' / Namespace: %(label_appcat_vshn_io_claim_namespace)s';

  local itemGroupDescJsonnet = 'local labels = std.extVar("labels"); "%s" %% labels' % itemGroupDesc;

  local instanceJsonnet = 'local labels = std.extVar("labels"); "%s" %% labels' % '%(label_appcat_vshn_io_claim_namespace)s/%(label_appcat_vshn_io_claim_name)s';

  local productID = 'appcat-vshn-%(name)s-%(sla)s' % { name: name, sla: sla };

  local jobEnv = std.prune([
    {
      name: 'AR_PRODUCT_ID',
      value: productID,
    },
    {
      name: 'AR_QUERY',
      value: query,
    },
    {
      name: 'AR_INSTANCE_JSONNET',
      value: instanceJsonnet,
    },
    if itemGroupDescJsonnet != null then {
      name: 'AR_ITEM_GROUP_DESCRIPTION_JSONNET',
      value: itemGroupDescJsonnet,
    },
    if itemDescJsonnet != null then {
      name: 'AR_ITEM_DESCRIPTION_JSONNET',
      value: itemDescJsonnet,
    },
    {
      name: 'AR_UNIT_ID',
      value: params.billing.instanceUOM,
    },
  ]);
  common.CronJob('%(product)s-%(type)s' % { product: escape(productID), type: type }, 'backfill', {
    containers: [
      {
        name: 'backfill',
        image: formatImage(params.images.reporting),
        env+: commonEnv + jobEnv,
        command: [ 'sh', '-c' ],
        args: [
          'appuio-reporting report --timerange 1h --begin=$(date -d "now -3 hours" -u +"%Y-%m-%dT%H:00:00Z") --repeat-until=$(date -u -Iseconds)',
        ],
        resources: {},
      },
    ],
  }) {
    metadata+: {
      annotations+: {
        'product-id': productID,
      },
    },
    spec+: {
      jobTemplate+: {
        metadata+: {
          annotations+: {
            'product-id': productID,
          },
        },
      },
      failedJobsHistoryLimit: 10,
    },
  };

local generateCloudAndManaged = function(name)

  // For postgresql we have a missmatch between the label and the name in our definition.
  local queryName = if name == 'postgres' then name + 'ql' else name;

  local managedQuery = 'appcat:metering{label_appuio_io_billing_name="appcat-' + queryName + '",label_appcat_vshn_io_sla="%s"}';
  local cloudQuery = managedQuery + ' * on(label_appuio_io_organization) group_left(sales_order) label_replace(appuio_control_organization_info{namespace="appuio-control-api-production"}, "label_appuio_io_organization", "$1", "organization", "(.*)")';

  local permutations = [
    {
      query: cloudQuery % 'besteffort',
      sla: 'besteffort',
      type: 'cloud',
    },
    {
      query: cloudQuery % 'guaranteed',
      sla: 'guaranteed',
      type: 'cloud',
    },
    // Currently appcat on appuio managed isn't billed, so we don't need the permutations
    // {
    //   query: managedQuery % 'besteffort',
    //   sla: 'besteffort',
    //   type: 'managed',
    // },
    // {
    //   query: managedQuery % 'guaranteed',
    //   sla: 'guaranteed',
    //   type: 'managed',
    // },
  ];

  std.flatMap(function(r) [ backfillCJ(name, r.query, r.sla, r.type) ], permutations);

local keysAndValues(obj) = std.map(function(x) { name: x, value: obj[x] }, std.objectFields(obj));
local vshnServices = std.filter(function(r) std.type(r.value) == 'object' && std.objectHas(r.value, 'billing') && r.value.billing, keysAndValues(params.services.vshn));
local billingCronjobs = std.flattenArrays(std.flatMap(function(r) [ generateCloudAndManaged(r.name) ], vshnServices));

if params.billing.vshn.enableCronjobs then
  {
    'billing/00_namespace': kube.Namespace(params.billing.namespace) {
      metadata+: {
        labels+: common.Labels {
          'openshift.io/cluster-monitoring': 'true',
        },
      },
    },
    [if std.length(params.billing.network_policies.target_namespaces) != 0 then 'billing/01_netpol']: netPol.Policies,
    'billing/10_odoo_secret': odooSecret,
    'billing/11_backfill': billingCronjobs,
    [if params.billing.monitoring.enabled then 'billing/50_alerts']: alerts.Alerts,
  } else {}
