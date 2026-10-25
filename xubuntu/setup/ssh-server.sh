#!/usr/bin/env bash

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "ERROR: Run this script as your normal user, not root." >&2
    exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
    echo "ERROR: sudo is required." >&2
    exit 1
fi

if [[ ! -f /etc/os-release ]]; then
    echo "ERROR: Cannot determine operating system." >&2
    exit 1
fi

source /etc/os-release

if [[ "${ID:-}" != "ubuntu" ]]; then
    echo "ERROR: This script is intended for Ubuntu/Xubuntu." >&2
    exit 1
fi

sudo apt-get update
sudo apt-get install -y openssh-server ufw
sudo systemctl enable --now ssh

if grep -q '^IPV6=' /etc/default/ufw; then
    sudo sed -i 's/^IPV6=.*/IPV6=yes/' /etc/default/ufw
else
    echo 'IPV6=yes' | sudo tee -a /etc/default/ufw >/dev/null
fi

sudo ufw --force delete allow OpenSSH >/dev/null 2>&1 || true
sudo ufw --force delete allow from 192.168.0.0/24 to any port 22 proto tcp >/dev/null 2>&1 || true
sudo ufw --force delete deny 22/tcp >/dev/null 2>&1 || true

sudo ufw insert 1 allow from 192.168.0.0/24 to any port 22 proto tcp comment 'OpenSSH from LAN'
sudo ufw insert 2 deny 22/tcp comment 'Deny SSH outside LAN'
sudo ufw --force enable
sudo ufw reload

echo
echo "OpenSSH server is ready for connections as ${USER}@$(hostname)."
echo "From Windows, map a Linux folder using SSHFS-Win, for example:"
printf '  net use X: \\\\sshfs.r\\%s@%s\\home\\%s\n' "$USER" "$(hostname)" "$USER"
echo "Replace the host name or path as needed."