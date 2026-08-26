#!/bin/sh

set -eu

# Conservative dependency baseline shared by the legacy and Ubuntu 16 images.
# Keep source revisions compatible with GCC 4.6/4.7 unless a dependency is
# explicitly built only by the Ubuntu 16 X86 image.

OPENSSL_VERSION=1.1.1w
OPENSSL_TAG=OpenSSL_1_1_1w
OPENSSL_ARCHIVE="openssl-${OPENSSL_TAG}.tar.gz"
OPENSSL_URL="https://github.com/openssl/openssl/archive/refs/tags/${OPENSSL_TAG}.tar.gz"
OPENSSL_SHA256="2130E8C2FB3B79D1086186F78E59E8BC8D1A6AEDF17AB3907F4CB9AE20918C41"

CURL_VERSION=8.10.1
CURL_TAG=curl-8_10_1
CURL_ARCHIVE="curl-${CURL_VERSION}.tar.gz"
CURL_URL="https://github.com/curl/curl/releases/download/${CURL_TAG}/${CURL_ARCHIVE}"
CURL_SHA256="D15EBAB765D793E2E96DB090F0E172D127859D78CA6F6391D7EAFECFD894BBC0"

LIBXML2_VERSION=2.12.10
LIBXML2_ARCHIVE="libxml2-${LIBXML2_VERSION}.tar.xz"
LIBXML2_URL="https://download.gnome.org/sources/libxml2/2.12/${LIBXML2_ARCHIVE}"
LIBXML2_SHA256="C3D8C0C34AA39098F66576FE51969DB12A5100B956233DC56506F7A8679BE995"

FREETYPE_VERSION=2.13.3
FREETYPE_TAG=VER-2-13-3
FREETYPE_ARCHIVE="freetype-${FREETYPE_TAG}.tar.gz"
FREETYPE_URL="https://github.com/freetype/freetype/archive/refs/tags/${FREETYPE_TAG}.tar.gz"
FREETYPE_SHA256="BC5C898E4756D373E0D991BAB053036C5EB2AA7C0D5C67E8662DDC6DA40C4103"

LIBUSB_VERSION=1.0.23
LIBUSB_TAG=v1.0.23
LIBUSB_ARCHIVE="libusb-${LIBUSB_VERSION}.tar.bz2"
LIBUSB_URL="https://github.com/libusb/libusb/releases/download/${LIBUSB_TAG}/${LIBUSB_ARCHIVE}"
LIBUSB_SHA256="DB11C06E958A82DAC52CF3C65CB4DD2C3F339C8A988665110E0D24D19312AD8D"

SQLITE_VERSION=3.51.2
SQLITE_TAG=version-3.51.2
SQLITE_ARCHIVE="sqlite-${SQLITE_TAG}.tar.gz"
SQLITE_URL="https://github.com/sqlite/sqlite/archive/refs/tags/${SQLITE_TAG}.tar.gz"
SQLITE_SHA256="2F35E1E63E8D4B57184DA77A56CABC941F52BEB1398023B1FFED97389C3FEF6F"

FFMPEG_VERSION=4.4.5
FFMPEG_TAG=n4.4.5
FFMPEG_ARCHIVE="ffmpeg-${FFMPEG_TAG}.tar.gz"
FFMPEG_URL="https://github.com/FFmpeg/FFmpeg/archive/refs/tags/${FFMPEG_TAG}.tar.gz"
FFMPEG_SHA256="36D12B77917CEF669484C39FE9ECEA6FEDC26D0F12A5B01C154BCC64AFF86019"

# LaneApp HyperLPR3 is built for X86 and legacy ARM32. These revisions remain
# shared so each image fetches once and LaneApp builds stay offline.
CMAKE_VERSION=3.14.7
CMAKE_ARCHIVE="cmake-${CMAKE_VERSION}.tar.gz"
CMAKE_URL="https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/${CMAKE_ARCHIVE}"
CMAKE_SHA256="9221993E0AF3E6D10124D840FF24F5B2F3B884416FCA04D3312CB0388DEC1385"

