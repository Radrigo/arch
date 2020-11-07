#!/usr/bin/env bash


if [ $(id -u) -ne 0 ]; then exec sudo $0 $@; fi


__ScriptVersion="0.1"


function usage ()
{
    echo \
"Usage:
    $(basename $0) -d /dev/XXX -n HOSTNAME[-h] [-v]

Options:
    -d DISK     Set disk for install
    -n HOSTNAME Set hostname for system
    -h          Display this message
    -v          Display script version"
}

while getopts "d:n:hv" opt
do
    case $opt in
        n) HOSTNAMEARCH=${OPTARG} ;;
        d) DISK=${OPTARG} ;;
        h) usage; exit 0 ;;
        v) echo "Version: $__ScriptVersion"; exit 0 ;;
        *) echo -e "\nOption does not exist: $OPTARG\n"
           usage; exit 1 ;;
    esac
done
shift $(($OPTIND-1))

if [[ -z $DISK ]] || [[ -z $HOSTNAMEARCH ]]; then
    usage
    exit 1
fi

USERNAME=elpadre

function nvme_detect() {
    if echo $DISK | grep -q nvme; then
        FDISK_P_BOOT="${DISK}p1"
        FDISK_P_SWAP="${DISK}p2"
        FDISK_P_ROOT="${DISK}p3"
    else
        FDISK_P_BOOT="${DISK}1"
        FDISK_P_SWAP="${DISK}2"
        FDISK_P_ROOT="${DISK}3"
    fi
}

function create_fs() {
    mkfs.ext4 $FDISK_P_ROOT -L "ROOT"
    mount $FDISK_P_ROOT /mnt

    mkfs.vfat $FDISK_P_BOOT 
    mkdir -p /mnt/boot
    mount $FDISK_P_BOOT /mnt/boot
    
    mkswap $FDISK_P_SWAP -L "SWAP"
    swapon $FDISK_P_SWAP
}

function main() {
    nvme_detect
    fdisk_start
    create_fs

    pacstrap /mnt base linux linux-firmware base-devel

    genfstab -L -p -P -t UUID /mnt >> /mnt/etc/fstab

    arch-chroot /mnt pacman -S vim wpa_supplicant dhclient efibootmgr grub \
                               ipcalc bash-completion bc chromium cmatrix \
                               cryptsetup ctags curl deluge deluge-gtk dia \
                               dunst feh sxiv gimp git remmina htop i3lock \
                               i3status leafpad lm_sensors macchanger mpv mutt \
                               pass pcmanfm privoxy proxychains telegram-desktop \
                               tmux tor traceroute autocutsel xsel zenity zsh \
                               zsh-syntax-highlighting strace inotify-tools \
                               virtualbox-host-modules-arch dnsmasq bridge-utils \
                               electrum brasero firefox flameshot brightnessctl \
                               torbrowser-launcher dmenu lxterminal lxappearance


    arch-chroot /mnt loadkeys ru

    cat <<'EOF' >/mnt/etc/locale.gen
en_US.UTF-8 UTF-8
ru_RU.UTF-8 UTF-8
EOF
    arch-chroot /mnt locale-gen
    echo LANG="en_US.UTF-8" > /mnt/etc/locale.conf

    arch-chroot /mnt timedatectl set-timezone Europe/Moscow
    arch-chroot /mnt timedatectl set-ntp true
    arch-chroot /mnt timedatectl status

    echo "$HOSTNAMEARCH" > /mnt/etc/hostname
    cat <<EOF >/mnt/etc/hosts
127.0.0.1       localhost
::1             localhost
127.0.1.1       $HOSTNAMEARCH
EOF

    echo Set passwd for ROOT
    arch-chroot /mnt passwd

    sed 's/^\(HOOKS=.*\)fsck\(.*$\)/\1keymap\2/' -i /mnt/etc/mkinitcpio.conf
    arch-chroot /mnt mkinitcpio -p linux

    arch-chroot /mnt mkdir -p /boot/grub
    sed 's/^\(GRUB_CMDLINE_LINUX_DEFAULT=.*\)"$/\1 acpi_backlight=vendor"/' -i /mnt/etc/default/grub
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
    arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    arch-chroot /mnt pacman -S xorg-server xorg-apps xorg xterm lightdm \
                               lightdm-gtk-greeter lightdm-gtk-greeter-settings i3-gaps
    arch-chroot /mnt systemctl enable lightdm

    arch-chroot /mnt useradd -m -g users -G wheel -s /bin/zsh $USERNAME
    echo Set passwd for $USERNAME:
    arch-chroot /mnt passwd $USERNAME
    sed 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' -i /mnt/etc/sudoers


    umount -R /mnt
    echo
    echo "DONE. YOU CAN REBOOT MACHINE."
}

function fdisk_start() {

    # CREATE GPT
    fdisk $DISK <<EOF
g
w
q
EOF

    # CREATE BOOT PATRITION
    fdisk $DISK <<EOF
n
1

+512M
t
1
w
q
EOF
    # CREATE SWAP PATRITION
    fdisk $DISK <<EOF
n
2

+1G
t
2
19
w
q
EOF

    # CREATE ROOT PATRITION
    fdisk $DISK <<EOF
n
3


t
3
24
w
q
EOF
}

main
