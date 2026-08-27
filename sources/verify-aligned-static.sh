#!/bin/sh

set -eu

if [ "$#" -ne 1 ]; then
    echo "usage: $0 <x64|arm|arm64|la64>" >&2
    exit 1
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/build-common.sh"
. "$SCRIPT_DIR/dependency-versions.sh"

pcct_setup_target "$1"

workdir=/tmp/pcct-aligned-static-smoke
pkg_config=${PKG_CONFIG:-pkg-config}
readelf=readelf
if [ -n "$PCCT_CROSS_PREFIX" ] && command -v "${PCCT_CROSS_PREFIX}readelf" >/dev/null 2>&1; then
    readelf=${PCCT_CROSS_PREFIX}readelf
fi

rm -rf "$workdir"
mkdir -p "$workdir"
trap 'rm -rf "$workdir"' EXIT INT TERM

required_archives="
libcurl.a
libxml2.a
libfreetype.a
libsqlite3.a
libusb-1.0.a
libavformat.a
libavcodec.a
libavutil.a
libswscale.a
libpeer.a
libsrtp2.a
libmbedtls.a
libmbedx509.a
libmbedcrypto.a
liblaneapp-lvgl.a
libpq.a
libpgcommon.a
libpgcommon_shlib.a
libpgport.a
libminigui.a
libmgext.a
libopencv_core.a
libopencv_imgproc.a
libMNN.a
libhyperlpr3.a
liblaneapp-nanodet.a
"

for archive in $required_archives; do
    archive_path="$PCCT_LIBDIR/$archive"
    test -f "$archive_path"
    member=$("$AR" t "$archive_path" | sed -n '1p')
    test -n "$member"
    "$AR" p "$archive_path" "$member" > "$workdir/archive-member.o"
    pcct_assert_target_file "$workdir/archive-member.o"
done

"$pkg_config" --exists \
    laneapp-webrtc laneapp-lvgl libcurl libxml-2.0 libpq libusb-1.0 \
    mbedtls opencv4 laneapp-hyperlpr3 laneapp-nanodet
test "$("$pkg_config" --modversion laneapp-hyperlpr3)" = "$HYPERLPR_VERSION"
test "$("$pkg_config" --variable=detection_observation_abi laneapp-hyperlpr3)" = \
    "$HYPERLPR_OBSERVATION_ABI_VERSION"
test "$("$pkg_config" --variable=detection_observation_max laneapp-hyperlpr3)" = \
    "$HYPERLPR_OBSERVATION_MAX"
test "$("$pkg_config" --modversion laneapp-nanodet)" = "$NANODET_VERSION"
"$pkg_config" --static --libs libcurl | grep -q -- '-lmbedtls'
"$pkg_config" --static --libs laneapp-webrtc | grep -q -- '-l:libpeer.a'
"$pkg_config" --static --libs laneapp-hyperlpr3 | grep -q -- '-lMNN'
"$pkg_config" --static --libs laneapp-nanodet | grep -q -- '-lMNN'
if [ "${PCCT_FORCE_STATIC_CXX:-0}" = "1" ]; then
    for package in laneapp-hyperlpr3 laneapp-nanodet; do
        package_libs=$("$pkg_config" --static --libs "$package")
        printf '%s\n' "$package_libs" | grep -q -- '-static-libstdc++'
        printf '%s\n' "$package_libs" | grep -q -- '-static-libgcc'
    done
    cxx_static_flags=
else
    cxx_static_flags="-static-libstdc++ -static-libgcc"
fi
test -x "$PCCT_PREFIX/bin/freetype-config"
"$NM" -g --defined-only "$PCCT_LIBDIR/libminigui.a" | \
    grep -q ' T InitFreeTypeFonts$'

if find "$PCCT_LIBDIR" -maxdepth 1 \
    \( -name 'libopencv_*.so*' -o -name 'libMNN.so*' -o \
       -name 'libhyperlpr3.so*' -o -name 'liblaneapp-nanodet.so*' \) | \
    grep -q .; then
    echo "recognition shared libraries remain in the $PCCT_TARGET profile" >&2
    exit 1
fi

