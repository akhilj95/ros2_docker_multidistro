# ros2-multidistro

One repo, many ROS 2 distros. Each distro gets its own image, container, and
colcon workspace; a single `make` command drops you into a terminal in the one
you want. The distro is a **parameter**, so adding one is just creating a folder.

## Layout

```
.
├── Makefile                 # make shell DISTRO=jazzy  (and friends)
├── compose.yml              # single service, parameterized by ROS_DISTRO
├── compose.gpu.yml          # NVIDIA overlay (opt-in, layered on top)
├── .env.example             # copy to .env, or run `make init`
├── docker/
│   ├── Dockerfile           # one Dockerfile, ROS_DISTRO build arg
│   ├── entrypoint.sh        # distro-agnostic (sources ROS + overlay)
│   └── shell-setup.sh       # distro-agnostic (cb / cbp / ct aliases)
├── scripts/
│   ├── init.sh              # generate .env from your host user
│   ├── shell.sh             # build/start/enter a distro's container
│   └── _x11_setup.sh        # X11 cookie injection (GUIs, incl. ssh -Y)
├── config/
│   └── cyclonedds.xml       # shared, version-controlled DDS config
├── data/                    # single mounted data folder (gitignored)
├── ws/
│   ├── humble/src/          # per-distro workspace source (tracked)
│   └── jazzy/src/           # build/install/log get created + gitignored
└── .devcontainer/
    └── devcontainer.json    # VS Code, follows ROS_DISTRO from .env
```

## Quick start

```bash
make init                 # writes .env matching your host UID/GID (run once)
make shell DISTRO=humble  # first run builds the image, then opens a terminal
make jazzy                # shortcut for: make shell DISTRO=jazzy
```

Inside the container: put packages in `ws/<distro>/src` (edit them on the host),
then `cb` to build, `cbp <pkg>` for one package, `ct` to test. The build emits
`compile_commands.json` for clangd IntelliSense.

## Adding a distro

Nothing to edit — just:

```bash
make shell DISTRO=kilted
```

It creates `ws/kilted/`, builds `osrf/ros:kilted-desktop`, and enters it.
(Optional: add a two-line `kilted:` shortcut in the Makefile, and a
`ws/kilted/src/.gitkeep` if you want the folder tracked before it has code.)

Currently supported upstream distros to point at: **Humble** (Ubuntu 22.04,
supported to May 2027), **Jazzy** (24.04, LTS, to May 2029), **Kilted** (24.04,
non-LTS), **Lyrical Luth** (26.04, LTS), and **Rolling**. Iron/Foxy/Galactic are
end-of-life. Verify the current list at https://docs.ros.org before standardizing.

## GPU

Needs the NVIDIA Container Toolkit on the host (not just the driver). Then:

```bash
make shell DISTRO=humble GPU=1
```

This layers `compose.gpu.yml`, which reserves the GPU and sets the driver
capabilities. `graphics,display` handles OpenGL for RViz/Gazebo; `compute`
handles CUDA. You don't need a CUDA base image just for accelerated
visualization.

## VS Code dev container

Open the folder and "Reopen in Container". It attaches to whichever distro
`ROS_DISTRO` names in `.env`; to switch, change that value and rebuild. The CLI
(`make shell DISTRO=...`) can run any distro at any time regardless — VS Code
just tracks one active distro at a time.

## Adding packages to one distro only

Three channels, depending on what the thing is:

- **A ROS package you build** (e.g. the kiss-icp ROS node) → put it in
  `ws/<distro>/src/` (git clone, or a `*.repos` file + `vcs import`) and run `cb`
  inside the container. It's scoped to that workspace and needs no image rebuild.
- **A pip dependency** → add it to `docker/extras/<distro>/requirements.txt`.
- **A system lib or released ROS deb** → add it to
  `docker/extras/<distro>/apt-packages.txt`.

The last two are baked into that distro's image only; other distros ignore them.
Edit the manifest files, not the Dockerfile, then `make build DISTRO=<distro>`.
See `docker/extras/README.md` for details and a one-off Dockerfile alternative.

Worked example — kiss-icp on Jazzy (the ROS node is a colcon package). Either
clone it straight in:

```bash
git clone https://github.com/PRBonn/kiss-icp ws/jazzy/src/kiss-icp
make shell DISTRO=jazzy
cbp kiss_icp          # builds just that package; fetches its core lib
```

...or, better for reproducibility, list it in a `.repos` manifest (see below) so
a fresh checkout rebuilds the whole workspace with one command.

(The `kiss-icp` PyPI package is the standalone Python pipeline/CLI, not the ROS
node — use `requirements.txt` for that instead.)

### Reproducible source workspaces (`.repos` + `make import`)

Instead of cloning packages by hand, declare them in `ws/<distro>/project.repos`
(vcstool format) — copy `ws/<distro>/project.repos.example` to get started:

```bash
cp ws/jazzy/project.repos.example ws/jazzy/project.repos   # edit as needed
make import DISTRO=jazzy                                    # clones into ws/jazzy/src
make shell DISTRO=jazzy                                     # then: cb
```

`make import` uses your host's `vcstool` if it's installed. If it isn't, it runs
the import in a container — preferring the already-built `ros2_ws:<distro>` image
(which already has vcstool), or falling back to the same `osrf/ros:<distro>`
base the build uses, so it never pulls a distinct image just for importing. It
runs as root and chowns the cloned files back to you, so this works on a bare
machine with only Docker.

Commit `project.repos` (it's the source of truth). The cloned packages under
`ws/<distro>/src/` you can either commit or gitignore per project; if you prefer
to keep them out of git, add the specific imported paths to `.gitignore`.

## Notes / knobs

- **UID/GID matching** (`make init`) keeps workspace files owned by you on the
  host, not root. If you skip it, set `USER_UID`/`USER_GID` in `.env` manually.
- **One data folder**: everything non-code (bags, maps, calibration) goes under
  `data/`, mounted at `~/data`. Point `DATA_DIR` at a big disk or NAS to keep it
  out of the repo.
- **DDS**: `ROS_DOMAIN_ID` and the RMW/CycloneDDS settings in `.env` must match
  across every ROS 2 participant on the network.
- **Bespoke distro**: if one distro needs special build steps, drop in
  `docker/Dockerfile.jazzy` and set `DOCKERFILE=Dockerfile.jazzy` in `.env`.
- **Hardware access** (serial, USB cameras, etc.): this generic base has no
  device passthrough. Add a `compose.hw.yml` overlay with the `devices:` /
  `group_add:` / `privileged:` you need, and layer it like the GPU file.
