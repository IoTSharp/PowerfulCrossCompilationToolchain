#!/bin/sh

set -eu

if [ "$#" -ne 1 ]; then
    echo "usage: $0 <x86|arm>" >&2
    exit 1
fi

target=$1
archive=/work/minigui2.0.4-eb30dfdc.tar.gz
workdir=/tmp/pcct-minigui2.0.4

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
        ;;
    arm)
        # The pinned source contains the legacy ARM cross-configuration used
        # by LaneApp. Installation goes directly into the legacy sysroot.
        chmod 755 ./rebuild
        ./rebuild
        make -j"$(nproc)"
        make install
        install_root=/work/toolchain_R2_EABI/usr/arm-unknown-linux-gnueabi/sysroot/usr
        ;;
    *)
        echo "unsupported target: $target" >&2
        exit 1
        ;;
esac

test -f "$install_root/lib/libminigui.a"
test -f "$install_root/lib/libmgext.a"
test -f "$install_root/include/minigui/common.h"
test -f "$install_root/etc/MiniGUI.cfg"

rm -rf "$workdir"