OPENCV_VERSION=4.5.1
OPENCV_ARCHIVE="opencv-${OPENCV_VERSION}.tar.gz"
OPENCV_URL="https://github.com/opencv/opencv/archive/${OPENCV_VERSION}.tar.gz"
OPENCV_SHA256="E27FE5B168918AB60D58D7ACE2BD82DD14A4D0BD1D3AE182952C2113F5637513"

MNN_VERSION=2.2.0
MNN_ARCHIVE="mnn-${MNN_VERSION}.tar.gz"
MNN_URL="https://github.com/alibaba/MNN/archive/refs/tags/${MNN_VERSION}.tar.gz"
MNN_SHA256="0FD4EF9EA65128DC9964045FA6359107054BF471460D0B581B75565BA193D084"
MNN_LICENSE_REVISION=cda4a6f441b8ed58cc5c6f389359e5851e9d6322
MNN_LICENSE_ARCHIVE="mnn-license-${MNN_LICENSE_REVISION}.txt"
MNN_LICENSE_URL="https://raw.githubusercontent.com/alibaba/MNN/${MNN_LICENSE_REVISION}/LICENSE.txt"
MNN_LICENSE_SHA256="A830D59C4F98D110E0540D0581EFADA06192BA6E798434307D1794B07A290302"

HYPERLPR_VERSION=3.0.1.9307450.1
HYPERLPR_REVISION=9307450f7b7915be18f23a539ec05b41fe6629f4
HYPERLPR_ARCHIVE="hyperlpr-${HYPERLPR_REVISION}.tar.gz"
HYPERLPR_URL="https://github.com/szad670401/HyperLPR/archive/${HYPERLPR_REVISION}.tar.gz"
HYPERLPR_SHA256="40FE119E652AC0241A27F6CF868A11773E9E19777B0A6A63F594C78F46D77F68"
HYPERLPR_EMBEDDED_PATCH_SHA256="14DB7042A4BA4F1A9AB77B2EF4E4E4FF10A70A7AE1ACC8F4FAD814CC82224742"
HYPERLPR_OBSERVATION_PATCH_SHA256="187DFC88414B3BBE120CA96AC33685EBA127457E88BD39DC117A687D67152543"
HYPERLPR_OBSERVATION_ABI_VERSION=1
HYPERLPR_OBSERVATION_MAX=5

# NanoDet is built for X86 and legacy ARM32. The released MNN model is embedded
# into a static archive, so targets never load model files.
NANODET_VERSION=1.0.0-alpha-1
NANODET_MODEL_ARCHIVE="nanodet-plus-m_416_mnn.mnn"
NANODET_MODEL_URL="https://github.com/RangiLyu/nanodet/releases/download/v1.0.0-alpha-1/${NANODET_MODEL_ARCHIVE}"
NANODET_MODEL_SHA256="327AEC33F9B947144303A869AA4FFB3E69F12B4E40015C3DA2D415A0A05DF809"
NANODET_LICENSE_ARCHIVE="nanodet-${NANODET_VERSION}-LICENSE"
NANODET_LICENSE_URL="https://raw.githubusercontent.com/RangiLyu/nanodet/v1.0.0-alpha-1/LICENSE"
NANODET_LICENSE_SHA256="B074CCA89569A8F57266E4EE8F81A0C728433D5525D98608FF708FEC91034312"

LVGL_VERSION=9.5.0
LVGL_TAG=v9.5.0
LVGL_ARCHIVE="lvgl-${LVGL_TAG}.tar.gz"
LVGL_URL="https://github.com/lvgl/lvgl/archive/refs/tags/${LVGL_TAG}.tar.gz"
LVGL_SHA256="34A955CDF3A2D005507B704E87357AF669A114523B6D3F77B5344FDC68717BC6"

LANEAPP_LVGL_VERSION=9.3.0
LANEAPP_LVGL_TAG=v9.3.0
LANEAPP_LVGL_ARCHIVE="laneapp-lvgl-${LANEAPP_LVGL_TAG}.tar.gz"
LANEAPP_LVGL_URL="https://github.com/lvgl/lvgl/archive/refs/tags/${LANEAPP_LVGL_TAG}.tar.gz"
LANEAPP_LVGL_SHA256="4933BECFD3603B29158A5D04138139582836EF2BC17BEB6C39DCCDA9CB0D32E7"

