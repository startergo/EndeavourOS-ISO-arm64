#!/usr/bin/env bash

# Chrooted cleaner script — aarch64 adaptation of
# endeavouros-team/calamares data/eos/scripts/chrooted_cleaner_script.sh
# (original by @fernandomaroto, @manuel, @killajoe — see upstream for history)
#
# ARM changes:
# - keep mkinitcpio on the target (x86 removes it in favour of dracut)
# - remove only packages actually installed (ARM lacks several x86 packages;
#   a single pacman -Rsn with missing targets would fail the whole transaction)
# - strip broadcom/nvidia/marvell handling (x86-only hardware)
# - guard the hotfix script (no network on offline installs)

_c_c_s_msg() {            # use this to provide all user messages (info, warning, error, ...)
    local type="$1"
    local msg="$2"
    echo "==> $type: $msg"
}

_pkg_msg() {            # use this for all package management messages (install, uninstall)
    local op="$1"
    local pkgs="$2"
    case "$op" in
        remove | uninstall) op="uninstalling" ;;
        install) op="installing" ;;
    esac
    echo "==> $op $pkgs"
}

_remove_a_pkg() {
    local pkgname="$1"
    if pacman -Q "$pkgname" >/dev/null 2>&1; then
        _pkg_msg remove "$pkgname"
        pacman -Rsn --noconfirm "$pkgname" || true
    fi
}

_sed_stuff(){

    # Journal for offline. Turn volatile (for iso) into a real system.
    sed -i 's/volatile/auto/g' /etc/systemd/journald.conf 2>>/tmp/.errlog || true
    sed -i 's/.*pam_wheel\.so/#&/' /etc/pam.d/su 2>>/tmp/.errlog || true
}

_clean_archiso(){

    local _files_to_remove=(
        /etc/sudoers.d/g_wheel
        /var/lib/NetworkManager/NetworkManager.state
        /etc/systemd/system/getty@tty1.service.d/autologin.conf
        /etc/systemd/system/getty@tty1.service.d
        /etc/systemd/system/multi-user.target.wants/*
        /etc/systemd/journald.conf.d
        /etc/systemd/logind.conf.d
        /etc/mkinitcpio.conf.d
        /etc/initcpio
        /root/{,.[!.],..?}*
        /etc/motd
        /{gpg.conf,gpg-agent.conf,pubring.gpg,secring.gpg}
        /version
    )

    local xx

    for xx in ${_files_to_remove[*]}; do rm -rf "$xx"; done

    find /usr/lib/initcpio -name "archiso*" -type f -exec rm '{}' \; 2>/dev/null

}

_clean_offline_packages(){

    local packages_to_remove=(

        # BASE

        ## Base system

        # SOFTWARE

        # ISO

        ## Live iso specific
        arch-install-scripts
        net-tools
        mkinitcpio-archiso
        mkinitcpio-nfs-utils
        nbd
        pv
        syslinux

        ## Live iso tools
        clonezilla
        fsarchiver
        gpart
        gparted
        grsync

        # ENDEAVOUROS REPO

        ## Calamares EndeavourOS
        $(pacman -Qq 2>/dev/null | grep calamares || true)        # finds calamares related packages
        ckbcomp
    )

    local pkgs=() xx

    for xx in "${packages_to_remove[@]}"; do
        [[ -n "$xx" ]] || continue
        pacman -Q "$xx" >/dev/null 2>&1 && pkgs+=("$xx")
    done

    if (( ${#pkgs[@]} > 0 )); then
        _pkg_msg remove "${pkgs[*]}"
        pacman -Rsn --noconfirm "${pkgs[@]}" || true
    fi

}

_clean_up(){
    local xx

    # change log file permissions
    [ -r /var/log/Calamares.log ]         && chown root:root /var/log/Calamares.log

    # fix skel issue for Titan ISO
    cp -rT /etc/skel/ /home/$NEW_USER/
    chown -R "$NEW_USER":"$NEW_USER" "/home/$NEW_USER/"
}

_show_info_about_installed_system() {
    local cmd
    local cmds=( "lsblk -f -o+SIZE"
                 "fdisk -l"
               )

    for cmd in "${cmds[@]}" ; do
        _c_c_s_msg info "$cmd"
        $cmd || true
    done
}

_run_hotfix_end() {
    local file=hotfix-end.bash
    _c_c_s_msg info "running script $file (if present)"
    [ -r /tmp/$file ] && bash /tmp/$file || true
}

Main() {
    _c_c_s_msg info "Chrooted cleaner started, parameters: $*"

    local i
    local NEW_USER=""
    INSTALL_TYPE=""

    # parse the options
    for i in "$@"; do
        case $i in
            --user=*)
                NEW_USER="${i#*=}"
                ;;
            --online)
                INSTALL_TYPE="online"
                ;;
        esac
    done
    if [ -z "$NEW_USER" ]; then
        _c_c_s_msg error "new username is unknown!"
    fi

    if [ "$INSTALL_TYPE" != "online" ]; then
        _clean_offline_packages
        _clean_archiso
        chown "$NEW_USER":"$NEW_USER" "/home/$NEW_USER/.bashrc" 2>/dev/null
        _sed_stuff
    fi

    _clean_up
    _run_hotfix_end
    _show_info_about_installed_system

    # Remove pacnew files
    find /etc -type f -name "*.pacnew" -exec rm {} \;

    rm -rf /etc/calamares /opt/extra-drivers

    _c_c_s_msg info "Chrooted cleaner done."
}


########################################
########## SCRIPT STARTS HERE ##########
########################################

Main "$@"
