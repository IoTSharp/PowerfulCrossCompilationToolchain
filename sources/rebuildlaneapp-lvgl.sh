#!/bin/sh

set -eu

if [ "$#" -ne 1 ] || [ "$1" != "x86" ]; then
    echo "usage: $0 x86" >&2
    exit 1
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/build-common.sh"
. "$SCRIPT_DIR/dependency-versions.sh"

pcct_setup_target x86

cp "$SCRIPT_DIR/lane2nd-lv_conf.h" ./lv_conf.h
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT INT TERM

n=0
for source_file in $(find src -name '*.c' -type f | sort); do
    n=$((n + 1))
    "$CC" \
        -std=gnu99 \
        -O2 \
        -fPIC \
        -DLV_CONF_INCLUDE_SIMPLE \
        -I. \
        -I./src \
        -c "$source_file" \
        -o "$tmpdir/$n.o"
done

"$AR" rcs liblaneapp-lvgl.a "$tmpdir"/*.o
"$RANLIB" liblaneapp-lvgl.a

include_root="$PCCT_INCLUDEDIR/laneapp-lvgl"
rm -rf "$include_root"
mkdir -p "$PCCT_LIBDIR" "$include_root/lvgl" "$PCCT_PKGCONFIGDIR"
install -m 0644 liblaneapp-lvgl.a "$PCCT_LIBDIR/liblaneapp-lvgl.a"
cp -R src "$include_root/lvgl/"
install -m 0644 lvgl.h "$include_root/lvgl/lvgl.h"
install -m 0644 lv_version.h "$include_root/lvgl/lv_version.h"
install -m 0644 lv_conf.h "$include_root/lv_conf.h"

# Clang 6 promotes missing final newlines in installed LVGL headers under
# LaneApp's -Werror profile, so normalize the exported header set once here.
find "$include_root" -type f -name '*.h' -exec sh -c '
    for file do
        if [ -s "$file" ] && [ "$(tail -c 1 "$file" | wc -l)" -eq 0 ]; then
            printf "\n" >> "$file"
        fi
    done
' sh {} +

cat > "$PCCT_PKGCONFIGDIR/laneapp-lvgl.pc" <<EOF
prefix=$PCCT_PREFIX
includedir=$include_root
libdir=$PCCT_LIBDIR

Name: laneapp-lvgl
Description: LaneApp second-screen LVGL static profile
Version: $LANEAPP_LVGL_VERSION
Cflags: -I\${includedir} -I\${includedir}/lvgl -DLV_CONF_INCLUDE_SIMPLE
Libs: -L\${libdir} -llaneapp-lvgl -lm -lrt
EOF

test -f "$PCCT_LIBDIR/liblaneapp-lvgl.a"
test -f "$include_root/lvgl/lvgl.h"
