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
        libconfig jpeg freetype sqlite libusb mbedtls curl postgresql

FROM debian:trixie-slim

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG LOONGSON_TOOLCHAIN_VERSION=2025.02.21
ARG LOONGSON_TOOLCHAIN_FILE=x86_64-cross-tools-loongarch64-binutils_2.44-gcc_14.2.0-glibc_2.41.tar.xz
ARG LOONGSON_TOOLCHAIN_SHA256=B6B058AB77CF21C806DB409D1FB2AD4B43FA23832616216099CF8168274F16B6
ARG PCCT_USE_TUNA_MIRROR=1
ARG PCCT_HTTP_PROXY=http://host.docker.internal:7890

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Shanghai \
    SYSROOT=/opt/cross-tools/target \
    CROSS_COMPILE=loongarch64-unknown-linux-gnu- \
    ARCH=loongarch64 \
    CC=loongarch64-unknown-linux-gnu-gcc \
    CXX=loongarch64-unknown-linux-gnu-g++ \
    AR=loongarch64-unknown-linux-gnu-ar \
    AS=loongarch64-unknown-linux-gnu-as \
    LD=loongarch64-unknown-linux-gnu-ld \
    NM=loongarch64-unknown-linux-gnu-nm \
    RANLIB=loongarch64-unknown-linux-gnu-ranlib \
    STRIP=loongarch64-unknown-linux-gnu-strip \
    OBJCOPY=loongarch64-unknown-linux-gnu-objcopy \
    OBJDUMP=loongarch64-unknown-linux-gnu-objdump \
    PKG_CONFIG_SYSROOT_DIR=/opt/cross-tools/target \
    PKG_CONFIG_LIBDIR=/opt/cross-tools/target/usr/lib64/pkgconfig:/opt/cross-tools/target/usr/share/pkgconfig \
    PATH=/opt/cross-tools/bin:/usr/local/bin:$PATH

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
               autoconf automake binutils bison ca-certificates cmake file flex \
               g++ gcc lbzip2 libtool libtool-bin m4 make patch perl pkg-config \
               wget xz-utils; then \
            break; \
        fi; \
        if [ "$attempt" = "5" ]; then exit 1; fi; \
        echo "apt bootstrap attempt $attempt failed, retrying..." >&2; \
        sleep 10; \
    done && \
    rm -rf /var/lib/apt/lists/*

RUN cd /tmp && \
    toolchain_url="https://github.com/loongson/build-tools/releases/download/${LOONGSON_TOOLCHAIN_VERSION}/${LOONGSON_TOOLCHAIN_FILE}" && \
    if ! wget -q --https-only --tries=5 --waitretry=5 \
        "$toolchain_url" -O loongarch64-toolchain.tar.xz; then \
        https_proxy="$PCCT_HTTP_PROXY" HTTPS_PROXY="$PCCT_HTTP_PROXY" \
            wget -q --https-only --tries=3 --waitretry=5 \
            "$toolchain_url" -O loongarch64-toolchain.tar.xz; \
    fi && \
    echo "${LOONGSON_TOOLCHAIN_SHA256}  loongarch64-toolchain.tar.xz" | sha256sum -c - && \
    mkdir -p /opt && \
    tar -xf loongarch64-toolchain.tar.xz -C /opt && \
    rm -f loongarch64-toolchain.tar.xz && \
    test -x /opt/cross-tools/bin/loongarch64-unknown-linux-gnu-gcc && \
    test "$(readlink -f "$(/opt/cross-tools/bin/loongarch64-unknown-linux-gnu-gcc -print-sysroot)")" = "/opt/cross-tools/target"

COPY sources/build-common.sh /work/build-common.sh
COPY sources/build-selected-deps.sh /work/build-selected-deps.sh
COPY sources/dependency-versions.sh /work/dependency-versions.sh
COPY --from=fetcher /dist/ /dist/
COPY sources/minigui2.0.4-eb30dfdc.tar.gz /work/minigui2.0.4-eb30dfdc.tar.gz

RUN mkdir -p /opt/cross-tools/target/usr/lib64/pkgconfig && \
    printf '%s\n' \
        'prefix=/opt/cross-tools/target/usr' \
        'exec_prefix=${prefix}' \
        'libdir=${prefix}/lib64' \
        'includedir=${prefix}/include' \
        '' \
        'Name: zlib' \
        'Description: LoongArch glibc 2.41 toolchain zlib static profile' \
        'Version: 1.3.1' \
        'Libs: -L${libdir} -l:libz.a' \
        'Cflags: -I${includedir}' \
        > /opt/cross-tools/target/usr/lib64/pkgconfig/zlib.pc && \
    chmod +x /work/*.sh

COPY --chmod=0755 sources/rebuildlibconfig.sh /work/rebuildlibconfig.sh
RUN /work/build-selected-deps.sh la64 libconfig
COPY --chmod=0755 sources/rebuildjpeg.sh /work/rebuildjpeg.sh
RUN /work/build-selected-deps.sh la64 jpeg
COPY --chmod=0755 sources/rebuildfreetype.sh /work/rebuildfreetype.sh
RUN /work/build-selected-deps.sh la64 freetype
COPY --chmod=0755 sources/rebuildsqlite.sh /work/rebuildsqlite.sh
RUN /work/build-selected-deps.sh la64 sqlite
COPY --chmod=0755 sources/rebuildlibusb.sh /work/rebuildlibusb.sh
RUN /work/build-selected-deps.sh la64 libusb
RUN apt-get update && \
    apt-get install -y --no-install-recommends python3 && \
    rm -rf /var/lib/apt/lists/*
COPY --chmod=0755 sources/rebuildmbedtls.sh /work/rebuildmbedtls.sh
RUN /work/build-selected-deps.sh la64 mbedtls
COPY --chmod=0755 rebuildcurl.sh /work/rebuildcurl.sh
RUN /work/build-selected-deps.sh la64 curl
COPY --chmod=0755 sources/rebuildpostgresql.sh /work/rebuildpostgresql.sh
RUN /work/build-selected-deps.sh la64 postgresql
COPY --chmod=0755 sources/rebuildminigui.sh /work/rebuildminigui.sh
RUN /work/rebuildminigui.sh la64

COPY --chmod=0755 sources/verify-loongarch64.sh /work/verify-loongarch64.sh
RUN find /opt/cross-tools/target/usr/lib64/pkgconfig -type f -name '*.pc' \
        -exec sed -i 's/-lz\([[:space:]]\|$\)/-l:libz.a\1/g' {} + && \
    /work/verify-loongarch64.sh && \
    rm -rf /dist /tmp/pcct-*

WORKDIR /tmp/LaneApp
CMD ["bash"]
