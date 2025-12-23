###############################################################################
# Stage 0 — CUDA-enabled development base
# This replaces NVIDIA's cuda:<version>-devel images for dev builds.
###############################################################################
FROM ubuntu:22.04 AS cuda-dev-base

# Non-interactive apt + NVIDIA environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVARCH=x86_64
ENV CUDA_VERSION=12.4.1
ENV PYTORCH_VERSION=2.6.0

# Core development tools
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
        build-essential \
        gnupg2 \
        curl \
        ca-certificates \
        wget \
        software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# Add NVIDIA CUDA repo key
RUN curl -fsSL https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/${NVARCH}/cuda-keyring_1.1-1_all.deb \
     -o cuda-keyring.deb \
 && dpkg -i cuda-keyring.deb \
 && rm cuda-keyring.deb

# NVIDIA repo pinning (recommended)
RUN wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/${NVARCH}/cuda-ubuntu2204.pin \
    && mv cuda-ubuntu2204.pin /etc/apt/preferences.d/cuda-repository-pin-600

# CUDA 12.4 toolkit + libraries
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
        cuda-cudart-12-4 \
        cuda-compiler-12-4 \
        cuda-libraries-12-4 \
        cuda-libraries-dev-12-4 \
        cuda-compat-12-4 \
    && rm -rf /var/lib/apt/lists/*

# Other dev helpers
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
        cmake \
        git \
    && rm -rf /var/lib/apt/lists/*

# CUDA environment setup
ENV CUDA_HOME="/usr/local/cuda"
ENV PATH="${CUDA_HOME}/bin:${PATH}"
#ENV LD_LIBRARY_PATH="${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}"

###############################################################################
# Stage 1 — dev-base (now built on top of your cuda-dev-base)
# Adds PyTorch build prerequisites, ccache, image libs, etc.
###############################################################################
FROM cuda-dev-base AS dev-base

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ccache \
        libjpeg-dev \
        libpng-dev \
    && rm -rf /var/lib/apt/lists/*

RUN /usr/sbin/update-ccache-symlinks
RUN mkdir /opt/ccache && ccache --set-config=cache_dir=/opt/ccache

ENV PATH=/opt/conda/bin:$PATH

###############################################################################
# Stage 2 — Conda install (unchanged)
###############################################################################
FROM dev-base AS conda
ARG PYTHON_VERSION=3.11
ARG TARGETPLATFORM

RUN case ${TARGETPLATFORM} in \
         "linux/arm64") MINICONDA_ARCH=aarch64 ;; \
         *)             MINICONDA_ARCH=x86_64 ;; \
    esac \
    && curl -fsSL -o ~/miniconda.sh \
       "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-${MINICONDA_ARCH}.sh"

COPY requirements.txt requirements-build.txt ./

RUN chmod +x ~/miniconda.sh \
    && bash ~/miniconda.sh -b -p /opt/conda \
    && rm ~/miniconda.sh \
    && /opt/conda/bin/conda install -y \
         python=${PYTHON_VERSION} \
         cmake conda-build pyyaml numpy ipython \
    && /opt/conda/bin/python -m pip install -r requirements.txt \
    && /opt/conda/bin/conda clean -ya

###############################################################################
# Stage 3 — Fetch submodules
###############################################################################
FROM dev-base AS submodule-update
ARG PYTORCH_VERSION
RUN git clone https://github.com/pytorch/pytorch.git /opt/pytorch && \
    cd /opt/pytorch && \
    git fetch origin v${PYTORCH_VERSION} && \
    git checkout FETCH_HEAD
WORKDIR /opt/pytorch
RUN git submodule update --init --recursive

###############################################################################
# Stage 4 — Install PyTorch from wheels into Conda
###############################################################################
FROM conda AS conda-installs
ARG CONDA_VERSION=25.7.0
ARG CUDA_PATH=cu124
ARG INSTALL_CHANNEL=whl
ARG CUDA_VERSION
ARG TARGETPLATFORM

RUN /opt/conda/bin/conda install -y python=${PYTHON_VERSION} conda=${CONDA_VERSION}

RUN case ${TARGETPLATFORM} in \
         "linux/arm64") \
             pip install --extra-index-url https://download.pytorch.org/whl/cpu/ \
                 "torch==${PYTORCH_VERSION}" torchvision torchaudio ;; \
         *) \
             pip install --index-url https://download.pytorch.org/${INSTALL_CHANNEL}/${CUDA_PATH#.}/ \
                 "torch==${PYTORCH_VERSION}" torchvision torchaudio ;; \
    esac \
    && /opt/conda/bin/conda clean -ya

RUN /opt/conda/bin/pip install torchelastic

RUN IS_CUDA=$(python -c "import torch; print(torch.cuda._is_compiled())"); \
    echo "CUDA Enabled: $IS_CUDA"; \
    if [ "$IS_CUDA" != "True" ] && [ -n "${CUDA_VERSION}" ]; then exit 1; fi

###############################################################################
# Stage 5 — Official Runtime image (remains Ubuntu-only)
###############################################################################
FROM conda-installs AS official
ARG PYTORCH_VERSION
ARG TRITON_VERSION
ARG TARGETPLATFORM
ARG CUDA_VERSION

LABEL com.nvidia.volumes.needed="nvidia_driver"

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates libjpeg-dev libpng-dev \
    && rm -rf /var/lib/apt/lists/*

RUN if [ -n "${TRITON_VERSION}" ] && [ "${TARGETPLATFORM}" != "linux/arm64" ]; then \
        apt-get update && apt-get install -y gcc; \
        rm -rf /var/lib/apt/lists/*; \
    fi

ENV LD_LIBRARY_PATH=/usr/local/nvidia/lib:/usr/local/nvidia/lib64:${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}
ENV PATH=/usr/local/nvidia/bin:/usr/local/cuda/bin:$PATH
ENV PYTORCH_VERSION=${PYTORCH_VERSION}

WORKDIR /workspace

###############################################################################
# Stage 6 — Dev image (inherits CUDA 12.4 from your base)
###############################################################################
FROM official AS dev

COPY --from=conda /opt/conda /opt/conda
COPY --from=submodule-update /opt/pytorch /opt/pytorch

###############################################################################
# Stage 7 — ComfyUI image
###############################################################################

FROM dev
# This image is based on the latest official PyTorch image, because it already contains CUDA, CuDNN, and PyTorch
#ARG PYTORCH_VERSION=2.9.1-cuda13.0-cudnn9-devel
#FROM pytorch/pytorch:${PYTORCH_VERSION}

# Defines the versions of ComfyUI, ComfyUI Manager, and PyTorch to use
ARG COMFYUI_VERSION=v0.5.1
#ARG COMFYUI_MANAGER_VERSION=3.35
# number of CPU's use for compilation
ARG CPUS=10

ENV DEBIAN_FRONTEND=noninteractive PIP_PREFER_BINARY=1

RUN apt update --assume-yes && \
    apt install --assume-yes \
        git \
        sudo \
        build-essential \
        libgl1-mesa-glx \
        libglib2.0-0 \
        libsm6 \
        libxext6 \
        autoconf \
        automake \
        cmake \
        git-core \
        libass-dev \
        libfreetype6-dev \
        libgnutls28-dev \
        libmp3lame-dev \
        libsdl2-dev \
        libtool \
        libva-dev \
        libvdpau-dev \
        libvorbis-dev \
        libxcb1-dev \
        libxcb-shm0-dev \
        libxcb-xfixes0-dev \
        meson \
        ninja-build \
        pkg-config \
        texinfo \
        wget \
        yasm \
        zlib1g-dev \
        nasm \
        libunistring-dev \
        libaom-dev \
        libx265-dev \
        libx264-dev \
        libnuma-dev \
        libfdk-aac-dev \
        libc6 \
        libc6-dev \
        unzip \
        libnuma1 \
#        ffmpeg \
    && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Clones the ComfyUI repository and checks out the latest release
RUN git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git /opt/comfyui && \
    cd /opt/comfyui && \
    git fetch origin ${COMFYUI_VERSION} && \
    git checkout FETCH_HEAD

# Clones the ComfyUI Manager repository and checks out the latest release; ComfyUI Manager is an extension for ComfyUI that enables users to install
# custom nodes and download models directly from the ComfyUI interface; instead of installing it to "/opt/comfyui/custom_nodes/ComfyUI-Manager", which
# is the directory it is meant to be installed in, it is installed to its own directory; the entrypoint will symlink the directory to the correct
# location upon startup; the reason for this is that the ComfyUI Manager must be installed in the same directory that it installs custom nodes to, but
# this directory is mounted as a volume, so that the custom nodes are not installed inside of the container and are not lost when the container is
# removed; this way, the custom nodes are installed on the host machine
RUN git clone --depth=1 https://github.com/Comfy-Org/ComfyUI-Manager.git /opt/comfyui-manager && \
    cd /opt/comfyui-manager
#    cd /opt/comfyui-manager && \
#    git fetch origin ${COMFYUI_MANAGER_VERSION} && \
#    git checkout FETCH_HEAD

# Installs the required Python packages for both ComfyUI and the ComfyUI Manager
RUN pip install \
    --requirement /opt/comfyui/requirements.txt \
    --requirement /opt/comfyui-manager/requirements.txt

RUN pip install --no-cache-dir \
    opencv-python \
    opencv-contrib-python \
    diffusers \
    triton \
    torchsde \
    nvidia-ml-py \
    sageattention \
    packaging \
    ninja  \
    compel  \
    psutil \
    nvitop

ENV TORCH_CUDA_ARCH_LIST="8.0;8.6;8.9;9.0"

# PyTorch include/lib for ABI correctness
ENV CFLAGS="-I/opt/conda/lib/python3.11/site-packages/torch/include \
            -I/opt/conda/lib/python3.11/site-packages/torch/include/torch/csrc/api/include \
            -I/opt/conda/lib/python3.11/site-packages/torch/include/TH \
            -I/opt/conda/lib/python3.11/site-packages/torch/include/THC"

ENV CXXFLAGS="${CFLAGS}"
ENV LDFLAGS="-L/opt/conda/lib/python3.11/site-packages/torch/lib"

# NVCC compatibility flags for CUDA 12.4 + GCC 11 (Ubuntu 22.04)
ENV NVCCFLAGS="--threads=4 -Xcompiler -Wno-float-conversion"

# install flash-attention
ARG FLASH_ATTENTION_VERSION=2.5.9.post1
ARG GPU_ARCHS=native
ARG MAX_JOBS=4
RUN GPU_ARCHS=${GPU_ARCHS} MAX_JOBS=${MAX_JOBS} pip install --no-cache-dir --no-build-isolation \
    "flash-attn==${FLASH_ATTENTION_VERSION}" --verbose

# install ffmpeg-nvidia adapter
RUN mkdir ~/nv && cd ~/nv && \
  git clone https://github.com/FFmpeg/nv-codec-headers.git && \
  cd nv-codec-headers && make install

# compile ffmpeg with cuda
RUN cd ~/nv && \
  git clone https://git.ffmpeg.org/ffmpeg.git ffmpeg/ && \
  cd ffmpeg && \
  ./configure \
    --enable-nonfree \
    --enable-nvenc \
    --enable-cuda \
    --enable-cuda-nvcc \
    --enable-cuvid \
    --extra-cflags=-I/usr/local/cuda/include \
    --extra-ldflags=-L/usr/local/cuda/lib64 \
    --disable-static \
    --enable-gpl \
    --enable-gnutls \
    --enable-shared  \
    --enable-libaom \
    --enable-libass \
    --enable-libfdk-aac \
    --enable-libfreetype \
    --enable-libmp3lame \
    --enable-libvorbis \
    --enable-libx264 \
    --enable-libx265 \
#    --enable-libnpp \ # ERROR: libnpp support is deprecated, version 13.0 and up are not supported \
#    --enable-libopus \ # not found : install ?
#    --enable-libvpx \
    && \
  make -j $CPUS && \
  make install

# Pre-install previously used custom nodes requirements from volume
COPY ./install/merged-requirements.txt* /docker/requirements.txt
RUN sh -c '[ -f /docker/requirements.txt ] && pip install --no-cache-dir -r /docker/requirements.txt  \
    || echo "merged-requirements.txt not found, skipping pre-install."'

# Sets the working directory to the ComfyUI directory
WORKDIR /opt/comfyui
COPY . /docker/
RUN chmod u+x /docker/entrypoint.sh && cp /docker/extra_model_paths.yaml /opt/comfyui

ENV PYTHONPATH="\${PYTHONPATH}:\${PWD}" CLI_ARGS=""
EXPOSE 7861

# Adds the startup script to the container; the startup script will create all necessary directories in the models and custom nodes volumes that were
# mounted to the container and symlink the ComfyUI Manager to the correct directory; it will also create a user with the same UID and GID as the user
# that started the container, so that the files created by the container are owned by the user that started the container and not the root user
ENTRYPOINT ["/bin/bash", "/docker/entrypoint.sh"]

# On startup, ComfyUI is started at its default port; the IP address is changed from localhost to 0.0.0.0, because Docker is only forwarding traffic
# to the IP address it assigns to the container, which is unknown at build time; listening to 0.0.0.0 means that ComfyUI listens to all incoming
# traffic; the auto-launch feature is disabled, because we do not want (nor is it possible) to open a browser window in a Docker container
CMD ["/opt/conda/bin/python", "main.py", "--listen", "0.0.0.0", "--port", "7861", "--disable-auto-launch"]
