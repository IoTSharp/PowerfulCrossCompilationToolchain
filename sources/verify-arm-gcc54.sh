#!/bin/sh

set -eu

workdir=/tmp/pcct-arm-gcc54-smoke
cc=/work/toolchain_R2_EABI/usr/bin/arm-none-linux-gnueabi-gcc
ar=/work/toolchain_R2_EABI/usr/bin/arm-none-linux-gnueabi-ar
readelf=/usr/bin/arm-linux-gnueabi-readelf
sysroot=/work/toolchain_R2_EABI/usr/arm-unknown-linux-gnueabi/sysroot

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
test "$("$cc" -print-sysroot)" = "/work/toolchain_R2_EABI/usr/arm-unknown-linux-gnueabi/sysroot"
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
pkg_config=/work/toolchain_R2_EABI/usr/bin/pkg-config
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

rm -rf "$workdir"
