# 构建镜像说明

English README: [README.md](README.md)

本仓库保存的是构建镜像定义，供本地验证、CI，以及遗留的 VisualGDB 调试容器共同使用。

## 目录布局

- `sources/`：保存共享依赖版本清单、源码拉取脚本、各平台构建脚本、LaneApp 的 LVGL 配置、固定的 MiniGUI 源码归档，以及遗留 ARM 工具链压缩包。
- `x86Legacy/`：遗留 Wheezy 基线的 X86 调试镜像，包含 MiniGUI 2.0.4、SSH，以及旧版工具链/调试环境。
- `x86/`：独立的 LaneApp i386 编译基线，固定为 Ubuntu 16.04、GCC 5.4、glibc 2.23、Clang 6，并包含 MiniGUI 2.0.4、GDB/GDBServer、Valgrind、strace/ltrace 和 GCC Sanitizer 运行库。
- `arm/`：`ARM` 平台构建镜像。
- `x64/`：`X64` 平台构建镜像。
- `arm64/`：`ARM64` 平台构建镜像。
- `loongson/`：`LA64` 平台构建镜像。

## 共享依赖策略

- 可移植的第三方依赖统一在镜像构建阶段下载，来源为固定的 GitHub release/tag 压缩包，并在解压前进行 SHA256 校验。
- X86 LaneApp 配置固定为：`curl 8.10.1`、`libxml2 2.12.10`、`freetype 2.13.3`、`libusb 1.0.23`、`sqlite 3.51.2`、`FFmpeg 4.4.5`、`PostgreSQL/libpq 17.2`、`mbedTLS 3.4.0`、固定提交的 libpeer，以及 `LVGL 9.3.0`。
- `libusb` 固定在 `1.0.23`，因为 `1.0.24+` 已切换到 C11 基线，不适合遗留 ARM `gcc 4.6.1` 工具链。
- `sqlite` 与上游应用保持 `3.51.2` 一致，镜像内提供匹配版本的静态库 `libsqlite3.a`，并与其他依赖一样在镜像构建时从固定 GitHub tag 拉取源码。
- 独立 X86 镜像从固定源码归档构建 LaneApp 依赖，把静态库、头文件和 `pkg-config` 元数据安装到 `/usr/local`。原来 LaneApp 私有的 FFmpeg/VAAPI 构建链也迁入该镜像，因此以后只修改 LaneApp 代码时不再重新编译这些第三方库，LaneApp 也不再保留 FFmpeg 子模块。
- X86 curl 保留 HTTPS，并与 libpeer、libsrtp、FFmpeg 统一使用 mbedTLS 3.4.0；IPv6 关闭。OpenSSL 1.1.1w 只保留为可选源码构建配置，不进入默认 X86 镜像，避免同一 LaneApp 进程同时引入两套 TLS 实现。
- X86 FFmpeg 启用 H.264 VAAPI，并使用 Xenial 的 libva/libdrm。FFmpeg 本身静态链接，面向硬件的 i965 驱动及其固定的 32 位 libva/libdrm 运行时输出到 `/opt/pcct/runtime/vaapi`，供 LaneApp 打包。
- X86 镜像构建时会把 curl、libxml2、FFmpeg、libpeer/libsrtp、mbedTLS、libpq、libusb 和 LaneApp LVGL 配置链接到同一个静态验证程序；最终只允许系统基线库以及明确随包携带的 VAAPI/libdrm 运行时保持动态链接。
- `x86Legacy` 和 `x86` 各自从仓库内固定的 MiniGUI 2.0.4 归档构建，不从其他镜像复制构建产物，镜像之间保持独立。

## 使用 Docker Compose 并行构建

