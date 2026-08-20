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
    libva libva-drm libdrm
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

ldd --version | head -n 1 | grep -q '2\.23'
