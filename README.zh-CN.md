# 构建镜像说明

English README: [README.md](README.md)

本仓库保存的是构建镜像定义，供本地验证、CI，以及遗留的 VisualGDB 调试容器共同使用。

## 目录布局

- `sources/`：保存共享依赖版本清单、源码拉取脚本、各平台构建脚本、LaneApp 的 LVGL 配置、固定的 MiniGUI 源码归档，以及遗留 ARM 工具链压缩包。
- `x86Legacy/`：遗留 Wheezy 基线的 X86 调试镜像，包含 MiniGUI 2.0.4、SSH，以及旧版工具链/调试环境。
- `x86/`：独立的 LaneApp i386 编译基线，固定为 Ubuntu 16.04、GCC 5.4、glibc 2.23、Clang 6，并包含 MiniGUI 2.0.4、GDB/GDBServer、Valgrind、strace/ltrace 和 GCC Sanitizer 运行库。
- `arm/`：ARM32 LaneApp 交叉编译基线，使用 Ubuntu 16.04 宿主工具、GCC 5.4、遗留 glibc 2.13、从固定源码归档重建的 MiniGUI 2.0.4、EABI5 soft-float，并生成兼容 ARMv4T 的代码，同时提供与 X86 镜像一致的静态车牌识别 API。
- `x64/`：带完整静态依赖和识别栈的原生 `X64` 构建镜像。
- `arm64/`：带完整静态依赖和识别栈的 `ARM64` 交叉构建镜像。
- `loongson/`：带完整静态依赖和识别栈的 `LA64` 交叉构建镜像。
- `centos79/`：面向最终版 CentOS 7.9.2009/glibc 2.17 基线的专用原生 X64 构建镜像。

## 共享依赖策略

- 可移植的第三方依赖统一在镜像构建阶段下载，来源为固定的 GitHub release/tag 压缩包，并在解压前进行 SHA256 校验。
- 所有对齐后的镜像统一固定使用 `curl 8.10.1`、`libxml2 2.12.10`、`freetype 2.13.3`、`libusb 1.0.23`、`sqlite 3.51.2`、`FFmpeg 4.4.5`、`PostgreSQL/libpq 17.2`、`mbedTLS 3.4.0`、固定提交的 libpeer，以及 LaneApp `LVGL 9.3.0` 配置。
- `libusb` 固定在 `1.0.23`，继续保持保守的 ARM32 源码和运行时兼容基线。
- ARM 镜像把 Ubuntu GCC 5.4 交叉编译器与仓库内遗留 sysroot 组合使用；镜像自检会验证 32 位 EABI5 soft-float、`/lib/ld-linux.so.3`、glibc 2.13 上限、FORTIFY 关闭状态、PostgreSQL 私有静态库，以及识别栈的目标架构和静态链接闭包。
- `sqlite` 与上游应用保持 `3.51.2` 一致，镜像内提供匹配版本的静态库 `libsqlite3.a`，并与其他依赖一样在镜像构建时从固定 GitHub tag 拉取源码。
- 独立 X86 镜像从固定源码归档构建 LaneApp 依赖，把静态库、头文件和 `pkg-config` 元数据安装到 `/usr/local`。原来 LaneApp 私有的 FFmpeg/VAAPI 构建链也迁入该镜像，因此以后只修改 LaneApp 代码时不再重新编译这些第三方库，LaneApp 也不再保留 FFmpeg 子模块。
- 对齐后的镜像均为 curl 保留 HTTPS，并与 libpeer、libsrtp、FFmpeg 统一使用 mbedTLS 3.4.0；IPv6 关闭。OpenSSL 1.1.1w 只保留为可选源码构建配置，不进入默认镜像，避免同一 LaneApp 进程同时引入两套 TLS 实现。
- X86 FFmpeg 启用 H.264 VAAPI，并使用 Xenial 的 libva/libdrm。FFmpeg 本身静态链接，面向硬件的 i965 驱动及其固定的 32 位 libva/libdrm 运行时输出到 `/opt/pcct/runtime/vaapi`，供 LaneApp 打包。
- X86、X64、ARM32、ARM64、LA64 和 CentOS 7.9 的 LaneApp 车牌识别配置统一固定使用 OpenCV `4.5.1`、MNN `2.2.0` 和 HyperLPR 提交 `9307450f7b7915be18f23a539ec05b41fe6629f4`（PCCT 包版本 `3.0.1.9307450.1`）。OpenCV 只保留静态 `core`、`imgproc`，MNN 只保留单线程 CPU 静态推理；HyperLPR 和 6 个已校验模型全部放入 `libhyperlpr3.a`，各架构也都通过 `liblaneapp-nanodet.a` 提供嵌入式 NanoDet 模型。新增的 extend-only `HLPR_ContextObserveDetections` ABI 最多返回 5 项 OCR 过滤前的检测观察，同时保留原更新接口。所有架构使用相同的 pkg-config 契约离线链接，不增加识别运行时共享库或模型文件。X86、ARM32 和 CentOS 7.9 会在基础系统 CMake 过旧时构建固定的 CMake `3.14.7` 宿主工具，现代 Debian 镜像使用发行版 CMake。
- 识别依赖许可证、模型哈希、补丁哈希、能力元数据和 NOTICE 记录安装在目标前缀的 `share/licenses` 下，MNN、OpenCV 的许可证位于相邻版本目录；受控 HyperLPR 补丁及维护规则记录在 `sources/HYPERLPR3.md`。固定的 MNN 工具链补丁补充标准整数头文件，并带入上游 2.2.1 的 ARM64 汇编兼容修复；`sources/patches/mnn-2.2.0-i386-simd.patch` 仍只服务于 i386 的 SSE4.1/AVX2/FMA 运行时分派。遗留 ARMv4T 配置明确使用 MNN 的通用标量 CPU 路径，不启用 ARMv7 NEON 汇编。
- 所有对齐后的镜像都会把 curl、libxml2、FFmpeg、libpeer/libsrtp、mbedTLS、libpq、libusb 和 LaneApp LVGL 配置链接到目标架构的静态验证程序，并交叉链接 HyperLPR 和 NanoDet 消费程序，拒绝识别共享库或散落的运行时模型文件。X86 继续验证专用 VAAPI 运行时，ARM32 继续验证 EABI5/glibc 2.13，LA64 继续验证工具链，CentOS 7.9 强制 glibc 2.17 上限。
- 所有镜像都分别从仓库内固定的 MiniGUI 2.0.4 源码归档构建，不从其他镜像或遗留 ARM sysroot 复用 MiniGUI 构建产物。
- CentOS 7 已停止维护；专用镜像固定到最终版 `7.9.2009` 基础镜像和归档软件源，仅用于兼容性构建，不代表仍可持续获得安全更新。
- CentOS 配置使用归档的 Developer Toolset 7 编译器，因为 MNN 要求 GCC 4.9 或更高版本；链接验证仍强制 CentOS glibc 2.17 上限，并拒绝动态识别库或 C++ 运行库依赖。

