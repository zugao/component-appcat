local common = import 'common.libsonnet';
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local crossplane = import 'lib/appcat-crossplane.libsonnet';

local inv = kap.inventory();
local params = inv.parameters.appcat;
local appcatImage = params.images.functionAppcat;
local pntImage = params.images.functionpnt;

local getFunction(name, package, runtimeConfigName) = {
  apiVersion: 'pkg.crossplane.io/v1beta1',
  kind: 'Function',
  metadata: {
    name: name,
  },
  spec: {
    package: package,
    runtimeConfigRef: {
      name: runtimeConfigName,
    },
  },
};

local appcatRuntimeConfig = {
  apiVersion: 'pkg.crossplane.io/v1beta1',
  kind: 'DeploymentRuntimeConfig',
  metadata: {
    name: 'function-appcat',
  },
  spec: {
    deploymentTemplate: {
      spec: {
        selector: {},
        template: {
          spec:
            {
              containers: [
                {
                  name: 'package-runtime',
                  command: [ 'appcat' ],
                  args: [ 'functions' ],
                  securityContext: {},
                },
              ],
              securityContext: {},
              serviceAccountName: 'function-appcat',
            },
        },
      },
    },
  },
};

local appcatImageTag = std.strReplace(appcatImage.tag, '/', '_');

local appcatFunctionImage = appcatImage.registry + '/' + appcatImage.repository + ':' + appcatImageTag;

local appcat = getFunction('function-appcat', appcatFunctionImage, 'function-appcat');

local saAppCat = kube.ServiceAccount('function-appcat') {
  metadata+: {
    namespace: params.crossplane.namespace,
  },
};

local saPnT = kube.ServiceAccount('function-patch-and-transform') {
  metadata+: {
    namespace: params.crossplane.namespace,
  },
};

local pntFunctionImage = pntImage.registry + '/' + pntImage.repository + ':' + pntImage.tag;

if params.functions.enabled then
{
  '10_function_patch_and_transform': getFunction('function-patch-and-transform', pntFunctionImage, 'function-patch-and-transform'),
  '10_function_appcat': appcat,
  '10_runtimeconfig_function_appcat': appcatRuntimeConfig,
  '10_runtimeconfig_function_pnt': common.DefaultRuntimeConfigWithSaName('function-patch-and-transform'),
  '20_serviceaccount_appcat': saAppCat,
  '20_serviceaccount_pnt': saPnT,
} else {}
