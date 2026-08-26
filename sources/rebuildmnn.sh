#!/bin/sh

set -eu

if [ "$#" -ne 1 ]; then
    echo "usage: $0 <x86|arm>" >&2
    exit 1
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/build-common.sh"
. "$SCRIPT_DIR/dependency-versions.sh"

case "$1" in
    x86|arm) ;;
    *)
        echo "usage: $0 <x86|arm>" >&2
        exit 1
        ;;
esac

pcct_setup_target "$1"

# HyperLPR owns scheduling. MNN is therefore built as a CPU-only static engine
# with both OpenMP and its internal worker pool disabled.
if [ "$PCCT_TARGET" = "x86" ]; then
    patch -p1 < "$SCRIPT_DIR/patches/mnn-2.2.0-i386-simd.patch"
    mnn_use_sse=ON
    cmake_processor_arg="-DCMAKE_SYSTEM_PROCESSOR=i686"
else
    # The legacy ARM target is ARMv4T soft-float. Selecting processor "arm"
    # keeps MNN on its portable scalar CPU path instead of ARMv7 NEON assembly.
    mnn_use_sse=OFF
    cmake_processor_arg=
fi

cmake_toolchain_arg=
if [ "$PCCT_IS_CROSS" = "1" ]; then
    toolchain_file=$(mktemp)
    trap 'rm -f "$toolchain_file"' EXIT INT TERM
    pcct_write_cmake_toolchain "$toolchain_file"
    cmake_toolchain_arg="-DCMAKE_TOOLCHAIN_FILE=$toolchain_file"
fi

mkdir -p build
cd build
# shellcheck disable=SC2086
cmake .. $cmake_toolchain_arg $cmake_processor_arg \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$PCCT_PREFIX" \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DMNN_ARM82=OFF \
    -DMNN_AVX512=OFF \
    -DMNN_BUILD_BENCHMARK=OFF \
    -DMNN_BUILD_CODEGEN=OFF \
    -DMNN_BUILD_CONVERTER=OFF \
    -DMNN_BUILD_DEMO=OFF \
    -DMNN_BUILD_MINI=OFF \
    -DMNN_BUILD_OPENCV=OFF \
    -DMNN_BUILD_PROTOBUFFER=OFF \
    -DMNN_BUILD_QUANTOOLS=OFF \
    -DMNN_BUILD_SHARED_LIBS=OFF \
    -DMNN_BUILD_TEST=OFF \
    -DMNN_BUILD_TOOLS=OFF \
    -DMNN_BUILD_TRAIN=OFF \
    -DMNN_COREML=OFF \
    -DMNN_CUDA=OFF \
    -DMNN_EVALUATION=OFF \
    -DMNN_FORBID_MULTI_THREAD=ON \
    -DMNN_INTERNAL=OFF \
    -DMNN_JNI=OFF \
    -DMNN_METAL=OFF \
    -DMNN_NNAPI=OFF \
    -DMNN_NPU=OFF \
    -DMNN_ONEDNN=OFF \
    -DMNN_OPENCL=OFF \
    -DMNN_OPENGL=OFF \
    -DMNN_OPENMP=OFF \
    -DMNN_SEP_BUILD=OFF \
    -DMNN_SUPPORT_BF16=OFF \
    -DMNN_TENSORRT=OFF \
    -DMNN_USE_SSE="$mnn_use_sse" \
    -DMNN_USE_SYSTEM_LIB=OFF \
    -DMNN_USE_THREAD_POOL=OFF \
    -DMNN_VULKAN=OFF \
    -DMNN_WITH_PLUGIN=OFF

cmake --build . --target MNN -- -j"$(pcct_nproc)"
cmake --build . --target install -- -j"$(pcct_nproc)"

test -f "$PCCT_LIBDIR/libMNN.a"
if find "$PCCT_LIBDIR" -maxdepth 1 -name 'libMNN.so*' | grep -q .; then
    echo "MNN shared libraries remain in the $PCCT_TARGET static profile" >&2
    exit 1
fi

license_dir="$PCCT_PREFIX/share/licenses/MNN-$MNN_VERSION"
mkdir -p "$license_dir"
install -m 0644 "/dist/$MNN_LICENSE_ARCHIVE" "$license_dir/LICENSE.txt"
install -m 0644 ../README.md "$license_dir/README.md"
