# EndeavourOS-ISO-arm64

[![Build](https://github.com/startergo/EndeavourOS-ISO-arm64/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/startergo/EndeavourOS-ISO-arm64/actions/workflows/build.yml)
[![Release](https://img.shields.io/github/v/release/startergo/EndeavourOS-ISO-arm64?label=latest%20release)](https://github.com/startergo/EndeavourOS-ISO-arm64/releases/latest)

EndeavourOS live ISO for **aarch64** — designed to run in **UTM on Apple Silicon** (QEMU/HVF).

## Distribution

Since the EndeavourOS Live ISO now uses KDE Plasma, the image is too large for GitHub Release asset limits.
This repository publishes release assets as compressed files (and split parts when needed), plus a generated `helper.sh`.
Run the helper from your target release tag:

```bash
curl -fsSL https://github.com/startergo/EndeavourOS-ISO-arm64/releases/download/<release-tag>/helper.sh | bash
```

Modelled after [EndeavourOS-ISO-t2](https://github.com/t2linux/EndeavourOS-ISO-t2):
same mkarchiso toolchain, same KDE Plasma 6 desktop, same Calamares installer — adapted for
ARM64 architecture and QEMU virtual machines.

---

## Quick start

### Build requirements

Must build on **aarch64** (native ARM64). Options:
- GitHub Actions `ubuntu-24.04-arm` runner (CI — recommended)
- Locally in a UTM VM on Apple Silicon running EndeavourOS/Arch ARM

```bash
sudo pacman -S --needed arch-install-scripts squashfs-tools mtools dosfstools xorriso imagemagick wget
```

`mkarchiso` is shipped in this repository, so the `archiso` package is not required on hosts where it is unavailable.
`reflector` is also not required for this profile (the repository mirrorlist is copied by `prepare.sh`).

If your host is not already configured with EndeavourOS ARM repositories and keys, bootstrap them once:

```bash
sudo cp pacman.conf /tmp/bootstrap-pacman.conf
sudo sed -i 's/SigLevel = PackageRequired/SigLevel = Never/' /tmp/bootstrap-pacman.conf
sudo pacman --config /tmp/bootstrap-pacman.conf -Sy --noconfirm
sudo pacman --config /tmp/bootstrap-pacman.conf -S --noconfirm endeavouros-keyring endeavouros-mirrorlist
sudo pacman-key --populate endeavouros
sudo rm -f /tmp/bootstrap-pacman.conf
```

### Build

```bash
git clone https://github.com/startergo/EndeavourOS-ISO-arm64
cd EndeavourOS-ISO-arm64

bash prepare.sh         # download wallpapers, rank mirrors, build skel
bash reset.sh           # clean cached work/out when retrying after config changes
sudo bash mkarchiso -v "."   # build ISO → out/
```

### Boot in UTM

1. Open **UTM** → New VM → **Virtualize** → **Linux**
2. Select the `out/EndeavourOS_Ganymede-YYYY.MM.DD.iso`
3. Allocate RAM (4 GB+ recommended for live KDE session)

---

## Docker build (cross-platform)

Build the ISO on any platform with Docker installed (macOS, Linux, x86_64, aarch64).

### Build using the helper script

```bash
git clone https://github.com/startergo/EndeavourOS-ISO-arm64
cd EndeavourOS-ISO-arm64

./docker-build.sh build    # Build Docker image (one-time)
./docker-build.sh all      # Full build (prepare + iso)
```

### Available commands

| Command | Description |
|---------|-------------|
| `./docker-build.sh build` | Build Docker image (no cache) |
| `./docker-build.sh build-cache` | Build Docker image (with cache) |
| `./docker-build.sh prepare` | Run prepare.sh only |
| `./docker-build.sh iso` | Build ISO only |
| `./docker-build.sh all` | Full build (prepare + iso) |
| `./docker-build.sh push [tag]` | Push builder image + ISO to both registries |
| `./docker-build.sh push-ghcr [tag]` | Push builder image + ISO to ghcr.io only |
| `./docker-build.sh push-dockerhub [tag]` | Push builder image to Docker Hub only |
| `./docker-build.sh shell` | Interactive shell in container |
| `./docker-build.sh clean` | Clean build artifacts |

### Pre-built Docker image

Pull the builder image directly instead of building it:

```bash
# From Docker Hub
docker pull startergo/endeavouros-aarch64-builder:latest

# From GitHub Container Registry
docker pull ghcr.io/startergo/endeavouros-aarch64-builder:latest
```

Then run a full build using the pulled image:

```bash
mkdir -p out
docker run --rm -it --privileged \
  -v "$(pwd):/workspace" \
  -v "$(pwd)/out:/out" \
  -w /workspace \
  startergo/endeavouros-aarch64-builder \
  bash -c "mkdir -p /build/work /build/out && bash prepare.sh && \
           MKARCHISO_WORK_DIR=/build/work bash mkarchiso -v -w /build/work -o /build/out . && \
           cp /build/out/*.iso /out/"
```

> **Note:** The build work directory is kept inside the container at `/build/work` (Linux
> case-sensitive filesystem) rather than bind-mounted from macOS, which avoids
> case-collision issues with `xorg-server` package files.

---
4. Boot — UTM provides UEFI firmware automatically for aarch64

---

## Repository structure

```
EndeavourOS-ISO-arm64/
├── profiledef.sh               # arch=aarch64, uefi.systemd-boot only
├── pacman.conf                 # Arch Linux ARM + EndeavourOS ARM repos
├── mirrorlist                  # ALARM mirror fallback
├── packages.aarch64            # Package list (x86-specific packages removed)
├── mkarchiso                   # Build script (from upstream archiso, EOS fork)
├── prepare.sh                  # Pre-build: wallpaper, mirrorlist, skel
├── run_before_squashfs.sh      # Chroot: users, services, offline packages
├── reset.sh                    # Clean build artifacts
├── Dockerfile                  # Docker builder image (Arch Linux ARM)
├── docker-build.sh             # Build/push helper script
├── docker-entrypoint.sh        # Container entrypoint
├── .dockerignore               # Docker build context exclusions
│
├── airootfs/                   # Live filesystem overlay
│   ├── etc/systemd/system/     # Services (no NVIDIA/Intel/Broadcom)
│   └── usr/bin/                # No hardware detection scripts
│
├── efiboot/loader/
│   ├── loader.conf             # default archiso-aarch64-linux.conf
│   └── entries/
│       └── archiso-aarch64-linux.conf  # UEFI boot entry (no microcode, no x86 opts)
│
└── .github/workflows/build.yml   # CI on ubuntu-24.04-arm (native aarch64)
```

---

## Credits

- [EndeavourOS](https://endeavouros.com) — distribution and build system
- [EndeavourOS-ISO-t2](https://github.com/endeavouros-team/EndeavourOS-ISO-t2) — direct base
- [Arch Linux ARM](https://archlinuxarm.org) — aarch64 package repositories
- [UTM](https://mac.getutm.app) — QEMU frontend for Apple Silicon
