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

# The LaneApp extensions keep upstream file loading and recognition intact
# while adding an embedded:// resolver and an extend-only observation ABI.
# HyperLPR stores this one source file with CRLF; normalize the extracted copy
# so GNU patch applies the pinned mixed-file patches consistently on Xenial.
embedded_patch="$SCRIPT_DIR/patches/hyperlpr3-embedded-models.patch"
observation_patch="$SCRIPT_DIR/patches/hyperlpr3-detector-observations.patch"
printf '%s  %s\n' "$HYPERLPR_EMBEDDED_PATCH_SHA256" "$embedded_patch" | \
    sha256sum -c -
printf '%s  %s\n' "$HYPERLPR_OBSERVATION_PATCH_SHA256" "$observation_patch" | \
    sha256sum -c -
sed -i 's/\r$//' cpp/src/inference_helper_module/inference_helper_mnn.cpp
patch -p1 < "$embedded_patch"
patch -p1 < "$observation_patch"

model_dir="resource/models/r2_mobile"
model_manifest="$(mktemp)"
patch_manifest="$(mktemp)"
build_dir="$(mktemp -d)"
trap 'rm -rf "$model_manifest" "$patch_manifest" "$build_dir"' EXIT INT TERM

cat > "$model_manifest" <<'EOF'
93BECA2566CCC8AD7FB5E5CE1BD87D158C3F1B2A6B48C1380366ABCF9F2C6F66  b320_backbone_h.mnn
B2B5C4126AAAD2C80901DDB8693005D73BC9856A80803DAE9C7D598033273841  b320_header_h.mnn
954D1592AF55297F12CD82847365C47DBE5CC5A07AFF54AACF8F49A91784BF37  b640x_backbone_h.mnn
AB946655FDBD0F9F8EE4EFA51AD3765F8FE757B12CE658D6944D3FB1DF7EACEA  b640x_head_h.mnn
0BBF5AEEE7E4D36BE2B545CADE9C025D70E0D0A2465DD701238EEA617C9EADB8  litemodel_cls_96xh.mnn
DAA9ED4E674EDED73FF51BFCA528ACEC35EDBBB63A500BE65C49F74E5739E043  rpv3_mdict_160h.mnn
EOF

cat > "$patch_manifest" <<EOF
$HYPERLPR_EMBEDDED_PATCH_SHA256  hyperlpr3-embedded-models.patch
$HYPERLPR_OBSERVATION_PATCH_SHA256  hyperlpr3-detector-observations.patch
EOF

(
    cd "$model_dir"
    sha256sum -c "$model_manifest"
)

# Build the bounded upstream source set manually so HyperLPR's normal CMake
# path cannot invoke FetchContent or produce a shared object.
object_index=0
for source_file in $(find cpp/src -type f -name '*.cpp' | sort); do
    object_index=$((object_index + 1))
    "$CXX" \
        -std=c++11 \
        -O2 \
        -fPIC \
        -DINFERENCE_HELPER_ENABLE_MNN \
        -Icpp/src \
        -Icpp/c_api \
        -Icpp/platform \
        -I"$PCCT_INCLUDEDIR" \
        -I"$PCCT_INCLUDEDIR/opencv4" \
        -c "$source_file" \
        -o "$build_dir/source-$object_index.o"
done

for source_file in $(find cpp/c_api -type f \( -name '*.cc' -o -name '*.cpp' \) | sort); do
    object_index=$((object_index + 1))
    "$CXX" \
        -std=c++11 \
        -O2 \
        -fPIC \
        -DINFERENCE_HELPER_ENABLE_MNN \
        -Icpp/src \
        -Icpp/c_api \
        -Icpp/platform \
        -I"$PCCT_INCLUDEDIR" \
        -I"$PCCT_INCLUDEDIR/opencv4" \
        -c "$source_file" \
        -o "$build_dir/capi-$object_index.o"
done

