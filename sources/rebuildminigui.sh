#!/bin/sh

set -eu

archive=/work/minigui2.0.4-eb30dfdc.tar.gz
workdir=/tmp/pcct-minigui2.0.4

rm -rf "$workdir"
mkdir -p "$workdir"
tar -xf "$archive" -C "$workdir" --strip-components=1
cd "$workdir"

# MiniGUI 2.0.4 is part of the X86 ABI baseline, so build it from the pinned
# source archive instead of importing artifacts from another image.
chmod 755 ./rebuildx86
./rebuildx86
make -j"$(nproc)"
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
    echo "MiniGUI.cfg was not installed" >&2
    exit 1
fi

test -f /usr/local/lib/libminigui.a
test -f /usr/local/lib/libmgext.a
test -f /usr/local/include/minigui/common.h
test -f /usr/local/etc/MiniGUI.cfg

rm -rf "$workdir"
