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
  if [ -e "${to_path}" ] || [ -L "${to_path}" ]; then
    rm -rf "${to_path}"
  fi 
  if [ ! -d "$from_path" ]; then
    mkdir -vp "$from_path"
  fi
  mkdir -vp "$(dirname "${to_path}")"
  ln -sT "${from_path}" "${to_path}"
  echo "Mounted ${from_path} -> ${to_path}"
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

# Fix for "libGL.so.1" error: Ensure only headless OpenCV is installed
# Some custom nodes (like Inspire Pack) install 'opencv-python' via Manager,
# which breaks the headless container. We forcibly remove it on boot.
if pip list | grep -F "opencv-python " > /dev/null; then
    echo "Removing unsupported opencv-python..."
    pip uninstall -y opencv-python || true
fi
pip install opencv-python-headless

exec "$@"
