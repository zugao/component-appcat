/**
 * \file crossplane.libsonnet
 * \brief Helpers to create Crossplane CRs.
 *        API reference: https://doc.crds.dev/github.com/crossplane/crossplane
 */

local kube = import 'lib/kube.libjsonnet';

// Define Crossplane API versions
local api_version = {
  pkg: 'pkg.crossplane.io/v1',
  apiextensions: 'apiextensions.crossplane.io/v1',
};

local sync_options = {
  metadata+: {
    annotations+: {
      'argocd.argoproj.io/sync-options': 'SkipDryRunOnMissingResource=true',
      'argocd.argoproj.io/sync-wave': '10',
    },
  },
};

{
  api_version: api_version,

  /**
  * \brief Helper to create Provider objects.
  *
  * \arg The name of the Provider.
  * \return A Provider object.
  */
  Provider(name):
    kube._Object(api_version.pkg, 'Provider', name) + sync_options,

  /**
  * \brief Helper to create ProviderConfig objects.
  *
  * \arg The name of the ProviderConfig.
  * \return A ProviderConfig object.
  */
  ProviderConfig(name):
    kube._Object('', 'ProviderConfig', name) + sync_options,

  /**
  * \brief Helper to create Configuration objects.
  *
  * \arg The name of the Configuration.
  * \return A Configuration object.
  */
  Configuration(name):
    kube._Object(api_version.pkg, 'Configuration', name) + sync_options,

  /**
  * \brief Helper to create ControllerConfig objects.
  *
  * \arg The name of the ControllerConfig.
  * \return A ControllerConfig object.
  */
  ControllerConfig(name):
    kube._Object('pkg.crossplane.io/v1alpha1', 'ControllerConfig', name) + sync_options,

  /**
  * \brief Helper to create Composition objects.
  *
  * \arg The name of the Composition.
  * \return A Composition object.
  */
  Composition(name):
    kube._Object(api_version.apiextensions, 'Composition', name) + sync_options,

  /**
  * \brief Helper to create CompositeResourceDefinition objects.
  *
  * \arg The name of the CompositeResourceDefinition.
  * \return A CompositeResourceDefinition object.
  */
  CompositeResourceDefinition(name):
    kube._Object(api_version.apiextensions, 'CompositeResourceDefinition', name) + sync_options,
}
