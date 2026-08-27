#!/bin/sh

set -eu

if [ "$#" -ne 1 ]; then
    echo "usage: $0 <x86|x64|arm|arm64|la64>" >&2
    exit 1
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/build-common.sh"

pcct_setup_target "$1"
pcct_reset_build_tree
pcct_bootstrap_autotools

# GitHub tag archives don't vendor the optional `dlg` submodule that
# FreeType's makefiles expect to copy into the tree. Release builds here keep
# FT_DEBUG_LOGGING disabled, so minimal placeholders are enough to skip the
# submodule checkout path and compile `dlgwrap.c`.
if [ ! -f "src/dlg/dlg.c" ]; then
    mkdir -p src/dlg
    cat > src/dlg/dlg.c <<'EOF'
/* Stub for release builds without the optional dlg submodule. */
EOF
fi

if [ ! -f "include/dlg/dlg.h" ] || [ ! -f "include/dlg/output.h" ]; then
    mkdir -p include/dlg
    if [ ! -f "include/dlg/dlg.h" ]; then
        cat > include/dlg/dlg.h <<'EOF'
#ifndef DLG_DLG_H
#define DLG_DLG_H

typedef void (*dlg_handler)(const char *, int, const char *, void *);

#endif
EOF
    fi
    if [ ! -f "include/dlg/output.h" ]; then
        cat > include/dlg/output.h <<'EOF'
#ifndef DLG_OUTPUT_H
#define DLG_OUTPUT_H

#include "dlg.h"

#endif
EOF
    fi
fi

if [ ! -x "builds/unix/configure" ] && [ -x "./autogen.sh" ]; then
    ./autogen.sh
fi

export CFLAGS="${CFLAGS:-} -O2 -fPIC"
export CXXFLAGS="${CXXFLAGS:-} -O2 -fPIC"

./configure \
    --host="$PCCT_HOST" \
    --build="$PCCT_BUILD" \
    --prefix="$PCCT_PREFIX" \
    --libdir="$PCCT_LIBDIR" \
    --includedir="$PCCT_INCLUDEDIR" \
    --disable-shared \
    --enable-static \
    --enable-freetype-config \
    --with-pic \
    --with-zlib=no \
    --with-bzip2=no \
    --with-png=no \
    --with-harfbuzz=no \
    --with-brotli=no

make -j"$(pcct_nproc)"
make install
