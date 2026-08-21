ARG BASE_PLATFORM=linux/amd64

FROM debian:bookworm-slim AS fetcher

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY sources/dependency-versions.sh /work/dependency-versions.sh
COPY sources/fetch-github-sources.sh /work/fetch-github-sources.sh

RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates wget && \
    rm -rf /var/lib/apt/lists/*

RUN chmod +x /work/*.sh && \
    /work/fetch-github-sources.sh /dist curl freetype libusb sqlite ffmpeg lvgl && \
    echo "Fetching PostgreSQL 17.2..." && \
    wget -q --https-only --tries=5 --waitretry=10 \
        -O /dist/postgresql-REL_17_2.tar.gz \
        https://github.com/postgres/postgres/archive/refs/tags/REL_17_2.tar.gz && \
    echo "PostgreSQL 17.2 fetched successfully"

FROM --platform=${BASE_PLATFORM} ubuntu:16.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG PCCT_UBUNTU_MIRROR=http://mirrors.aliyun.com/ubuntu

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Shanghai \
    PCCT_ARM_SYSROOT=/work/toolchain_R2_EABI/usr/arm-unknown-linux-gnueabi/sysroot \
    CROSS_COMPILE=arm-none-linux-gnueabi- \
    SYSROOT=/work/toolchain_R2_EABI/usr/arm-unknown-linux-gnueabi/sysroot \
    CC=/work/toolchain_R2_EABI/usr/bin/arm-none-linux-gnueabi-gcc \
    CXX=/work/toolchain_R2_EABI/usr/bin/arm-none-linux-gnueabi-g++ \
    AR=/work/toolchain_R2_EABI/usr/bin/arm-none-linux-gnueabi-ar \
    AS=/work/toolchain_R2_EABI/usr/bin/arm-none-linux-gnueabi-as \
    LD=/work/toolchain_R2_EABI/usr/bin/arm-none-linux-gnueabi-ld \
    NM=/work/toolchain_R2_EABI/usr/bin/arm-none-linux-gnueabi-nm \
    RANLIB=/work/toolchain_R2_EABI/usr/bin/arm-none-linux-gnueabi-ranlib \
    STRIP=/work/toolchain_R2_EABI/usr/bin/arm-none-linux-gnueabi-strip \
    OBJCOPY=/work/toolchain_R2_EABI/usr/bin/arm-none-linux-gnueabi-objcopy \
    OBJDUMP=/work/toolchain_R2_EABI/usr/bin/arm-none-linux-gnueabi-objdump \
    PKG_CONFIG=/work/toolchain_R2_EABI/usr/bin/pkg-config \
    PATH=/work/toolchain_R2_EABI/usr/bin:/work/toolchain_R2_EABI/usr/sbin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

COPY sources/toolchain.tar.gzaa /work/
COPY sources/toolchain.tar.gzab /work/
COPY sources/toolchain.tar.gzac /work/
COPY rebuildcurl.sh /work/rebuildcurl.sh
COPY sources/build-common.sh /work/build-common.sh
COPY sources/build-selected-deps.sh /work/build-selected-deps.sh
COPY sources/dependency-versions.sh /work/dependency-versions.sh
COPY sources/lv_conf.h /work/lv_conf.h
COPY sources/pcct-arm-gcc54-wrapper /usr/local/bin/pcct-arm-gcc54-wrapper
COPY sources/pcct-arm-pkg-config /usr/local/bin/pcct-arm-pkg-config
COPY sources/rebuildffmpeg.sh /work/rebuildffmpeg.sh
COPY sources/rebuildfreetype.sh /work/rebuildfreetype.sh
COPY sources/rebuildlibusb.sh /work/rebuildlibusb.sh
COPY sources/rebuildlvgl.sh /work/rebuildlvgl.sh
COPY sources/rebuildminigui.sh /work/rebuildminigui.sh
COPY sources/rebuildsqlite.sh /work/rebuildsqlite.sh
COPY sources/rebuildpostgresql.sh /work/rebuildpostgresql.sh
COPY sources/verify-arm-gcc54.sh /work/verify-arm-gcc54.sh
COPY --from=fetcher /dist/ /dist/
COPY sources/minigui2.0.4-eb30dfdc.tar.gz /work/minigui2.0.4-eb30dfdc.tar.gz

RUN sed -i \
        -e "s|http://archive.ubuntu.com/ubuntu/|${PCCT_UBUNTU_MIRROR}/|g" \
        -e "s|http://security.ubuntu.com/ubuntu/|${PCCT_UBUNTU_MIRROR}/|g" \
        /etc/apt/sources.list && \
    printf '%s\n' \
        'Acquire::Retries "5";' \
        'Acquire::http::Timeout "60";' \
        'Acquire::https::Timeout "60";' \
        'Acquire::http::Pipeline-Depth "0";' \
        > /etc/apt/apt.conf.d/99laneapp-network

RUN set -e; \
    retry() { \
        n=1; \
        while true; do \
            "$@" && return 0; \
            if [ "$n" -ge 5 ]; then return 1; fi; \
            echo "Retry $n/5: $*" >&2; \
            n=$((n + 1)); \
            sleep 5; \
        done; \
    }; \
    rm -rf /var/lib/apt/lists/* && \
    retry apt-get update && \
    retry apt-get install -y --no-install-recommends --fix-missing \
        autoconf \
        automake \
        binutils \
        binutils-arm-linux-gnueabi \
        build-essential \
        ca-certificates \
        cmake \
        file \
        flex \
        bison \
        g++-5-arm-linux-gnueabi \
        gcc-5-arm-linux-gnueabi \
        libtool \
        libtool-bin \
        m4 \
        make \
        patch \
        perl \
        pkg-config \
        wget \
        xz-utils && \
    retry apt-get install -y --no-install-recommends --fix-missing \
        libconfig-dev \
        libjpeg-dev \
        libpng12-dev \
        libpq-dev \
        libudev-dev \
        zlib1g-dev && \
    retry apt-get install -y --no-install-recommends --fix-missing \
        libxml2-dev && \
    retry apt-get install -y --no-install-recommends --fix-missing \
        libgtk2.0-dev \
        libvncserver-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN chmod +x /work/*.sh && \
    cd /work && \
    cat toolchain.tar.gz* | tar xz && \
    tar xzf ./toolchain_R2_EABI.tar.gz && \
    rm -f ./toolchain_R2_EABI.tar.gz ./toolchain.tar.gz*

RUN set -e; \
    chmod 755 /usr/local/bin/pcct-arm-gcc54-wrapper /usr/local/bin/pcct-arm-pkg-config; \
    for entry in /work/toolchain_R2_EABI/usr/bin/*; do \
        name=$(basename "$entry"); \
        case "$name" in \
            arm-none-linux-gnueabi-*|pkg-config) ;; \
            *) \
                if [ -f "$entry" ] || [ -L "$entry" ]; then rm -f "$entry"; fi; \
                ;; \
        esac; \
    done; \
    for tool in ar as cpp g++ gcc gfortran ld nm objcopy objdump ranlib strip; do \
        rm -f "/work/toolchain_R2_EABI/usr/bin/arm-none-linux-gnueabi-$tool"; \
        ln -s /usr/local/bin/pcct-arm-gcc54-wrapper "/work/toolchain_R2_EABI/usr/bin/arm-none-linux-gnueabi-$tool"; \
    done; \
    rm -f /work/toolchain_R2_EABI/usr/bin/pkg-config; \
    ln -s /usr/local/bin/pcct-arm-pkg-config /work/toolchain_R2_EABI/usr/bin/pkg-config; \
    arm-none-linux-gnueabi-gcc --version | head -n 1 | grep -q '5\.4\.0'; \
    test "$(arm-none-linux-gnueabi-gcc -print-sysroot)" = "$PCCT_ARM_SYSROOT"; \
    test -f "$(arm-none-linux-gnueabi-gcc -print-file-name=crt1.o)"

RUN rm -rf \
        /work/toolchain_R2_EABI/usr/arm-unknown-linux-gnueabi/sysroot/usr/include/minigui \
        /work/toolchain_R2_EABI/usr/arm-unknown-linux-gnueabi/sysroot/usr/include/freetype2 \
        /work/toolchain_R2_EABI/usr/arm-unknown-linux-gnueabi/sysroot/usr/include/lvgl && \
    rm -f \
        /work/toolchain_R2_EABI/usr/arm-unknown-linux-gnueabi/sysroot/usr/etc/MiniGUI.cfg \
        /work/toolchain_R2_EABI/usr/arm-unknown-linux-gnueabi/sysroot/usr/bin/curl-config \
        /work/toolchain_R2_EABI/usr/arm-unknown-linux-gnueabi/sysroot/usr/bin/freetype-config \
        /work/toolchain_R2_EABI/usr/arm-unknown-linux-gnueabi/sysroot/usr/include/lvgl.h \
        /work/toolchain_R2_EABI/usr/arm-unknown-linux-gnueabi/sysroot/usr/include/lv_conf.h \
        /work/toolchain_R2_EABI/usr/arm-unknown-linux-gnueabi/sysroot/usr/lib/libmgext* \
        /work/toolchain_R2_EABI/usr/arm-unknown-linux-gnueabi/sysroot/usr/lib/libminigui* \
        /work/toolchain_R2_EABI/usr/arm-unknown-linux-gnueabi/sysroot/usr/lib/libcurl* \
        /work/toolchain_R2_EABI/usr/arm-unknown-linux-gnueabi/sysroot/usr/lib/libfreetype* \
        /work/toolchain_R2_EABI/usr/arm-unknown-linux-gnueabi/sysroot/usr/lib/libsqlite3* \
        /work/toolchain_R2_EABI/usr/arm-unknown-linux-gnueabi/sysroot/usr/lib/libusb-1.0* \
        /work/toolchain_R2_EABI/usr/arm-unknown-linux-gnueabi/sysroot/usr/lib/libavcodec* \
        /work/toolchain_R2_EABI/usr/arm-unknown-linux-gnueabi/sysroot/usr/lib/libavformat* \
        /work/toolchain_R2_EABI/usr/arm-unknown-linux-gnueabi/sysroot/usr/lib/libavutil* \
        /work/toolchain_R2_EABI/usr/arm-unknown-linux-gnueabi/sysroot/usr/lib/libswscale* \
        /work/toolchain_R2_EABI/usr/arm-unknown-linux-gnueabi/sysroot/usr/lib/liblvgl.a \
        /work/toolchain_R2_EABI/usr/arm-unknown-linux-gnueabi/sysroot/usr/lib/pkgconfig/freetype2.pc \
        /work/toolchain_R2_EABI/usr/arm-unknown-linux-gnueabi/sysroot/usr/lib/pkgconfig/libcurl.pc \
        /work/toolchain_R2_EABI/usr/arm-unknown-linux-gnueabi/sysroot/usr/lib/pkgconfig/libusb-1.0.pc \
        /work/toolchain_R2_EABI/usr/arm-unknown-linux-gnueabi/sysroot/usr/lib/pkgconfig/sqlite3.pc \
        /work/toolchain_R2_EABI/usr/arm-unknown-linux-gnueabi/sysroot/usr/lib/pkgconfig/libavcodec.pc \
        /work/toolchain_R2_EABI/usr/arm-unknown-linux-gnueabi/sysroot/usr/lib/pkgconfig/libavformat.pc \
        /work/toolchain_R2_EABI/usr/arm-unknown-linux-gnueabi/sysroot/usr/lib/pkgconfig/libavutil.pc \
        /work/toolchain_R2_EABI/usr/arm-unknown-linux-gnueabi/sysroot/usr/lib/pkgconfig/libswscale.pc \
        /work/toolchain_R2_EABI/usr/arm-unknown-linux-gnueabi/sysroot/usr/lib/pkgconfig/lvgl.pc

RUN /work/build-selected-deps.sh arm freetype && \
    /work/rebuildminigui.sh arm && \
    /work/build-selected-deps.sh arm sqlite libusb curl ffmpeg lvgl postgresql && \
    /work/verify-arm-gcc54.sh && \
    rm -rf /dist /tmp/pcct-*

WORKDIR /tmp/LaneApp

CMD ["bash"]
