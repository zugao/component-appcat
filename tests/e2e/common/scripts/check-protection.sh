#!/bin/bash

set -e

type="$1"
name="$2"

ns=$(kubectl -n "$NAMESPACE" get "$type" "$name" -oyaml | yq -r '.status.instanceNamespace')

if ! kubectl delete ns "$ns" ; then
  echo "namespace protected"
else
  echo "namespace got deleted! Please check deletion protection!"
  false
fi
