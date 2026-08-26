#!/bin/sh

set -eu

if [ "$#" -ne 1 ]; then
    echo "usage: $0 <x86|x64|arm|arm64|la64>" >&2
    exit 1
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/build-common.sh"

pcct_setup_target "$1"

build_dir=$(pwd)/pcct-build
rm -rf "$build_dir"
mkdir -p "$build_dir"

cmake_args="
    -S .
    -B $build_dir
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_INSTALL_PREFIX=$PCCT_PREFIX
    -DCMAKE_INSTALL_LIBDIR=$PCCT_LIBDIR
    -DCMAKE_INSTALL_INCLUDEDIR=$PCCT_INCLUDEDIR
    -DENABLE_SHARED=OFF
    -DENABLE_STATIC=ON
    -DWITH_SIMD=OFF
    -DWITH_JAVA=OFF
    -DWITH_TURBOJPEG=OFF
"

if [ "$PCCT_IS_CROSS" = "1" ]; then
    toolchain_file=$build_dir/pcct-toolchain.cmake
    pcct_write_cmake_toolchain "$toolchain_file"
    cmake_args="$cmake_args -DCMAKE_TOOLCHAIN_FILE=$toolchain_file"
fi

# shellcheck disable=SC2086
cmake $cmake_args
cmake --build "$build_dir" --parallel "$(pcct_nproc)"
cmake --install "$build_dir"

rm -f "$PCCT_LIBDIR"/libjpeg.so* "$PCCT_LIBDIR"/libturbojpeg.so*
