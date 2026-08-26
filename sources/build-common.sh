#!/bin/sh

set -eu

pcct_nproc() {
    if command -v nproc >/dev/null 2>&1; then
        nproc
    else
        getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1
    fi
}

pcct_reset_build_tree() {
    if [ -f Makefile ]; then
        make distclean >/dev/null 2>&1 || make clean >/dev/null 2>&1 || true
    fi
    rm -f config.cache config.status config.log config.mak config.h
}

pcct_bootstrap_autotools() {
    if [ -f configure ]; then
        return 0
    fi

    if [ -x ./bootstrap.sh ]; then
        ./bootstrap.sh
    elif [ -x ./autogen.sh ]; then
        ./autogen.sh
    fi

    if [ ! -f configure ]; then
        echo "configure was not generated in $(pwd)" >&2
        exit 2
    fi
}

pcct_setup_target() {
    if [ "$#" -ne 1 ]; then
        echo "pcct_setup_target expects exactly one target argument" >&2
        exit 1
    fi

    target=$1

    unset SYSROOT STAGING_DIR CROSS_COMPILE PKG_CONFIG_SYSROOT_DIR PKG_CONFIG_LIBDIR PKG_CONFIG_PATH PERLLIB || true

    case "$target" in
        x86)
            export CC="${CC:-gcc}"
            export CXX="${CXX:-g++}"
            export AR="${AR:-ar}"
            export AS="${AS:-as}"
            export LD="${LD:-ld}"
            export NM="${NM:-nm}"
            export RANLIB="${RANLIB:-ranlib}"
            export STRIP="${STRIP:-strip}"
            export OBJCOPY="${OBJCOPY:-objcopy}"
            export OBJDUMP="${OBJDUMP:-objdump}"
            export PKG_CONFIG="${PKG_CONFIG:-pkg-config}"
            export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/local/share/pkgconfig"
            PCCT_HOST="i686-pc-linux-gnu"
            PCCT_BUILD="i686-pc-linux-gnu"
            PCCT_ARCH="x86"
            PCCT_PREFIX="/usr/local"
            PCCT_LIBDIR="/usr/local/lib"
            PCCT_INCLUDEDIR="/usr/local/include"
            PCCT_PKGCONFIGDIR="/usr/local/lib/pkgconfig"
            PCCT_CROSS_PREFIX=""
            PCCT_IS_CROSS=0
            ;;
        x64|X64)
            export CC="${CC:-gcc}"
            export CXX="${CXX:-g++}"
            export AR="${AR:-ar}"
            export AS="${AS:-as}"
            export LD="${LD:-ld}"
            export NM="${NM:-nm}"
            export RANLIB="${RANLIB:-ranlib}"
            export STRIP="${STRIP:-strip}"
            export OBJCOPY="${OBJCOPY:-objcopy}"
            export OBJDUMP="${OBJDUMP:-objdump}"
            export PKG_CONFIG="${PKG_CONFIG:-pkg-config}"
            export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:/usr/local/share/pkgconfig"
            PCCT_HOST="x86_64-pc-linux-gnu"
            PCCT_BUILD="x86_64-pc-linux-gnu"
            PCCT_ARCH="x86_64"
            PCCT_PREFIX="/usr/local"
            PCCT_LIBDIR="/usr/local/lib"
            PCCT_INCLUDEDIR="/usr/local/include"
            PCCT_PKGCONFIGDIR="/usr/local/lib/pkgconfig"
            PCCT_CROSS_PREFIX=""
            PCCT_IS_CROSS=0
            ;;
        arm)
            export STAGING_DIR="/work/toolchain_R2_EABI/usr/arm-unknown-linux-gnueabi/sysroot"
            export SYSROOT="$STAGING_DIR"
            export CROSS_COMPILE="arm-none-linux-gnueabi-"
            export PATH="/work/toolchain_R2_EABI/usr/bin:/work/toolchain_R2_EABI/usr/sbin:$PATH"
            export CC="/work/toolchain_R2_EABI/usr/bin/arm-none-linux-gnueabi-gcc"
            export CXX="/work/toolchain_R2_EABI/usr/bin/arm-none-linux-gnueabi-g++"
            export AR="/work/toolchain_R2_EABI/usr/bin/arm-none-linux-gnueabi-ar"
            export AS="/work/toolchain_R2_EABI/usr/bin/arm-none-linux-gnueabi-as"
            export LD="/work/toolchain_R2_EABI/usr/bin/arm-none-linux-gnueabi-ld"
            export NM="/work/toolchain_R2_EABI/usr/bin/arm-none-linux-gnueabi-nm"
            export RANLIB="/work/toolchain_R2_EABI/usr/bin/arm-none-linux-gnueabi-ranlib"
            export STRIP="/work/toolchain_R2_EABI/usr/bin/arm-none-linux-gnueabi-strip"
            export OBJCOPY="/work/toolchain_R2_EABI/usr/bin/arm-none-linux-gnueabi-objcopy"
            export OBJDUMP="/work/toolchain_R2_EABI/usr/bin/arm-none-linux-gnueabi-objdump"
            export CC_FOR_BUILD="/usr/bin/gcc"
            export CXX_FOR_BUILD="/usr/bin/g++"
            export AR_FOR_BUILD="/usr/bin/ar"
            export AS_FOR_BUILD="/usr/bin/as"
            export LD_FOR_BUILD="/usr/bin/ld"
            export PKG_CONFIG="/work/toolchain_R2_EABI/usr/bin/pkg-config"
            export PERLLIB="/work/toolchain_R2_EABI/usr/lib/perl"
            PCCT_HOST="arm-unknown-linux-gnueabi"
            PCCT_BUILD="i686-pc-linux-gnu"
            PCCT_ARCH="arm"
            PCCT_PREFIX="$STAGING_DIR/usr"
            PCCT_LIBDIR="$PCCT_PREFIX/lib"
            PCCT_INCLUDEDIR="$PCCT_PREFIX/include"
            PCCT_PKGCONFIGDIR="$PCCT_LIBDIR/pkgconfig"
            PCCT_CROSS_PREFIX="arm-none-linux-gnueabi-"
            PCCT_IS_CROSS=1
            ;;
        arm64|ARM64)
            export CC="${CC:-aarch64-linux-gnu-gcc}"
            export CXX="${CXX:-aarch64-linux-gnu-g++}"
            export AR="${AR:-aarch64-linux-gnu-ar}"
            export AS="${AS:-aarch64-linux-gnu-as}"
            export LD="${LD:-aarch64-linux-gnu-ld}"
            export NM="${NM:-aarch64-linux-gnu-nm}"
            export RANLIB="${RANLIB:-aarch64-linux-gnu-ranlib}"
            export STRIP="${STRIP:-aarch64-linux-gnu-strip}"
            export OBJCOPY="${OBJCOPY:-aarch64-linux-gnu-objcopy}"
            export OBJDUMP="${OBJDUMP:-aarch64-linux-gnu-objdump}"
            export PKG_CONFIG="${PKG_CONFIG:-pkg-config}"
            export PKG_CONFIG_LIBDIR="/usr/lib/aarch64-linux-gnu/pkgconfig:/usr/share/pkgconfig:/usr/lib/pkgconfig"
            PCCT_HOST="aarch64-linux-gnu"
            PCCT_BUILD="x86_64-pc-linux-gnu"
            PCCT_ARCH="aarch64"
            PCCT_PREFIX="/usr"
            PCCT_LIBDIR="/usr/lib/aarch64-linux-gnu"
            PCCT_INCLUDEDIR="/usr/include"
            PCCT_PKGCONFIGDIR="/usr/lib/aarch64-linux-gnu/pkgconfig"
            PCCT_CROSS_PREFIX="aarch64-linux-gnu-"
            PCCT_IS_CROSS=1
            ;;
        la64|LA64)
            export SYSROOT="/opt/cross-tools/target"
            export PATH="/usr/local/bin:/opt/cross-tools/bin:$PATH"
            export CC="${CC:-loongarch64-unknown-linux-gnu-gcc}"
            export CXX="${CXX:-loongarch64-unknown-linux-gnu-g++}"
            export AR="${AR:-loongarch64-unknown-linux-gnu-ar}"
            export AS="${AS:-loongarch64-unknown-linux-gnu-as}"
            export LD="${LD:-loongarch64-unknown-linux-gnu-ld}"
            export NM="${NM:-loongarch64-unknown-linux-gnu-nm}"
            export RANLIB="${RANLIB:-loongarch64-unknown-linux-gnu-ranlib}"
            export STRIP="${STRIP:-loongarch64-unknown-linux-gnu-strip}"
            export OBJCOPY="${OBJCOPY:-loongarch64-unknown-linux-gnu-objcopy}"
            export OBJDUMP="${OBJDUMP:-loongarch64-unknown-linux-gnu-objdump}"
            export PKG_CONFIG="${PKG_CONFIG:-pkg-config}"
            export PKG_CONFIG_SYSROOT_DIR="$SYSROOT"
            export PKG_CONFIG_LIBDIR="/opt/cross-tools/target/usr/lib/loongarch64-linux-gnu/pkgconfig:/opt/cross-tools/target/usr/lib64/pkgconfig:/opt/cross-tools/target/usr/lib/pkgconfig:/opt/cross-tools/target/usr/share/pkgconfig"
            PCCT_HOST="loongarch64-unknown-linux-gnu"
            PCCT_BUILD="x86_64-pc-linux-gnu"
            PCCT_ARCH="loongarch64"
            PCCT_PREFIX="/opt/cross-tools/target/usr"
            PCCT_LIBDIR="/opt/cross-tools/target/usr/lib64"
            PCCT_INCLUDEDIR="/opt/cross-tools/target/usr/include"
            PCCT_PKGCONFIGDIR="/opt/cross-tools/target/usr/lib64/pkgconfig"
            PCCT_CROSS_PREFIX="loongarch64-unknown-linux-gnu-"
            PCCT_IS_CROSS=1
            ;;
        *)
            echo "unsupported target: $target" >&2
            exit 1
            ;;
    esac

    export PCCT_TARGET="$target" PCCT_HOST PCCT_BUILD PCCT_ARCH PCCT_PREFIX PCCT_LIBDIR PCCT_INCLUDEDIR PCCT_PKGCONFIGDIR PCCT_CROSS_PREFIX PCCT_IS_CROSS
}

pcct_write_cmake_toolchain() {
    if [ "$#" -ne 1 ]; then
        echo "pcct_write_cmake_toolchain expects exactly one output path" >&2
        exit 1
    fi

    if [ "${PCCT_IS_CROSS:-0}" != "1" ]; then
        echo "pcct_write_cmake_toolchain requires a cross target" >&2
        exit 1
    fi

    toolchain_file=$1
    cat > "$toolchain_file" <<EOF
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR "$PCCT_ARCH")
set(CMAKE_SYSROOT "$SYSROOT")
set(CMAKE_C_COMPILER "$CC")
set(CMAKE_CXX_COMPILER "$CXX")
set(CMAKE_AR "$AR")
set(CMAKE_ASM_COMPILER "$CC")
set(CMAKE_LINKER "$LD")
set(CMAKE_NM "$NM")
set(CMAKE_RANLIB "$RANLIB")
set(CMAKE_STRIP "$STRIP")
set(CMAKE_OBJCOPY "$OBJCOPY")
set(CMAKE_FIND_ROOT_PATH "$PCCT_PREFIX")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
EOF
}
