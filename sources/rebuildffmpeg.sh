#!/bin/sh

set -eu

if [ "$#" -ne 1 ]; then
    echo "usage: $0 <x86|x64|arm|arm64|la64>" >&2
    exit 1
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/build-common.sh"

pcct_setup_target "$1"
pcct_reset_build_tree

COMMON_ARGS="\
    --disable-all \
    --disable-autodetect \
    --disable-programs \
    --disable-doc \
    --disable-podpages \
    --disable-debug \
    --disable-asm \
    --disable-symver \
    --enable-static \
    --disable-shared \
    --enable-pic \
    --enable-avcodec \
    --enable-avformat \
    --enable-avutil \
    --enable-swscale \
    --enable-decoders \
    --enable-demuxers \
    --enable-parsers \
    --enable-zlib"

export CFLAGS="${CFLAGS:-} -O2 -fPIC"
export CXXFLAGS="${CXXFLAGS:-} -O2 -fPIC"

CFG_ARGS="\
    --prefix=$PCCT_PREFIX \
    --libdir=$PCCT_LIBDIR \
    --incdir=$PCCT_INCLUDEDIR \
    --pkgconfigdir=$PCCT_PKGCONFIGDIR \
    --arch=$PCCT_ARCH \
    --target-os=linux \
    --cc=$CC \
    --cxx=$CXX \
    --ld=$CC \
    --ar=$AR \
    --ranlib=$RANLIB \
    --strip=$STRIP \
    --nm=$NM \
    --pkg-config=${PKG_CONFIG:-pkg-config}"

if [ "$PCCT_IS_CROSS" = "1" ]; then
    CFG_ARGS="$CFG_ARGS --enable-cross-compile --cross-prefix=$PCCT_CROSS_PREFIX --host-cc=${CC_FOR_BUILD:-gcc}"
    if [ -n "${SYSROOT:-}" ]; then
        CFG_ARGS="$CFG_ARGS --sysroot=$SYSROOT"
    fi
fi

if [ -f "$PCCT_LIBDIR/libmbedtls.a" ] && \
   [ -f "$PCCT_INCLUDEDIR/mbedtls/ssl.h" ]; then
    COMMON_ARGS="$COMMON_ARGS \
        --enable-version3 \
        --enable-network \
        --enable-mbedtls \
        --enable-decoder=h264 \
        --enable-encoder=mjpeg \
        --enable-parser=h264 \
        --enable-bsf=h264_mp4toannexb \
        --enable-demuxer=rtsp \
        --enable-demuxer=rtp \
        --enable-demuxer=h264 \
        --enable-protocol=file \
        --enable-protocol=http \
        --enable-protocol=https \
        --enable-protocol=tcp \
        --enable-protocol=tls \
        --enable-protocol=udp \
        --enable-protocol=rtp"
    if [ "$PCCT_TARGET" = "x86" ]; then
        COMMON_ARGS="$COMMON_ARGS \
            --enable-libdrm \
            --enable-vaapi \
            --enable-hwaccel=h264_vaapi"
    fi
else
    # x86Legacy does not build mbedTLS and retains its offline FFmpeg profile.
    COMMON_ARGS="$COMMON_ARGS --disable-network --enable-protocol=file"
fi

# shellcheck disable=SC2086
./configure $CFG_ARGS $COMMON_ARGS

make -j"$(pcct_nproc)"
make install

# glibc before 2.17 keeps clock_gettime in librt. Export it from libavutil so
# consumers of the legacy ARM sysroot can link FFmpeg statically via pkg-config.
if [ "$PCCT_TARGET" = "arm" ]; then
    sed -i '/^Libs.private:/ s/$/ -lrt/' "$PCCT_PKGCONFIGDIR/libavutil.pc"
fi
