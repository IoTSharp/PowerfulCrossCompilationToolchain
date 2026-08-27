#!/bin/sh

set -eu

show_usage() {
    cat >&2 <<'EOF'
Usage:
  compose-up-all.sh <build-dir> [build-command] [options] [-- docker-compose-up-args...]

Options:
  --mode pull|build      Choose remote image pull or local image build. Default: pull
  --pull                 Alias for --mode pull
  --build                Alias for --mode build
  --targets <list>       Comma-separated or space-separated targets, for example x64,arm64 or x64 arm64. Default: all
  --cmd <command>        Build command to run inside the containers. Default: make
  --help                 Show this help

Targets:
  all, x86legacy, x86, arm, x64, arm64, loongson, centos79

Examples:
  sh ./compose-up-all.sh /work/LaneApp
  sh ./compose-up-all.sh /work/LaneApp --targets x64,arm64
  sh ./compose-up-all.sh /work/LaneApp "cmake --build build" --build --targets x86,x64
  sh ./compose-up-all.sh /work/LaneApp --mode build --targets all -- --abort-on-container-exit
EOF
}

if [ "$#" -lt 1 ]; then
    show_usage
    exit 1
fi

if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    show_usage
    exit 0
fi

BUILD_DIR=$1
shift

BUILD_COMMAND=make
MODE=pull
TARGETS=all
COMPOSE_ARGS=
if [ "$#" -gt 0 ]; then
    case "$1" in
        -*)
            ;;
        *)
            BUILD_COMMAND=$1
            shift
            ;;
    esac
fi

while [ "$#" -gt 0 ]; do
    case "$1" in
        --help|-h)
            show_usage
            exit 0
            ;;
        --mode)
            if [ "$#" -lt 2 ]; then
                echo "Missing value for --mode" >&2
                exit 2
            fi
            MODE=$2
            shift 2
            ;;
        --pull)
            MODE=pull
            shift
            ;;
        --build)
            MODE=build
            shift
            ;;
        --targets|--target)
            if [ "$#" -lt 2 ]; then
                echo "Missing value for --targets" >&2
                exit 2
            fi
            TARGETS=$2
            shift 2
            while [ "$#" -gt 0 ]; do
                case "$1" in
                    -*)
                        break
                        ;;
                    *)
                        TARGETS=$TARGETS,$1
                        shift
                        ;;
                esac
            done
            ;;
        --cmd)
            if [ "$#" -lt 2 ]; then
                echo "Missing value for --cmd" >&2
                exit 2
            fi
            BUILD_COMMAND=$2
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            COMPOSE_ARGS="$COMPOSE_ARGS $1"
            shift
            ;;
    esac
done

while [ "$#" -gt 0 ]; do
    COMPOSE_ARGS="$COMPOSE_ARGS $1"
    shift
done

case "$MODE" in
    pull|build)
        ;;
    *)
        echo "Unsupported mode: $MODE" >&2
        exit 2
        ;;
esac

SERVICES=
if [ "$TARGETS" != "all" ]; then
    TARGETS=$(printf '%s' "$TARGETS" | tr '+' ',')
    OLD_IFS=$IFS
    IFS=,
    for service in $TARGETS; do
        IFS=$OLD_IFS
        if [ -n "$service" ]; then
            SERVICES="$SERVICES $service"
        fi
        IFS=,
    done
    IFS=$OLD_IFS
fi

FILES="-f docker-compose.yml"
if [ "$MODE" = "build" ]; then
    FILES="$FILES -f docker-compose.override.yml"
    COMPOSE_ARGS="$COMPOSE_ARGS --build"
fi

echo "BUILD_DIR=$BUILD_DIR"
echo "BUILD_COMMAND=$BUILD_COMMAND"
echo "MODE=$MODE"
echo "TARGETS=$TARGETS"
if [ -n "$COMPOSE_ARGS$SERVICES" ]; then
    echo "docker compose $FILES up$COMPOSE_ARGS$SERVICES"
else
    echo "docker compose $FILES up"
fi

export BUILD_DIR BUILD_COMMAND
# shellcheck disable=SC2086
exec docker compose $FILES up $COMPOSE_ARGS $SERVICES
