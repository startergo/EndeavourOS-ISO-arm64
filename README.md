# EndeavourOS-ISO-arm64

[![Build](https://github.com/startergo/EndeavourOS-ISO-arm64/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/startergo/EndeavourOS-ISO-arm64/actions/workflows/build.yml)
[![Release](https://img.shields.io/github/v/release/startergo/EndeavourOS-ISO-arm64?label=latest%20release)](https://github.com/startergo/EndeavourOS-ISO-arm64/releases/latest)

EndeavourOS live ISO for **aarch64** — designed to run in **UTM on Apple Silicon** (QEMU/HVF).

## Distribution

Since the EndeavourOS Live ISO now uses KDE Plasma, the image is too large for GitHub Release asset limits.
This repository publishes split `.iso.zst.part-*` release assets when needed.
Download all parts from the matching release and reassemble locally:

```bash
cat EndeavourOS_Ganymede-YYYY.MM.DD.iso.zst.part-* > EndeavourOS_Ganymede-YYYY.MM.DD.iso.zst
zstd -d EndeavourOS_Ganymede-YYYY.MM.DD.iso.zst -o EndeavourOS_Ganymede-YYYY.MM.DD.iso
```

Modelled after [EndeavourOS-ISO-t2](https://github.com/t2linux/EndeavourOS-ISO-t2):
same mkarchiso toolchain, same KDE Plasma 6 desktop, same Calamares installer — adapted for
ARM64 architecture and QEMU virtual machines.

---

## What's different from the x86_64 ISO

| | x86_64 (EndeavourOS-ISO-t2) | aarch64 (this repo) |
|---|---|---|
| Architecture | x86_64 | aarch64 |
| Packages | Arch Linux + EOS repos | Arch Linux ARM + EOS ARM repos |
| Boot modes | BIOS (syslinux) + UEFI | UEFI only |
| CPU microcode | intel-ucode, amd-ucode | — (not applicable) |
| GPU drivers | xf86-video-amdgpu/ati, nvidia | — (QEMU uses virtio-gpu) |
| Hardware detection | NVIDIA, Intel GPU, Broadcom WiFi | — (clean VM, virtio-net) |
| WiFi | broadcom-wl (physical NIC) | virtio-net (QEMU) |
| VM tools | qemu-guest-agent, spice-vdagent | qemu-guest-agent, spice-vdagent |

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
├── reset.sh                    # Clean build artefacts
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
