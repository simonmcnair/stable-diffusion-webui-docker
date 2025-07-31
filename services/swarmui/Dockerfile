ARG SWARMUI_VERSION=0.9.6-Beta
ARG DOTNET_VERSION=8.0-bookworm-slim

FROM mcr.microsoft.com/dotnet/sdk:${DOTNET_VERSION} AS build
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1
ENV SWARM_PATH="/SwarmUI"
#ENV SWARM_PATH=/opt/swarmui

RUN --mount=type=cache,target=/var/cache/apt \
    apt-get update && \
    apt-get install -y git

WORKDIR ${SWARM_PATH}

# Clones the SwarmUI repository and checks out the latest release
RUN git clone --depth=1 https://github.com/mcmonkeyprojects/SwarmUI.git ${SWARM_PATH} && \
    cd ${SWARM_PATH} && \
    git fetch origin ${SWARMUI_VERSION} && \
    git checkout FETCH_HEAD

RUN dotnet build src/SwarmUI.csproj --configuration Release -o ./bin

# RUN
FROM mcr.microsoft.com/dotnet/aspnet:8.0-bookworm-slim
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1
ENV SWARM_PATH="/SwarmUI"
#ENV SWARM_PATH=/opt/swarmui
ARG SWARMUI_USER_ID=1000
ARG SWARMUI_GROUP_ID=1000

ARG GPU_TYPE="nv"
ENV NVIDIA_VISIBLE_DEVICES=all
ENV CLI_ARGS=""

RUN addgroup --gid $SWARMUI_GROUP_ID swarmui && \
    adduser --uid $SWARMUI_USER_ID --gid $SWARMUI_GROUP_ID --gecos "" --disabled-password swarmui

COPY --from=build ${SWARM_PATH} "${SWARM_PATH}/"

RUN mkdir -p "${SWARM_PATH}/Data" && \
    chown -R swarmui:swarmui ${SWARM_PATH}
ENV HOME=${SWARM_PATH}

RUN --mount=type=cache,target=/var/cache/apt \
    apt update --assume-yes && \
    apt install -y \
        git \
        wget \
        build-essential \
        python3.11 \
        python3.11-venv \
        python3.11-dev \
        python3-pip \
        ffmpeg  \
        libglib2.0-0 \
        libgl1

WORKDIR ${SWARM_PATH}

USER swarmui

RUN chmod +x ${SWARM_PATH}/launchtools/comfy-install-linux.sh && \
    ${SWARM_PATH}/launchtools/comfy-install-linux.sh ${GPU_TYPE}

EXPOSE 7801

COPY entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh", "--launch_mode", "none", "--host", "0.0.0.0"]
