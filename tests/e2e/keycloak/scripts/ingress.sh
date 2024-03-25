#!/bin/bash

set -e

ns=$(kubectl -n "$NAMESPACE" get vshnkeycloak keycloak-e2e -ojson | jq -r '.status.instanceNamespace')

fqdn=$(kubectl -n "$ns" get ingress -ojson | jq -r '.items.[0].spec.tls.[0].hosts[0]')

echo "$fqdn = keycloak-e2e.example.com"
[[ "$fqdn" == "keycloak-e2e.example.com" ]]