LIBPEER_VERSION=638addcca88662533f5fc7d7fe2cc4d218312764
LIBPEER_ARCHIVE="libpeer-${LIBPEER_VERSION}.tar.gz"
LIBPEER_URL="https://github.com/IoTSharp/libpeer/archive/${LIBPEER_VERSION}.tar.gz"
LIBPEER_SHA256="B0CE4FB6E0537FFE2D46A0CB0F0AD651E76D19C7D7FCF166F03B1A5F5EEDC5CE"

LIBSRTP_VERSION=90d05bf8980d16e4ac3f16c19b77e296c4bc207b
LIBSRTP_ARCHIVE="libsrtp-${LIBSRTP_VERSION}.tar.gz"
LIBSRTP_URL="https://github.com/cisco/libsrtp/archive/${LIBSRTP_VERSION}.tar.gz"
LIBSRTP_SHA256="0CAEC0CF84569463C1FF186FE6A92101FE9036375140DD4588170787925F5335"

MBEDTLS_VERSION=1873d3bfc2da771672bd8e7e8f41f57e0af77f33
MBEDTLS_ARCHIVE="mbedtls-${MBEDTLS_VERSION}.tar.gz"
MBEDTLS_URL="https://github.com/Mbed-TLS/mbedtls/archive/${MBEDTLS_VERSION}.tar.gz"
MBEDTLS_SHA256="E639DB55558CE853D4AD916C0EC89F04263F36DA4BE582A6BB7E1F22A59D7216"

POSTGRESQL_VERSION=17.2
POSTGRESQL_TAG=REL_17_2
POSTGRESQL_ARCHIVE="postgresql-${POSTGRESQL_TAG}.tar.gz"
POSTGRESQL_URL="https://github.com/postgres/postgres/archive/refs/tags/${POSTGRESQL_TAG}.tar.gz"
# Verified from downloaded source archive (REL_17_2.tar.gz)
POSTGRESQL_SHA256="DEA967B2C9FD112C27478354E3FCF8D5A5F00ACC7CC6D8D185C3FAE70B6EB67A"

pcct_dep_archive() {
    case "$1" in
        openssl) echo "$OPENSSL_ARCHIVE" ;;
        curl) echo "$CURL_ARCHIVE" ;;
        libxml2) echo "$LIBXML2_ARCHIVE" ;;
        freetype) echo "$FREETYPE_ARCHIVE" ;;
        libusb) echo "$LIBUSB_ARCHIVE" ;;
        sqlite) echo "$SQLITE_ARCHIVE" ;;
        ffmpeg) echo "$FFMPEG_ARCHIVE" ;;
        cmake) echo "$CMAKE_ARCHIVE" ;;
        opencv) echo "$OPENCV_ARCHIVE" ;;
        mnn) echo "$MNN_ARCHIVE" ;;
        mnn-license) echo "$MNN_LICENSE_ARCHIVE" ;;
        hyperlpr) echo "$HYPERLPR_ARCHIVE" ;;
        nanodet-model) echo "$NANODET_MODEL_ARCHIVE" ;;
        nanodet-license) echo "$NANODET_LICENSE_ARCHIVE" ;;
        lvgl) echo "$LVGL_ARCHIVE" ;;
        laneapp-lvgl) echo "$LANEAPP_LVGL_ARCHIVE" ;;
        libpeer) echo "$LIBPEER_ARCHIVE" ;;
        libsrtp) echo "$LIBSRTP_ARCHIVE" ;;
        mbedtls) echo "$MBEDTLS_ARCHIVE" ;;
        postgresql) echo "$POSTGRESQL_ARCHIVE" ;;
        *)
            echo "unknown dependency: $1" >&2
            return 1
            ;;
    esac
}

