#!/usr/bin/env bash

set -Eeuo pipefail

die() {
	echo "ERROR: $*" >&2
	exit 1
}

ensure_directory() {
	local path="$1"
	local fstype

	if findmnt -rn -M "$path" >/dev/null 2>&1; then
		if mountpoint -q "$path"; then
			return
		fi

		fstype="$(findmnt -nro FSTYPE -M "$path")"
		if [[ "$path" == "/srv/storage" && "$fstype" == "fuse.mergerfs" ]]; then
			echo "Detaching inaccessible stale mergerfs mount at $path."
			sudo umount -l -- "$path" || die "Could not detach stale mergerfs mount at $path."
		else
			die "Mount table contains an inaccessible $fstype mount at $path."
		fi
	fi

	if sudo test -d "$path"; then
		return
	fi
	if sudo test -e "$path"; then
		die "Path exists but is not a directory: $path"
	fi
	if ! sudo mkdir -p -- "$path"; then
		sudo test -d "$path" && return
		die "Could not create directory: $path"
	fi
}

if [[ $EUID -eq 0 ]]; then
	die "Run this script as your normal user, not root."
fi

command -v sudo >/dev/null 2>&1 || die "sudo is required."
command -v blkid >/dev/null 2>&1 || die "blkid is required."
command -v lsblk >/dev/null 2>&1 || die "lsblk is required."
command -v findmnt >/dev/null 2>&1 || die "findmnt is required."
command -v mountpoint >/dev/null 2>&1 || die "mountpoint is required."

fstab_path=/etc/fstab
begin_marker="# BEGIN homelab mergerfs"
end_marker="# END homelab mergerfs"
storage_user="$(id -un)"
media_dir="/run/media/$storage_user"
mount_root=/srv/disks

root_source="$(findmnt -nro SOURCE /)" || die "Cannot determine the root filesystem."
root_source="${root_source%%\[*}"
[[ -b "$root_source" ]] || die "Cannot safely identify the system disk."
mapfile -t root_devices < <(lsblk -s -nrpo NAME "$root_source")
declare -A root_device_set=()
for device in "${root_devices[@]}"; do
	root_device_set["$device"]=1
done

declare -A detected_uuids=()
declare -A detected_types=()
declare -A detected_labels_by_uuid=()
while IFS= read -r device; do
	label="$(sudo blkid -s LABEL -o value "$device" 2>/dev/null || true)"
	[[ "$label" =~ ^disk_[0-9]+$ ]] || continue
	[[ -z "${root_device_set[$device]+x}" ]] ||		die "Refusing to pool $device: it contains the running root filesystem."

	uuid="$(sudo blkid -s UUID -o value "$device" 2>/dev/null || true)"
	fstype="$(sudo blkid -s TYPE -o value "$device" 2>/dev/null || true)"
	[[ -n "$uuid" && -n "$fstype" ]] ||		die "Labeled filesystem $device ($label) has no UUID or type."
	[[ "$uuid" =~ ^[[:alnum:]-]+$ ]] || die "Unexpected UUID format for $device: $uuid"
	[[ -z "${detected_uuids[$label]+x}" ]] ||		die "More than one connected filesystem has the label $label."
	[[ -z "${detected_labels_by_uuid[$uuid]+x}" ]] ||		die "UUID $uuid is shared by multiple connected filesystems."

	detected_uuids["$label"]="$uuid"
	detected_types["$label"]="$fstype"
	detected_labels_by_uuid["$uuid"]="$label"
done < <(sudo blkid -o device)

