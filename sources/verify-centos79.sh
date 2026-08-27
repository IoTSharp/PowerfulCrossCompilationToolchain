#!/bin/sh

set -eu

grep -qx 'CentOS Linux release 7.9.2009 (Core)' /etc/centos-release
"$CC" --version | sed -n '1p' | grep -q '7\.3\.1'
"$CXX" --version | sed -n '1p' | grep -q '7\.3\.1'
case "$("$CXX" -print-file-name=libstdc++.a)" in
    /opt/rh/devtoolset-7/*) ;;
    *)
        echo "Developer Toolset 7 static libstdc++ is unavailable" >&2
        exit 1
        ;;
esac
test -f "$("$CXX" -print-file-name=libstdc++.a)"
cmake --version | sed -n '1p' | grep -qx 'cmake version 3.14.7'
gdb --version | sed -n '1p'
valgrind --version
ldd --version 2>&1 | sed -n '1p' | grep -q '2\.17'

workdir=/tmp/pcct-centos79-smoke
rm -rf "$workdir"
mkdir -p "$workdir"
trap 'rm -rf "$workdir"' EXIT INT TERM

cat > "$workdir/probe.c" <<'EOF'
#include <stdio.h>

int main(void)
{
    puts("pcct-centos79");
    return 0;
}
EOF

gcc -O2 "$workdir/probe.c" -o "$workdir/probe"
file "$workdir/probe" | grep -q 'ELF 64-bit.*x86-64'
"$workdir/probe" | grep -qx 'pcct-centos79'

if readelf --version-info "$workdir/probe" | \
    grep -Eq 'GLIBC_2\.(1[89]|[2-9][0-9])'; then
    echo "CentOS 7.9 probe exceeds the glibc 2.17 baseline" >&2
    exit 1
fi
