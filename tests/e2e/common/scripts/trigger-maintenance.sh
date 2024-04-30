#!/bin/bash

set -e

type="$1"
name="$2"
to_be_found="$3"

ns=$(kubectl -n "$NAMESPACE" get "$type" "$name" -oyaml | yq -r '.status.instanceNamespace')

kubectl -n "$ns" delete job --ignore-not-found=true --now=true vacuum databasesrepack
kubectl -n "$ns" create job --from cronjob/maintenancejob test

# wait until job is done
kubectl -n "$ns" wait --for=condition=complete --timeout=240s job/test

if [ "$to_be_found" == "r" ]; then
  kubectl -n "$ns" get job
  kubectl -n "$ns" get job databasesrepack
elif [ "$to_be_found" == "v" ]; then
  kubectl -n "$ns" get job
  kubectl -n "$ns" get job vacuum
elif [ "$to_be_found" == "b" ]; then
  kubectl -n "$ns" get job
  kubectl -n "$ns" get job databasesrepack
  kubectl -n "$ns" get job vacuum
else
  echo "Invalid argument"
  exit 1
fi
