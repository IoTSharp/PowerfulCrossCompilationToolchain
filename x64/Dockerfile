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
    CC=gcc \
    CXX=g++ \
    AR=ar \
    AS=as \
    LD=ld \
    NM=nm \
    RANLIB=ranlib \
    STRIP=strip \
    OBJCOPY=objcopy \
    OBJDUMP=objdump \
    PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:/usr/local/share/pkgconfig

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
    for attempt in 1 2 3 4 5; do \
        rm -rf /var/lib/apt/lists/*; \
        if apt-get update && \
           apt-get install -y --no-install-recommends --fix-missing \
               autoconf \
               automake \
               gcc \
               g++ \
               ca-certificates \
               file \
               flex \
               bison \
               cmake \
               libconfig-dev \
               libjpeg-dev \
               libpq-dev \
               libudev-dev \
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
               zlib1g-dev; then \
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
    /work/build-selected-deps.sh x64 mbedtls libxml2 freetype && \
    /work/rebuildminigui.sh x64 && \
    /work/build-selected-deps.sh x64 \
        sqlite libusb curl ffmpeg postgresql libpeer lvgl laneapp-lvgl \
        opencv mnn hyperlpr && \
    /work/rebuildnanodet.sh x64 && \
    find /usr/local/lib/pkgconfig -type f -name '*.pc' \
        -exec sed -i 's/-lz\([[:space:]]\|$\)/-l:libz.a\1/g' {} + && \
    /work/verify-aligned-static.sh x64 && \
    rm -rf /dist /tmp/pcct-*

WORKDIR /LaneApp

CMD ["bash"]
