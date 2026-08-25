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

# CMake 3.14 is built in the image before the recognition dependencies; no
# package manager or network access is needed by later dependency builds.
./bootstrap --prefix="$PCCT_PREFIX" --parallel="$(pcct_nproc)" -- \
    -DCMAKE_USE_OPENSSL=OFF
make -j"$(pcct_nproc)"
make install

cmake --version | head -n 1 | grep -qx "cmake version $CMAKE_VERSION"

license_dir="$PCCT_PREFIX/share/licenses/cmake-$CMAKE_VERSION"
mkdir -p "$license_dir"
install -m 0644 Copyright.txt "$license_dir/Copyright.txt"
