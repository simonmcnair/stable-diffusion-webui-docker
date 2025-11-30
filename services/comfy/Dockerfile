# Defines the versions of ComfyUI, ComfyUI Manager, and PyTorch to use
ARG COMFYUI_VERSION=v0.3.71
#ARG COMFYUI_MANAGER_VERSION=3.35
ARG PYTORCH_VERSION=2.9.1-cuda13.0-cudnn9-devel
# number of CPU's use for compilation
ARG CPUS=10

# This image is based on the latest official PyTorch image, because it already contains CUDA, CuDNN, and PyTorch
FROM pytorch/pytorch:${PYTORCH_VERSION}

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

RUN pip3 install --no-cache-dir \
    opencv-python \
    diffusers \
    triton \
    torchsde \
    nvidia-ml-py \
    sageattention \
    flash-attention \
    psutil \
    nvitop

# compile ffmpeg
RUN mkdir -p ~/ffmpeg_sources ~/bin && \
  cd ~/ffmpeg_sources && \
  wget -O ffmpeg-snapshot.tar.bz2 https://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2 && \
  tar xjvf ffmpeg-snapshot.tar.bz2 && \
  cd ffmpeg && \
  PATH="$HOME/bin:$PATH" PKG_CONFIG_PATH="$HOME/ffmpeg_build/lib/pkgconfig" ./configure \
    --prefix="$HOME/ffmpeg_build" \
    --pkg-config-flags="--static" \
    --extra-cflags="-I$HOME/ffmpeg_build/include" \
    --extra-ldflags="-L$HOME/ffmpeg_build/lib" \
    --extra-libs="-lpthread -lm" \
    --ld="g++" \
    --bindir="$HOME/bin" \
    --enable-gpl \
    --enable-gnutls \
    --enable-libass \
    --enable-libfdk-aac \
    --enable-libfreetype \
    --enable-libmp3lame \
    --enable-libx264 \
    --enable-libx265 \
    --enable-nonfree && \
  PATH="$HOME/bin:$PATH" make -j $CPUS && \
  make install && \
  hash -r

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

ENV NVIDIA_VISIBLE_DEVICES=all PYTHONPATH="\${PYTHONPATH}:\${PWD}" CLI_ARGS=""
EXPOSE 7861

# Adds the startup script to the container; the startup script will create all necessary directories in the models and custom nodes volumes that were
# mounted to the container and symlink the ComfyUI Manager to the correct directory; it will also create a user with the same UID and GID as the user
# that started the container, so that the files created by the container are owned by the user that started the container and not the root user
ENTRYPOINT ["/bin/bash", "/docker/entrypoint.sh"]

# On startup, ComfyUI is started at its default port; the IP address is changed from localhost to 0.0.0.0, because Docker is only forwarding traffic
# to the IP address it assigns to the container, which is unknown at build time; listening to 0.0.0.0 means that ComfyUI listens to all incoming
# traffic; the auto-launch feature is disabled, because we do not want (nor is it possible) to open a browser window in a Docker container
CMD ["/opt/conda/bin/python", "main.py", "--listen", "0.0.0.0", "--port", "7861", "--disable-auto-launch"]
