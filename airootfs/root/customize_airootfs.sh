#!/bin/bash
# Runs inside the chroot right after pacstrap (mkarchiso _make_customize_airootfs),
# BEFORE the ESP/eltorito boot files are assembled — the only hook where the
# pinned systemd-boot binary can be swapped in time (run_before_squashfs.sh runs
# too late).
#
# Why: sd-boot >= 260 fails to launch ANY kernel on QEMU/EDK2 armvirt firmware
# (UTM): the menu renders, the kernel EFI launch dies silently / raises a
# Synchronous Exception. 259.1 is the last known-good bootloader (proven on the
# 2026.02.22 ISO; kernel version was ruled out by pinning 6.18.8 into a current
# build — still crashed). Only this EFI binary is pinned; userspace systemd
# stays current. Provenance and removal condition: assets/README.md.
set -e

echo ">>> customize_airootfs: pinning systemd-boot to 259.1"

sdboot="/root/packages/systemd-bootaa64-259.1.efi"
if [[ ! -r "$sdboot" ]]; then
    echo "FATAL: pinned systemd-boot binary missing from /root/packages — aborting" >&2
    exit 1
fi

# Sanity: it must be the 259.1 build (140800 bytes, contains version string)
if ! grep -aq 'systemd-boot version: 259' "$sdboot"; then
    echo "FATAL: staged sd-boot binary is not 259.x — aborting" >&2
    exit 1
fi

install -m 0644 -- "$sdboot" /usr/lib/systemd/boot/efi/systemd-bootaa64.efi
rm -f -- "$sdboot"
ls -la /usr/lib/systemd/boot/efi/systemd-bootaa64.efi

echo ">>> customize_airootfs: systemd-boot 259.1 pinned"
