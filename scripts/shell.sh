#!/usr/bin/env bash
# ==============================================================================
# Build (if needed), start, and drop into a terminal for one ROS 2 distro.
#     ./scripts/shell.sh <distro> [gpu]
#     ./scripts/shell.sh jazzy          # CPU
#     ./scripts/shell.sh humble 1       # with NVIDIA GPU passthrough
# Usually invoked via `make shell DISTRO=... [GPU=1]`.
# ==============================================================================
set -euo pipefail
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$( dirname "${SCRIPT_DIR}" )"
cd "${PROJECT_ROOT}"

DISTRO="${1:-humble}"
GPU="${2:-0}"

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/_x11_setup.sh"

# Load .env (user name, data dir, DDS settings, ...).
if [ -f .env ]; then
    set -a; # shellcheck disable=SC1091
    source .env; set +a
fi
USER_NAME="${USER_NAME:-ros2user}"

# ROS_DISTRO must be exported so compose interpolates image/container/volume names.
export ROS_DISTRO="${DISTRO}"
# Own compose project per distro → starting one never recreates another.
export COMPOSE_PROJECT_NAME="ros2_${DISTRO}"

COMPOSE_FILES=(-f compose.yml)
[ "${GPU}" = "1" ] && COMPOSE_FILES+=(-f compose.gpu.yml)

CONTAINER="ros2_${DISTRO}"
mkdir -p "ws/${DISTRO}/src" "ws/${DISTRO}/build" "ws/${DISTRO}/install" "ws/${DISTRO}/log"

if ! docker ps > /dev/null 2>&1; then
    echo "ERROR: Docker is not accessible. Add yourself to the docker group:"
    echo "         sudo usermod -aG docker \$USER && newgrp docker"
    exit 1
fi

# Start (building on first run) if the container isn't up.
if [ -z "$(docker ps -q -f name=^/${CONTAINER}$)" ]; then
    echo "-> ${CONTAINER} not running — building/starting (first build takes a while)..."
    docker compose "${COMPOSE_FILES[@]}" up -d --build
    until docker exec "${CONTAINER}" true > /dev/null 2>&1; do sleep 1; done
fi

# Refresh this session's X11 cookie into the container (GUIs over local or ssh -Y).
push_xauth_into_container "${CONTAINER}" "${USER_NAME}"

echo "Entering ${CONTAINER} (ROS 2 ${DISTRO}) as ${USER_NAME}..."
exec docker exec -it \
    -e DISPLAY="${DISPLAY:-}" \
    -u "${USER_NAME}" \
    -w "/home/${USER_NAME}/ros2_ws" \
    "${CONTAINER}" bash