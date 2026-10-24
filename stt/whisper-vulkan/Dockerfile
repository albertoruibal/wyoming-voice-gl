FROM debian:trixie-slim@sha256:d7e12182ce18b85b93007c1dedf31f2d29e01ccf3182cc4017c709b6259bc132 AS builder

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates git build-essential cmake curl \
        python3 python3-pip python3-venv \
        libvulkan-dev vulkan-tools mesa-vulkan-drivers glslc spirv-headers \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/whisper.cpp
RUN git clone https://github.com/ggml-org/whisper.cpp.git . \
    && git checkout 231638a0717b7822784297e5980965ffcec05810

RUN git clean -xdf \
    && cmake -B build -DGGML_VULKAN=1 \
    && cmake --build build -j --config Release

WORKDIR /tmp/libs
RUN find /opt/whisper.cpp/build \( -name "libwhisper*" -o -name "libggml*" \) -exec cp -a {} /tmp/libs/ \; \
    && ls -la /tmp/libs/

WORKDIR /opt/wyoming-whisper-api-client
RUN git clone https://github.com/ser/wyoming-whisper-api-client.git . \
    && git checkout 4a5de75634d42cda75a67303f85ad99c9489995d \
    && script/setup \
    && .venv/bin/pip install --no-deps .

FROM debian:trixie-slim@sha256:d7e12182ce18b85b93007c1dedf31f2d29e01ccf3182cc4017c709b6259bc132 AS runtime

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash ca-certificates libstdc++6 libgcc-s1 libatomic1 libgomp1 \
        vulkan-tools mesa-vulkan-drivers python3 passwd \
    && groupadd --gid 1000 whisper \
    && useradd --uid 1000 --gid 1000 --create-home --shell /usr/sbin/nologin whisper \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/wyoming-whisper-api-client
COPY --from=builder /opt/wyoming-whisper-api-client/.venv .venv
COPY --from=builder /opt/whisper.cpp/build/bin /usr/bin
COPY --from=builder /tmp/libs/ /usr/local/lib/
RUN ldconfig

COPY run.sh /opt/wyoming-whisper-vulkan-service/run.sh
RUN chmod 0755 /opt/wyoming-whisper-vulkan-service/run.sh
WORKDIR /opt/wyoming-whisper-vulkan-service

ENV HOME=/home/whisper
USER 1000:1000

EXPOSE 10300
ENTRYPOINT ["/opt/wyoming-whisper-vulkan-service/run.sh"]