if find "$PCCT_PREFIX" -type f -name '*.mnn' | grep -q .; then
    echo "recognition model files must be embedded, not installed for runtime" >&2
    exit 1
fi

for metadata in \
    "$PCCT_PREFIX/share/licenses/laneapp-hyperlpr3/MODEL-SHA256SUMS" \
    "$PCCT_PREFIX/share/licenses/laneapp-hyperlpr3/PATCH-SHA256SUMS" \
    "$PCCT_PREFIX/share/licenses/laneapp-hyperlpr3/CAPABILITIES.txt" \
    "$PCCT_PREFIX/share/licenses/laneapp-nanodet/MODEL-SHA256SUMS"; do
    test -f "$metadata"
done

cat > "$workdir/dependency-smoke.c" <<'EOF'
#include <curl/curl.h>
#include <libxml/parser.h>
#include <libavformat/avformat.h>
#include <libpq-fe.h>
#include <libusb.h>
#include <lvgl.h>
#include <mbedtls/ssl.h>
#include <peer.h>

int main(void)
{
    mbedtls_ssl_context tls;
    libusb_context *usb = NULL;
    int result;
    mbedtls_ssl_init(&tls);
    result = curl_global_init(CURL_GLOBAL_DEFAULT);
    xmlInitParser();
    avformat_network_init();
    if (result == 0) result = peer_init();
    if (result == 0 && PQlibVersion() <= 0) result = 1;
    if (result == 0) result = libusb_init(&usb);
    lv_init();
    lv_deinit();
    if (usb != NULL) libusb_exit(usb);
    peer_deinit();
    avformat_network_deinit();
    xmlCleanupParser();
    curl_global_cleanup();
    mbedtls_ssl_free(&tls);
    return result;
}
EOF

# shellcheck disable=SC2046
"$CC" -std=gnu99 -o "$workdir/dependency-smoke" "$workdir/dependency-smoke.c" \
    $("$pkg_config" --cflags --static --libs \
        laneapp-webrtc laneapp-lvgl libcurl libxml-2.0 libpq libusb-1.0 mbedtls)
pcct_assert_target_file "$workdir/dependency-smoke"

if "$readelf" -d "$workdir/dependency-smoke" | grep NEEDED | \
    grep -Eq 'lib(peer|avformat|avcodec|avutil|swscale|curl|xml2|srtp|mbedtls|pq|usb|laneapp|z\.so)'; then
    echo "dependency smoke retained a third-party shared dependency" >&2
    exit 1
fi

cat > "$workdir/webrtc-smoke.c" <<'EOF'
#include <libavformat/avformat.h>
#include <peer.h>

int main(void)
{
    avformat_network_init();
    if (peer_init() == 0) peer_deinit();
    avformat_network_deinit();
    return 0;
}
EOF

# shellcheck disable=SC2046
"$CC" -std=gnu99 -o "$workdir/webrtc-smoke" "$workdir/webrtc-smoke.c" \
    $("$pkg_config" --cflags --static --libs laneapp-webrtc)
pcct_assert_target_file "$workdir/webrtc-smoke"

if "$readelf" -d "$workdir/webrtc-smoke" | grep NEEDED | \
    grep -Eq 'lib(peer|avformat|avcodec|avutil|swscale|srtp|mbedtls|z\.so)'; then
    echo "WebRTC smoke retained a third-party shared dependency" >&2
    exit 1
fi

cat > "$workdir/hyperlpr-smoke.cpp" <<'EOF'
#include <hyper_lpr_sdk.h>
#include <hyper_lpr_sdk_observation.h>

int main()
{
    HLPR_ContextConfiguration configuration{};
    configuration.max_num = HLPR_MAX_DETECTION_OBSERVATIONS;
    configuration.threads = 1;
    configuration.box_conf_threshold = 0.3f;
    configuration.nms_threshold = 0.5f;
    configuration.rec_confidence_threshold = 0.75f;
    configuration.det_level = DETECT_LEVEL_LOW;
    P_HLPR_Context context = HLPR_CreateContextFromEmbeddedModels(&configuration);
    if (context == NULL) return 1;
    HLPR_ReleaseContext(context);
    return 0;
}
EOF

