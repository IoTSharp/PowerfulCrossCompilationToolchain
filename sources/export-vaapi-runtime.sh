#!/bin/sh

set -eu

runtime_root=/opt/pcct/runtime/vaapi
system_libdir=/usr/lib/i386-linux-gnu

copy_runtime_family() {
    pattern=$1
    found=0

    # The pattern must expand so both the SONAME link and its versioned target
    # are preserved in the deployable runtime directory.
    # shellcheck disable=SC2086
    for source_path in $pattern; do
        if [ -e "$source_path" ] || [ -L "$source_path" ]; then
            cp -a "$source_path" "$runtime_root/lib/"
            found=1
        fi
    done

    if [ "$found" -ne 1 ]; then
        echo "missing VAAPI runtime family: $pattern" >&2
        exit 1
    fi
}

rm -rf "$runtime_root"
mkdir -p "$runtime_root/lib" "$runtime_root/dri"

copy_runtime_family "$system_libdir/libva.so.1*"
copy_runtime_family "$system_libdir/libva-drm.so.1*"
copy_runtime_family "$system_libdir/libdrm.so.2*"
copy_runtime_family "$system_libdir/libdrm_intel.so.1*"
copy_runtime_family "$system_libdir/libpciaccess.so.0*"

install -m 0755 \
    "$system_libdir/dri/i965_drv_video.so" \
    "$runtime_root/dri/i965_drv_video.so"

cat > "$runtime_root/README.txt" <<'EOF'
LaneApp private 32-bit VAAPI runtime for Intel i965 on Ubuntu 16.04/Xenial.
This directory is exported by the independent PCCT X86 compiler image.
Deploy it as /EMRC-ETC/EXTRAS/X86/vaapi without installing dpkg packages.
FFmpeg is statically linked; these libva/libdrm libraries and the i965 driver
remain dynamic because they are the hardware-facing VAAPI runtime.
EOF

if ldd "$runtime_root/dri/i965_drv_video.so" | grep -q 'not found'; then
    echo "the exported i965 VAAPI driver has unresolved dependencies" >&2
    exit 1
fi
