#!/bin/bash
set -e

name=$(kubectl -n $NAMESPACE get vshnkeycloak keycloak-e2e -o jsonpath='{.spec.resourceRef.name}')
sts="${name}-keycloakx"
ns=$(kubectl -n "$NAMESPACE" get vshnkeycloak keycloak-e2e -o yaml | yq -r '.status.instanceNamespace')

kubectl get statefulset $sts -n "$ns" \
  -o jsonpath='{.spec.template.spec.volumes[*].configMap.name}' | grep test-cm

kubectl get statefulset $sts -n "$ns" \
  -o jsonpath='{.spec.template.spec.volumes[*].secret.secretName}' | grep test-secret

kubectl get statefulset $sts -n "$ns" \
  -o jsonpath='{.spec.template.spec.containers[0].volumeMounts[*].mountPath}' | grep /custom/configs/test-cm

kubectl get statefulset $sts -n "$ns" \
  -o jsonpath='{.spec.template.spec.containers[0].volumeMounts[*].mountPath}' | grep /custom/secrets/test-secret

pod="${sts}-0"
kubectl -n "$ns" exec "$pod" -- test -d /custom/configs/test-cm
kubectl -n "$ns" exec "$pod" -- test -d /custom/secrets/test-secret
