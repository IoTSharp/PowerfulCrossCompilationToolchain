@echo off
setlocal EnableExtensions EnableDelayedExpansion

if "%~1"=="" goto :usage
if /I "%~1"=="--help" goto :usage0
if /I "%~1"=="-h" goto :usage0

set "BUILD_DIR=%~1"
shift

set "BUILD_COMMAND=make"
set "MODE=pull"
set "TARGETS=all"
if not "%~1"=="" (
    set "FIRST_ARG=%~1"
    if not "!FIRST_ARG:~0,1!"=="-" (
        set "BUILD_COMMAND=%~1"
        shift
    )
)

set "COMPOSE_ARGS="
:collect_args
if "%~1"=="" goto :normalize
if /I "%~1"=="--help" goto :usage0
if /I "%~1"=="-h" goto :usage0
if /I "%~1"=="--mode" goto :set_mode
if /I "%~1"=="--pull" goto :set_pull
if /I "%~1"=="--build" goto :set_build
if /I "%~1"=="--targets" goto :set_targets
if /I "%~1"=="--target" goto :set_targets
if /I "%~1"=="--cmd" goto :set_cmd
if /I "%~1"=="--" goto :collect_rest
set "COMPOSE_ARGS=%COMPOSE_ARGS% %1"
shift
goto :collect_args

:set_mode
if "%~2"=="" goto :missing_mode
set "MODE=%~2"
shift
shift
goto :collect_args

:set_pull
set "MODE=pull"
shift
goto :collect_args

:set_build
set "MODE=build"
shift
goto :collect_args

:set_targets
if "%~2"=="" goto :missing_targets
set "TARGETS=%~2"
shift
shift
:collect_targets_tail
if "%~1"=="" goto :collect_args
set "NEXT_ARG=%~1"
if "!NEXT_ARG:~0,1!"=="-" goto :collect_args
set "TARGETS=%TARGETS%,%~1"
shift
goto :collect_targets_tail

:set_cmd
if "%~2"=="" goto :missing_cmd
set "BUILD_COMMAND=%~2"
shift
shift
goto :collect_args

:collect_rest
shift
if "%~1"=="" goto :normalize
set "COMPOSE_ARGS=%COMPOSE_ARGS% %1"
shift
goto :collect_rest

:missing_mode
echo Missing value for --mode 1>&2
exit /b 2

:missing_targets
echo Missing value for --targets 1>&2
exit /b 2

:missing_cmd
echo Missing value for --cmd 1>&2
exit /b 2

:normalize
if /I "%MODE%"=="pull" goto :resolve_targets
if /I "%MODE%"=="build" goto :resolve_targets
echo Unsupported mode: %MODE% 1>&2
exit /b 2

:resolve_targets
set "SERVICES="
if /I "%TARGETS%"=="all" goto :resolve_files
set "TARGET_LIST=%TARGETS:,= %"
set "TARGET_LIST=!TARGET_LIST:+= !"
for %%S in (%TARGET_LIST%) do (
    if not "%%~S"=="" set "SERVICES=!SERVICES! %%~S"
)

:resolve_files
set "COMPOSE_FILES=-f docker-compose.yml"
if /I "%MODE%"=="build" (
    set "COMPOSE_FILES=!COMPOSE_FILES! -f docker-compose.override.yml"
    set "COMPOSE_ARGS=!COMPOSE_ARGS! --build"
)

:run

echo BUILD_DIR=%BUILD_DIR%
echo BUILD_COMMAND=%BUILD_COMMAND%
echo MODE=%MODE%
echo TARGETS=%TARGETS%
if not "%COMPOSE_ARGS%%SERVICES%"=="" (
    echo docker compose %COMPOSE_FILES% up %COMPOSE_ARGS% %SERVICES%
) else (
    echo docker compose %COMPOSE_FILES% up
)

set "BUILD_DIR=%BUILD_DIR%"
set "BUILD_COMMAND=%BUILD_COMMAND%"
docker compose %COMPOSE_FILES% up %COMPOSE_ARGS% %SERVICES%
exit /b %ERRORLEVEL%

:usage
echo Usage:
echo   %~nx0 ^<build-dir^> [build-command] [options] [-- docker-compose-up-args...]
echo.
echo Options:
echo   --mode pull^|build      Choose remote image pull or local image build. Default: pull
echo   --pull                 Alias for --mode pull
echo   --build                Alias for --mode build
echo   --targets LIST         Comma-separated or space-separated targets, for example x64,arm64 or x64 arm64. Default: all
echo   --cmd COMMAND          Build command to run inside the containers. Default: make
echo   --help                 Show this help
echo.
echo Targets:
echo   all, x86legacy, x86, arm, x64, arm64, loongson, centos79
echo.
echo Examples:
echo   %~nx0 D:\work\LaneApp
echo   %~nx0 D:\work\LaneApp --targets x64,arm64
echo   %~nx0 D:\work\LaneApp "cmake --build build" --build --targets x86,x64
echo   %~nx0 D:\work\LaneApp --mode build --targets all -- --abort-on-container-exit
exit /b 1

:usage0
call :usage
exit /b 0
