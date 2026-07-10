# ==============================================================================
# Interactive-shell setup, sourced from ~/.bashrc inside every container.
# Distro-agnostic via $ROS_DISTRO. Edit here once; every distro picks it up on
# its next image rebuild.
# ==============================================================================

# ---- ROS + workspace overlay ----
source "/opt/ros/${ROS_DISTRO:-humble}/setup.bash"
[ -f "${HOME}/ros2_ws/install/local_setup.bash" ] && source "${HOME}/ros2_ws/install/local_setup.bash"
[ -f /usr/share/colcon_argcomplete/hook/colcon-argcomplete.bash ] && source /usr/share/colcon_argcomplete/hook/colcon-argcomplete.bash

# ---- Build aliases ----
# -DCMAKE_EXPORT_COMPILE_COMMANDS=ON emits compile_commands.json so clangd gives
# you working C++ IntelliSense (in VS Code / the devcontainer).
#   cb        build the whole workspace
#   cbp <pkg> build a single package
#   ct        run tests and show results
alias cb='colcon build --symlink-install --parallel-workers ${PARALLEL_WORKERS:-2} --cmake-args -DCMAKE_BUILD_TYPE=Release -DCMAKE_EXPORT_COMPILE_COMMANDS=ON'
alias cbp='colcon build --symlink-install --parallel-workers ${PARALLEL_WORKERS:-2} --cmake-args -DCMAKE_BUILD_TYPE=Release -DCMAKE_EXPORT_COMPILE_COMMANDS=ON --packages-select'
alias ct='colcon test && colcon test-result --verbose'

echo "ROS 2 ${ROS_DISTRO:-humble} — workspace at ${HOME}/ros2_ws  (build: cb | cbp <pkg> | test: ct)"