- `docker-compose.yml` 可以一次启动全部构建镜像，并把宿主机上的源码目录挂载到容器内的 `/LaneApp`。
- `docker-compose.yml` 是日常运行入口，默认从 GHCR 拉取预构建镜像。
- `docker-compose.override.yml` 只保存本地 `build` 定义；执行 `docker compose up --build` 时，会在启动前按 override 中的配置本地构建镜像。
- 通过环境变量 `BUILD_DIR` 指定要构建的宿主机目录，可选环境变量 `BUILD_COMMAND` 指定实际执行的构建命令，默认是 `make`。
- 可选环境变量 `PCCT_IMAGE_PREFIX` 用于切换镜像前缀，默认值为 `ghcr.io/maikebing`；`PCCT_IMAGE_TAG` 默认为 `latest`。
- 为了避免每次手动设置环境变量，仓库根目录还提供了 `compose-up-all.cmd` 和 `compose-up-all.sh` 两个包装脚本。
- 包装脚本默认工作模式是 `pull`，即只使用 `docker-compose.yml` 并从远端拉取镜像；传入 `--build` 或 `--mode build` 后，会自动叠加 `docker-compose.override.yml` 并执行本地镜像构建。
- 包装脚本默认目标平台是 `all`，也可以通过 `--targets` 指定单个或多个平台，例如 `x64`、`arm64`、`x86,x64` 或 `x86 x64`。支持的平台名为 `x86legacy`、`x86`、`arm`、`x64`、`arm64`、`loongson`。
- PowerShell 示例：
  `$env:BUILD_DIR='D:/path/to/project'; $env:BUILD_COMMAND='make'; docker compose up --build`
- Bash 示例：
  `BUILD_DIR=/abs/path/to/project BUILD_COMMAND=make docker compose up --build`
- Windows `cmd` 示例：
  `compose-up-all.cmd D:\path\to\project`
  `compose-up-all.cmd D:\path\to\project --targets x64,arm64`
  `compose-up-all.cmd D:\path\to\project "cmake --build build" --build --targets x86,x64`
  `compose-up-all.cmd D:\path\to\project --mode build --targets all -- --abort-on-container-exit`
- Linux/macOS `sh` 示例：
  `sh ./compose-up-all.sh /path/to/project`
  `sh ./compose-up-all.sh /path/to/project --targets x64,arm64`
  `sh ./compose-up-all.sh /path/to/project "cmake --build build" --build --targets x86,x64`
  `sh ./compose-up-all.sh /path/to/project --mode build --targets all -- --abort-on-container-exit`
- 所有服务执行结束后，`docker compose up` 会退出；构建产物会保留在挂载的宿主机目录中。

## x86Legacy 特殊说明

- `x86Legacy` 仍保留 MiniGUI 2.0.4、SSH，以及 `arm + x86` 双目标的历史调试流程。
- `x86Legacy` 所需的 `MiniGUI 2.0.4` 源码压缩包已随仓库一同保存，避免未来因上游 GitHub 仓库改名、删除或不可访问而导致遗留镜像无法重建。
- MiniGUI 本地归档的来源、固定提交和 SHA256 记录在 `sources/minigui2.0.4-eb30dfdc.txt`。

## 依赖构建约定

- 通用版本信息集中在 `sources/dependency-versions.sh`。
- 通用源码下载逻辑在 `sources/fetch-github-sources.sh`。
- 通用构建入口在 `sources/build-selected-deps.sh`。
- 各依赖的具体重建逻辑分别位于 `rebuildcurl.sh` 与 `sources/rebuild*.sh`。
- 镜像发布流水线位于 `.github/workflows/publish-build-images.yml`，提交后可由 CI 统一验证和发布。

## 遗留 VisualGDB 调试入口

- 使用 `docker compose -f docker-compose.debug.yml up --build -d x86-debug-builder` 启动本地调试构建容器。
- 容器通过 `127.0.0.1:2221` 暴露 SSH，对应 `LaneApp-Debug.vgdbsettings` 中的配置。
- 除 `x86Legacy` 外，其余镜像均采用统一的现代依赖栈。
