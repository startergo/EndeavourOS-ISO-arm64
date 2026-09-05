#!/usr/bin/env bash

# Build EndeavourOS Calamares for aarch64 (stages it into airootfs/root/packages).
# Skip with SKIP_CALAMARES=1.
bash "$(dirname "$(readlink -f "$0")")/build-calamares.sh" || {
    echo "ERROR: build-calamares.sh failed — aborting prepare" >&2
    exit 1
}

# add date to wallpaper
cp airootfs/root/livewall.png airootfs/root/livewall-original.png

magick airootfs/root/livewall.png \
  -gravity NorthEast \
  -pointsize 24 \
  -fill white \
  -font "DejaVu-Sans" \
  -annotate +10+10 "$(date '+%Y-%m-%d')" \
  airootfs/root/livewall.png

  # Copy the repo's ALARM mirrorlist (reflector does not support ALARM mirrors)
mkdir -p "airootfs/etc/pacman.d/"
cp mirrorlist airootfs/etc/pacman.d/mirrorlist


# Get wallpaper for installed system
wget -qN --show-progress -P "airootfs/root/" "https://raw.githubusercontent.com/endeavouros-team/Branding/master/backgrounds/endeavouros-wallpaper.png"


# Make sure build scripts are executable
chmod +x "./"{"mkarchiso","run_before_squashfs.sh"}

get_pkg() {
    # --nodeps: download only the named package, not its whole dep tree.
    # The tree used to be installed wholesale in the chroot, which caused
    # stale-version conflicts (deps resolve from the repos there instead).
    sudo pacman -Syw --nodeps "$1" --noconfirm --cachedir "airootfs/root/packages" \
    && sudo chown $USER:$USER "airootfs/root/packages/"*".pkg.tar"*
}

get_pkg "eos-settings-plasma"

# Build liveuser skel (makepkg refuses to run as root; drop to a build user)
SKEL_DIR="$(pwd)/airootfs/root/endeavouros-skel-liveuser"
if [ "$(id -u)" = "0" ]; then
  useradd -M -s /bin/bash builduser 2>/dev/null || true
  chown -R builduser "$SKEL_DIR"
  su -c "cd '$SKEL_DIR' && makepkg -f" builduser
else
  cd "$SKEL_DIR"
  makepkg -f
fi
