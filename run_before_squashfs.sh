#!/usr/bin/env bash

# Made by Fernando "maroto"
# Run anything in the filesystem right before being "mksquashed"
# ISO-NEXT specific cleanup removals and additions (08-2021 + 10-2021) @killajoe and @manuel
# refining and changes november 2021 @killajoe and @manuel
# aarch64/UTM adaptation: removed x86 hardware detection, ALARM mirrorlist

script_path=$(readlink -f "${0%/*}")
work_dir="work"

# Adapted from AIS. An excellent bit of code!
# all pathes must be in quotation marks "path/to/file/or/folder" for now.

arch_chroot() {
    arch-chroot "${script_path}/${work_dir}/aarch64/airootfs" /bin/bash -c "${1}"
}

do_merge() {

arch_chroot "$(cat << EOF

echo "##############################"
echo "# start chrooted commandlist #"
echo "##############################"

cd "/root"

echo "---> Init & Populate keys --->"
pacman-key --init || true
keyrings=()
[[ -f /usr/share/pacman/keyrings/archlinuxarm.gpg ]] && keyrings+=(archlinuxarm)
[[ -f /usr/share/pacman/keyrings/archlinux.gpg ]] && keyrings+=(archlinux)
[[ -f /usr/share/pacman/keyrings/endeavouros.gpg ]] && keyrings+=(endeavouros)
if (( ${#keyrings[@]} > 0 )); then
    pacman-key --populate "${keyrings[@]}" || true
fi
pacman -Syy

echo "---> backup bash configs from skel to replace after liveuser creation --->"
mkdir -p "/root/filebackups/"
cp -af "/etc/skel/"{".bashrc",".bash_profile"} "/root/filebackups/"

echo "---> Install liveuser skel (in case of conflicts use overwrite) --->"
if compgen -G "/root/endeavouros-skel-liveuser/*.pkg.tar.zst" > /dev/null; then
    pacman -U --noconfirm --overwrite "/etc/skel/.bash_profile","/etc/skel/.bashrc" -- "/root/endeavouros-skel-liveuser/"*.pkg.tar.zst
fi
echo "---> start validate skel files --->"
ls /etc/skel/.*
ls /etc/skel/
echo "---> end validate skel files --->"

echo "---> Prepare livesession settings and user --->"
sed -i 's/#\(en_US\.UTF-8\)/\1/' "/etc/locale.gen"
locale-gen
ln -sf "/usr/share/zoneinfo/UTC" "/etc/localtime"

echo "---> Set root permission and shell --->"
usermod -s /usr/bin/bash root

echo "---> Create liveuser --->"
useradd -m -p "" -g 'liveuser' -G 'sys,rfkill,wheel,uucp,nopasswdlogin,adm,tty' -s /bin/bash liveuser
cp -af /etc/skel/. /home/liveuser/
chown -R liveuser:liveuser /home/liveuser
cp "/root/liveuser.png" "/var/lib/AccountsService/icons/liveuser"
rm "/root/liveuser.png"

echo "---> Remove liveuser skel to clean for target skel --"
if pacman -Q endeavouros-skel-liveuser >/dev/null 2>&1; then
    pacman -Rns --noconfirm -- "endeavouros-skel-liveuser"
fi
rm -rf "/root/endeavouros-skel-liveuser"

echo "---> setup theming for root user --->"
cp -a "/root/root-theme" "/root/.config"
rm -R "/root/root-theme"

echo "---> Add builddate to motd --->"
cat "/usr/lib/endeavouros-release" >> "/etc/motd"
echo "------------------" >> "/etc/motd"

echo "---> Install locally builded packages on ISO (place packages under airootfs/root/packages) --->"
mkdir -p "/root/packages"
echo "--> content of /root/packages:"
ls "/root/packages/" || true
echo "end of content of /root/packages. <---"
pacman -Sy
if compgen -G "/root/packages/*.pkg.tar.zst" > /dev/null; then
    cp /etc/pacman.conf /tmp/pacman-local.conf
    sed -i 's/^LocalFileSigLevel.*/LocalFileSigLevel = Never/' /tmp/pacman-local.conf
    if ! grep -q '^LocalFileSigLevel' /tmp/pacman-local.conf; then
        printf '\nLocalFileSigLevel = Never\n' >> /tmp/pacman-local.conf
    fi
    pacman -U --config /tmp/pacman-local.conf --noconfirm --needed -- "/root/packages/"*.pkg.tar.zst || true
    rm -f /tmp/pacman-local.conf
fi
rm -rf "/root/packages/"

echo "---> Enable systemd services in case needed --->"
echo " --> per default now in airootfs/etc/systemd/system/multi-user.target.wants"
#systemctl enable NetworkManager.service systemd-timesyncd.service bluetooth.service firewalld.service
if pacman -Q sddm >/dev/null 2>&1; then
    systemctl enable sddm.service
    systemctl set-default graphical.target
else
    systemctl set-default multi-user.target
fi

echo "---> Set wallpaper for live-session and original for installed system --->"
mkdir -p "/etc/calamares/files"
if [[ -f "/root/endeavouros-wallpaper.png" ]]; then
    mv "/root/endeavouros-wallpaper.png" "/etc/calamares/files/endeavouros-wallpaper.png"
fi
if [[ -f "/root/livewall.png" ]]; then
    mv "/root/livewall.png" "/usr/share/endeavouros/backgrounds/endeavouros-wallpaper.png"
fi
if compgen -G "/usr/share/endeavouros/backgrounds/*.png" > /dev/null; then
    chmod 644 "/usr/share/endeavouros/backgrounds/"*.png
fi

echo "---> install bash configs back into /etc/skel for offline install target --->"
cp -af "/root/filebackups/"{".bashrc",".bash_profile"} "/etc/skel/"

echo "---> get needed packages for offline installs --->"
mkdir -p "/usr/share/packages"
pacman -Syy
offline_pkgs=()
for pkg in grub os-prober eos-dracut kernel-install-for-dracut; do
    if pacman -Si "$pkg" >/dev/null 2>&1; then
        offline_pkgs+=("$pkg")
    fi
done
if (( ${#offline_pkgs[@]} > 0 )); then
    pacman -Sw --noconfirm --cachedir "/usr/share/packages" "${offline_pkgs[@]}"
fi

echo "---> Clean pacman log and package cache --->"
rm -f "/var/log/pacman.log"
# pacman -Scc seem to fail so:
rm -rf "/var/cache/pacman/pkg/"

echo "---> Get ALARM mirrorlist for offline installs --->"
cat > "/etc/pacman.d/mirrorlist" << 'MIRROREOF'
Server = http://mirror.archlinuxarm.org/\$arch/\$repo
MIRROREOF

echo "---> create package versions file --->"
pacman -Qs | grep "/calamares " | cut -c7- > iso_package_versions
pacman -Qs | grep "/firefox " | cut -c7- >> iso_package_versions
pacman -Qs | grep "/linux " | cut -c7- >> iso_package_versions
pacman -Qs | grep "/mesa " | cut -c7- >> iso_package_versions
pacman -Qs | grep "/xorg-server " | cut -c7- >> iso_package_versions
mv "iso_package_versions" "/home/liveuser/"

echo "############################"
echo "# end chrooted commandlist #"
echo "############################"

EOF
)"
}

#################################
########## STARTS HERE ##########
#################################

do_merge
