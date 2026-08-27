FROM debian:bookworm-slim AS fetcher

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY sources/dependency-versions.sh /work/dependency-versions.sh
COPY sources/fetch-github-sources.sh /work/fetch-github-sources.sh

RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates wget && \
    rm -rf /var/lib/apt/lists/*

RUN chmod +x /work/*.sh && \
    /work/fetch-github-sources.sh /dist \
        curl libxml2 freetype libusb sqlite ffmpeg lvgl postgresql \
        libpeer libsrtp mbedtls laneapp-lvgl \
        opencv mnn mnn-license hyperlpr nanodet-model nanodet-license

FROM debian:trixie-slim

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG PCCT_USE_TUNA_MIRROR=1

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Shanghai \
    CC=aarch64-linux-gnu-gcc \
    CXX=aarch64-linux-gnu-g++ \
    AR=aarch64-linux-gnu-ar \
    AS=aarch64-linux-gnu-as \
    LD=aarch64-linux-gnu-ld \
    NM=aarch64-linux-gnu-nm \
    RANLIB=aarch64-linux-gnu-ranlib \
    STRIP=aarch64-linux-gnu-strip \
    OBJCOPY=aarch64-linux-gnu-objcopy \
    OBJDUMP=aarch64-linux-gnu-objdump \
    PKG_CONFIG_LIBDIR=/usr/lib/aarch64-linux-gnu/pkgconfig:/usr/share/pkgconfig:/usr/lib/pkgconfig

RUN printf '%s\n' \
        'Acquire::Retries "5";' \
        'Acquire::http::Timeout "60";' \
        'Acquire::https::Timeout "60";' \
        'Acquire::http::Pipeline-Depth "0";' \
        > /etc/apt/apt.conf.d/99laneapp-network && \
    rm -f /etc/apt/sources.list.d/debian.sources && \
    if [ "$PCCT_USE_TUNA_MIRROR" = "1" ]; then \
        DEBIAN_MIRROR='http://mirrors.tuna.tsinghua.edu.cn/debian'; \
        DEBIAN_SECURITY_MIRROR='http://mirrors.tuna.tsinghua.edu.cn/debian-security'; \
    else \
        DEBIAN_MIRROR='http://deb.debian.org/debian'; \
        DEBIAN_SECURITY_MIRROR='http://deb.debian.org/debian-security'; \
    fi && \
    printf '%s\n' \
        "deb ${DEBIAN_MIRROR} trixie main" \
        "deb ${DEBIAN_MIRROR} trixie-updates main" \
        "deb ${DEBIAN_SECURITY_MIRROR} trixie-security main" \
        > /etc/apt/sources.list && \
    dpkg --add-architecture arm64 && \
    for attempt in 1 2 3 4 5; do \
        rm -rf /var/lib/apt/lists/*; \
        if apt-get update && \
           apt-get install -y --no-install-recommends --fix-missing \
               autoconf \
               automake \
               binutils-aarch64-linux-gnu \
               gcc \
               g++ \
               ca-certificates \
               file \
               flex \
               bison \
               cmake \
               gcc-aarch64-linux-gnu \
               g++-aarch64-linux-gnu \
               libconfig-dev:arm64 \
               libc6-dev-arm64-cross \
               libjpeg-dev:arm64 \
               libpq-dev:arm64 \
               libudev-dev:arm64 \
               lbzip2 \
               libtool \
               libtool-bin \
               m4 \
               make \
               patch \
               perl \
               pkg-config \
               python3 \
               wget \
               xz-utils \
               zlib1g-dev:arm64; then \
            break; \
        fi; \
        if [ "$attempt" = "5" ]; then \
            exit 1; \
        fi; \
        echo "apt attempt $attempt failed, retrying..." >&2; \
        sleep 10; \
    done && \
    rm -rf /var/lib/apt/lists/*

COPY rebuildcurl.sh /work/rebuildcurl.sh
COPY sources/build-common.sh /work/build-common.sh
COPY sources/build-selected-deps.sh /work/build-selected-deps.sh
COPY sources/dependency-versions.sh /work/dependency-versions.sh
COPY sources/lv_conf.h /work/lv_conf.h
COPY sources/lane2nd-lv_conf.h /work/lane2nd-lv_conf.h
COPY sources/rebuildffmpeg.sh /work/rebuildffmpeg.sh
COPY sources/rebuildfreetype.sh /work/rebuildfreetype.sh
COPY sources/rebuildhyperlpr.sh /work/rebuildhyperlpr.sh
COPY sources/rebuildlaneapp-lvgl.sh /work/rebuildlaneapp-lvgl.sh
COPY sources/rebuildlibpeer.sh /work/rebuildlibpeer.sh
COPY sources/rebuildlibusb.sh /work/rebuildlibusb.sh
COPY sources/rebuildlibxml2.sh /work/rebuildlibxml2.sh
COPY sources/rebuildlvgl.sh /work/rebuildlvgl.sh
COPY sources/rebuildmbedtls.sh /work/rebuildmbedtls.sh
COPY sources/rebuildminigui.sh /work/rebuildminigui.sh
COPY sources/rebuildmnn.sh /work/rebuildmnn.sh
COPY sources/rebuildnanodet.sh /work/rebuildnanodet.sh
COPY sources/rebuildopencv.sh /work/rebuildopencv.sh
COPY sources/rebuildpostgresql.sh /work/rebuildpostgresql.sh
COPY sources/rebuildsqlite.sh /work/rebuildsqlite.sh
COPY sources/verify-aligned-static.sh /work/verify-aligned-static.sh
COPY sources/patches/ /work/patches/
COPY --from=fetcher /dist/ /dist/
COPY sources/minigui2.0.4-eb30dfdc.tar.gz /work/minigui2.0.4-eb30dfdc.tar.gz

RUN chmod +x /work/*.sh && \
    /work/build-selected-deps.sh arm64 mbedtls libxml2 freetype && \
    /work/rebuildminigui.sh arm64 && \
    /work/build-selected-deps.sh arm64 \
        sqlite libusb curl ffmpeg postgresql libpeer lvgl laneapp-lvgl \
        opencv mnn hyperlpr && \
    /work/rebuildnanodet.sh arm64 && \
    . /work/build-common.sh && \
    pcct_setup_target arm64 && \
    pcct_enforce_static_zlib && \
    /work/verify-aligned-static.sh arm64 && \
    rm -rf /dist /tmp/pcct-*

WORKDIR /LaneApp

CMD ["bash"]
