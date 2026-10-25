#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
    echo "Usage: sudo $0 <drive> <label>"
    echo "Example: sudo $0 sda disk_0"
    exit 2
}

die() {
    echo "ERROR: $*" >&2
    exit 1
}

# Require the drive and filesystem label.
[[ $# -eq 2 ]] || usage

# Accept either sda or /dev/sda.
arg="${1#/dev/}"
[[ "$arg" =~ ^[a-zA-Z0-9._+-]+$ ]] ||
    die "Invalid drive name."

DISK="/dev/$arg"
LABEL="$2"
[[ -n "$LABEL" ]] || die "Filesystem label cannot be empty."

# Require root privileges.
[[ $EUID -eq 0 ]] || die "Run with sudo."

FORMAT_USER="${SUDO_USER:-}"
[[ -n "$FORMAT_USER" && "$FORMAT_USER" != "root" ]] ||
    die "Run this script with sudo from the user who should own the disk."
id "$FORMAT_USER" >/dev/null 2>&1 ||
    die "Cannot find the invoking user account: $FORMAT_USER"
FORMAT_GROUP="$(id -gn "$FORMAT_USER")"

# Check required utilities.
for cmd in lsblk findmnt swapon wipefs parted \
           partprobe udevadm mount mountpoint umount swapoff mkfs.btrfs; do
    command -v "$cmd" >/dev/null 2>&1 ||
        die "Required command not found: $cmd"
done

# Must be an existing whole-disk block device.
[[ -b "$DISK" ]] || die "Not a block device: $DISK"

TYPE="$(lsblk -dnro TYPE "$DISK")"
[[ "$TYPE" == "disk" ]] ||
    die "$DISK is not a whole disk."

# Never wipe the disk containing the running root filesystem.
ROOT_SOURCE="$(findmnt -nro SOURCE /)" ||
    die "Cannot determine the root filesystem."

ROOT_SOURCE="${ROOT_SOURCE%%\[*}"

if [[ -b "$ROOT_SOURCE" ]]; then
    if lsblk -s -nrpo NAME "$ROOT_SOURCE" |
        grep -Fxq "$DISK"; then
        die "$DISK contains the running root filesystem."
    fi
else
    die "Cannot safely identify the physical root disk."
fi

# Record active swap on the disk so it can be disabled after confirmation.
ACTIVE_SWAP=()
while IFS= read -r swapdev; do
    [[ -z "$swapdev" ]] && continue
    if [[ -b "$swapdev" ]] &&
       lsblk -s -nrpo NAME "$swapdev" |
           grep -Fxq "$DISK"; then
        ACTIVE_SWAP+=("$swapdev")
    fi
done < <(swapon --show --noheadings --raw --output NAME)

echo
echo "========================================"
echo "  DESTRUCTIVE DISK OPERATION"
echo "========================================"
lsblk -o NAME,SIZE,MODEL,TYPE,FSTYPE,MOUNTPOINTS "$DISK"
echo
echo "ALL DATA AND PARTITIONS ON $DISK WILL BE DESTROYED."
echo "The new filesystem label will be: $LABEL"
echo
read -r -p "Type 'WIPE $DISK' to continue: " confirmation

[[ "$confirmation" == "WIPE $DISK" ]] ||
    die "Confirmation did not match. Nothing changed."

echo
echo "Disabling active swap and unmounting filesystems on $DISK..."
for swapdev in "${ACTIVE_SWAP[@]}"; do
    swapoff "$swapdev"
done

mapfile -t DEVICES < <(lsblk -nrpo NAME "$DISK")
for ((i = ${#DEVICES[@]} - 1; i >= 0; i--)); do
    device="${DEVICES[i]}"
    if lsblk -nrpo MOUNTPOINTS "$device" | grep -q '[^[:space:]]'; then
        umount --all-targets "$device"
    fi
done

echo
echo "Removing existing filesystem and partition-table signatures..."

wipefs --all --force "$DISK"

echo "Creating a fresh GPT partition table..."
parted --script --align optimal "$DISK" mklabel gpt

echo "Creating one partition using the available disk space..."
parted --script --align optimal "$DISK" \
    mkpart primary 1MiB 100%

partprobe "$DISK"
udevadm settle

# Discover the newly created partition rather than assuming
# its name (e.g. sda1 versus nvme0n1p1).
mapfile -t PARTITIONS < <(
    lsblk -nrpo NAME,TYPE "$DISK" |
        awk '$2 == "part" { print $1 }'
)

[[ ${#PARTITIONS[@]} -eq 1 ]] ||
    die "Expected exactly one partition; inspect $DISK manually."

PARTITION="${PARTITIONS[0]}"

echo "Formatting $PARTITION as Btrfs, label $LABEL..."
wipefs --all --force "$PARTITION"
mkfs.btrfs --force -L "$LABEL" "$PARTITION"

TEMP_MOUNT="$(mktemp -d)"
cleanup_temp_mount() {
    if mountpoint -q "$TEMP_MOUNT"; then
        umount "$TEMP_MOUNT"
    fi
    rmdir "$TEMP_MOUNT"
}
trap cleanup_temp_mount EXIT

mount "$PARTITION" "$TEMP_MOUNT"
chown "$FORMAT_USER:$FORMAT_GROUP" "$TEMP_MOUNT"
chmod 0755 "$TEMP_MOUNT"
umount "$TEMP_MOUNT"
rmdir "$TEMP_MOUNT"
trap - EXIT

echo
echo "Disk formatted successfully!"
echo "Filesystem root is writable by $FORMAT_USER; root retains full access."
lsblk -o NAME,SIZE,FSTYPE,LABEL,UUID,MOUNTPOINTS "$DISK"
echo
echo "Partition: $PARTITION"
echo "Label:     $LABEL"
echo "Mount it with:"
printf '  sudo mkdir -p %q\n' "/mnt/$LABEL"
printf '  sudo mount %q %q\n' "/dev/disk/by-label/$LABEL" "/mnt/$LABEL"