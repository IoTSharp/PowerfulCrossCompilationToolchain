#!/bin/sh

set -eu

required_archives="
libcurl.a
libxml2.a
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
libusb-1.0.a
libopencv_core.a
libopencv_imgproc.a
libMNN.a
libhyperlpr3.a
liblaneapp-nanodet.a
"

for archive in $required_archives; do
    test -f "/usr/local/lib/$archive"
done

gcc --version | head -n 1 | grep -q '5\.4\.0'
clang-6.0 --version | head -n 1
gdb --version | head -n 1
valgrind --version

pkg-config --exists \
    laneapp-webrtc laneapp-lvgl libcurl libxml-2.0 libpq libusb-1.0 \
    laneapp-hyperlpr3 laneapp-nanodet libva libva-drm libdrm
test "$(pkg-config --modversion laneapp-hyperlpr3)" = "3.0.1.9307450"
test "$(pkg-config --modversion laneapp-nanodet)" = "1.0.0-alpha-1"
pkg-config --static --libs laneapp-hyperlpr3 | grep -q -- '-Wl,--whole-archive'
pkg-config --static --libs laneapp-hyperlpr3 | grep -q -- '-lMNN'
pkg-config --static --libs laneapp-hyperlpr3 | grep -q -- '-lopencv_imgproc'
pkg-config --static --libs laneapp-hyperlpr3 | grep -q -- '-lopencv_core'
pkg-config --static --libs laneapp-nanodet | grep -q -- '-Wl,--whole-archive'
pkg-config --static --libs laneapp-nanodet | grep -q -- '-lMNN'
pkg-config --static --libs laneapp-nanodet | grep -q -- '-lopencv_imgproc'
pkg-config --static --libs laneapp-nanodet | grep -q -- '-lopencv_core'
pkg-config --static --libs libcurl | grep -q -- '-lmbedtls'
pkg-config --static --libs libcurl | grep -q -- '-lmbedcrypto'
pkg-config --static --libs libcurl | grep -q -- '-l:libz.a'
pkg-config --static --libs laneapp-webrtc | grep -q -- '-l:libz.a'
pkg-config --static --libs laneapp-webrtc | grep -q -- '-lva'
pkg-config --static --libs laneapp-webrtc | grep -q -- '-lva-drm'
curl-config --ssl-backends | grep -qx 'mbedTLS'
if curl-config --features | grep -qx 'IPv6'; then
    echo "curl unexpectedly retained IPv6 support" >&2
    exit 1
fi

if find /usr/local/lib -maxdepth 1 -name 'libpq.so*' | grep -q .; then
    echo "PostgreSQL shared libraries remain in the static compiler profile" >&2
    exit 1
fi

if find /usr/local/lib -maxdepth 1 \
    \( -name 'libopencv_*.so*' -o -name 'libMNN.so*' -o -name 'libhyperlpr3.so*' -o -name 'liblaneapp-nanodet.so*' \) | \
    grep -q .; then
    echo "recognition shared libraries remain in the X86 static profile" >&2
    exit 1
fi

if find /usr/local -type f -name '*.mnn' | grep -q .; then
    echo "HyperLPR model files must be embedded, not installed for runtime" >&2
    exit 1
fi

model_hashes=/usr/local/share/licenses/laneapp-hyperlpr3/MODEL-SHA256SUMS
test -f "$model_hashes"
grep -qx '93BECA2566CCC8AD7FB5E5CE1BD87D158C3F1B2A6B48C1380366ABCF9F2C6F66  b320_backbone_h.mnn' "$model_hashes"
grep -qx 'B2B5C4126AAAD2C80901DDB8693005D73BC9856A80803DAE9C7D598033273841  b320_header_h.mnn' "$model_hashes"
grep -qx '954D1592AF55297F12CD82847365C47DBE5CC5A07AFF54AACF8F49A91784BF37  b640x_backbone_h.mnn' "$model_hashes"
grep -qx 'AB946655FDBD0F9F8EE4EFA51AD3765F8FE757B12CE658D6944D3FB1DF7EACEA  b640x_head_h.mnn' "$model_hashes"
grep -qx '0BBF5AEEE7E4D36BE2B545CADE9C025D70E0D0A2465DD701238EEA617C9EADB8  litemodel_cls_96xh.mnn' "$model_hashes"
grep -qx 'DAA9ED4E674EDED73FF51BFCA528ACEC35EDBBB63A500BE65C49F74E5739E043  rpv3_mdict_160h.mnn' "$model_hashes"