# shellcheck disable=SC2046
"$CXX" -std=c++11 $cxx_static_flags -Wl,--gc-sections \
    -o "$workdir/hyperlpr-smoke" "$workdir/hyperlpr-smoke.cpp" \
    $("$pkg_config" --cflags --static --libs laneapp-hyperlpr3)
pcct_assert_target_file "$workdir/hyperlpr-smoke"

cat > "$workdir/nanodet-smoke.cpp" <<'EOF'
#include <MNN/Interpreter.hpp>
#include <laneapp_nanodet_model.h>

#include <cstddef>

int main()
{
    size_t size = 0U;
    const unsigned char *data = laneapp_nanodet_model_data(&size);
    MNN::Interpreter *interpreter = MNN::Interpreter::createFromBuffer(data, size);
    if (interpreter == NULL || size != 4822536U) return 1;
    delete interpreter;
    return 0;
}
EOF

# shellcheck disable=SC2046
"$CXX" -std=c++11 $cxx_static_flags -Wl,--gc-sections \
    -o "$workdir/nanodet-smoke" "$workdir/nanodet-smoke.cpp" \
    $("$pkg_config" --cflags --static --libs laneapp-nanodet)
pcct_assert_target_file "$workdir/nanodet-smoke"

for binary in hyperlpr-smoke nanodet-smoke; do
    if "$readelf" -d "$workdir/$binary" | grep NEEDED | \
        grep -Eq 'lib(hyperlpr|laneapp-nanodet|MNN|opencv|stdc\+\+|gcc_s|gomp)\.so'; then
        echo "$binary retained a recognition or C++ runtime shared dependency" >&2
        exit 1
    fi
done

if [ -n "${PCCT_MAX_GLIBC:-}" ]; then
    max_glibc_major=${PCCT_MAX_GLIBC%%.*}
    max_glibc_minor=${PCCT_MAX_GLIBC#*.}
    case "$max_glibc_major:$max_glibc_minor" in
        *[!0-9:]*|:|*:)
            echo "PCCT_MAX_GLIBC must use a numeric major.minor value" >&2
            exit 1
            ;;
    esac

    for binary in dependency-smoke webrtc-smoke hyperlpr-smoke nanodet-smoke; do
        version_info=$("$readelf" --version-info "$workdir/$binary")
        if printf '%s\n' "$version_info" | \
            grep -oE 'GLIBC_[0-9]+\.[0-9]+' | \
            awk -F'[_.]' -v max_major="$max_glibc_major" \
                -v max_minor="$max_glibc_minor" '
                    $2 > max_major || ($2 == max_major && $3 > max_minor) {
                        exceeded = 1
                    }
                    END { exit exceeded ? 0 : 1 }
                '; then
            echo "$binary exceeds the glibc $PCCT_MAX_GLIBC baseline" >&2
            exit 1
        fi
    done
fi

if [ "$PCCT_IS_CROSS" = "0" ]; then
    "$workdir/dependency-smoke"
    "$workdir/webrtc-smoke"
    "$workdir/hyperlpr-smoke"
    "$workdir/nanodet-smoke"
fi

"$NM" -g --defined-only "$PCCT_LIBDIR/libhyperlpr3.a" | \
    grep -q ' T HLPR_ContextObserveDetections$'
"$NM" -g --defined-only "$PCCT_LIBDIR/libhyperlpr3.a" | \
    grep -q ' T HLPR_ContextUpdateStream$'

(
    cd "$workdir"
    "$AR" x "$PCCT_LIBDIR/libhyperlpr3.a" model-b320_backbone_h.o
    pcct_assert_target_arch model-b320_backbone_h.o
    "$readelf" -S model-b320_backbone_h.o | grep -q '\.rodata'
    ! "$readelf" -S model-b320_backbone_h.o | grep -q '\.data'

    "$AR" x "$PCCT_LIBDIR/liblaneapp-nanodet.a" nanodet-model.o
    pcct_assert_target_arch nanodet-model.o
    "$readelf" -S nanodet-model.o | grep -q '\.rodata'
    ! "$readelf" -S nanodet-model.o | grep -q '\.data'
)
