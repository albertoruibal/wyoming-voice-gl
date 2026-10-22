ARG WHISPER_MODEL=large-v3-turbo

FROM registry.fedoraproject.org/fedora@sha256:4a78eff1423dcce55cf68b8fd66e7cdca61c85978283db3ecc3089a8419fbbc0 AS builder

RUN dnf -y --nodocs install \
        git python3-pip bash cmake g++ \
        vulkan-loader-devel vulkaninfo mesa-vulkan-drivers glslc spirv-headers-devel \
    && dnf clean all && rm -rf /var/cache/dnf/*

WORKDIR /opt/whisper.cpp
RUN git clone https://github.com/ggml-org/whisper.cpp.git . \
    && git checkout 231638a0717b7822784297e5980965ffcec05810

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
    && git checkout 4a5de75634d42cda75a67303f85ad99c9489995d \
    && script/setup \
    && .venv/bin/pip install --no-deps .

FROM registry.fedoraproject.org/fedora-minimal@sha256:1dc6bd367b14f10b205a0b49afcef8e295952a4187190f1672c3074f8117b74d AS runtime

RUN microdnf -y --nodocs --setopt=install_weak_deps=0 install \
        bash ncurses ca-certificates libstdc++ libgcc libatomic libgomp \
        vulkan-loader vulkaninfo mesa-vulkan-drivers python3 shadow-utils \
    && groupadd --gid 1000 whisper \
    && useradd --uid 1000 --gid 1000 --create-home --shell /sbin/nologin whisper \
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

ENV HOME=/home/whisper
USER 1000:1000

EXPOSE 10300
ENTRYPOINT ["/opt/wyoming-whisper-vulkan-service/run.sh"]