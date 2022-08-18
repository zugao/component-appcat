// main template for appcat
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.appcat;

local sync_options = {
  metadata+: {
    annotations+: {
      'argocd.argoproj.io/sync-options': 'SkipDryRunOnMissingResource=true',
      'argocd.argoproj.io/sync-wave': '10',
    },
  },
};

// https://syn.tools/syn/explanations/commodore-components/secrets.html
local secrets = [
  if params.secrets[s] != null then
    kube.Secret(s) {} + com.makeMergeable(params.secrets[s])
  for s in std.objectFields(params.secrets)
];

local additionalResources = [
  if params.additionalResources[s] != null then
    local res = params.additionalResources[s];
    kube._Object(res.apiVersion, res.kind, s) + com.makeMergeable(res)
  for s in std.objectFields(params.additionalResources)
];

local composites = [
  if params.composites[name] != null then
    local res = params.composites[name];
    kube._Object('apiextensions.crossplane.io/v1', 'CompositeResourceDefinition', name) + sync_options + com.makeMergeable(res)
  for name in std.objectFields(params.composites)
];

local compositions = [
  if params.compositions[name] != null then
    local composition = params.compositions[name];
    kube._Object('apiextensions.crossplane.io/v1', 'Composition', name) + sync_options + com.makeMergeable(composition)
  for name in std.objectFields(params.compositions)
];

// Define outputs below
{
  secrets: std.filter(function(it) it != null, secrets),
  additionalResources: std.filter(function(it) it != null, additionalResources),
  composites: std.filter(function(it) it != null, composites),
  compositions: std.filter(function(it) it != null, compositions),
}
