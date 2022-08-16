// main template for appcat
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.appcat;

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

// Define outputs below
{
  secrets: std.filter(function(it) it != null, secrets),
  additionalResources: std.filter(function(it) it != null, additionalResources),
}
