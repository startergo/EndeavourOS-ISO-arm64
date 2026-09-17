# Pinned build assets

## systemd-bootaa64-259.1.efi

`systemd-boot` 259.1-1-arch EFI bootloader for aarch64, extracted from the
bootable 2026.02.22 ISO.

sd-boot ≥ 260 cannot launch any kernel on QEMU/EDK2 armvirt firmware (UTM):
the menu renders but the kernel EFI launch dies (Synchronous Exception). This
was isolated on 2026-09-16 with a full ISO matrix — kernel version was ruled
out by pinning the Feb kernel into a current build, which still crashed under
sd-boot 261.3, while this 259.1 binary boots every kernel tested.

`prepare.sh` stages this file into the airootfs and `customize_airootfs.sh`
overwrites the chroot's `/usr/lib/systemd/boot/efi/systemd-bootaa64.efi` with
it, so the ISO's ESP ships 259.1 while userspace systemd stays current.

sha256: 91740f409dc527d925ba2b3cb887503a2961fc6208cd7419c8fca4090559e467

**Removal condition:** delete this file (and the wiring in `prepare.sh` +
`airootfs/root/customize_airootfs.sh`) once systemd-boot boots again on
QEMU/EDK2 armvirt.
