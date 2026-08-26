#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/build-common.sh"
. "$SCRIPT_DIR/dependency-versions.sh"

pcct_setup_target arm

workdir=/tmp/pcct-arm-gcc54-smoke
cc=$CC
cxx=$CXX
ar=$AR
nm=$NM
readelf=/usr/bin/arm-linux-gnueabi-readelf
sysroot=$SYSROOT
pkg_config=$PKG_CONFIG
cxx_archive=/usr/lib/gcc-cross/arm-linux-gnueabi/5/libstdc++.a

rm -rf "$workdir"
mkdir -p "$workdir"

cat > "$workdir/probe.c" <<'EOF'
#include <stdio.h>

int main(void)
{
    puts("PCCT_ARM_GCC54_OK");
    return 0;
}
EOF

"$cc" --version | head -n 1 | grep -q '5\.4\.0'
test "$("$cc" -print-sysroot)" = "$sysroot"
"$cc" -O2 "$workdir/probe.c" -o "$workdir/probe-dynamic"
"$cc" -O2 -static "$workdir/probe.c" -o "$workdir/probe-static"
file "$workdir/probe-dynamic" | grep -q 'ELF 32-bit LSB executable, ARM, EABI5'
file "$workdir/probe-static" | grep -q 'ELF 32-bit LSB executable, ARM, EABI5'
"$readelf" -l "$workdir/probe-dynamic" | grep -q '/lib/ld-linux.so.3'
"$readelf" -h "$workdir/probe-dynamic" | grep -q 'soft-float ABI'

if "$readelf" --version-info "$workdir/probe-dynamic" | \
    grep -Eq 'GLIBC_2\.(1[4-9]|[2-9][0-9])'; then
    echo "ARM probe exceeds the legacy glibc 2.13 baseline" >&2
    exit 1
fi

test "$(printf '' | "$cc" -dM -E - | awk '/_FORTIFY_SOURCE/ { print $3 }')" = "0"
test "$(printf '' | "$cxx" -dM -E -x c++ - | \
    awk '/_GLIBCXX_USE_CXX11_ABI/ { print $3 }')" = "0"
test "$("$cxx" -print-file-name=libstdc++.a)" = "$cxx_archive"
"$pkg_config" --static --libs libcurl | grep -q -- '-lz'
"$pkg_config" --static --libs libpq | grep -q -- '-l:libpgcommon_shlib.a'
"$pkg_config" --static --libs libpq | grep -q -- '-l:libpgport.a'
test -f "$sysroot/usr/include/minigui/common.h"
test -f "$sysroot/usr/lib/libminigui.a"
test -f "$sysroot/usr/lib/libmgext.a"
test -f "$sysroot/usr/etc/MiniGUI.cfg"

for archive in libminigui.a libmgext.a; do
    member=$("$ar" t "$sysroot/usr/lib/$archive" | sed -n '1p')
    test -n "$member"
    "$ar" p "$sysroot/usr/lib/$archive" "$member" > "$workdir/$archive.o"
    file "$workdir/$archive.o" | grep -q 'ELF 32-bit LSB relocatable, ARM, EABI5'
done

required_recognition_archives="
libopencv_core.a
libopencv_imgproc.a
libMNN.a
libhyperlpr3.a
liblaneapp-nanodet.a
"

for archive in $required_recognition_archives; do
    archive_path="$sysroot/usr/lib/$archive"
    test -f "$archive_path"
    member=$("$ar" t "$archive_path" | sed -n '1p')
    test -n "$member"
    "$ar" p "$archive_path" "$member" > "$workdir/$archive.o"
    file "$workdir/$archive.o" | grep -q 'ELF 32-bit LSB relocatable, ARM, EABI5'
done

"$pkg_config" --exists laneapp-hyperlpr3 laneapp-nanodet opencv4
test "$("$pkg_config" --modversion laneapp-hyperlpr3)" = "$HYPERLPR_VERSION"
test "$("$pkg_config" --variable=detection_observation_abi laneapp-hyperlpr3)" = "$HYPERLPR_OBSERVATION_ABI_VERSION"
test "$("$pkg_config" --variable=detection_observation_max laneapp-hyperlpr3)" = "$HYPERLPR_OBSERVATION_MAX"
test "$("$pkg_config" --modversion laneapp-nanodet)" = "$NANODET_VERSION"
"$pkg_config" --static --libs laneapp-hyperlpr3 | grep -q -- '-lMNN'
"$pkg_config" --static --libs laneapp-hyperlpr3 | grep -q -- '-lopencv_imgproc'
"$pkg_config" --static --libs laneapp-nanodet | grep -q -- '-lMNN'

if find "$sysroot/usr/lib" -maxdepth 1 \
    \( -name 'libopencv_*.so*' -o -name 'libMNN.so*' -o \
       -name 'libhyperlpr3.so*' -o -name 'liblaneapp-nanodet.so*' \) | \
    grep -q .; then
    echo "recognition shared libraries remain in the ARM static profile" >&2
    exit 1
fi

if find "$sysroot/usr" -type f -name '*.mnn' | grep -q .; then
    echo "recognition model files must be embedded, not installed for runtime" >&2
    exit 1
fi

