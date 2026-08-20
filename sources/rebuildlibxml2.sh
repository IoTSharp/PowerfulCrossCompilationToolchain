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
pcct_bootstrap_autotools

export CPPFLAGS="${CPPFLAGS:-} -I$PCCT_INCLUDEDIR"
export LDFLAGS="${LDFLAGS:-} -L$PCCT_LIBDIR"
export CFLAGS="${CFLAGS:-} -O2 -fPIC"

./configure \
    --host="$PCCT_HOST" \
    --build="$PCCT_BUILD" \
    --prefix="$PCCT_PREFIX" \
    --libdir="$PCCT_LIBDIR" \
    --includedir="$PCCT_INCLUDEDIR" \
    --disable-shared \
    --enable-static \
    --with-zlib \
    --without-lzma \
    --without-python \
    --without-readline \
    --without-history \
    --without-icu

make -j"$(pcct_nproc)"
make install

test -f "$PCCT_LIBDIR/libxml2.a"
test -x "$PCCT_PREFIX/bin/xml2-config"
