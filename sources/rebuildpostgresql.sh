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

# PostgreSQL uses custom configure, not GNU Autotools
if [ ! -f configure ]; then
    echo "ERROR: PostgreSQL configure script not found" >&2
    exit 2
fi

export CFLAGS="${CFLAGS:-} -O2 -fPIC"
export CXXFLAGS="${CXXFLAGS:-} -O2 -fPIC"

# Configure PostgreSQL with minimal client library dependencies:
# - disable SSL/TLS to remove OpenSSL dependency
# - disable Kerberos, LDAP authentication
# - disable server build features not needed for libpq
./configure \
    --host="$PCCT_HOST" \
    --build="$PCCT_BUILD" \
    --prefix="$PCCT_PREFIX" \
    --exec-prefix="$PCCT_PREFIX" \
    --libdir="$PCCT_LIBDIR" \
    --includedir="$PCCT_INCLUDEDIR" \
    --without-ldap \
    --without-bonjour \
    --without-tcl \
    --without-perl \
    --without-python \
    --without-icu \
    --without-openssl \
    --without-readline \
    --without-zlib

# Generate headers used by frontend sources before starting parallel builds.
# PostgreSQL's src/common Makefile also depends on this target, but invoking it
# with -j can compile hashfn.c before errcodes.h has been linked into src/include.
make -C src/backend generated-headers

# Build and install the frontend static archives required by libpq.pc.
# PostgreSQL 17.x advertises libpgcommon/libpgport as private static deps.
make -C src/common -j"$(pcct_nproc)"
make -C src/port -j"$(pcct_nproc)"
make -C src/interfaces/libpq -j"$(pcct_nproc)"
make -C src/common install libdir="$PCCT_LIBDIR"
make -C src/port install libdir="$PCCT_LIBDIR"
make -C src/interfaces/libpq install libdir="$PCCT_LIBDIR"

# PostgreSQL 17's generated libpq.pc names libpgcommon.a, but the frontend
# encoding functions referenced by static libpq live in libpgcommon_shlib.a.
# Use explicit archives so downstream builds cannot accidentally select a .so.
sed -i \
    -e 's/-lpq\([[:space:]]\|$\)/-l:libpq.a\1/g' \
    -e 's/-lpgcommon\([[:space:]]\|$\)/-l:libpgcommon_shlib.a\1/g' \
    -e 's/-lpgport\([[:space:]]\|$\)/-l:libpgport.a\1/g' \
    "$PCCT_PKGCONFIGDIR/libpq.pc"

# PostgreSQL always installs libpq shared objects. This compiler profile is
# intentionally static-only so an ordinary -lpq cannot select libpq.so first.
rm -f "$PCCT_LIBDIR"/libpq.so "$PCCT_LIBDIR"/libpq.so.*

# Install libpq header files
mkdir -p "$PCCT_INCLUDEDIR"
cp src/include/libpq-fe.h "$PCCT_INCLUDEDIR/" 2>/dev/null || true
cp src/include/libpq-events.h "$PCCT_INCLUDEDIR/" 2>/dev/null || true
cp src/include/postgres_ext.h "$PCCT_INCLUDEDIR/" 2>/dev/null || true
cp src/include/pg_config_ext.h "$PCCT_INCLUDEDIR/"
