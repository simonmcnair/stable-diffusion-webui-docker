ARG PYTORCH_VERSION=2.9.1-cuda13.0-cudnn9-devel
FROM pytorch/pytorch:${PYTORCH_VERSION} AS build

ARG COMFYUI_VERSION=v0.9.2
ENV DEBIAN_FRONTEND=noninteractive PIP_PREFER_BINARY=1
RUN python --version

RUN apt update && apt install -y \
    build-essential \
    git \
    git-core \
    autoconf \
    automake \
    cmake \
    libtool \
    meson \
    ninja-build \
    pkg-config \
    texinfo \
    yasm \
    nasm \
    wget \
    unzip \
    \
    # FFmpeg / codec headers
    libass-dev \
    libfreetype6-dev \
    libgnutls28-dev \
    libmp3lame-dev \
    libsdl2-dev \
    libva-dev \
    libvdpau-dev \
    libvorbis-dev \
    libxcb1-dev \
    libxcb-shm0-dev \
    libxcb-xfixes0-dev \
    libaom-dev \
    libx264-dev \
    libx265-dev \
    libfdk-aac-dev \
    libnuma-dev \
    libssl-dev \
    libunistring-dev \
    zlib1g-dev \
    libc6-dev \
    \
    ca-certificates \
    && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# install ffmpeg-nvidia adapter
RUN mkdir ~/nv && cd ~/nv && \
  git clone https://github.com/FFmpeg/nv-codec-headers.git && \
  cd nv-codec-headers && make install

# compile ffmpeg with cuda
ARG CPUS=10
RUN cd ~/nv && \
  git clone https://git.ffmpeg.org/ffmpeg.git ffmpeg/ && \
  cd ffmpeg && \
  ./configure \
    --enable-gpl \
    --enable-nonfree \
    --enable-shared \
    --enable-cuda-nvcc \
    --enable-nvenc \
    --enable-nvdec \
    --enable-cuvid \
    --enable-gpl \
    --enable-gnutls \
    --enable-libaom \
    --enable-libass \
    --enable-libfdk-aac \
    --enable-libfreetype \
    --enable-libmp3lame \
    --enable-libvorbis \
    --enable-libx264 \
    --enable-libx265 \
    --disable-static \
#    --enable-libnpp \ # ERROR: libnpp support is deprecated, version 13.0 and up are not supported \
#    --enable-libopus \ # not found : install ?
#    --enable-libvpx \
    --prefix=/usr/local \
    --extra-cflags="-I/usr/local/cuda/include" \
    --extra-ldflags="-L/usr/local/cuda/lib64" \
    --extra-libs="-lpthread -lm" \
    && \
  make -j $CPUS && \
  make install && ldconfig

# ------------------------------------------------------------
# Setup ComfyUI & Manager
# ------------------------------------------------------------
FROM pytorch/pytorch:${PYTORCH_VERSION}

ENV DEBIAN_FRONTEND=noninteractive PIP_PREFER_BINARY=1
ENV PIP_NO_CACHE_DIR=1

RUN apt update --assume-yes && \
    apt install --assume-yes \
    git \
    wget \
    build-essential \
    ca-certificates \
    sudo \
    # OpenCV runtime
    libgl1-mesa-glx \
    libgl1-mesa-dev \
    libglu1-mesa \
    freeglut3 \
    mesa-utils \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libc6 \
    # FFmpeg runtime libs (NVENC-enabled ffmpeg binary copied in)
    libass9 \
    libfreetype6 \
    libgnutls30 \
    libmp3lame0 \
    libvorbis0a \
    libx264-163 \
    libx265-199 \
    libfdk-aac2 \
    libxv1 \
    libva2 \
    libva-wayland2 \
    libva-x11-2 \
    libaom3 \
    libva-drm2 \
    libvdpau1 \
    # XCB runtime libraries
    libxcb1 \
    libxcb-shape0 \
    libxcb-shm0 \
    libxcb-xfixes0 \
    # audio runtime
    libasound2 \
    libasound2-plugins \
    libsndio7.0 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /usr/local /usr/local

# Version check
RUN python -c "import torch; print('Torch CUDA:', torch.version.cuda); print('CUDA available:', torch.cuda.is_available())"
RUN ldd /usr/local/bin/ffmpeg | grep "not found" && exit 1 || true
RUN ldconfig && ffmpeg -encoders | grep nvenc

RUN pip install --no-cache-dir \
    ffmpy \
    pillow \
    img2texture \
    PyOpenGL \
    PyOpenGL_accelerate \
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
    nvitop \
    https://github.com/mjun0812/flash-attention-prebuild-wheels/releases/download/v0.7.11/flash_attn-2.8.3%2Bcu131torch2.9-cp311-cp311-linux_x86_64.whl

# Clones the ComfyUI repository and checks out the latest release
RUN git clone --depth=1 https://github.com/comfyanonymous/ComfyUI.git /opt/comfyui && \
    cd /opt/comfyui && \
    git fetch origin ${COMFYUI_VERSION} && \
    git checkout FETCH_HEAD

# Clones the ComfyUI Manager repository; ComfyUI Manager is an extension for ComfyUI that enables users to install
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

# Pre-install previously used custom nodes requirements from volume
COPY ./install/merged-requirements.txt* /docker/requirements.txt
RUN sh -c '[ -f /docker/requirements.txt ] && pip install --no-cache-dir -r /docker/requirements.txt  \
    || echo "merged-requirements.txt not found, skipping pre-install."'

# Clean up
RUN rm -rf /root/.cache/pip

# Sets the working directory to the ComfyUI directory
WORKDIR /opt/comfyui
COPY . /docker/
RUN chmod u+x /docker/entrypoint.sh && cp /docker/extra_model_paths.yaml /opt/comfyui

ENV PYTHONPATH="\${PYTHONPATH}:\${PWD}" CLI_ARGS=""
EXPOSE 7861
ARG USER_ID
ARG GROUP_ID
RUN chown -R $USER_ID:$GROUP_ID /opt/conda
RUN chown -R $USER_ID:$GROUP_ID /opt/comfyui \
 && chmod -R u+rwx /opt/comfyui
RUN chown -R $USER_ID:$GROUP_ID /opt/comfyui-manager \
 && chmod -R u+rwx /opt/comfyui-manager
RUN mkdir -p /.cache \
 && chown -R $USER_ID:$GROUP_ID /.cache \
 && chmod -R u+rwx /.cache
RUN mkdir -p /.cache/uv \
 && chown -R $USER_ID:$GROUP_ID /.cache/uv \
 && chmod -R u+rwx /.cache/uv
RUN mkdir -p /.config \
 && chown -R $USER_ID:$GROUP_ID /.config \
 && chmod -R u+rwx /.config
USER $USER_ID

# Adds the startup script to the container; the startup script will create all necessary directories in the models and custom nodes volumes that were
# mounted to the container and symlink the ComfyUI Manager to the correct directory; it will also create a user with the same UID and GID as the user
# that started the container, so that the files created by the container are owned by the user that started the container and not the root user
ENTRYPOINT ["/bin/bash", "/docker/entrypoint.sh"]

# On startup, ComfyUI is started at its default port; the IP address is changed from localhost to 0.0.0.0, because Docker is only forwarding traffic
# to the IP address it assigns to the container, which is unknown at build time; listening to 0.0.0.0 means that ComfyUI listens to all incoming
# traffic; the auto-launch feature is disabled, because we do not want (nor is it possible) to open a browser window in a Docker container
CMD ["/opt/conda/bin/python", "main.py", "--listen", "0.0.0.0", "--port", "7861", "--disable-auto-launch"]
