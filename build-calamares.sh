#!/usr/bin/env bash
set -euo pipefail

# Build EndeavourOS Calamares for aarch64 and stage it into airootfs/root/packages/
# so run_before_squashfs.sh installs it into the live ISO.
#
# Runs inside the build container (CI ubuntu-24.04-arm job or the Docker image)
# on an aarch64 host. Skip with SKIP_CALAMARES=1, force a rebuild with FORCE=1.

script_path="$(cd -P "$(dirname "$0")" && pwd)"
pkg_dir="${script_path}/airootfs/root/packages"

if [[ "${SKIP_CALAMARES:-0}" = "1" ]]; then
    echo "build-calamares: SKIP_CALAMARES=1 -> skipping"
    exit 0
fi

if ls "${pkg_dir}"/calamares-*.pkg.tar.zst >/dev/null 2>&1 && [[ "${FORCE:-0}" != "1" ]]; then
    echo "build-calamares: package already staged -> skipping (use FORCE=1 to rebuild)"
    exit 0
fi

if [[ "$(uname -m)" != "aarch64" ]]; then
    echo "build-calamares: must run on aarch64 (uname -m: $(uname -m))" >&2
    exit 1
fi

echo "build-calamares: installing build dependencies..."
pacman -Sy --needed --noconfirm \
    git cmake extra-cmake-modules \
    python-jsonschema python-pyaml python-unidecode gawk \
    base-devel \
    qt6-svg qt6-declarative qt6-tools \
    yaml-cpp networkmanager upower \
    kcoreaddons kconfig ki18n kservice kwidgetsaddons kparts kpmcore solid polkit-qt6 \
    squashfs-tools rsync pybind11 cryptsetup dmidecode gptfdisk python libpwquality ckbcomp

build_dir="$(mktemp -d /tmp/calamares-build.XXXXXX)"
trap 'rm -rf "${build_dir}"' EXIT
cp "${script_path}/calamares-aarch64/PKGBUILD" "${build_dir}/"

echo "build-calamares: building in ${build_dir} ..."
if [[ "$(id -u)" = "0" ]]; then
    # makepkg refuses to run as root; drop to a build user (same as prepare.sh)
    useradd -M -s /bin/bash builduser 2>/dev/null || true
    chown -R builduser "${build_dir}"
    # a writable HOME keeps makepkg happy
    install -d -m 700 -o builduser /tmp/calamares-home
    su -c "cd '${build_dir}' && HOME=/tmp/calamares-home makepkg -f --noconfirm" builduser
    chown -R root "${build_dir}"
else
    (cd "${build_dir}" && makepkg -f --noconfirm)
fi

echo "build-calamares: staging package into ${pkg_dir} ..."
install -d -m 755 "${pkg_dir}"
cp "${build_dir}"/calamares-*.pkg.tar.zst "${pkg_dir}/"
ls -lh "${pkg_dir}"/calamares-*.pkg.tar.zst
echo "build-calamares: done."
