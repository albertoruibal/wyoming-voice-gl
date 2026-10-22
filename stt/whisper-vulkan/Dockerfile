ARG WHISPER_MODEL=large-v3-turbo

FROM registry.fedoraproject.org/fedora:latest AS builder

RUN dnf -y --nodocs install \
        git python3-pip bash cmake g++ \
        vulkan-loader-devel vulkaninfo mesa-vulkan-drivers glslc spirv-headers-devel \
    && dnf clean all && rm -rf /var/cache/dnf/*

WORKDIR /opt/whisper.cpp
RUN git clone https://github.com/ggml-org/whisper.cpp.git .

RUN git clean -xdf \
    && cmake -B build -DGGML_VULKAN=1 \
    && cmake --build build -j --config Release

ARG WHISPER_MODEL
RUN models/download-ggml-model.sh ${WHISPER_MODEL}

WORKDIR /tmp/libs
RUN find /opt/whisper.cpp/build \( -name "libwhisper*" -o -name "libggml*" \) -exec cp -a {} /tmp/libs/ \; \
    && ls -la /tmp/libs/

WORKDIR /opt/wyoming-whisper-api-client
RUN git clone https://github.com/ser/wyoming-whisper-api-client.git . \
    && script/setup \
    && .venv/bin/pip install --no-deps .

FROM registry.fedoraproject.org/fedora-minimal:latest AS runtime

RUN microdnf -y --nodocs --setopt=install_weak_deps=0 install \
        bash ncurses ca-certificates libstdc++ libgcc libatomic libgomp \
        vulkan-loader vulkaninfo mesa-vulkan-drivers python3 \
    && microdnf clean all && rm -rf /var/cache/dnf/*

ARG WHISPER_MODEL
WORKDIR /opt/whisper.cpp/models
COPY --from=builder /opt/whisper.cpp/models/ggml-${WHISPER_MODEL}.bin .

WORKDIR /opt/wyoming-whisper-api-client
COPY --from=builder /opt/wyoming-whisper-api-client/.venv .venv
COPY --from=builder /opt/whisper.cpp/build/bin /usr/bin
COPY --from=builder /tmp/libs/ /usr/lib64/

COPY run.sh /opt/wyoming-whisper-vulkan-service/run.sh
RUN chmod 0755 /opt/wyoming-whisper-vulkan-service/run.sh
WORKDIR /opt/wyoming-whisper-vulkan-service

EXPOSE 10300
ENTRYPOINT ["/opt/wyoming-whisper-vulkan-service/run.sh"]