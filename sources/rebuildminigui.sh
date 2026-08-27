#!/bin/sh

set -eu

if [ "$#" -ne 1 ]; then
    echo "usage: $0 <x86|x64|arm|arm64|la64>" >&2
    exit 1
fi

target=$1
archive=/work/minigui2.0.4-eb30dfdc.tar.gz
workdir=/tmp/pcct-minigui2.0.4
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/build-common.sh"

rm -rf "$workdir"
mkdir -p "$workdir"
tar -xf "$archive" -C "$workdir" --strip-components=1
cd "$workdir"

case "$target" in
    x86)
        # Keep the established X86 feature profile while rebuilding from the
        # repository-owned source archive.
        chmod 755 ./rebuildx86
        MAKEFLAGS="-j$(nproc)" ./rebuildx86
        make install

        mkdir -p /usr/local/lib /usr/local/include /usr/local/etc
        install -m 0644 /usr/lib/libminigui.a /usr/local/lib/libminigui.a
        install -m 0644 /usr/lib/libmgext.a /usr/local/lib/libmgext.a
        cp -R /usr/include/minigui /usr/local/include/minigui

        if [ -f /usr/etc/MiniGUI.cfg ]; then
            install -m 0644 /usr/etc/MiniGUI.cfg /usr/local/etc/MiniGUI.cfg
        elif [ -f /etc/MiniGUI.cfg ]; then
            install -m 0644 /etc/MiniGUI.cfg /usr/local/etc/MiniGUI.cfg
        else
            echo "MiniGUI.cfg was not installed for x86" >&2
            exit 1
        fi

        install_root=/usr/local
        install_libdir=$install_root/lib
        ;;
    arm)
        pcct_setup_target arm
        pcct_reset_build_tree
        chmod 755 ./autogen.sh
        ./autogen.sh
        pcct_refresh_config_scripts .
        PATH="$PCCT_PREFIX/bin:$PATH" \
        CPPFLAGS="-I$PCCT_INCLUDEDIR -I$PCCT_INCLUDEDIR/freetype2" \
        LDFLAGS="-L$PCCT_LIBDIR" \
        CFLAGS="-pipe -Os -D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64" \
        CXXFLAGS="-pipe -Os -D_LARGEFILE_SOURCE -D_LARGEFILE64_SOURCE -D_FILE_OFFSET_BITS=64" \
        ac_cv_lbl_unaligned_fail=yes \
        ac_cv_func_mmap_fixed_mapped=yes \
        ac_cv_func_memcmp_working=yes \
        ac_cv_have_decl_malloc=yes \
        gl_cv_func_malloc_0_nonnull=yes \
        ac_cv_func_malloc_0_nonnull=yes \
        ac_cv_func_calloc_0_nonnull=yes \
        ac_cv_func_realloc_0_nonnull=yes \
        lt_cv_sys_lib_search_path_spec= \
        ac_cv_c_bigendian=no \
        ./configure \
            --target="$PCCT_HOST" \
            --host="$PCCT_HOST" \
            --build="$PCCT_BUILD" \
            --prefix="$PCCT_PREFIX" \
            --libdir="$PCCT_LIBDIR" \
            --includedir="$PCCT_INCLUDEDIR" \
            --disable-shared \
            --enable-static \
            --disable-ttfsupport \
            --enable-ft2support \
            --disable-pngsupport
        make -j"$(nproc)"
        make install
        install_root=$PCCT_PREFIX
        install_libdir=$PCCT_LIBDIR
        ;;
    x64|X64|arm64|ARM64|la64|LA64)
        # Modern native and cross targets use the same pinned MiniGUI 2.0.4
        # feature profile and install only target static archives.
        pcct_setup_target "$target"
        pcct_reset_build_tree
        chmod 755 ./autogen.sh
        ./autogen.sh
        # MiniGUI 2.0.4 predates LoongArch; refresh only GNU canonicalization
        # helpers so the pinned MiniGUI source and feature profile stay intact.
        pcct_refresh_config_scripts .
        PATH="$PCCT_PREFIX/bin:$PATH" \
        CPPFLAGS="-I$PCCT_INCLUDEDIR -I$PCCT_INCLUDEDIR/freetype2" \
        LDFLAGS="-L$PCCT_LIBDIR" \
        CFLAGS="-O2 -fPIC" \
        CXXFLAGS="-O2 -fPIC" \
        ./configure \
            --host="$PCCT_HOST" \
            --build="$PCCT_BUILD" \
            --prefix="$PCCT_PREFIX" \
            --libdir="$PCCT_LIBDIR" \
            --includedir="$PCCT_INCLUDEDIR" \
            --disable-shared \
            --enable-static \
            --disable-ttfsupport \
            --enable-ft2support \
            --disable-libvcongui \
            --disable-pngsupport
        make -j"$(pcct_nproc)"
        make install
        rm -f "$PCCT_LIBDIR"/libminigui.so* "$PCCT_LIBDIR"/libmgext.so*
        install_root=$PCCT_PREFIX
        install_libdir=$PCCT_LIBDIR
        ;;
    *)
        echo "unsupported target: $target" >&2
        exit 1
        ;;
esac

test -f "$install_libdir/libminigui.a"
test -f "$install_libdir/libmgext.a"
test -f "$install_root/include/minigui/common.h"
test -f "$install_root/etc/MiniGUI.cfg"

case "$target" in
    arm|x64|X64|arm64|ARM64|la64|LA64)
        test -x "$install_root/bin/freetype-config"
        test -f "$install_root/include/minigui/mgconfig.h"
        grep -q '^#define _FT2_SUPPORT 1$' \
            "$install_root/include/minigui/mgconfig.h"
        ! grep -q '^#define _TTF_SUPPORT 1$' \
            "$install_root/include/minigui/mgconfig.h"
        "$NM" -g --defined-only "$install_libdir/libminigui.a" | \
            grep -q ' T InitFreeTypeFonts$'
        ;;
esac

rm -rf "$workdir"