[[ ${#detected_uuids[@]} -gt 0 ]] ||		die "No connected filesystems labeled disk_<number> were found."

fstab_entries="$(sudo awk -v begin="$begin_marker" -v end="$end_marker" '
	$0 == begin {
		if (inside || seen_begin) bad = 1
		inside = 1
		seen_begin = 1
		next
	}
	$0 == end {
		if (!inside || seen_end) bad = 1
		inside = 0
		seen_end = 1
		next
	}
	/^[[:space:]]*#/ || NF < 3 { next }
	$2 == "/srv/storage" || $2 ~ /^\/(mnt|srv\/disks)\/disk_[0-9]+$/ {
		printf "%s\t%s\t%s\n", $1, $2, $3
	}
	END {
		if (bad || inside || (seen_begin != seen_end)) exit 2
	}
' "$fstab_path")" || die "Could not safely inspect $fstab_path."

declare -A configured_uuids=()
declare -A configured_types=()
while IFS=$'\t' read -r source target fstype; do
	[[ -n "$target" ]] || continue
	if [[ "$target" == "/srv/storage" ]]; then
		[[ "$fstype" == "fuse.mergerfs" ]] ||			die "$target already has a non-mergerfs fstab entry."
		continue
	fi

	label="${target##*/}"
	[[ "$label" =~ ^disk_[0-9]+$ ]] || die "Unexpected managed mount path: $target"
	[[ "$source" =~ ^UUID=([[:alnum:]-]+)$ ]] ||		die "Expected a UUID= source for $target in $fstab_path."
	uuid="${BASH_REMATCH[1]}"
	if [[ -n "${configured_uuids[$label]+x}" ]]; then
		[[ "${configured_uuids[$label]}" == "$uuid" &&			"${configured_types[$label]}" == "$fstype" ]] ||			die "Conflicting fstab entries found for $target."
	else
		configured_uuids["$label"]="$uuid"
		configured_types["$label"]="$fstype"
	fi
done <<< "$fstab_entries"

for label in "${!detected_uuids[@]}"; do
	configured_uuids["$label"]="${detected_uuids[$label]}"
	configured_types["$label"]="${detected_types[$label]}"
done

labels=()
mapfile -t labels < <(printf '%s\n' "${!configured_uuids[@]}" | sort -V)
[[ ${#labels[@]} -gt 0 ]] || die "No mergerfs branches are configured."

declare -A configured_labels_by_uuid=()
for label in "${labels[@]}"; do
	uuid="${configured_uuids[$label]}"
	[[ -z "${configured_labels_by_uuid[$uuid]+x}" ]] ||		die "UUID $uuid is configured for more than one disk label."
	configured_labels_by_uuid["$uuid"]="$label"
done

sudo apt install -y mergerfs attr
ensure_directory "$mount_root"
ensure_directory /srv/storage

fstab_tmp="$(mktemp)"
trap 'rm -f "$fstab_tmp"' EXIT
sudo awk -v begin="$begin_marker" -v end="$end_marker" '
	$0 == begin { inside = 1; next }
	$0 == end { inside = 0; next }
	inside { next }
	/^[[:space:]]*#/ || NF == 0 { print; next }
	$2 == "/srv/storage" || $2 ~ /^\/(mnt|srv\/disks)\/disk_[0-9]+$/ { next }
	{ print }
' "$fstab_path" > "$fstab_tmp" || die "Could not prepare the managed fstab entries."

branch_entries=()
fstab_options="defaults,allow_other,use_ino,category.create=mspmfs,nofail"
for label in "${labels[@]}"; do
	mount_path="$mount_root/$label"
	branch_entries+=("$mount_path=RW")
	fstab_options+=",x-systemd.requires=$mount_path"
	disk_options="defaults,nofail,x-systemd.device-timeout=10s"
	printf 'UUID=%s\t%s\t%s\t%s\t0\t0\n' \
		"${configured_uuids[$label]}" "$mount_path" \
		"${configured_types[$label]}" "$disk_options" >> "$fstab_tmp"
done

branch_list="$(IFS=:; printf '%s' "${branch_entries[*]}")"
printf '%s\n' "$begin_marker" >> "$fstab_tmp"
printf '%s\t/srv/storage\tfuse.mergerfs\t%s\t0\t0\n' \
	"$branch_list" "$fstab_options" >> "$fstab_tmp"
printf '%s\n' "$end_marker" >> "$fstab_tmp"

fstab_backup=/etc/fstab.before-homelab-mergerfs
if ! sudo test -e "$fstab_backup"; then
	sudo cp -p "$fstab_path" "$fstab_backup"
fi
sudo install -m 0644 "$fstab_tmp" /etc/.fstab.homelab-mergerfs.tmp
sudo mv -f /etc/.fstab.homelab-mergerfs.tmp "$fstab_path"
sudo systemctl daemon-reload

for label in "${!detected_uuids[@]}"; do
	mount_path="$mount_root/$label"
	ensure_directory "$mount_path"
	if mountpoint -q "$mount_path"; then
		mounted_source="$(findmnt -nro SOURCE --mountpoint "$mount_path")"
		mounted_source="${mounted_source%%\[*}"
		mounted_uuid="$(sudo blkid -s UUID -o value "$mounted_source" 2>/dev/null || true)"
		[[ "$mounted_uuid" == "${detected_uuids[$label]}" ]] ||			die "$mount_path is already mounted from a different filesystem."
	else
		sudo mount "$mount_path"
	fi
done

if mountpoint -q /srv/storage; then
	configured_branches="$(sudo getfattr --only-values \
		-n user.mergerfs.branches /srv/storage/.mergerfs)" ||		die "Could not read the active mergerfs branches."
	IFS=: read -r -a active_entries <<< "$configured_branches"
	for label in "${!detected_uuids[@]}"; do
		mount_path="$mount_root/$label"
		legacy_path="$media_dir/$label"
		previous_path="/mnt/$label"
		already_active=false
		for entry in "${active_entries[@]}"; do
			active_path="${entry%%=*}"
			if [[ "$active_path" == "$mount_path" || \
				"$active_path" == "$previous_path" || \
				"$active_path" == "$legacy_path" ]]; then
				already_active=true
				break
			fi
		done
		if [[ "$already_active" == false ]]; then
			echo "Adding live mergerfs branch: $mount_path"
			sudo setfattr -n user.mergerfs.branches \
				-v "+>$mount_path=RW" /srv/storage/.mergerfs
		fi
	done
	echo "Persistent mergerfs configuration updated; active pool left mounted."
else
	for label in "${labels[@]}"; do
		if [[ -z "${detected_uuids[$label]+x}" ]]; then
			die "Configured pool drive $label is not connected; refusing to mount an incomplete pool."
		fi
	done
	echo "Mounting mergerfs pool from: ${branch_entries[*]}"
	sudo mount /srv/storage
fi
