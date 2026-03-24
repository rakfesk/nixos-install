#!/usr/bin/env bash

set -eo pipefail

###################################
#  Script Directory Detection
###################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

###################################
#  Cleanup on Exit/Error
###################################
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        echo ""
        echo "Installation failed. Cleaning up..."
    fi
    umount -R /mnt 2>/dev/null || true
    cryptsetup close cryptroot 2>/dev/null || true
    exit $exit_code
}
trap cleanup EXIT

###################################
#  Dependency Checking
###################################
check_dependencies() {
    local missing=()
    for cmd in nix parted cryptsetup mkfs.vfat mkfs.ext4 nixos-install nixos-generate-config partprobe curl; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "Error: Required commands not found: ${missing[*]}"
        echo "Please ensure you are running from a NixOS installation environment."
        exit 1
    fi
}

###################################
#  Pre-flight Checks
###################################
preflight_checks() {
    # Check required files exist
    local required_files=("flake.nix" "flake.lock" "vars.nix.tmp" "modules" "hosts")
    for f in "${required_files[@]}"; do
        if [[ ! -e "${SCRIPT_DIR}/${f}" ]]; then
            echo "Error: Required file/directory not found: ${SCRIPT_DIR}/${f}"
            echo "Please run this script from the repository directory or ensure all files are present."
            exit 1
        fi
    done

    # Check network connectivity
    if ! curl -sf --connect-timeout 5 https://cache.nixos.org &>/dev/null; then
        echo "Warning: Cannot reach cache.nixos.org. Network may be unavailable."
        read -rp "Continue anyway? [y/N]: " continue_anyway
        [[ "${continue_anyway,,}" == "y" ]] || exit 1
    fi
}

###################################
#  Helper: Escape for sed
###################################
escape_sed() {
    printf '%s' "$1" | sed -e 's/[\/&]/\\&/g'
}

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

###################################
#  Input Validation
###################################
validate_hostname() {
    local hostname="$1"
    if [[ ${#hostname} -gt 63 ]]; then
        echo "Error: Hostname must be 63 characters or less."
        return 1
    fi
    if [[ ! "$hostname" =~ ^[a-zA-Z][a-zA-Z0-9-]*$ ]]; then
        echo "Error: Hostname must start with a letter and contain only letters, numbers, and hyphens."
        return 1
    fi
    return 0
}

validate_username() {
    local username="$1"
    if [[ ! "$username" =~ ^[a-z][a-z0-9_-]*$ ]]; then
        echo "Error: Username must start with a lowercase letter and contain only lowercase letters, numbers, underscores, and hyphens."
        return 1
    fi
    if [[ ${#username} -gt 32 ]]; then
        echo "Error: Username must be 32 characters or less."
        return 1
    fi
    return 0
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root."
  echo "Re-running with sudo..."
  exec sudo "$0" "$@"
fi

# ===== Root-only code below =====
echo "Running as root"
echo ""

# Run pre-flight checks
check_dependencies
preflight_checks

echo ""
echo "======================================="
echo "       NixOS Installation Setup"
echo "======================================="
echo ""

# Hostname with validation
while true; do
    ask "Hostname" HOSTNAME "nixos"
    validate_hostname "$HOSTNAME" && break
done

# Username with validation
while true; do
    ask "Create an admin username" USERNAME "nixos"
    validate_username "$USERNAME" && break
done

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

# Final disk confirmation
echo ""
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "WARNING: This will ERASE ALL DATA on /dev/${name}"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo ""
read -rp "Type the disk name to confirm (${name}): " confirm_disk
if [[ "$confirm_disk" != "$name" ]]; then
    echo "Disk name does not match. Aborting."
    exit 1
fi

echo ""
echo "[1/6] Partitioning disk /dev/${name}..."

parted /dev/${name} -- mklabel gpt
parted /dev/${name} -- mkpart ESP fat32 1MiB 513MiB
parted /dev/${name} -- set 1 esp on
parted /dev/${name} -- mkpart primary 513MiB 100%

# Wait for kernel to recognize partitions
partprobe /dev/${name}
sleep 2

if [[ ! -b "$root_part" ]]; then
    echo "Error: Partition $root_part not found after partitioning."
    exit 1
fi
if [[ ! -b "$boot_part" ]]; then
    echo "Error: Partition $boot_part not found after partitioning."
    exit 1
fi

echo "[2/6] Setting up LUKS encryption..."

if ! printf '%s' "$LUKS_PASSPHRASE" | cryptsetup luksFormat "$root_part" -; then
    echo "Error: LUKS format failed."
    exit 1
fi

if ! printf '%s' "$LUKS_PASSPHRASE" | cryptsetup open "$root_part" cryptroot -; then
    echo "Error: Failed to open LUKS volume."
    exit 1
fi

echo "[3/6] Formatting filesystems..."

mkfs.vfat -n BOOT ${boot_part}
mkfs.ext4 -L nixos /dev/mapper/cryptroot

echo "[4/6] Mounting filesystems..."

mount /dev/mapper/cryptroot /mnt
mkdir -p /mnt/boot
mount ${boot_part} /mnt/boot

echo "[5/6] Generating hardware configuration..."

nixos-generate-config --root /mnt

cp "${SCRIPT_DIR}/flake.nix" /mnt/etc/nixos/flake.nix
cp "${SCRIPT_DIR}/flake.lock" /mnt/etc/nixos/flake.lock
cp -r "${SCRIPT_DIR}/modules" /mnt/etc/nixos/modules
cp -r "${SCRIPT_DIR}/hosts" /mnt/etc/nixos/hosts

# Escape values for sed substitution
USERNAME_ESC=$(escape_sed "$USERNAME")
USER_DESCRIPTION_ESC=$(escape_sed "$USER_DESCRIPTION")
PASSWORD_ESC=$(escape_sed "$PASSWORD")
HOSTNAME_ESC=$(escape_sed "$HOSTNAME")

sed -e "s#[@]USER_NAME[@]#${USERNAME_ESC}#" \
    -e "s#[@]USER_DESCRIPTION[@]#${USER_DESCRIPTION_ESC}#" \
    -e "s#[@]USER_INITIAL_PASSWORD[@]#${PASSWORD_ESC}#" \
    -e "s#[@]HOSTNAME[@]#${HOSTNAME_ESC}#" \
    "${SCRIPT_DIR}/vars.nix.tmp" > /mnt/etc/nixos/vars.nix

# Update flake.lock to recognize the generated hardware-configuration.nix
nix flake lock --update-input hardware-config /mnt/etc/nixos

echo "[6/6] Installing NixOS (this may take a while)..."

nixos-install --flake /mnt/etc/nixos#myhost

echo ""
echo "======================================="
echo "    Installation Complete!"
echo "======================================="
echo ""
echo "To boot into your new system:"
echo "  1. Run: reboot"
echo "  2. Remove the USB drive"
echo "  3. Enter your LUKS passphrase at boot"
echo ""
echo "Your admin user '${USERNAME}' is ready."
echo ""
