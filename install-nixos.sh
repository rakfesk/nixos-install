#!/usr/bin/env bash

set -eo pipefail

###################################
#  Helper: Prompt Function
###################################
ask() {
    local prompt="$1"
    local varname="$2"
    local default="$3"

    if [ -n "$default" ]; then
        read -rp "$prompt [$default]: " input
        input="${input:-$default}"
    else
        read -rp "$prompt: " input
    fi

    printf -v "$varname" "%s" "$input"
}

ask_password() {
    local prompt="$1"
    local varname="$2"

    local pass1 pass2

    while true; do
        read -rsp "$prompt: " pass1
        echo
        read -rsp "Confirm $prompt: " pass2
        echo

        if [[ "$pass1" == "$pass2" ]]; then
            printf -v "$varname" '%s' "$pass1"
            return 0
        fi

        echo "Passwords do not match. Please try again." >&2
    done
}

confirm_or_exit() {
    local answer

    while true; do
        read -rp "Continue with installation? [yes/no]: " answer
        case "${answer,,}" in
            yes)
                return 0
                ;;
            no)
                echo "Installation aborted by user."
                exit 1
                ;;
            *)
                echo "Please answer 'yes' or 'no'."
                ;;
        esac
    done
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root."
  echo "Re-running with sudo..."
  exec sudo "$0" "$@"
fi

# ===== Root-only code below =====
echo "Running as root"


# Hostname
ask "Hostname" HOSTNAME "nixos"
# User creation
ask "Create an admin username" USERNAME "nixos"
ask "Full name for admin user" USER_DESCRIPTION "nixos"
ask_password "Set password for ${USERNAME}" PASSWORD

# Get non-removable drives (RM=0), excluding loop devices
mapfile -t DRIVES < <(
  lsblk -d -n -o NAME,RM,SIZE,MODEL |
  awk '$2 == 0 { printf "%s|%s|%s\n", $1, $3, substr($0, index($0,$4)) }'
)

if [[ ${#DRIVES[@]} -eq 0 ]]; then
  echo "No non-removable drives found."
  exit 1
fi

echo "Available non-removable drives:"
echo

for i in "${!DRIVES[@]}"; do
  IFS="|" read -r name size model <<< "${DRIVES[$i]}"
  printf " [%d] /dev/%s  (%s, %s)\n" "$i" "$name" "$size" "$model"
done

echo
read -rp "Select a drive by number: " choice

if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 0 || choice >= ${#DRIVES[@]} )); then
  echo "Invalid selection."
  exit 1
fi

IFS="|" read -r name _ <<< "${DRIVES[$choice]}"
part_suffix=""
[[ "$name" =~ [0-9]$ ]] && part_suffix="p"

root_part="/dev/${name}${part_suffix}2"
boot_part="/dev/${name}${part_suffix}1"

ask_password "Set luks passphrase for ${root_part}" LUKS_PASSPHRASE

###################################
#  Show Summary
###################################

echo ""
echo "---------------------------------------"
echo " ❄ NixOS Installer — Summary ❄"
echo "---------------------------------------"
echo "Hostname:             $HOSTNAME"
echo "Install disk:         /dev/${name}"
echo "Admin user:           $USERNAME"
echo "Full Name:            $USER_DESCRIPTION"
echo "Password:             [hidden]"
echo "Luks Passphrase:      [hidden]"
echo "---------------------------------------"
echo ""

confirm_or_exit

echo
echo "Setting up partitions on: /dev/$name"

parted /dev/${name} -- mklabel gpt
parted /dev/${name} -- mkpart ESP fat32 1MiB 513MiB
parted /dev/${name} -- set 1 esp on
parted /dev/${name} -- mkpart primary 513MiB 100%

printf '%s' "$LUKS_PASSPHRASE" | cryptsetup luksFormat "$root_part" -
printf '%s' "$LUKS_PASSPHRASE" | cryptsetup open "$root_part" cryptroot -

mkfs.vfat -n BOOT ${boot_part}
mkfs.ext4 -L nixos /dev/mapper/cryptroot

mount /dev/mapper/cryptroot /mnt
mkdir /mnt/boot
mount ${boot_part} /mnt/boot

nixos-generate-config --root /mnt

git clone --branch init https://github.com/rakfesk/nixos-install.git

cp nixos-install/flake.nix /mnt/etc/nixos/flake.nix
cp nixos-install/flake.lock /mnt/etc/nixos/flake.lock
cp nixos-install/configuration.nix /mnt/etc/nixos/configuration.nix
cp nixos-install/vars.nix.tmp /mnt/etc/nixos/vars.nix.tmp

sed -e "s#[@]USER_NAME[@]#${USERNAME}#" \
    -e "s#[@]USER_DESCRIPTION[@]#${USER_DESCRIPTION}#" \
    -e "s#[@]USER_INITIAL_PASSWORD[@]#${PASSWORD}#" \
    -e "s#[@]HOSTNAME[@]#${HOSTNAME}#" \
    /mnt/etc/nixos/vars.nix.tmp > /mnt/etc/nixos/vars.nix

nixos-install --flake /mnt/etc/nixos#myhost
