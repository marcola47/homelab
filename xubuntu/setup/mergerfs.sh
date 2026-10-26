#!/usr/bin/env bash

set -Eeuo pipefail

die() {
	echo "ERROR: $*" >&2
	exit 1
}

if [[ $EUID -eq 0 ]]; then
	die "Run this script as your normal user, not root."
fi

command -v sudo >/dev/null 2>&1 || die "sudo is required."
command -v findmnt >/dev/null 2>&1 || die "findmnt is required."
command -v mountpoint >/dev/null 2>&1 || die "mountpoint is required."

storage_user="$(id -un)"
media_dir="/run/media/$storage_user"
branches=()

for mount_path in "$media_dir"/disk_[0-9]*; do
	[[ -d "$mount_path" ]] || continue
	[[ "${mount_path##*/}" =~ ^disk_[0-9]+$ ]] || continue
	findmnt --mountpoint "$mount_path" -n >/dev/null 2>&1 || continue
	branches+=("$mount_path")
done

sudo apt install -y mergerfs attr
sudo mkdir -p /srv/storage

if mountpoint -q /srv/storage; then
	configured_branches="$(sudo getfattr --only-values -n user.mergerfs.branches \
		/srv/storage/.mergerfs)" ||
		die "Could not read the current mergerfs branches."
	IFS=: read -r -a configured_entries <<< "$configured_branches"
	configured_paths=()
	for entry in "${configured_entries[@]}"; do
		configured_paths+=("${entry%%=*}")
	done

	added=0
	for mount_path in "${branches[@]}"; do
		already_configured=false
		for configured_path in "${configured_paths[@]}"; do
			if [[ "$configured_path" == "$mount_path" ]]; then
				already_configured=true
				break
			fi
		done

		if [[ "$already_configured" == false ]]; then
			echo "Adding mergerfs branch: $mount_path"
			sudo setfattr -n user.mergerfs.branches \\
				-v "+>$mount_path=RW" /srv/storage/.mergerfs
			((added += 1))
		fi
	done

	if (( added == 0 )); then
		echo "Mergerfs pool is already up to date."
	fi
	exit 0
fi

[[ ${#branches[@]} -gt 0 ]] ||
	die "No mounted drives matching $media_dir/disk_<number> were found."

branch_entries=()
for mount_path in "${branches[@]}"; do
	branch_entries+=("$mount_path=RW")
done
branch_list="$(IFS=:; printf '%s' "${branch_entries[*]}")"
echo "Mounting mergerfs pool from: ${branches[*]}"
sudo mergerfs -o defaults,allow_other,use_ino,category.create=mspmfs \
	"$branch_list" /srv/storage
