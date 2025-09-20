#!/bin/bash

set -Eeuo pipefail

mkdir -vp /data/config/comfy/custom_nodes
mkdir -vp /data/config/comfy/user/default/workflows

declare -A MOUNTS

MOUNTS["${ROOT}/models"]="/data/models"
MOUNTS["${USER_HOME}/.cache"]="/data/.cache"

MOUNTS["${ROOT}/input"]="/data/config/comfy/input"
MOUNTS["${ROOT}/output"]="/output/comfy"

MOUNTS["${ROOT}/custom_nodes"]="/data/config/comfy/custom_nodes"
MOUNTS["${ROOT}/user"]="/data/config/comfy/user"

for to_path in "${!MOUNTS[@]}"; do
  from_path="${MOUNTS[${to_path}]}"
  rm -rf "${to_path}"
  if [ ! -f "$from_path" ]; then
    mkdir -vp "$from_path"
  fi
  mkdir -vp "$(dirname "${to_path}")"
  ln -sT "${from_path}" "${to_path}"
  echo Mounted $(basename "${from_path}")
done

if [ -f "/data/config/comfy/startup.sh" ]; then
  pushd ${ROOT}
  . /data/config/comfy/startup.sh
  popd
fi

# Only chown if not running as root (UID != 0)
if [ "$(id -u)" -ne 0 ]; then
  chown -R "$(id -u):$(id -g)" ~ 2>/dev/null || true
fi

chown -R $PUID:$PGID ~/.cache/
chmod 776 ~/.cache/

exec "$@"
