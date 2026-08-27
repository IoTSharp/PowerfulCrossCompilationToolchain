#!/bin/sh

set -eu

if [ "$#" -ne 1 ]; then
    echo "usage: $0 <x86|x64|arm|arm64|la64>" >&2
    exit 1
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/build-common.sh"

case "$1" in
    x86|x64|X64|arm|arm64|ARM64|la64|LA64) ;;
    *)
        echo "unsupported target: $1" >&2
        exit 1
        ;;
esac

pcct_setup_target "$1"

sed -i 's|^//\(#define MBEDTLS_SSL_DTLS_SRTP\)|\1|' \
    include/mbedtls/mbedtls_config.h
make -j"$(pcct_nproc)" lib \
    CC="$CC" AR="$AR" PYTHON=python3 CFLAGS="-O2 -fPIC -std=c99"

mkdir -p "$PCCT_LIBDIR" "$PCCT_INCLUDEDIR/mbedtls" "$PCCT_INCLUDEDIR/psa" "$PCCT_PKGCONFIGDIR"
install -m 0644 \
    library/libmbedtls.a \
    library/libmbedx509.a \
    library/libmbedcrypto.a \
    "$PCCT_LIBDIR/"
cp -R include/mbedtls/. "$PCCT_INCLUDEDIR/mbedtls/"
cp -R include/psa/. "$PCCT_INCLUDEDIR/psa/"

cat > "$PCCT_PKGCONFIGDIR/mbedtls.pc" <<EOF
prefix=$PCCT_PREFIX
includedir=$PCCT_INCLUDEDIR
libdir=$PCCT_LIBDIR

Name: mbedTLS
Description: Static mbedTLS used by LaneApp curl, FFmpeg and libpeer
Version: 3.4.0
Cflags: -I\${includedir}
Libs: -L\${libdir} -lmbedtls -lmbedx509 -lmbedcrypto
Libs.private: -pthread
EOF

test -f "$PCCT_LIBDIR/libmbedtls.a"
test -f "$PCCT_INCLUDEDIR/mbedtls/ssl.h"
