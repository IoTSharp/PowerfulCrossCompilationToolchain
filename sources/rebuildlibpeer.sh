#!/bin/sh

set -eu

if [ "$#" -ne 1 ] || [ "$1" != "x86" ]; then
    echo "usage: $0 x86" >&2
    exit 1
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/build-common.sh"
. "$SCRIPT_DIR/dependency-versions.sh"

pcct_setup_target x86

if [ ! -f "$SCRIPT_DIR/libpeer-lanecamera.patch" ]; then
    echo "missing LaneApp libpeer compatibility patch" >&2
    exit 1
fi

libsrtp_root=$(mktemp -d)
objects_root=$(mktemp -d)
trap 'rm -rf "$libsrtp_root" "$objects_root"' EXIT INT TERM

tar -xf "/dist/$LIBSRTP_ARCHIVE" -C "$libsrtp_root" --strip-components=1

patch --dry-run --silent -p1 < "$SCRIPT_DIR/libpeer-lanecamera.patch"
patch -p1 < "$SCRIPT_DIR/libpeer-lanecamera.patch"

(
    cd "$libsrtp_root"
    test -x ./configure
    CC="$CC" CFLAGS="-O2 -fPIC -std=gnu99" \
        ./configure \
            --host="$PCCT_HOST" \
            --build="$PCCT_BUILD" \
            --prefix="$PCCT_PREFIX" \
            --libdir="$PCCT_LIBDIR" \
            --includedir="$PCCT_INCLUDEDIR" \
            --disable-shared \
            --enable-static \
            --disable-openssl
    make -j"$(pcct_nproc)" libsrtp2.a
    make install
)

mkdir -p "$PCCT_LIBDIR" "$PCCT_INCLUDEDIR/libpeer" "$PCCT_PKGCONFIGDIR"
test -f "$PCCT_LIBDIR/libmbedtls.a"
test -f "$PCCT_INCLUDEDIR/mbedtls/ssl.h"

peer_sources="address.c agent.c base64.c dtls_srtp.c ice.c mdns.c peer.c peer_connection.c ports.c rtcp.c rtp.c sctp.c sdp.c socket.c stun.c utils.c"
for source_name in $peer_sources; do
    "$CC" -std=gnu99 -O2 -fPIC -D_GNU_SOURCE \
        -DDISABLE_PEER_SIGNALING=1 -DCONFIG_USE_USRSCTP=0 \
        -Isrc \
        -I"$PCCT_INCLUDEDIR" \
        -c "src/$source_name" \
        -o "$objects_root/${source_name%.c}.o"
done

"$AR" rcs "$PCCT_LIBDIR/libpeer.a" "$objects_root"/*.o
"$RANLIB" "$PCCT_LIBDIR/libpeer.a"
install -m 0644 src/peer.h src/peer_connection.h src/peer_signaling.h \
    "$PCCT_INCLUDEDIR/libpeer/"

cat > "$PCCT_PKGCONFIGDIR/laneapp-webrtc.pc" <<EOF
prefix=$PCCT_PREFIX
includedir=$PCCT_INCLUDEDIR
libdir=$PCCT_LIBDIR

Name: laneapp-webrtc
Description: Static LaneApp libpeer and RTSP FFmpeg runtime
Version: 1.0
Cflags: -I\${includedir}/libpeer
Libs: -L\${libdir} -l:libpeer.a -l:libsrtp2.a -l:libmbedtls.a -l:libmbedx509.a -l:libmbedcrypto.a -l:libavformat.a -l:libavcodec.a -l:libswscale.a -l:libavutil.a -lva -lva-drm -ldrm -pthread -ldl -lm -lz
EOF

test -f "$PCCT_LIBDIR/libpeer.a"
test -f "$PCCT_INCLUDEDIR/libpeer/peer.h"
test -f "$PCCT_PKGCONFIGDIR/laneapp-webrtc.pc"
