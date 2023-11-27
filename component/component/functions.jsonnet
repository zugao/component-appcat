local common = import 'common.libsonnet';
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local crossplane = import 'lib/crossplane.libsonnet';

local inv = kap.inventory();
local params = inv.parameters.appcat;
local appcatImage = params.images.functionAppcat;
local pntImage = params.images.functionpnt;

local getFunction(name, package) = {
  apiVersion: 'pkg.crossplane.io/v1beta1',
  kind: 'Function',
  metadata: {
    name: name,
  },
  spec: {
    package: package,
  },
};

local appcatRuntimeConfig = {
  apiVersion: 'pkg.crossplane.io/v1beta1',
  kind: 'DeploymentRuntimeConfig',
  metadata: {
    name: 'appcat-runtime-config',
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
            },
        },
      },
    },
  },
};

local defaultRuntimeConfig = {
  apiVersion: 'pkg.crossplane.io/v1beta1',
  kind: 'DeploymentRuntimeConfig',
  metadata: {
    name: 'default',
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
                  securityContext: {},
                },
              ],
              securityContext: {},
            },
        },
      },
    },
  },
};


local appcatImageTag = std.strReplace(appcatImage.tag, '/', '_');

local appcatFunctionImage = appcatImage.registry + '/' + appcatImage.repository + ':' + appcatImageTag;

local appcat = getFunction('function-appcat', appcatFunctionImage) + {
  spec+: {
    runtimeConfigRef: {
      name: 'appcat-runtime-config',
    },
  },
};

local pntFunctionImage = pntImage.registry + '/' + pntImage.repository + ':' + pntImage.tag;

{
  '10_function_patch_and_transform': getFunction('function-patch-and-transform', pntFunctionImage),
  '10_function_appcat': appcat,
  '10_runtimeconfig_appcat': appcatRuntimeConfig,
  '10_runtimeconfig_default': defaultRuntimeConfig,
}
