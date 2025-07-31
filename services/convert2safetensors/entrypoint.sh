#!/bin/bash
set -ex

echo "Running container as $USER"
python convert_2_safetensors.py --source ./models/input --dest ./models/output --allow-pickle
