#!/bin/bash

set -Eeuo pipefail

# TODO: move all mkdir -p ?
mkdir -p /data/config/neo/scripts/
# mount scripts individually

echo $ROOT
ls -lha $ROOT

find "${ROOT}/scripts/" -maxdepth 1 -type l -delete
cp -vrfTs /data/config/neo/scripts/ "${ROOT}/scripts/"

# Set up config file
python /docker/config.py /data/config/neo/config.json

if [ ! -f /data/config/neo/ui-config.json ]; then
  echo '{}' >/data/config/neo/ui-config.json
fi

if [ ! -f /data/config/neo/styles.csv ]; then
  touch /data/config/neo/styles.csv
fi

# copy models from original models folder
mkdir -p /data/models/VAE-approx/ /data/models/karlo/

rsync -a --info=NAME ${ROOT}/models/VAE-approx/ /data/models/VAE-approx/
rsync -a --info=NAME ${ROOT}/models/karlo/ /data/models/karlo/

declare -A MOUNTS

MOUNTS["${USER_HOME}/.cache"]="/data/.cache"
MOUNTS["${ROOT}/models"]="/data/models"

MOUNTS["${ROOT}/embeddings"]="/data/embeddings"
MOUNTS["${ROOT}/config.json"]="/data/config/neo/config.json"
MOUNTS["${ROOT}/ui-config.json"]="/data/config/neo/ui-config.json"
MOUNTS["${ROOT}/styles.csv"]="/data/config/neo/styles.csv"
MOUNTS["${ROOT}/extensions"]="/data/config/neo/extensions"
MOUNTS["${ROOT}/config_states"]="/data/config/neo/config_states"

MOUNTS["${ROOT}/outputs"]="/output"
MOUNTS["${ROOT}/output"]="/output"

# extra hacks
MOUNTS["${ROOT}/repositories/CodeFormer/weights/facelib"]="/data/.cache"

for to_path in "${!MOUNTS[@]}"; do
  set -Eeuo pipefail
  from_path="${MOUNTS[${to_path}]}"
  rm -rf "${to_path}"
  if [ ! -f "$from_path" ]; then
    mkdir -vp "$from_path"
  fi
  mkdir -vp "$(dirname "${to_path}")"
  ln -sT "${from_path}" "${to_path}"
  echo Mounted $(basename "${from_path}")
done

chown -R $PUID:$PGID ~/.cache/
chmod 766 ~/.cache/
chown -R $PUID:$PGID /output
chmod 766 /output

echo "Installing extension dependencies (if any)"

shopt -s nullglob
# For install.py, please refer to https://github.com/AUTOMATIC1111/stable-diffusion-webui/wiki/Developing-extensions#installpy
list=(./extensions/*/install.py)
for installscript in "${list[@]}"; do
  EXTNAME=$(echo $installscript | cut -d '/' -f 3)
  # Skip installing dependencies if extension is disabled in config
  if $(jq -e ".disabled_extensions|any(. == \"$EXTNAME\")" config.json); then
    echo "Skipping disabled extension ($EXTNAME)"
    continue
  fi
  PYTHONPATH=${ROOT} python "$installscript"
done

if [ -f "/data/config/neo/startup.sh" ]; then
  pushd ${ROOT}
  echo "Running startup script"
  . /data/config/neo/startup.sh
  popd
fi

exec "$@"
