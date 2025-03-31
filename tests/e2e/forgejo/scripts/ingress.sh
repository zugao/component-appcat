#!/bin/bash

set -exf

ns=$(kubectl -n "$NAMESPACE" get vshnforgejo forgejo-e2e -oyaml | yq -r '.status.instanceNamespace')
composite=$(kubectl -n "$NAMESPACE" get vshnforgejo forgejo-e2e -oyaml | yq -r '.spec.resourceRef.name')

fqdn=$(kubectl -n "$ns" get ingress "${composite}-letsencrypt-ingress"  -oyaml | yq -r '.spec.tls.[0].hosts[0]')
fqdn_sub=$(kubectl -n "$ns" get ingress "${composite}-letsencrypt-ingress"  -oyaml | yq -r '.spec.tls.[0].hosts[1]')

echo "$fqdn = forgejo-e2e.apps.lab-cloudscale-rma-0.appuio.cloud"
echo "$fqdn_sub = sub1.forgejo-e2e.apps.lab-cloudscale-rma-0.appuio.cloud"
[[ "$fqdn" == "forgejo-e2e.apps.lab-cloudscale-rma-0.appuio.cloud" ]]
[[ "$fqdn_sub" == "sub1.forgejo-e2e.apps.lab-cloudscale-rma-0.appuio.cloud" ]]
