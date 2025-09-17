FROM pytorch/pytorch:2.7.1-cuda12.8-cudnn9-runtime

ENV DEBIAN_FRONTEND=noninteractive PIP_PREFER_BINARY=1

RUN apt-get update && apt-get install -y git libgoogle-perftools-dev && apt-get clean

ARG PUID=0
ARG PGID=0
ARG USER_HOME=/root
# set build args as container environment variables for entrypoint reference
ENV PUID=$PUID
ENV PGID=$PGID
ENV USER_HOME=$USER_HOME

# if user home does not exist, create it
RUN mkdir -p "$USER_HOME"

# home already exists, chown it
RUN chown -R "${PUID}:${PGID}" "$USER_HOME"

# Only groupadd if we're non root
RUN if [ "$PGID" -ne "0" ]; then \
      echo non root group detected; \
      groupadd \
        --gid "$PGID" \
        stablediffusion ;\
    else \
      echo "root group detected" ; \
    fi

# Only useradd if we're non root
RUN if [ "$PUID" -ne "0" ]; then \
      echo non root user detected; \
      useradd \
        --gid="$PGID" \
        --no-user-group \
        -M \
        --home "$USER_HOME" \
        stablediffusion ; \
    else \
      echo "root group detected" ; \
    fi

USER $PUID:$PGID

ENV ROOT=/stable-diffusion
RUN --mount=type=cache,target="$USER_HOME"/.cache/pip \
  git clone -b v0.3.57 --depth=1 https://github.com/comfyanonymous/ComfyUI.git ${ROOT} && \
  pip install -r ${ROOT}/requirements.txt

RUN git clone -b 3.35 --depth=1  https://github.com/ltdrdata/ComfyUI-Manager ${ROOT}/custom_nodes/comfyui-manager && \
  pip install -r ${ROOT}/custom_nodes/comfyui-manager/requirements.txt

RUN chown -R "$PUID:$PGID" "${ROOT}"

WORKDIR ${ROOT}
COPY --chown=$PUID:$PGID . /docker
RUN chmod u+x /docker/entrypoint.sh && cp /docker/extra_model_paths.yaml ${ROOT}

ENV NVIDIA_VISIBLE_DEVICES=all PYTHONPATH="${PYTHONPATH}:${PWD}" CLI_ARGS=""
EXPOSE 7860
ENTRYPOINT ["/docker/entrypoint.sh"]
#CMD python -u main.py --listen --port 7860 ${CLI_ARGS}
CMD sh -c "python3 -c 'import os; print(f\"Running as UID={os.getuid()}, GID={os.getgid()}\")' && python -u main.py --listen --port 7860 ${CLI_ARGS}"

