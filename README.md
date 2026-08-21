# Build Images

Chinese README: [README.zh-CN.md](README.zh-CN.md)

These Dockerfiles are the build-image definitions used by local verification, CI, and the legacy VisualGDB debug container.

Image layout:

- `sources/` stores the shared dependency version manifest, source-fetch helpers, target build scripts, the LaneApp LVGL profile, the pinned MiniGUI source archive, and the legacy ARM toolchain bundles.
- `x86Legacy/` keeps the legacy Wheezy-based X86 debug image, including MiniGUI 2.0.4, SSH, and the old toolchain/debug baseline.
- `x86/` is the independent LaneApp i386 compiler baseline: Ubuntu 16.04, GCC 5.4, glibc 2.23, Clang 6, MiniGUI 2.0.4, GDB/GDBServer, Valgrind, strace/ltrace, and GCC sanitizer runtimes.
- `arm/` for `ARM`
- `x64/` for `X64`
- `arm64/` for `ARM64`
- `loongson/` for `LA64`

Shared dependency policy:

- All portable third-party dependencies are downloaded at build time from pinned GitHub release/tag archives and verified with SHA256 before extraction.
- The X86 LaneApp profile pins `curl 8.10.1`, `libxml2 2.12.10`, `freetype 2.13.3`, `libusb 1.0.23`, `sqlite 3.51.2`, `FFmpeg 4.4.5`, `PostgreSQL/libpq 17.2`, `mbedTLS 3.4.0`, the LaneApp libpeer revision, and `LVGL 9.3.0`.
- `libusb` is intentionally pinned to `1.0.23` because `1.0.24+` switched to a C11 baseline, which is not a safe match for the legacy ARM `gcc 4.6.1` toolchain.
- `sqlite` stays aligned with the upstream app's `3.51.2` baseline so the image exposes a matching static `libsqlite3.a`, and it is fetched from the pinned GitHub mirror tag at image-build time like the other portable dependencies.
- The independent X86 image builds the LaneApp dependencies from pinned source archives and installs static libraries, headers, and pkg-config metadata under `/usr/local`. This includes the former LaneApp-private FFmpeg/VAAPI build chain, so LaneApp code changes do not rebuild these dependencies and LaneApp does not retain an FFmpeg submodule.
- X86 curl keeps HTTPS enabled through the same mbedTLS 3.4.0 stack used by libpeer, libsrtp, and FFmpeg; IPv6 is disabled. OpenSSL 1.1.1w remains an optional source-build profile and is not installed in the default X86 image, avoiding two TLS implementations in one LaneApp process.
- The X86 FFmpeg profile enables H.264 VAAPI against Xenial's libva/libdrm stack. FFmpeg remains static, while the hardware-facing i965 driver and its pinned 32-bit libva/libdrm runtime are exported at `/opt/pcct/runtime/vaapi` for LaneApp packaging.
- The X86 static verification links curl, libxml2, FFmpeg, libpeer/libsrtp, mbedTLS, libpq, libusb, and the LaneApp LVGL profile into one smoke binary. Only baseline OS libraries and the explicitly packaged VAAPI/libdrm runtime may remain dynamic.
- `x86Legacy` and `x86` both use the repository-owned MiniGUI 2.0.4 archive; neither image copies build artifacts from the other image.

Batch build with Docker Compose:

- `docker-compose.yml` can start all build images in parallel and bind-mount a host source directory into `/LaneApp`.
- `docker-compose.yml` is the runtime entrypoint and pulls prebuilt images from GHCR by default.
- `docker-compose.override.yml` only carries the local `build` definitions. When you run `docker compose up --build`, Compose uses the override and rebuilds the images locally before starting them.
- Set `BUILD_DIR` to the host directory you want to build, and optionally set `BUILD_COMMAND` (defaults to `make`).
- Optionally set `PCCT_IMAGE_PREFIX` (defaults to `ghcr.io/iotsharp`) and `PCCT_IMAGE_TAG` (defaults to `latest`) to switch image registry/tag.
- The repo root also provides `compose-up-all.cmd` and `compose-up-all.sh` wrapper scripts so you do not have to export the environment variables manually each time.
- The wrapper scripts default to `pull` mode, which only uses `docker-compose.yml` and pulls remote images. Pass `--build` or `--mode build` to add `docker-compose.override.yml` and rebuild the images locally.
- The wrapper scripts default to the `all` target set. You can narrow the run with `--targets`, for example `x64`, `arm64`, `x86,x64`, or `x86 x64`. Supported targets are `x86legacy`, `x86`, `arm`, `x64`, `arm64`, and `loongson`.
- PowerShell example:
  `$env:BUILD_DIR='D:/path/to/project'; $env:BUILD_COMMAND='make'; docker compose up --build`
- Bash example:
  `BUILD_DIR=/abs/path/to/project BUILD_COMMAND=make docker compose up --build`
- Windows `cmd` examples:
  `compose-up-all.cmd D:\path\to\project`
  `compose-up-all.cmd D:\path\to\project --targets x64,arm64`
  `compose-up-all.cmd D:\path\to\project "cmake --build build" --build --targets x86,x64`
  `compose-up-all.cmd D:\path\to\project --mode build --targets all -- --abort-on-container-exit`
- Linux/macOS `sh` examples:
  `sh ./compose-up-all.sh /path/to/project`
  `sh ./compose-up-all.sh /path/to/project --targets x64,arm64`
  `sh ./compose-up-all.sh /path/to/project "cmake --build build" --build --targets x86,x64`
  `sh ./compose-up-all.sh /path/to/project --mode build --targets all -- --abort-on-container-exit`
- The compose run exits after all service commands finish. Build outputs stay in the mounted host directory.

Legacy VisualGDB debug entrypoint:

- Start the local debug builder with `docker compose -f docker-compose.debug.yml up --build -d x86-debug-builder`
- The container exposes SSH on `127.0.0.1:2221`, which matches `LaneApp-Debug.vgdbsettings`
- `x86Legacy` still keeps the MiniGUI 2.0.4, SSH, and dual-target `arm + x86` legacy workflow; the other images stay on the unified modern dependency stack.
