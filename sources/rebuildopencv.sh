#!/bin/sh

set -eu

if [ "$#" -ne 1 ]; then
    echo "usage: $0 <x86|arm>" >&2
    exit 1
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/build-common.sh"
. "$SCRIPT_DIR/dependency-versions.sh"

case "$1" in
    x86|arm) ;;
    *)
        echo "usage: $0 <x86|arm>" >&2
        exit 1
        ;;
esac

pcct_setup_target "$1"

cmake_toolchain_arg=
opencv_cxx_flags="-O2 -fPIC"
if [ "$PCCT_IS_CROSS" = "1" ]; then
    toolchain_file=$(mktemp)
    trap 'rm -f "$toolchain_file"' EXIT INT TERM
    pcct_write_cmake_toolchain "$toolchain_file"
    cmake_toolchain_arg="-DCMAKE_TOOLCHAIN_FILE=$toolchain_file"
fi
if [ "$PCCT_TARGET" = "arm" ]; then
    # This GCC 5 ARM libstdc++ profile omits std::exception_ptr. OpenCV keeps
    # AsyncArray available through its cv::Exception fallback.
    opencv_cxx_flags="$opencv_cxx_flags -DCV__EXCEPTION_PTR=0"
fi

# LaneApp recognition only needs matrix primitives and color/geometry
# processing. Keep all media, UI, DNN, accelerator, binding and test surfaces
# out of this static profile.
mkdir -p build
cd build
# shellcheck disable=SC2086
cmake .. $cmake_toolchain_arg \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$PCCT_PREFIX" \
    -DCMAKE_INSTALL_LIBDIR=lib \
    -DCMAKE_C_FLAGS="-O2 -fPIC" \
    -DCMAKE_CXX_FLAGS="$opencv_cxx_flags" \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_LIST=core,imgproc \
    -DBUILD_opencv_apps=OFF \
    -DBUILD_opencv_calib3d=OFF \
    -DBUILD_opencv_dnn=OFF \
    -DBUILD_opencv_features2d=OFF \
    -DBUILD_opencv_flann=OFF \
    -DBUILD_opencv_gapi=OFF \
    -DBUILD_opencv_highgui=OFF \
    -DBUILD_opencv_imgcodecs=OFF \
    -DBUILD_opencv_java=OFF \
    -DBUILD_opencv_js=OFF \
    -DBUILD_opencv_ml=OFF \
    -DBUILD_opencv_objdetect=OFF \
    -DBUILD_opencv_photo=OFF \
    -DBUILD_opencv_python2=OFF \
    -DBUILD_opencv_python3=OFF \
    -DBUILD_opencv_stitching=OFF \
    -DBUILD_opencv_ts=OFF \
    -DBUILD_opencv_video=OFF \
    -DBUILD_opencv_videoio=OFF \
    -DBUILD_opencv_world=OFF \
    -DBUILD_DOCS=OFF \
    -DBUILD_EXAMPLES=OFF \
    -DBUILD_JAVA=OFF \
    -DBUILD_JPEG=OFF \
    -DBUILD_OPENEXR=OFF \
    -DBUILD_PACKAGE=OFF \
    -DBUILD_PERF_TESTS=OFF \
    -DBUILD_PNG=OFF \
    -DBUILD_PROTOBUF=OFF \
    -DBUILD_TESTS=OFF \
    -DBUILD_TIFF=OFF \
    -DBUILD_WEBP=OFF \
    -DENABLE_PRECOMPILED_HEADERS=OFF \
    -DOPENCV_DISABLE_THREAD_SUPPORT=ON \
    -DOPENCV_ENABLE_NONFREE=OFF \
    -DOPENCV_GENERATE_PKGCONFIG=ON \
    -DOPENCV_SKIP_PYTHON_LOADER=ON \
    -DWITH_1394=OFF \
    -DWITH_ADE=OFF \
    -DWITH_EIGEN=OFF \
    -DWITH_FFMPEG=OFF \
    -DWITH_GPHOTO2=OFF \
    -DWITH_GSTREAMER=OFF \
    -DWITH_GTK=OFF \
    -DWITH_IPP=OFF \
    -DWITH_ITT=OFF \
    -DWITH_JASPER=OFF \
    -DWITH_JPEG=OFF \
    -DWITH_LAPACK=OFF \
    -DWITH_OPENCL=OFF \
    -DWITH_OPENEXR=OFF \
    -DWITH_OPENGL=OFF \
    -DWITH_OPENMP=OFF \
    -DWITH_OPENJPEG=OFF \
    -DWITH_PNG=OFF \
    -DWITH_PROTOBUF=OFF \
    -DWITH_PTHREADS_PF=OFF \
    -DWITH_QT=OFF \
    -DWITH_TBB=OFF \
    -DWITH_TIFF=OFF \
    -DWITH_V4L=OFF \
    -DWITH_VA=OFF \
    -DWITH_VA_INTEL=OFF \
    -DWITH_WEBP=OFF

cmake --build . --target install -- -j"$(pcct_nproc)"

test -f "$PCCT_LIBDIR/libopencv_core.a"
test -f "$PCCT_LIBDIR/libopencv_imgproc.a"
if find "$PCCT_LIBDIR" -maxdepth 1 -name 'libopencv_*.so*' | grep -q .; then
    echo "OpenCV shared libraries remain in the $PCCT_TARGET static profile" >&2
    exit 1
fi

license_dir="$PCCT_PREFIX/share/licenses/opencv-$OPENCV_VERSION"
mkdir -p "$license_dir"
install -m 0644 ../LICENSE "$license_dir/LICENSE"
