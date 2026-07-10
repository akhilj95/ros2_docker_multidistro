# syntax=docker/dockerfile:1.6
# ==============================================================================
# Generic ROS 2 workspace image, parameterized by ROS_DISTRO.
# One Dockerfile serves every distro — the base image and package names are all
# derived from ${ROS_DISTRO}. Build a distro with:
#     ROS_DISTRO=jazzy docker compose build
# (the Makefile sets ROS_DISTRO for you).
# ==============================================================================
ARG ROS_DISTRO=humble
FROM osrf/ros:${ROS_DISTRO}-desktop

# ARGs used *after* FROM must be re-declared.
ARG ROS_DISTRO
ARG DEBIAN_FRONTEND=noninteractive
ARG USERNAME=ros2user
ARG USER_UID=1000
ARG USER_GID=1000

# ---------- 1. Base dev tooling (distro-agnostic via ${ROS_DISTRO}) ----------
RUN apt-get update && apt-get install -y --no-install-recommends \
        ros-${ROS_DISTRO}-rmw-cyclonedds-cpp \
        build-essential cmake \
        clang clang-format clang-tidy clangd gdb \
        git wget curl nano vim tmux less sudo \
        iputils-ping iproute2 xauth \
        python3-pip \
        python3-colcon-common-extensions \
        python3-rosdep python3-vcstool python3-pytest \
    && rm -rf /var/lib/apt/lists/*

# ---------- 2. User account matching the host UID/GID ----------
# 24.04-based images (Jazzy, Kilted, ...) ship an 'ubuntu' user at UID 1000;
# remove it so the host-matching user can claim that UID. Matching UID/GID means
# files created in the bind-mounted workspace are owned by *you* on the host,
# not root.
RUN if getent passwd ubuntu > /dev/null 2>&1; then userdel -r ubuntu; fi && \
    if ! getent group  $USER_GID  > /dev/null 2>&1; then groupadd --gid $USER_GID $USERNAME; fi && \
    if ! getent passwd $USERNAME  > /dev/null 2>&1; then useradd --uid $USER_UID --gid $USER_GID -m -s /bin/bash $USERNAME; fi && \
    usermod -aG dialout,video $USERNAME 2>/dev/null || true && \
    echo "$USERNAME ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/$USERNAME && \
    chmod 0440 /etc/sudoers.d/$USERNAME

RUN rosdep init 2>/dev/null || true

# ---------- 2b. Per-distro extras (declarative; only affects THIS distro) -----
# Anything in docker/extras/<distro>/apt-packages.txt (system/ROS debs) or
# requirements.txt (pip) is installed only when building that distro. Missing or
# comment-only files are a no-op, so other distros stay lean. Edit those files,
# NOT this Dockerfile.
#
# pip: try --break-system-packages (needed on 24.04 / PEP 668), fall back to
# plain install on older pip (22.04) that doesn't know the flag.
COPY docker/extras /tmp/extras
RUN set -e; D="/tmp/extras/${ROS_DISTRO}"; \
    if [ -f "$D/apt-packages.txt" ] && grep -qvE '^[[:space:]]*(#|$)' "$D/apt-packages.txt"; then \
        apt-get update && \
        grep -vE '^[[:space:]]*(#|$)' "$D/apt-packages.txt" \
            | xargs apt-get install -y --no-install-recommends && \
        rm -rf /var/lib/apt/lists/*; \
    fi; \
    if [ -f "$D/requirements.txt" ] && grep -qvE '^[[:space:]]*(#|$)' "$D/requirements.txt"; then \
        python3 -m pip install --no-cache-dir -r "$D/requirements.txt" --break-system-packages 2>/dev/null \
        || python3 -m pip install --no-cache-dir -r "$D/requirements.txt"; \
    fi; \
    rm -rf /tmp/extras

# ---------- 3. Shared entrypoint + interactive-shell setup ----------
COPY docker/entrypoint.sh  /usr/local/bin/entrypoint.sh
COPY docker/shell-setup.sh /etc/ros2_shell_setup.sh
RUN chmod +x /usr/local/bin/entrypoint.sh && chmod 0644 /etc/ros2_shell_setup.sh

# ---------- 4. Switch to the user and wire up the shell ----------
USER $USERNAME
ENV HOME=/home/$USERNAME
WORKDIR $HOME/ros2_ws
RUN echo "source /etc/ros2_shell_setup.sh" >> $HOME/.bashrc
RUN rosdep update --rosdistro=${ROS_DISTRO}

# ---------- 5. (Optional) bake project deps ----------
# For a real project, copy your src in and let rosdep apt-install the system
# deps declared in each package.xml, then delete src (the live src arrives via
# the bind mount at runtime). Uncomment when you have packages:
#
# COPY --chown=$USER_UID:$USER_GID ws/${ROS_DISTRO}/src ./src
# RUN sudo apt-get update && \
#     rosdep install -i --from-path src --rosdistro ${ROS_DISTRO} -y --ignore-src && \
#     sudo rm -rf /var/lib/apt/lists/* && rm -rf ./src

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash"]
