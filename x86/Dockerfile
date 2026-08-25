ARG BASE_PLATFORM=linux/386

FROM debian:bookworm-slim AS fetcher

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG PCCT_HTTP_PROXY=http://host.docker.internal:7890
ENV PCCT_HTTP_PROXY=${PCCT_HTTP_PROXY}

COPY sources/dependency-versions.sh /work/dependency-versions.sh
COPY sources/fetch-github-sources.sh /work/fetch-github-sources.sh

RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates wget && \
    rm -rf /var/lib/apt/lists/*

RUN chmod +x /work/*.sh && \
    /work/fetch-github-sources.sh /dist \
        curl libxml2 freetype libusb sqlite ffmpeg postgresql \
        libpeer libsrtp mbedtls laneapp-lvgl \
        cmake opencv mnn mnn-license hyperlpr

FROM --platform=${BASE_PLATFORM} i386/ubuntu:16.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG PCCT_UBUNTU_MIRROR=http://mirrors.aliyun.com/ubuntu

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

RUN sed -i \
        -e "s|http://archive.ubuntu.com/ubuntu/|${PCCT_UBUNTU_MIRROR}/|g" \
        -e "s|http://security.ubuntu.com/ubuntu/|${PCCT_UBUNTU_MIRROR}/|g" \
        /etc/apt/sources.list && \
    printf '%s\n' \
        'Acquire::Retries "5";' \
        'Acquire::http::Timeout "60";' \
        'Acquire::https::Timeout "60";' \
        'Acquire::http::Pipeline-Depth "0";' \
        > /etc/apt/apt.conf.d/99laneapp-network && \
    for attempt in 1 2 3 4 5; do \
        rm -rf /var/lib/apt/lists/*; \
        if apt-get update && \
           apt-get install -y --no-install-recommends --fix-missing \
               autoconf \
               automake \
               binutils \
               build-essential \
               ca-certificates \
               clang-6.0 \
               cmake \
               curl \
               file \
               flex \
               bison \
               g++ \
               gcc \
               gdb \
               gdbserver \
               git \
               lbzip2 \
               libasan2 \
               libclang-common-6.0-dev \
               libconfig-dev \
               libdrm-dev \
               libfreetype6-dev \
               libgtk2.0-dev \
               libjpeg-dev \
               libpciaccess-dev \
               libpng12-dev \
               libtool \
               libtool-bin \
               libubsan0 \
               libudev-dev \
               libva-dev \
               ltrace \
               m4 \
               make \
               patch \
               perl \
               pkg-config \
               python3 \
               strace \
               unzip \
               valgrind \
               wget \
               xz-utils \
               zip \
               i965-va-driver \
               zlib1g-dev; then \
            break; \
        fi; \
        if [ "$attempt" = "5" ]; then \
            exit 1; \
        fi; \
        sleep 10; \
    done && \
    ln -sf /usr/bin/python3 /usr/local/bin/python && \
    rm -rf /var/lib/apt/lists/*

COPY rebuildcurl.sh /work/rebuildcurl.sh
COPY sources/build-common.sh /work/build-common.sh
COPY sources/build-selected-deps.sh /work/build-selected-deps.sh
COPY sources/dependency-versions.sh /work/dependency-versions.sh
COPY sources/export-vaapi-runtime.sh /work/export-vaapi-runtime.sh
COPY sources/lane2nd-lv_conf.h /work/lane2nd-lv_conf.h
COPY sources/rebuildffmpeg.sh /work/rebuildffmpeg.sh
COPY sources/rebuildfreetype.sh /work/rebuildfreetype.sh
COPY sources/rebuildcmake.sh /work/rebuildcmake.sh
COPY sources/rebuildhyperlpr.sh /work/rebuildhyperlpr.sh
COPY sources/rebuildlaneapp-lvgl.sh /work/rebuildlaneapp-lvgl.sh
COPY sources/rebuildlibpeer.sh /work/rebuildlibpeer.sh
COPY sources/rebuildlibusb.sh /work/rebuildlibusb.sh
COPY sources/rebuildlibxml2.sh /work/rebuildlibxml2.sh
COPY sources/rebuildmbedtls.sh /work/rebuildmbedtls.sh
COPY sources/rebuildminigui.sh /work/rebuildminigui.sh
COPY sources/rebuildmnn.sh /work/rebuildmnn.sh
COPY sources/rebuildopencv.sh /work/rebuildopencv.sh
COPY sources/rebuildpostgresql.sh /work/rebuildpostgresql.sh
COPY sources/rebuildsqlite.sh /work/rebuildsqlite.sh
COPY sources/verify-x86-static.sh /work/verify-x86-static.sh
COPY sources/patches/ /work/patches/
COPY --from=fetcher /dist/ /dist/
COPY sources/minigui2.0.4-eb30dfdc.tar.gz /work/minigui2.0.4-eb30dfdc.tar.gz

RUN test -f /usr/lib/i386-linux-gnu/libz.a && \
    mkdir -p /usr/local/lib/pkgconfig && \
    zlib_version="$(pkg-config --modversion zlib)" && \
    printf '%s\n' \
        'prefix=/usr' \
        'exec_prefix=${prefix}' \
        'libdir=${prefix}/lib/i386-linux-gnu' \
        'includedir=${prefix}/include' \
        '' \
        'Name: zlib' \
        'Description: zlib compression library (PCCT static profile)' \
        "Version: ${zlib_version}" \
        'Libs: -L${libdir} -l:libz.a' \
        'Cflags: -I${includedir}' \
        > /usr/local/lib/pkgconfig/zlib.pc && \
    chmod +x /work/*.sh && \
    /work/rebuildminigui.sh x86 && \
    /work/build-selected-deps.sh x86 \
        mbedtls curl libxml2 freetype sqlite libusb ffmpeg postgresql \
        libpeer laneapp-lvgl cmake opencv mnn hyperlpr && \
    find /usr/local/lib/pkgconfig -type f -name '*.pc' \
        -exec sed -i 's/-lz\([[:space:]]\|$\)/-l:libz.a\1/g' {} + && \
    /work/export-vaapi-runtime.sh && \
    /work/verify-x86-static.sh && \
    rm -rf /dist /tmp/pcct-* /tmp/pcct-static-smoke*

ENV LD_LIBRARY_PATH=/usr/local/lib \
    LIBRARY_PATH=/usr/local/lib \
    CMAKE_PREFIX_PATH=/usr/local \
    LANE_CAMERA_CC=gcc

WORKDIR /tmp/LaneApp
CMD ["bash"]