model_object_dir=$(mktemp -d)
(
    cd "$model_object_dir"
    ar x /usr/local/lib/libhyperlpr3.a model-b320_backbone_h.o
    readelf -S model-b320_backbone_h.o | grep -q '\.rodata'
    if readelf -S model-b320_backbone_h.o | grep -q '\.data'; then
        echo "embedded HyperLPR model retained a writable data section" >&2
        exit 1
    fi
)
rm -rf "$model_object_dir"

nanodet_model_hashes=/usr/local/share/licenses/laneapp-nanodet/MODEL-SHA256SUMS
test -f "$nanodet_model_hashes"
grep -qx '327AEC33F9B947144303A869AA4FFB3E69F12B4E40015C3DA2D415A0A05DF809  nanodet-plus-m_416_mnn.mnn' "$nanodet_model_hashes"

nanodet_object_dir=$(mktemp -d)
(
    cd "$nanodet_object_dir"
    ar x /usr/local/lib/liblaneapp-nanodet.a nanodet-model.o
    readelf -S nanodet-model.o | grep -q '\.rodata'
    if readelf -S nanodet-model.o | grep -q '\.data'; then
        echo "embedded NanoDet model retained a writable data section" >&2
        exit 1
    fi
)
rm -rf "$nanodet_object_dir"

if nm -A -u \
    /usr/local/lib/libcurl.a \
    /usr/local/lib/libpeer.a \
    /usr/local/lib/libsrtp2.a \
    /usr/local/lib/libavformat.a \
    /usr/local/lib/libavcodec.a 2>/dev/null | \
    grep -Eq ' (SSL_|OPENSSL_|EVP_|BIO_|X509_)'; then
    echo "OpenSSL symbols remain in the unified mbedTLS profile" >&2
    exit 1
fi

if ! nm -A /usr/local/lib/libavcodec.a 2>/dev/null | \
    grep -q ' ff_h264_vaapi_hwaccel$'; then
    echo "FFmpeg was built without the H.264 VAAPI hardware accelerator" >&2
    exit 1
fi

vaapi_runtime=/opt/pcct/runtime/vaapi
for runtime_path in \
    "$vaapi_runtime/lib/libva.so.1" \
    "$vaapi_runtime/lib/libva-drm.so.1" \
    "$vaapi_runtime/lib/libdrm.so.2" \
    "$vaapi_runtime/lib/libdrm_intel.so.1" \
    "$vaapi_runtime/lib/libpciaccess.so.0" \
    "$vaapi_runtime/dri/i965_drv_video.so" \
    "$vaapi_runtime/README.txt"; do
    test -e "$runtime_path"
done
file "$vaapi_runtime/dri/i965_drv_video.so" | grep -q 'ELF 32-bit.*Intel 80386'

printf '#include <lvgl.h>\nint main(void) { return 0; }\n' | \
    clang-6.0 $(pkg-config --cflags laneapp-lvgl) \
        -std=c11 -Werror -Wnewline-eof -x c -c \
        -o /tmp/pcct-lvgl-header-smoke.o -

cat > /tmp/pcct-static-smoke.c <<'EOF'
#include <curl/curl.h>
#include <libxml/parser.h>
#include <libavformat/avformat.h>
#include <libpq-fe.h>
#include <libusb.h>
#include <lvgl.h>
#include <mbedtls/ssl.h>
#include <peer.h>

int main(void) {
    mbedtls_ssl_context tls;
    libusb_context *usb = NULL;
    int result = 0;
    mbedtls_ssl_init(&tls);
    if (result == 0) {
        result = curl_global_init(CURL_GLOBAL_DEFAULT);
    }
    if (result == 0) {
        xmlInitParser();
        avformat_network_init();
        result = peer_init();
        if (result == 0 && PQlibVersion() <= 0) {
            result = 1;
        }
        if (result == 0) {
            result = libusb_init(&usb);
        }
        lv_init();
        lv_deinit();
        if (usb != NULL) {
            libusb_exit(usb);
        }
        peer_deinit();
        avformat_network_deinit();
        xmlCleanupParser();
        curl_global_cleanup();
    }
    mbedtls_ssl_free(&tls);
    return result;
}
EOF