pcct_dep_url() {
    case "$1" in
        openssl) echo "$OPENSSL_URL" ;;
        curl) echo "$CURL_URL" ;;
        libxml2) echo "$LIBXML2_URL" ;;
        freetype) echo "$FREETYPE_URL" ;;
        libusb) echo "$LIBUSB_URL" ;;
        sqlite) echo "$SQLITE_URL" ;;
        ffmpeg) echo "$FFMPEG_URL" ;;
        cmake) echo "$CMAKE_URL" ;;
        opencv) echo "$OPENCV_URL" ;;
        mnn) echo "$MNN_URL" ;;
        mnn-license) echo "$MNN_LICENSE_URL" ;;
        hyperlpr) echo "$HYPERLPR_URL" ;;
        nanodet-model) echo "$NANODET_MODEL_URL" ;;
        nanodet-license) echo "$NANODET_LICENSE_URL" ;;
        lvgl) echo "$LVGL_URL" ;;
        laneapp-lvgl) echo "$LANEAPP_LVGL_URL" ;;
        libpeer) echo "$LIBPEER_URL" ;;
        libsrtp) echo "$LIBSRTP_URL" ;;
        mbedtls) echo "$MBEDTLS_URL" ;;
        postgresql) echo "$POSTGRESQL_URL" ;;
        *)
            echo "unknown dependency: $1" >&2
            return 1
            ;;
    esac
}

pcct_dep_sha256() {
    case "$1" in
        openssl) echo "$OPENSSL_SHA256" ;;
        curl) echo "$CURL_SHA256" ;;
        libxml2) echo "$LIBXML2_SHA256" ;;
        freetype) echo "$FREETYPE_SHA256" ;;
        libusb) echo "$LIBUSB_SHA256" ;;
        sqlite) echo "$SQLITE_SHA256" ;;
        ffmpeg) echo "$FFMPEG_SHA256" ;;
        cmake) echo "$CMAKE_SHA256" ;;
        opencv) echo "$OPENCV_SHA256" ;;
        mnn) echo "$MNN_SHA256" ;;
        mnn-license) echo "$MNN_LICENSE_SHA256" ;;
        hyperlpr) echo "$HYPERLPR_SHA256" ;;
        nanodet-model) echo "$NANODET_MODEL_SHA256" ;;
        nanodet-license) echo "$NANODET_LICENSE_SHA256" ;;
        lvgl) echo "$LVGL_SHA256" ;;
        laneapp-lvgl) echo "$LANEAPP_LVGL_SHA256" ;;
        libpeer) echo "$LIBPEER_SHA256" ;;
        libsrtp) echo "$LIBSRTP_SHA256" ;;
        mbedtls) echo "$MBEDTLS_SHA256" ;;
        postgresql) echo "$POSTGRESQL_SHA256" ;;
        *)
            echo "unknown dependency: $1" >&2
            return 1
            ;;
    esac
}

pcct_dep_version() {
    case "$1" in
        openssl) echo "$OPENSSL_VERSION" ;;
        curl) echo "$CURL_VERSION" ;;
        libxml2) echo "$LIBXML2_VERSION" ;;
        freetype) echo "$FREETYPE_VERSION" ;;
        libusb) echo "$LIBUSB_VERSION" ;;
        sqlite) echo "$SQLITE_VERSION" ;;
        ffmpeg) echo "$FFMPEG_VERSION" ;;
        cmake) echo "$CMAKE_VERSION" ;;
        opencv) echo "$OPENCV_VERSION" ;;
        mnn) echo "$MNN_VERSION" ;;
        mnn-license) echo "$MNN_LICENSE_REVISION" ;;
        hyperlpr) echo "$HYPERLPR_VERSION" ;;
        nanodet-model|nanodet-license) echo "$NANODET_VERSION" ;;
        lvgl) echo "$LVGL_VERSION" ;;
        laneapp-lvgl) echo "$LANEAPP_LVGL_VERSION" ;;
        libpeer) echo "$LIBPEER_VERSION" ;;
        libsrtp) echo "$LIBSRTP_VERSION" ;;
        mbedtls) echo "$MBEDTLS_VERSION" ;;
        postgresql) echo "$POSTGRESQL_VERSION" ;;
        *)
            echo "unknown dependency: $1" >&2
            return 1
            ;;
    esac
}
