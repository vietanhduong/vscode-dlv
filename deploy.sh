#!/usr/bin/env bash
set -e

wait_pod_ready() {
  pod=$1
  if [[ -z "$pod" ]]; then
    echo "pod name is empty" >&2
    return 1
  fi

  until [[ "$(kubectl get pod $pod -ojsonpath='{.status.phase}')" = "Running" ]]; do
    echo "Waiting for pod $pod to become ready..." && sleep 1
  done
}

check_cmd() {
  cmd=$1
  if [[ -z "$cmd" ]]; then
    echo "check command is empty" >&2 && return 1
  fi

  if ! command -v $cmd &>/dev/null; then
    echo "command not found: $cmd" >&2 && return 1
  fi
  return 0
}

image_loaded() {
  image=$1
  if [[ -z "$image" ]]; then
    echo "check image is empty" >&2
  fi

  result="$(minikube image ls | grep "$image" || echo "ERR_NF")"
  [[ "$result" = "ERR_NF" ]] && return 1 || return 0
}

check_cmd "minikube" || exit 1
check_cmd "docker" || exit 1
check_cmd "kubectl" || exit 1

TP=""
if check_cmd "telepresence"; then
  check_cmd "jq" || exit 1
  TP="telepresence"
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"

BASE_IMAGE=remote-debug
if ! image_loaded "$BASE_IMAGE" || [[ "$FORCE_REBUILD" = "1" ]]; then
  docker build -t $BASE_IMAGE -f $REPO_ROOT/Dockerfile . &&
    minikube image load $BASE_IMAGE &&
    echo "Loaded image $BASE_IMAGE to minikube registry"
else
  echo "The base image already exists, skip to re-build"
fi

GOARCH=amd64 GOOS=linux go build -gcflags="all=-N -l" \
  -o $REPO_ROOT/.bin/app $REPO_ROOT

# Must be mapped with the pod yaml spec
TARGET_PORT=40000
POD_NAME=remote-debug

# If Telepresence is not available, we will use port-forwarding instead.
# Therefore, we need to terminate the currently running port before
# initiating port-forwarding again.
if [[ -z "$TP" ]] && lsof -t -i:$TARGET_PORT; then
  kill $(lsof -t -i:$TARGET_PORT) || true
fi

# We need to shutdown the dlv pod first. Because, if the application binary
# is being used, the copy command below will be failed.
kubectl delete pod $POD_NAME 2>/dev/null || true

# WARN: Must be mapped with the pod yaml spec
minikube cp $REPO_ROOT/.bin/app /tmp/app &&
  minikube ssh "sudo chmod +x /tmp/app"

kubectl apply -f $REPO_ROOT/dlv-pod.yaml

wait_pod_ready "$POD_NAME" || exit 1

if [[ -n "$TP" ]]; then
  namespace="$(kubectl get pod $POD_NAME -ojsonpath='{.metadata.namespace}')"
  status="$($TP status --output=json | jq -r ".user_daemon.status")"
  if [[ ! "$status" = "Connected" ]]; then
    echo "$TP has not connected yet; please connect the $TP first" >&2
    exit 1
  fi
  echo "Please connect to go-dlv using the address ${POD_NAME}.${namespace}:${TARGET_PORT}"
else
  kubectl port-forward cooper-agent 40000 &
  echo "Please connect to go-dlv using address localhost:$TARGET_PORT"
fi
