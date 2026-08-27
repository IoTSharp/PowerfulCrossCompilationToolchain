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
        libconfig curl libxml2 freetype libusb sqlite ffmpeg postgresql \
        libpeer libsrtp mbedtls laneapp-lvgl cmake \
        opencv mnn mnn-license hyperlpr nanodet-model nanodet-license

FROM quay.io/centos/centos:7.9.2009@sha256:e4ca2ed0202e76be184e75fb26d14bf974193579039d5573fb2348664deef76e

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ARG CENTOS_VERSION=7.9.2009
ARG PCCT_CENTOS_VAULT=https://mirrors.aliyun.com/centos-vault

ENV TZ=Asia/Shanghai \
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

RUN rm -f /etc/yum.repos.d/*.repo && \
    printf '%s\n' \
        '[base]' \
        'name=CentOS-7 Base' \
        "baseurl=${PCCT_CENTOS_VAULT}/${CENTOS_VERSION}/os/\$basearch/" \
        'enabled=1' \
        'gpgcheck=1' \
        'gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7' \
        '' \
        '[updates]' \
        'name=CentOS-7 Updates' \
        "baseurl=${PCCT_CENTOS_VAULT}/${CENTOS_VERSION}/updates/\$basearch/" \
        'enabled=1' \
        'gpgcheck=1' \
        'gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7' \
        '' \
        '[extras]' \
        'name=CentOS-7 Extras' \
        "baseurl=${PCCT_CENTOS_VAULT}/${CENTOS_VERSION}/extras/\$basearch/" \
        'enabled=1' \
        'gpgcheck=1' \
        'gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7' \
        > /etc/yum.repos.d/CentOS-Base.repo && \
    printf '%s\n' 'retries=5' 'timeout=60' >> /etc/yum.conf && \
    yum -y install centos-release-scl-rh && \
    rm -f /etc/yum.repos.d/CentOS-SCLo-*.repo && \
    printf '%s\n' \
        '[centos-sclo-rh]' \
        'name=CentOS-7 SCLo rh' \
        "baseurl=${PCCT_CENTOS_VAULT}/${CENTOS_VERSION}/sclo/\$basearch/rh/" \
        'enabled=1' \
        'gpgcheck=1' \
        'gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-SIG-SCLo' \
        '' \
        '[centos-sclo-sclo]' \
        'name=CentOS-7 SCLo sclo' \
        "baseurl=${PCCT_CENTOS_VAULT}/${CENTOS_VERSION}/sclo/\$basearch/sclo/" \
        'enabled=1' \
        'gpgcheck=1' \
        'gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-SIG-SCLo' \
        > /etc/yum.repos.d/CentOS-SCLo-Archive.repo && \
    yum -y install \
        autoconf automake binutils bison bzip2 ca-certificates file flex \
        gcc gcc-c++ gdb gdb-gdbserver git libasan libdrm-devel \
        libjpeg-turbo-devel libjpeg-turbo-static libpciaccess-devel \
        libpng-devel libtool libva-devel ltrace m4 make \
        patch perl pkgconfig python3 strace systemd-devel unzip valgrind wget \
        which xz zip zlib-devel zlib-static \
        devtoolset-7-gcc devtoolset-7-gcc-c++ \
        devtoolset-7-libstdc++-devel && \
    yum clean all && \
    rm -rf /var/cache/yum

# CentOS exposes both libz.so and libz.a. Keep pkg-config consumers on the
# image's static dependency contract by overriding only zlib's link metadata.
RUN zlib_pc="$(pkg-config --variable=pcfiledir zlib)/zlib.pc" && \
    test -f "$zlib_pc" && \
    test -f /usr/lib64/libz.a && \
    mkdir -p /usr/local/lib/pkgconfig && \
    cp "$zlib_pc" /usr/local/lib/pkgconfig/zlib.pc && \
    sed -i 's/-lz\([[:space:]]\|$\)/-l:libz.a\1/g' \
        /usr/local/lib/pkgconfig/zlib.pc

ENV DEVTOOLSET_ROOT=/opt/rh/devtoolset-7/root \
    PATH=/opt/rh/devtoolset-7/root/usr/bin:${PATH} \
    LD_LIBRARY_PATH=/opt/rh/devtoolset-7/root/usr/lib64 \
    CC=/opt/rh/devtoolset-7/root/usr/bin/gcc \
    CXX=/opt/rh/devtoolset-7/root/usr/bin/g++ \
    PCCT_FORCE_STATIC_CXX=1 \
    PCCT_MAX_GLIBC=2.17

COPY rebuildcurl.sh /work/rebuildcurl.sh
COPY sources/build-common.sh /work/build-common.sh
COPY sources/build-selected-deps.sh /work/build-selected-deps.sh
COPY sources/dependency-versions.sh /work/dependency-versions.sh
COPY sources/lane2nd-lv_conf.h /work/lane2nd-lv_conf.h
COPY sources/rebuildcmake.sh /work/rebuildcmake.sh
COPY sources/rebuildffmpeg.sh /work/rebuildffmpeg.sh
COPY sources/rebuildfreetype.sh /work/rebuildfreetype.sh
COPY sources/rebuildhyperlpr.sh /work/rebuildhyperlpr.sh
COPY sources/rebuildlaneapp-lvgl.sh /work/rebuildlaneapp-lvgl.sh
COPY sources/rebuildlibconfig.sh /work/rebuildlibconfig.sh
COPY sources/rebuildlibpeer.sh /work/rebuildlibpeer.sh
COPY sources/rebuildlibusb.sh /work/rebuildlibusb.sh
COPY sources/rebuildlibxml2.sh /work/rebuildlibxml2.sh
COPY sources/rebuildmbedtls.sh /work/rebuildmbedtls.sh
COPY sources/rebuildminigui.sh /work/rebuildminigui.sh
COPY sources/rebuildmnn.sh /work/rebuildmnn.sh
COPY sources/rebuildnanodet.sh /work/rebuildnanodet.sh
COPY sources/rebuildopencv.sh /work/rebuildopencv.sh
COPY sources/rebuildpostgresql.sh /work/rebuildpostgresql.sh
COPY sources/rebuildsqlite.sh /work/rebuildsqlite.sh
COPY sources/verify-aligned-static.sh /work/verify-aligned-static.sh
COPY sources/verify-centos79.sh /work/verify-centos79.sh
COPY sources/patches/ /work/patches/
COPY --from=fetcher /dist/ /dist/
COPY sources/minigui2.0.4-eb30dfdc.tar.gz /work/minigui2.0.4-eb30dfdc.tar.gz

RUN chmod +x /work/*.sh && \
    /work/build-selected-deps.sh x64 cmake && \
    /work/build-selected-deps.sh x64 \
        libconfig mbedtls libxml2 freetype && \
    /work/rebuildminigui.sh x64 && \
    /work/build-selected-deps.sh x64 \
        sqlite libusb curl ffmpeg postgresql libpeer laneapp-lvgl \
        opencv mnn hyperlpr && \
    /work/rebuildnanodet.sh x64 && \
    . /work/build-common.sh && \
    pcct_setup_target x64 && \
    pcct_enforce_static_zlib && \
    /work/verify-aligned-static.sh x64 && \
    /work/verify-centos79.sh && \
    rm -rf /dist /tmp/pcct-*

WORKDIR /tmp/LaneApp
CMD ["bash"]
