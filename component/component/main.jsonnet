// main template for appcat
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local com = import 'lib/commodore.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.appcat;

// https://syn.tools/syn/explanations/commodore-components/secrets.html
local secrets = [
  if params.secrets[s] != null then
    kube.Secret(s) {} + com.makeMergeable(params.secrets[s])
  for s in std.objectFields(params.secrets)
];

// Define outputs below
{
  secrets: std.filter(function(it) it != null, secrets),
}
