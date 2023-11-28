#!/usr/bin/env bash

set -e

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

check_cmd "minikube" || exit 1

# Prefered for eBPF
DRIVER=qemu
CRI=containerd
K8S_VERSION=v1.25.10

minikube start \
  --driver=$DRIVER \
  --container-runtime=$CRI \
  --kubernetes-version=$K8S_VERSION