model_hashes="$sysroot/usr/share/licenses/laneapp-hyperlpr3/MODEL-SHA256SUMS"
patch_hashes="$sysroot/usr/share/licenses/laneapp-hyperlpr3/PATCH-SHA256SUMS"
nanodet_hashes="$sysroot/usr/share/licenses/laneapp-nanodet/MODEL-SHA256SUMS"
test -f "$model_hashes"
test -f "$patch_hashes"
test -f "$nanodet_hashes"
grep -qx '93BECA2566CCC8AD7FB5E5CE1BD87D158C3F1B2A6B48C1380366ABCF9F2C6F66  b320_backbone_h.mnn' "$model_hashes"
grep -qx "$HYPERLPR_EMBEDDED_PATCH_SHA256  hyperlpr3-embedded-models.patch" "$patch_hashes"
grep -qx "$HYPERLPR_OBSERVATION_PATCH_SHA256  hyperlpr3-detector-observations.patch" "$patch_hashes"
grep -qx "$NANODET_MODEL_SHA256  $NANODET_MODEL_ARCHIVE" "$nanodet_hashes"

(
    cd "$workdir"
    "$ar" x "$sysroot/usr/lib/libhyperlpr3.a" model-b320_backbone_h.o
    "$readelf" -S model-b320_backbone_h.o | grep -q '\.rodata'
    if "$readelf" -S model-b320_backbone_h.o | grep -q '\.data'; then
        echo "embedded HyperLPR model retained a writable data section" >&2
        exit 1
    fi

    "$ar" x "$sysroot/usr/lib/liblaneapp-nanodet.a" nanodet-model.o
    "$readelf" -S nanodet-model.o | grep -q '\.rodata'
    if "$readelf" -S nanodet-model.o | grep -q '\.data'; then
        echo "embedded NanoDet model retained a writable data section" >&2
        exit 1
    fi
)

cat > "$workdir/hyperlpr-smoke.cpp" <<'EOF'
#include <hyper_lpr_sdk.h>
#include <hyper_lpr_sdk_memory.h>
#include <hyper_lpr_sdk_observation.h>

#include <cstddef>
#include <cstring>

static_assert(sizeof(HLPR_DetectionObservation) == 100U,
              "LaneApp observation item ABI changed");
static_assert(offsetof(HLPR_DetectionObservation, plate_utf8) == 36U,
              "LaneApp observation text offset changed");
static_assert(sizeof(HLPR_DetectionObservationBatch) == 516U,
              "LaneApp observation batch ABI changed");
static_assert(offsetof(HLPR_DetectionObservationBatch, items) == 16U,
              "LaneApp observation item-array offset changed");

int main()
{
    HLPR_ContextConfiguration configuration;
    P_HLPR_Context context = NULL;
    std::memset(&configuration, 0, sizeof(configuration));
    configuration.max_num = HLPR_MAX_DETECTION_OBSERVATIONS;
    context = HLPR_CreateContextFromEmbeddedModels(&configuration);
    if (context != NULL)
    {
        HLPR_ReleaseContext(context);
    }
    return 0;
}
EOF

# shellcheck disable=SC2046
"$cxx" -std=c++11 -static-libstdc++ -static-libgcc -Wl,--gc-sections \
    -o "$workdir/hyperlpr-smoke" "$workdir/hyperlpr-smoke.cpp" \
    $("$pkg_config" --cflags --static --libs laneapp-hyperlpr3)

cat > "$workdir/nanodet-smoke.cpp" <<'EOF'
#include <MNN/Interpreter.hpp>
#include <laneapp_nanodet_model.h>

#include <cstddef>

int main()
{
    size_t size = 0U;
    const unsigned char *data = laneapp_nanodet_model_data(&size);
    MNN::Interpreter *interpreter = MNN::Interpreter::createFromBuffer(data, size);
    delete interpreter;
    return 0;
}
EOF

# shellcheck disable=SC2046
"$cxx" -std=c++11 -static-libstdc++ -static-libgcc -Wl,--gc-sections \
    -o "$workdir/nanodet-smoke" "$workdir/nanodet-smoke.cpp" \
    $("$pkg_config" --cflags --static --libs laneapp-nanodet)

for binary in hyperlpr-smoke nanodet-smoke; do
    file "$workdir/$binary" | grep -q 'ELF 32-bit LSB.*ARM.*EABI5'
    "$readelf" -h "$workdir/$binary" | grep -q 'soft-float ABI'
    if "$readelf" -d "$workdir/$binary" | \
        grep NEEDED | \
        grep -Eq 'lib(hyperlpr|laneapp-nanodet|MNN|opencv|stdc\+\+|gcc_s|gomp|atomic)\.so'; then
        echo "$binary retained a recognition or C++ runtime shared dependency" >&2
        exit 1
    fi
    if "$readelf" --version-info "$workdir/$binary" | \
        grep -Eq 'GLIBC_2\.(1[4-9]|[2-9][0-9])'; then
        echo "$binary exceeds the legacy glibc 2.13 baseline" >&2
        exit 1
    fi
done

"$nm" -g --defined-only "$sysroot/usr/lib/libhyperlpr3.a" | \
    grep -q ' T HLPR_ContextObserveDetections$'
"$nm" -g --defined-only "$sysroot/usr/lib/libhyperlpr3.a" | \
    grep -q ' T HLPR_ContextUpdateStream$'

rm -rf "$workdir"
