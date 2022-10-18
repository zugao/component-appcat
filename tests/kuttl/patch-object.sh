#!/bin/bash

set -eo pipefail
#set -x

user_type=${1}
bucket_type=${2}

user_name=$(kubectl get ${user_type} -o name)
bucket_name=$(kubectl get ${bucket_type} -o name)
kubectl patch -n default --subresource=status --type=merge ${user_name} -p '{"status":{"conditions":[{"type":"Synced","status":"False","reason":"Unavailable","message":"Something is wrong with underlying access user","lastTransitionTime":"2022-09-02T15:06:22Z"}]}}'
kubectl patch -n default --subresource=status --type=merge ${bucket_name} -p '{"status":{"conditions":[{"type":"Ready","status":"False","reason":"Unavailable","message":"Something is wrong with the bucket","lastTransitionTime":"2022-09-02T15:06:22Z"}]}}'
