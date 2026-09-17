#!/bin/sh

set -eu

if [ "$#" -ne 1 ]; then
    echo "usage: $0 <x86|arm>" >&2
    exit 1
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/build-common.sh"
. "$SCRIPT_DIR/dependency-versions.sh"
pcct_setup_target "$1"

case "$PCCT_TARGET" in
    x86|arm) ;;
    *) echo "unsupported OpenH264 target: $PCCT_TARGET" >&2; exit 1 ;;
esac

# Portable C/C++ preserves ARMv4T soft-float compatibility and avoids a new
# assembler dependency. Build only the static library, never upstream tools.
make -j"${PCCT_CODEC_JOBS:-4}" libopenh264.a \
    OS=linux ARCH="$PCCT_ARCH" BUILDTYPE=Release USE_ASM=No \
    CC="$CC" CXX="$CXX" AR="$AR" \
    CFLAGS="-O2 -fPIC -fno-strict-aliasing -DNDEBUG -DGENERATED_VERSION_HEADER" \
    CXXFLAGS="-O2 -fPIC -fno-strict-aliasing -DNDEBUG -DGENERATED_VERSION_HEADER -std=c++11"

mkdir -p "$PCCT_LIBDIR" "$PCCT_INCLUDEDIR/wels" "$PCCT_PKGCONFIGDIR" \
    "$PCCT_PREFIX/share/licenses/openh264-$OPENH264_VERSION"
install -m 0644 libopenh264.a "$PCCT_LIBDIR/"
install -m 0644 codec/api/wels/*.h "$PCCT_INCLUDEDIR/wels/"
install -m 0644 LICENSE "$PCCT_PREFIX/share/licenses/openh264-$OPENH264_VERSION/"

# The C FFmpeg consumers must link the target C++ runtime statically too.
cxx_archive=$("$CXX" -print-file-name=libstdc++.a)
test -f "$cxx_archive"
# A distinct archive name prevents the older ARM sysroot libstdc++.a from
# winning the link search before the GCC 5.4 runtime selected by the wrapper.
ln -sf "$cxx_archive" "$PCCT_LIBDIR/libpcct-openh264-cxx.a"
cat > "$PCCT_PKGCONFIGDIR/openh264.pc" <<EOF
prefix=$PCCT_PREFIX
includedir=$PCCT_INCLUDEDIR
libdir=$PCCT_LIBDIR

Name: OpenH264
Description: Static OpenH264 camera encoder with target static C++ runtime
Version: $OPENH264_VERSION
Cflags: -I\${includedir}
Libs: -L\${libdir} -l:libopenh264.a
Libs.private: -l:libpcct-openh264-cxx.a -static-libgcc -pthread -lm
EOF

test -f "$PCCT_LIBDIR/libopenh264.a"
