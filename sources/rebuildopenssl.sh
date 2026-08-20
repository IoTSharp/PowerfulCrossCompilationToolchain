#!/bin/sh

set -eu

if [ "$#" -ne 1 ] || [ "$1" != "x86" ]; then
    echo "usage: $0 x86" >&2
    exit 1
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/build-common.sh"

pcct_setup_target x86
pcct_reset_build_tree

./Configure linux-x86 \
    no-shared \
    no-tests \
    no-ssl3 \
    no-comp \
    --prefix="$PCCT_PREFIX" \
    --openssldir=/etc/ssl \
    -fPIC

make -j"$(pcct_nproc)"
make install_sw

test -f "$PCCT_LIBDIR/libssl.a"
test -f "$PCCT_LIBDIR/libcrypto.a"
