# Per-distro image extras

Files here are consumed by `docker/Dockerfile` at build time. Each distro folder
may contain:

- `apt-packages.txt` — system libraries or released ROS debs (one per line)
- `requirements.txt` — pip packages

Only the folder matching the distro being built is used, so extras for one distro
never bloat another. Comment lines (`#`) and blank lines are ignored, and missing
files are fine. After editing, rebuild that distro's image:

    make build DISTRO=jazzy      # or: make shell DISTRO=jazzy (rebuilds if needed)

## Which channel?

- ROS **package you build** (e.g. the kiss-icp ROS node) → put it in
  `ws/<distro>/src/` and run `cb`; no image change needed.
- **pip** dependency → `requirements.txt` here.
- **system lib / released ROS deb** → `apt-packages.txt` here.

## One-off alternative

For a genuine one-off you can also branch inside the Dockerfile directly:

    ARG ROS_DISTRO
    RUN if [ "$ROS_DISTRO" = "jazzy" ]; then \
          sudo apt-get update && sudo apt-get install -y --no-install-recommends \
            ros-jazzy-something && sudo rm -rf /var/lib/apt/lists/* ; \
        fi

The manifest files are just a tidier version of this that you don't have to keep
editing the Dockerfile for.
