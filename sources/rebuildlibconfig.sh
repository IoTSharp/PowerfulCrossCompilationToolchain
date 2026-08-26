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
pcct_bootstrap_autotools

export CFLAGS="${CFLAGS:-} -O2 -fPIC"
export CXXFLAGS="${CXXFLAGS:-} -O2 -fPIC"

./configure \
    --host="$PCCT_HOST" \
    --build="$PCCT_BUILD" \
    --prefix="$PCCT_PREFIX" \
    --libdir="$PCCT_LIBDIR" \
    --includedir="$PCCT_INCLUDEDIR" \
    --disable-shared \
    --enable-static \
    --disable-examples

make -j"$(pcct_nproc)"
make install
