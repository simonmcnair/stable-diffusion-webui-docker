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

if [ -d "${ROOT}/comfyui-manager" ]; then
  manager_exists=false
  shopt -s nullglob
  for dir in "${ROOT}/custom_nodes"/*; do
    dirname=$(basename "$dir")
    if [[ "${dirname,,}" == "comfyui-manager" ]]; then
      manager_exists=true
      break
    fi
  done
  shopt -u nullglob

  if [ "$manager_exists" = false ]; then
    echo "Initializing ComfyUI-Manager..."

    # Determine Manager Config Directory (New vs Old ComfyUI structure)
    MANAGER_CONFIG_DIR="__manager"
    if ! grep -q "get_system_user_directory" "${ROOT}/folder_paths.py"; then
        MANAGER_CONFIG_DIR="default/ComfyUI-Manager"
    fi

    # Ensure User Config Directory exists and copy override file
    USER_CONFIG_PATH="/data/config/comfy/user/${MANAGER_CONFIG_DIR}"
    mkdir -vp "${USER_CONFIG_PATH}"
    cp "${ROOT}/comfyui-manager/pip_overrides.json.template" "${USER_CONFIG_PATH}/pip_overrides.json"

    echo "################################################################################"
    echo "#                                                                              #"
    echo "#  NOTICE: INITIALIZING COMFYUI-MANAGER WITH HEADLESS OPENCV OVERRIDES         #"
    echo "#                                                                              #"
    echo "#  pip_overrides.json is being copied to your user configuration directory:    #"
    echo "#  ${USER_CONFIG_PATH}/"
    echo "#                                                                              #"
    echo "#  This forces the installation of opencv-contrib-python-headless instead      #"
    echo "#  of the standard opencv-python to prevent system library crashes (libGL).    #"
    echo "#                                                                              #"
    echo "################################################################################"

    # Debug: List contents to see why it wasn't found (optional, can be removed later)
    ls -la "${ROOT}/custom_nodes" || true
    cp -r "${ROOT}/comfyui-manager" "${ROOT}/custom_nodes/comfyui-manager"
  else
    echo "ComfyUI-Manager detected in custom_nodes, skipping initialization."
  fi
fi

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
