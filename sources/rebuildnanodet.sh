#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/build-common.sh"
. "$SCRIPT_DIR/dependency-versions.sh"

pcct_setup_target "${1:-}"

if [ "$PCCT_TARGET" != "x86" ]; then
    echo "NanoDet is supported only by the X86 static profile" >&2
    exit 1
fi

model_path="/dist/$NANODET_MODEL_ARCHIVE"
license_path="/dist/$NANODET_LICENSE_ARCHIVE"
build_dir="/tmp/pcct-nanodet-build"

echo "$NANODET_MODEL_SHA256  $model_path" | sha256sum -c -
echo "$NANODET_LICENSE_SHA256  $license_path" | sha256sum -c -

rm -rf "$build_dir"
mkdir -p "$build_dir"
cp "$model_path" "$build_dir/$NANODET_MODEL_ARCHIVE"

# GNU binary objects keep the pinned model inside the archive. The section is
# made read-only before archiving so deployed LaneApp processes cannot mutate it.
(
    cd "$build_dir"
    "$LD" -r -b binary "$NANODET_MODEL_ARCHIVE" -o nanodet-model.o
    "$OBJCOPY" \
        --rename-section .data=.rodata,alloc,load,readonly,data,contents \
        nanodet-model.o
    file nanodet-model.o | grep -q 'ELF 32-bit.*Intel 80386'
)

cat > "$build_dir/nanodet-model.c" <<'EOF'
#include <laneapp_nanodet_model.h>

extern const unsigned char _binary_nanodet_plus_m_416_mnn_mnn_start[];
extern const unsigned char _binary_nanodet_plus_m_416_mnn_mnn_end[];

const unsigned char *laneapp_nanodet_model_data(size_t *size)
{
    const unsigned char *data = _binary_nanodet_plus_m_416_mnn_mnn_start;
    if (size != NULL)
    {
        *size = (size_t)(_binary_nanodet_plus_m_416_mnn_mnn_end - data);
    }
    return data;
}
EOF

cat > "$build_dir/laneapp_nanodet_model.h" <<'EOF'
#ifndef LANEAPP_NANODET_MODEL_H
#define LANEAPP_NANODET_MODEL_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

const unsigned char *laneapp_nanodet_model_data(size_t *size);

#ifdef __cplusplus
}
#endif

#endif
EOF

"$CC" -std=c99 -O2 -fPIC -I"$build_dir" \
    -c "$build_dir/nanodet-model.c" -o "$build_dir/nanodet-model-accessor.o"
"$AR" rcs "$build_dir/liblaneapp-nanodet.a" \
    "$build_dir/nanodet-model-accessor.o" "$build_dir/nanodet-model.o"
"$RANLIB" "$build_dir/liblaneapp-nanodet.a"

mkdir -p "$PCCT_LIBDIR" "$PCCT_INCLUDEDIR" "$PCCT_PKGCONFIGDIR"
install -m 0644 "$build_dir/liblaneapp-nanodet.a" \
    "$PCCT_LIBDIR/liblaneapp-nanodet.a"
install -m 0644 "$build_dir/laneapp_nanodet_model.h" \
    "$PCCT_INCLUDEDIR/laneapp_nanodet_model.h"

cat > "$PCCT_PKGCONFIGDIR/laneapp-nanodet.pc" <<EOF
prefix=$PCCT_PREFIX
includedir=\${prefix}/include
libdir=\${prefix}/lib

Name: laneapp-nanodet
Description: LaneApp X86 static NanoDet-Plus-m-416 profile with embedded MNN model
Version: $NANODET_VERSION
Cflags: -I\${includedir} -I\${includedir}/opencv4
Libs: -L\${libdir} -llaneapp-nanodet
Libs.private: -Wl,--whole-archive -lMNN -Wl,--no-whole-archive -lopencv_imgproc -lopencv_core -l:libz.a -pthread -ldl -lm -lrt
EOF

license_dir="$PCCT_PREFIX/share/licenses/laneapp-nanodet"
mkdir -p "$license_dir"
install -m 0644 "$license_path" "$license_dir/NanoDet-LICENSE"
printf '%s  %s\n' "$NANODET_MODEL_SHA256" "$NANODET_MODEL_ARCHIVE" \
    > "$license_dir/MODEL-SHA256SUMS"
cat > "$license_dir/NOTICE.txt" <<EOF
LaneApp X86 NanoDet static profile

NanoDet model: $NANODET_MODEL_ARCHIVE
NanoDet release: $NANODET_VERSION
NanoDet license: Apache-2.0 (NanoDet-LICENSE)

MNN source: alibaba/MNN tag $MNN_VERSION
MNN license: Apache-2.0 (/usr/local/share/licenses/MNN-$MNN_VERSION/LICENSE.txt)

OpenCV source: opencv/opencv tag $OPENCV_VERSION
OpenCV license: BSD-3-Clause (/usr/local/share/licenses/opencv-$OPENCV_VERSION/LICENSE)

The NanoDet model is embedded as read-only ELF data in liblaneapp-nanodet.a.
No model file is required at LaneApp runtime.
EOF

test -f "$PCCT_LIBDIR/liblaneapp-nanodet.a"
test -f "$PCCT_PKGCONFIGDIR/laneapp-nanodet.pc"
nm "$PCCT_LIBDIR/liblaneapp-nanodet.a" | grep -q 'laneapp_nanodet_model_data'
nm "$PCCT_LIBDIR/liblaneapp-nanodet.a" | grep -q '_binary_nanodet_plus_m_416_mnn_mnn_start'
