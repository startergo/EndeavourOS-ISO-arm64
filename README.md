# EndeavourOS-ISO-arm64

[![Build](https://github.com/startergo/EndeavourOS-ISO-arm64/actions/workflows/build.yml/badge.svg)](https://github.com/startergo/EndeavourOS-ISO-arm64/actions/workflows/build.yml)

EndeavourOS live ISO for **aarch64** — designed to run in **UTM on Apple Silicon** (QEMU/HVF).

Modelled after [EndeavourOS-ISO-t2](https://github.com/endeavouros-team/EndeavourOS-ISO-t2):
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
sudo pacman -S archiso imagemagick reflector
```

### Build

```bash
git clone https://github.com/startergo/EndeavourOS-ISO-arm64
cd EndeavourOS-ISO-arm64

bash prepare.sh         # download wallpapers, rank mirrors, build skel
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
