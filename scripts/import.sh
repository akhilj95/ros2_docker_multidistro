#!/usr/bin/env bash
# ==============================================================================
# Import source repositories for a distro's workspace with vcstool.
#
#     ./scripts/import.sh <distro> [repos-file]
#     make import DISTRO=jazzy
#
# Reads ws/<distro>/project.repos (override with a 2nd arg) and clones the listed
# repos into ws/<distro>/src. If vcstool isn't installed on the host, it runs the
# import inside a throwaway ros:<distro>-ros-base container and chowns the result
# back to you (so the cloned files aren't left root-owned).
# ==============================================================================
set -euo pipefail
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$( dirname "${SCRIPT_DIR}" )"
cd "${PROJECT_ROOT}"

DISTRO="${1:-humble}"
REPOS_FILE="${2:-ws/${DISTRO}/project.repos}"
SRC_DIR="ws/${DISTRO}/src"

if [ ! -f "${REPOS_FILE}" ]; then
    echo "No repos file at ${REPOS_FILE} — nothing to import."
    echo "  Create one (copy ws/${DISTRO}/project.repos.example) and re-run:"
    echo "    make import DISTRO=${DISTRO}"
    exit 0
fi

mkdir -p "${SRC_DIR}"

if command -v vcs > /dev/null 2>&1; then
    echo "-> Importing ${REPOS_FILE} into ${SRC_DIR} (host vcstool)..."
    vcs import --recursive "${SRC_DIR}" < "${REPOS_FILE}"
else
    if ! docker ps > /dev/null 2>&1; then
        echo "ERROR: neither vcstool nor a usable Docker is available."
        echo "       Install vcstool (pipx install vcstool / apt install python3-vcstool)"
        echo "       or add yourself to the docker group."
        exit 1
    fi
    # Reuse an image you already have/need rather than pulling a distinct one:
    # prefer the built project image (already has vcstool → no apt, works
    # offline), else fall back to the same osrf/ros base the build uses. Run as
    # root (-u 0:0) because the built image's default user is non-root, so apt
    # and chown would otherwise fail.
    if docker image inspect "ros2_ws:${DISTRO}" > /dev/null 2>&1; then
        IMPORT_IMAGE="ros2_ws:${DISTRO}"
    else
        IMPORT_IMAGE="osrf/ros:${DISTRO}-desktop"
    fi
    echo "-> vcstool not on host; importing via ${IMPORT_IMAGE}..."
    # $(id -u)/$(id -g) expand on the HOST so the chown inside the container
    # restores your ownership. safe.directory '*' avoids git's 'dubious
    # ownership' error on the bind-mounted tree. vcstool is apt-installed only if
    # the chosen image doesn't already provide it.
    docker run --rm -u 0:0 \
        -v "${PROJECT_ROOT}:/work" \
        -w /work \
        "${IMPORT_IMAGE}" bash -c "\
            (command -v vcs > /dev/null 2>&1 || \
                (apt-get update -qq && apt-get install -y -qq python3-vcstool > /dev/null)) && \
            git config --global --add safe.directory '*' && \
            vcs import --recursive '${SRC_DIR}' < '${REPOS_FILE}' && \
            chown -R $(id -u):$(id -g) '${SRC_DIR}'"
fi

echo "Done. Next:  make shell DISTRO=${DISTRO}   then   cb"
