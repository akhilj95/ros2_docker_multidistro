#!/bin/bash
# Shared entrypoint: source ROS + the workspace overlay, then exec the command.
# Distro-agnostic — $ROS_DISTRO is set by the osrf/ros base image.
set -e

source "/opt/ros/${ROS_DISTRO:-humble}/setup.bash" || true

WS_SETUP="${HOME}/ros2_ws/install/local_setup.bash"
[ -f "${WS_SETUP}" ] && source "${WS_SETUP}" || true

if [ -f /usr/share/colcon_argcomplete/hook/colcon-argcomplete.bash ]; then
    source /usr/share/colcon_argcomplete/hook/colcon-argcomplete.bash
fi

exec "$@"
