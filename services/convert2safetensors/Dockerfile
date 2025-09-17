ARG PYTORCH_VERSION=2.7.1-cuda12.8-cudnn9-runtime
FROM pytorch/pytorch:${PYTORCH_VERSION}

ENV DEBIAN_FRONTEND=noninteractive PIP_PREFER_BINARY=1

RUN apt update --assume-yes && \
#    apt install --assume-yes \
#        git \
#        sudo \
#        build-essential \
#        libgl1-mesa-glx \
#        libglib2.0-0 \
#        libsm6 \
#        libxext6 \
#        ffmpeg && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /opt/convert2safetensors
COPY . /opt/convert2safetensors/
RUN chmod u+x /opt/convert2safetensors/entrypoint.sh

RUN pip install --requirement /opt/convert2safetensors/requirements.txt

ENV NVIDIA_VISIBLE_DEVICES=all PYTHONPATH="${PYTHONPATH}:${PWD}" CLI_ARGS=""
ENTRYPOINT ["/bin/bash", "/opt/convert2safetensors/entrypoint.sh"]
