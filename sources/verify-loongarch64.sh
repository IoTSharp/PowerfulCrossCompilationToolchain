#!/bin/sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/build-common.sh"

pcct_setup_target la64

workdir=/tmp/pcct-loongarch64-smoke
readelf=readelf
rm -rf "$workdir"
mkdir -p "$workdir"

cat > "$workdir/probe.c" <<'EOF'
#include <stdio.h>
int main(void)
{
    puts("pcct-loongarch64");
    return 0;
}
EOF

"$CC" --version | sed -n '1p' | grep -q '14\.2\.0'
test "$(readlink -f "$("$CC" -print-sysroot)")" = "$(readlink -f "$SYSROOT")"
"$CC" -O2 "$workdir/probe.c" -o "$workdir/probe"
file "$workdir/probe" | grep -q 'ELF 64-bit LSB.*LoongArch'
"$readelf" -l "$workdir/probe" | grep -q '/lib64/ld-linux-loongarch-lp64d.so.1'

if "$readelf" --version-info "$workdir/probe" | \
    grep -Eq 'GLIBC_2\.(4[2-9]|[5-9][0-9])'; then
    echo "LoongArch compiler exceeds the target glibc 2.41 baseline" >&2
    exit 1
fi

required_archives="
libconfig.a
libcurl.a
libfreetype.a
libjpeg.a
libmbedcrypto.a
libmbedtls.a
libmbedx509.a
libmgext.a
libminigui.a
libpq.a
libsqlite3.a
libusb-1.0.a
"

for archive in $required_archives; do
    archive_path="$PCCT_LIBDIR/$archive"
    test -f "$archive_path"
    member=$("$AR" t "$archive_path" | sed -n '1p')
    test -n "$member"
    "$AR" p "$archive_path" "$member" > "$workdir/archive-member.o"
    file "$workdir/archive-member.o" | grep -q 'ELF 64-bit LSB.*LoongArch'
done

for header in \
    libconfig.h \
    curl/curl.h \
    freetype2/ft2build.h \
    jpeglib.h \
    libpq-fe.h \
    libusb-1.0/libusb.h \
    minigui/common.h; do
    test -f "$PCCT_INCLUDEDIR/$header"
done

"$PKG_CONFIG" --exists libconfig libcurl freetype2 libjpeg libpq libusb-1.0
"$PKG_CONFIG" --static --libs libcurl | grep -q -- '-lmbedtls'
"$PKG_CONFIG" --static --libs libcurl | grep -q -- '-l:libz.a'
"$PKG_CONFIG" --static --libs libpq | grep -q -- '-l:libpgcommon_shlib.a'

cat > "$workdir/dependency-smoke.c" <<'EOF'
#include <curl/curl.h>
#include <libconfig.h>
#include <libpq-fe.h>
#include <libusb-1.0/libusb.h>

int main(void)
{
    config_t config;
    libusb_context *usb = NULL;
    config_init(&config);
    config_destroy(&config);
    (void)curl_version_info(CURLVERSION_NOW);
    (void)PQlibVersion();
    (void)libusb_init(&usb);
    libusb_exit(usb);
    return 0;
}
EOF

# shellcheck disable=SC2046
"$CC" -O2 -o "$workdir/dependency-smoke" "$workdir/dependency-smoke.c" \
    $("$PKG_CONFIG" --cflags --static --libs libconfig libcurl libpq libusb-1.0)

cat > "$workdir/cxx-smoke.cpp" <<'EOF'
#include <string>
int main()
{
    const std::string value("loongarch64");
    return value.empty() ? 1 : 0;
}
EOF

"$CXX" -O2 -static-libstdc++ -static-libgcc \
    "$workdir/cxx-smoke.cpp" -o "$workdir/cxx-smoke"

for binary in dependency-smoke cxx-smoke; do
    file "$workdir/$binary" | grep -q 'ELF 64-bit LSB.*LoongArch'
    if "$readelf" -d "$workdir/$binary" | grep NEEDED | \
        grep -Eq 'lib(config|curl|pq|usb|mbedtls|mbedx509|mbedcrypto|stdc\+\+|gcc_s)\.so'; then
        echo "$binary retained a forbidden compiler-profile shared dependency" >&2
        exit 1
    fi
    if "$readelf" --version-info "$workdir/$binary" | \
        grep -Eq 'GLIBC_2\.(4[2-9]|[5-9][0-9])'; then
        echo "$binary exceeds the target glibc 2.41 baseline" >&2
        exit 1
    fi
done

rm -rf "$workdir"
