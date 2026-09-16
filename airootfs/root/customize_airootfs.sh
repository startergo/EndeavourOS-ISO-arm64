#!/bin/bash
# Runs inside the chroot right after pacstrap (mkarchiso _make_customize_airootfs),
# BEFORE the kernel/initramfs are copied to the ISO 9660 tree — the only hook
# where the pinned kernel can be installed in time (run_before_squashfs.sh runs
# after _make_boot_on_iso9660 and would be too late).
#
# Why a pinned kernel at all: linux-eos-arm 7.2.x crashes in its EFI stub on
# QEMU/EDK2 armvirt firmware (UTM) before any console output. 6.18.8 is the
# last known-good build. The package is staged by prepare.sh from the
# kernel-pin-6.18.8 release.
set -e

echo ">>> customize_airootfs: installing pinned kernel linux-eos-arm 6.18.8"
ls -la /root/packages/ || true

pkg="$(compgen -G '/root/packages/linux-eos-arm-*.pkg.tar.*' || true)"
if [[ -z "$pkg" ]]; then
    echo "FATAL: pinned kernel package missing from /root/packages — aborting" >&2
    exit 1
fi

cp /etc/pacman.conf /tmp/pacman-local.conf
sed -i 's/^LocalFileSigLevel.*/LocalFileSigLevel = Never/' /tmp/pacman-local.conf
grep -q '^LocalFileSigLevel' /tmp/pacman-local.conf || printf '\nLocalFileSigLevel = Never\n' >> /tmp/pacman-local.conf
pacman -U --config /tmp/pacman-local.conf --noconfirm -- "$pkg"
rm -f /tmp/pacman-local.conf /root/packages/linux-eos-arm-*.pkg.tar.*

# The mkinitcpio pacman hook is a silent no-op for this /boot/vmlinuz-*
# layout on ALARM (CI log shows "Updating linux initcpios..." building
# nothing after pacman -U), so generate the ISO initramfs explicitly —
# same invocation mkarchiso's _ensure_boot_artifacts fallback uses.
mkinitcpio -c /etc/mkinitcpio.conf.d/archiso.conf \
           -k /boot/vmlinuz-linux-eos-arm \
           -g /boot/initramfs-linux-eos-arm.img

# Hard-verify both artifacts the ISO needs.
for f in /boot/vmlinuz-linux-eos-arm /boot/initramfs-linux-eos-arm.img; do
    [[ -r "$f" ]] || { echo "FATAL: $f missing after kernel install" >&2; exit 1; }
done
echo ">>> customize_airootfs: pinned kernel ready"
