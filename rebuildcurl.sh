#!/bin/sh

set -eu

if [ "$#" -ne 1 ]; then
    echo "usage: $0 <x86|x64|arm|arm64|la64>" >&2
    exit 1
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
if [ -f "$SCRIPT_DIR/build-common.sh" ]; then
    . "$SCRIPT_DIR/build-common.sh"
else
    . "$SCRIPT_DIR/sources/build-common.sh"
fi

pcct_setup_target "$1"
pcct_reset_build_tree

if [ ! -f "configure" ]; then
    echo ""
    echo " --------- Missing configure in curl release tarball --------- "
    echo ""
    exit 2
fi

COMMON_CURL_ARGS="\
    --disable-shared --enable-static --with-pic \
    --without-librtmp --with-zlib \
    --without-brotli --without-zstd --without-libpsl --without-libidn2 \
    --without-nghttp2 --without-nghttp3 --without-ngtcp2 \
    --disable-ldap --disable-rtsp --disable-dict --disable-smtp --disable-gopher --disable-manual \
    --disable-ipv6 --disable-threaded-resolver \
    --disable-openssl-auto-load-config --disable-sspi"

export CFLAGS="${CFLAGS:-} -O2 -fPIC"
export CXXFLAGS="${CXXFLAGS:-} -O2 -fPIC"

case "$PCCT_TARGET" in
    x86)
        echo "Build X86"
        ./configure --target=i686-pc-linux-gnu \
            --host=i686-pc-linux-gnu \
            --build=i686-pc-linux-gnu \
            --prefix="$PCCT_PREFIX" \
            --libdir="$PCCT_LIBDIR" \
            --includedir="$PCCT_INCLUDEDIR" \
            --with-mbedtls="$PCCT_PREFIX" \
            $COMMON_CURL_ARGS
        ;;
    x64|X64)
        echo "Build X64"
        ./configure --target=x86_64-pc-linux-gnu \
            --host=x86_64-pc-linux-gnu \
            --build=x86_64-pc-linux-gnu \
            --prefix="$PCCT_PREFIX" \
            --libdir="$PCCT_LIBDIR" \
            --includedir="$PCCT_INCLUDEDIR" \
            --without-ssl \
            $COMMON_CURL_ARGS
        ;;
    arm)
        echo "Build ARM"
        CFLAGS="-pipe -g -D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64" \
        CXXFLAGS="-pipe -g -D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64" \
        STAGING_DIR="/work/toolchain_R2_EABI/usr/arm-unknown-linux-gnueabi/sysroot" \
        ac_cv_lbl_unaligned_fail=yes ac_cv_func_mmap_fixed_mapped=yes ac_cv_func_memcmp_working=yes \
        ac_cv_have_decl_malloc=yes gl_cv_func_malloc_0_nonnull=yes ac_cv_func_malloc_0_nonnull=yes \
        ac_cv_func_calloc_0_nonnull=yes ac_cv_func_realloc_0_nonnull=yes lt_cv_sys_lib_search_path_spec="" ac_cv_c_bigendian=no \
        ./configure --target=arm-unknown-linux-gnueabi \
            --host=arm-unknown-linux-gnueabi \
            --build=i686-pc-linux-gnu \
            --prefix="$PCCT_PREFIX" \
            --libdir="$PCCT_LIBDIR" \
            --includedir="$PCCT_INCLUDEDIR" \
            --without-ssl \
            $COMMON_CURL_ARGS
        ;;
    arm64|ARM64)
        echo "Build ARM64"
        ./configure --target=aarch64-linux-gnu \
            --host=aarch64-linux-gnu \
            --build=x86_64-pc-linux-gnu \
            --prefix="$PCCT_PREFIX" \
            --libdir="$PCCT_LIBDIR" \
            --includedir="$PCCT_INCLUDEDIR" \
            --without-ssl \
            $COMMON_CURL_ARGS
        ;;
    la64|LA64)
        echo "Build LA64"
        ./configure --target=loongarch64-unknown-linux-gnu \
            --host=loongarch64-unknown-linux-gnu \
            --build=x86_64-pc-linux-gnu \
            --prefix="$PCCT_PREFIX" \
            --libdir="$PCCT_LIBDIR" \
            --includedir="$PCCT_INCLUDEDIR" \
            --without-ssl \
            $COMMON_CURL_ARGS
        ;;
    *)
        echo "Please make sure the platform variable is x86/x64/arm/arm64/la64."
        exit 1
        ;;
esac

make -j"$(pcct_nproc)"
make install