## 使用 Docker Compose 并行构建

- `docker-compose.yml` 可以一次启动全部构建镜像，并把宿主机上的源码目录挂载到容器内的 `/LaneApp`。
- `docker-compose.yml` 是日常运行入口，默认从 GHCR 拉取预构建镜像。
- `docker-compose.override.yml` 只保存本地 `build` 定义；执行 `docker compose up --build` 时，会在启动前按 override 中的配置本地构建镜像。
- 通过环境变量 `BUILD_DIR` 指定要构建的宿主机目录，可选环境变量 `BUILD_COMMAND` 指定实际执行的构建命令，默认是 `make`。
- 可选环境变量 `PCCT_IMAGE_PREFIX` 用于切换镜像前缀，默认值为 `ghcr.io/iotsharp`；`PCCT_IMAGE_TAG` 默认为 `latest`。
- CentOS 镜像还会发布随主分支更新的 `7.9` 和 `7.9.2009` 别名。使用 CentOS 专属标签时应同时指定 `--targets centos79`；其他镜像仓库发布 `latest` 和不可变的 `sha-<提交>` 标签。
- 为了避免每次手动设置环境变量，仓库根目录还提供了 `compose-up-all.cmd` 和 `compose-up-all.sh` 两个包装脚本。
- 包装脚本默认工作模式是 `pull`，即只使用 `docker-compose.yml` 并从远端拉取镜像；传入 `--build` 或 `--mode build` 后，会自动叠加 `docker-compose.override.yml` 并执行本地镜像构建。
- 包装脚本默认目标平台是 `all`，也可以通过 `--targets` 单独或组合指定，例如 `x64`、`arm64`、`centos79` 或 `x86 x64`；支持的平台名为 `x86legacy`、`x86`、`arm`、`x64`、`arm64`、`loongson`、`centos79`。
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
- 除 `x86Legacy` 外，其他镜像使用对齐后的依赖栈。

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