gcc -std=gnu99 -o /tmp/pcct-static-smoke /tmp/pcct-static-smoke.c \
    $(pkg-config --cflags laneapp-webrtc laneapp-lvgl libcurl libxml-2.0 libpq libusb-1.0 mbedtls) \
    $(pkg-config --static --libs laneapp-webrtc laneapp-lvgl libcurl libxml-2.0 libpq libusb-1.0 mbedtls)

if readelf -d /tmp/pcct-static-smoke | \
    grep NEEDED | \
    grep -Eq 'lib(peer|avformat|avcodec|avutil|swscale|curl|xml2|ssl|crypto|srtp|mbedtls|pq|usb|laneapp|z\.so)'; then
    echo "static smoke binary retained a third-party shared dependency" >&2
    exit 1
fi

if ldd /tmp/pcct-static-smoke | grep -q 'not found'; then
    echo "static smoke binary has unresolved dynamic dependencies" >&2
    exit 1
fi

cat > /tmp/pcct-hyperlpr-smoke.cpp <<'EOF'
#include <hyper_lpr_sdk.h>
#include <hyper_lpr_sdk_memory.h>

#include <cstring>

int main() {
    HLPR_ContextConfiguration configuration;
    P_HLPR_Context context = NULL;
    int result = 1;
    std::memset(&configuration, 0, sizeof(configuration));
    configuration.max_num = 1;
    configuration.threads = 1;
    configuration.box_conf_threshold = 0.3f;
    configuration.nms_threshold = 0.5f;
    configuration.rec_confidence_threshold = 0.75f;
    configuration.det_level = DETECT_LEVEL_LOW;
    context = HLPR_CreateContextFromEmbeddedModels(&configuration);
    if (context != NULL && HLPR_ContextQueryStatus(context) == Ok) {
        result = 0;
    }
    if (context != NULL) {
        HLPR_ReleaseContext(context);
    }
    return result;
}
EOF

g++ -std=c++11 -static-libstdc++ -static-libgcc \
    -Wl,--gc-sections \
    -o /tmp/pcct-hyperlpr-smoke /tmp/pcct-hyperlpr-smoke.cpp \
    $(pkg-config --cflags --static --libs laneapp-hyperlpr3)

/tmp/pcct-hyperlpr-smoke

if readelf -d /tmp/pcct-hyperlpr-smoke | \
    grep NEEDED | \
    grep -Eq 'lib(hyperlpr|MNN|opencv|stdc\+\+|gcc_s|gomp)\.so'; then
    echo "HyperLPR static smoke retained a recognition or C++ runtime shared dependency" >&2
    exit 1
fi

if ldd /tmp/pcct-hyperlpr-smoke | grep -q 'not found'; then
    echo "HyperLPR static smoke has unresolved dynamic dependencies" >&2
    exit 1
fi

cat > /tmp/pcct-nanodet-smoke.cpp <<'EOF'
#include <MNN/Interpreter.hpp>
#include <laneapp_nanodet_model.h>

#include <cstddef>
#include <memory>

int main()
{
    size_t size = 0U;
    const unsigned char *data = laneapp_nanodet_model_data(&size);
    std::unique_ptr<MNN::Interpreter> interpreter;
    int result = 1;
    if (data != NULL && size == 4822536U)
    {
        interpreter.reset(MNN::Interpreter::createFromBuffer(data, size));
        result = interpreter.get() != NULL ? 0 : 1;
    }
    return result;
}
EOF

g++ -std=c++11 -static-libstdc++ -static-libgcc \
    -Wl,--gc-sections \
    -o /tmp/pcct-nanodet-smoke /tmp/pcct-nanodet-smoke.cpp \
    $(pkg-config --cflags --static --libs laneapp-nanodet)

/tmp/pcct-nanodet-smoke

if readelf -d /tmp/pcct-nanodet-smoke | \
    grep NEEDED | \
    grep -Eq 'lib(laneapp-nanodet|MNN|opencv|stdc\+\+|gcc_s|gomp)\.so'; then
    echo "NanoDet static smoke retained a recognition or C++ runtime shared dependency" >&2
    exit 1
fi

if ldd /tmp/pcct-nanodet-smoke | grep -q 'not found'; then
    echo "NanoDet static smoke has unresolved dynamic dependencies" >&2
    exit 1
fi

ldd --version | head -n 1 | grep -q '2\.23'