# GNU binary objects keep model bytes in the ELF archive. Rename the generated
# data section to read-only storage before archiving it with HyperLPR.
(
    cd "$model_dir"
    for model_file in \
        b320_backbone_h.mnn \
        b320_header_h.mnn \
        b640x_backbone_h.mnn \
        b640x_head_h.mnn \
        litemodel_cls_96xh.mnn \
        rpv3_mdict_160h.mnn; do
        model_name=${model_file%.mnn}
        "$LD" -r -b binary "$model_file" -o "$build_dir/model-$model_name.o"
        "$OBJCOPY" \
            --rename-section .data=.rodata,alloc,load,readonly,data,contents \
            "$build_dir/model-$model_name.o"
        case "$PCCT_TARGET" in
            x86) file "$build_dir/model-$model_name.o" | grep -q 'ELF 32-bit.*Intel 80386' ;;
            arm) file "$build_dir/model-$model_name.o" | grep -q 'ELF 32-bit.*ARM' ;;
        esac
    done
)

"$AR" rcs "$build_dir/libhyperlpr3.a" "$build_dir"/*.o
"$RANLIB" "$build_dir/libhyperlpr3.a"

# Exercise the production projection helper with synthetic detector/OCR stage
# outputs. This covers the gates that cannot be made deterministic with a
# blank model input while still linking the same object used by the archive.
cat > "$build_dir/detection-observation-smoke.cpp" <<'EOF'
#include "context_module/detection_observation.h"

#include <cmath>
#include <cstring>

int main() {
    hyper::PlateLocation location{};
    hyper::DetectionObservation observation{};
    hyper::TextLine text_line{};
    location.x1 = 10.0f;
    location.y1 = 20.0f;
    location.x2 = 110.0f;
    location.y2 = 60.0f;
    location.det_confidence = 0.91f;
    if (!hyper::InitializeDetectionObservation(
            location, 320, 240, &observation)) {
        return 1;
    }

    text_line.code = "TEST1234";
    text_line.average_score = 0.95f;
    hyper::ApplyDetectionObservationOcr(
            false, text_line, 0.80f, hyper::PlateType::BLUE, &observation);
    if (observation.ocr_valid || observation.ocr_confidence != 0.0f ||
        observation.plate_utf8[0] != '\0') {
        return 2;
    }

    text_line.average_score = 0.79f;
    hyper::ApplyDetectionObservationOcr(
            true, text_line, 0.80f, hyper::PlateType::BLUE, &observation);
    if (observation.ocr_valid ||
        std::fabs(observation.ocr_confidence - 0.79f) > 0.0001f ||
        observation.plate_utf8[0] != '\0') {
        return 3;
    }

    text_line.code = "SHORT";
    text_line.average_score = 0.95f;
    hyper::ApplyDetectionObservationOcr(
            true, text_line, 0.80f, hyper::PlateType::BLUE, &observation);
    if (observation.ocr_valid || observation.plate_utf8[0] != '\0') {
        return 4;
    }

    text_line.code = "TEST1234";
    hyper::ApplyDetectionObservationOcr(
            true, text_line, 0.80f, hyper::PlateType::BLUE, &observation);
    if (!observation.ocr_valid ||
        std::strcmp(observation.plate_utf8, "TEST1234") != 0 ||
        observation.plate_type != static_cast<int>(hyper::PlateType::BLUE) ||
        std::fabs(observation.detector_confidence - 0.91f) > 0.0001f ||
        observation.x1 != 10.0f || observation.y1 != 20.0f ||
        observation.x2 != 110.0f || observation.y2 != 60.0f) {
        return 5;
    }
    return 0;
}
EOF

"$CXX" \
    -std=c++11 \
    -O2 \
    -Icpp/src \
    -Icpp/c_api \
    -Icpp/platform \
    -I"$PCCT_INCLUDEDIR" \
    -I"$PCCT_INCLUDEDIR/opencv4" \
    "$build_dir/detection-observation-smoke.cpp" \
    "$build_dir/libhyperlpr3.a" \
    -o "$build_dir/detection-observation-smoke"
if [ "$PCCT_IS_CROSS" = "0" ]; then
    "$build_dir/detection-observation-smoke"
else
    file "$build_dir/detection-observation-smoke" | \
        grep -q 'ELF 32-bit LSB.*ARM.*EABI5'
fi

mkdir -p "$PCCT_LIBDIR" "$PCCT_INCLUDEDIR" "$PCCT_PKGCONFIGDIR"
install -m 0644 "$build_dir/libhyperlpr3.a" "$PCCT_LIBDIR/libhyperlpr3.a"
install -m 0644 cpp/c_api/hyper_lpr_sdk.h "$PCCT_INCLUDEDIR/hyper_lpr_sdk.h"
install -m 0644 cpp/c_api/hyper_lpr_sdk_memory.h "$PCCT_INCLUDEDIR/hyper_lpr_sdk_memory.h"
install -m 0644 cpp/c_api/hyper_lpr_sdk_observation.h \
    "$PCCT_INCLUDEDIR/hyper_lpr_sdk_observation.h"

cat > "$PCCT_PKGCONFIGDIR/laneapp-hyperlpr3.pc" <<EOF
prefix=$PCCT_PREFIX
includedir=\${prefix}/include
libdir=\${prefix}/lib
detection_observation_abi=$HYPERLPR_OBSERVATION_ABI_VERSION
detection_observation_max=$HYPERLPR_OBSERVATION_MAX

Name: laneapp-hyperlpr3
Description: LaneApp $PCCT_TARGET static HyperLPR3 profile with embedded models and detector observations
Version: $HYPERLPR_VERSION
Cflags: -I\${includedir}
Libs: -L\${libdir} -lhyperlpr3
Libs.private: -Wl,--whole-archive -lMNN -Wl,--no-whole-archive -lopencv_imgproc -lopencv_core -l:libz.a -pthread -ldl -lm -lrt
EOF

license_dir="$PCCT_PREFIX/share/licenses/laneapp-hyperlpr3"
mkdir -p "$license_dir"
install -m 0644 LICENSE "$license_dir/HyperLPR-LICENSE"
install -m 0644 "$model_manifest" "$license_dir/MODEL-SHA256SUMS"
install -m 0644 "$patch_manifest" "$license_dir/PATCH-SHA256SUMS"
cat > "$license_dir/CAPABILITIES.txt" <<EOF
symbol=HLPR_ContextObserveDetections
detection_observation_abi=$HYPERLPR_OBSERVATION_ABI_VERSION
detection_observation_max=$HYPERLPR_OBSERVATION_MAX
ocr_valid_gate=existing-confidence-and-minimum-8-byte-text
runtime_models=embedded-read-only
EOF
cat > "$license_dir/NOTICE.txt" <<EOF
LaneApp $PCCT_TARGET HyperLPR3 static profile

HyperLPR source: szad670401/HyperLPR
HyperLPR revision: $HYPERLPR_REVISION
HyperLPR packaged version: $HYPERLPR_VERSION
HyperLPR license: Apache-2.0 (HyperLPR-LICENSE)

MNN source: alibaba/MNN tag $MNN_VERSION
MNN license: Apache-2.0 ($PCCT_PREFIX/share/licenses/MNN-$MNN_VERSION/LICENSE.txt)

OpenCV source: opencv/opencv tag $OPENCV_VERSION
OpenCV license: BSD-3-Clause ($PCCT_PREFIX/share/licenses/opencv-$OPENCV_VERSION/LICENSE)

The six HyperLPR model files are embedded as read-only ELF objects in
libhyperlpr3.a. Their pinned hashes are recorded in MODEL-SHA256SUMS. No model
file is required at LaneApp runtime.

The LaneApp patches add embedded-model loading and the extend-only
HLPR_ContextObserveDetections ABI. Patch hashes are recorded in
PATCH-SHA256SUMS. The observation ABI returns at most
$HYPERLPR_OBSERVATION_MAX fixed items; detector boxes survive OCR rejection,
while rejected OCR text is always empty.
EOF

test -f "$PCCT_LIBDIR/libhyperlpr3.a"
test -f "$PCCT_PKGCONFIGDIR/laneapp-hyperlpr3.pc"
"$NM" "$PCCT_LIBDIR/libhyperlpr3.a" | grep -q 'HLPR_CreateContextFromEmbeddedModels'
"$NM" "$PCCT_LIBDIR/libhyperlpr3.a" | grep -q 'HLPR_ContextObserveDetections'
"$NM" "$PCCT_LIBDIR/libhyperlpr3.a" | grep -q 'HLPR_ContextUpdateStream'
"$NM" "$PCCT_LIBDIR/libhyperlpr3.a" | grep -q '_binary_rpv3_mdict_160h_mnn_start'
