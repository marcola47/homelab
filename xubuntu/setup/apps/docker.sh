#!/usr/bin/env bash

set -euo pipefail

echo "==> Docker installation for Xubuntu/Ubuntu"
echo

# -------------------------------------------------------------------
# 1. Check prerequisites
# -------------------------------------------------------------------

if [[ $EUID -eq 0 ]]; then
    echo "ERROR: Don't run this script as root."
    echo "Run it as your normal user: ./install-docker.sh"
    exit 1
fi

if [[ ! -f /etc/os-release ]]; then
    echo "ERROR: Cannot determine operating system."
    exit 1
fi

source /etc/os-release

if [[ "${ID}" != "ubuntu" ]]; then
    echo "ERROR: This script is intended for Ubuntu/Xubuntu."
    echo "Detected: ${PRETTY_NAME:-unknown}"
    exit 1
fi

# Xubuntu reports itself as Ubuntu in /etc/os-release.
UBUNTU_CODENAME="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"

if [[ -z "${UBUNTU_CODENAME}" ]]; then
    echo "ERROR: Could not determine Ubuntu codename."
    exit 1
fi

echo "Detected OS: ${PRETTY_NAME}"
echo "Ubuntu codename: ${UBUNTU_CODENAME}"
echo

# -------------------------------------------------------------------
# 2. Remove conflicting packages
# -------------------------------------------------------------------

echo "==> Removing conflicting Docker packages..."

sudo apt-get remove -y \
    docker.io \
    docker-compose \
    docker-compose-v2 \
    docker-doc \
    podman-docker \
    containerd \
    runc \
    2>/dev/null || true

# -------------------------------------------------------------------
# 4. Configure Docker's official GPG key
# -------------------------------------------------------------------

echo "==> Configuring Docker GPG key..."

sudo install -m 0755 -d /etc/apt/keyrings

sudo curl -fsSL \
    https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc

sudo chmod a+r /etc/apt/keyrings/docker.asc

# -------------------------------------------------------------------
# 5. Configure Docker's official repository
# -------------------------------------------------------------------

echo "==> Configuring Docker repository..."

sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${UBUNTU_CODENAME}
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

# -------------------------------------------------------------------
# 6. Install Docker
# -------------------------------------------------------------------

echo "==> Installing Docker Engine..."

sudo apt-get update

sudo apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

# -------------------------------------------------------------------
# 7. Enable and start Docker
# -------------------------------------------------------------------

echo "==> Enabling Docker service..."

sudo systemctl enable --now docker

# -------------------------------------------------------------------
# 8. Restrict published media ports to the local network
# -------------------------------------------------------------------

echo "==> Configuring Docker LAN firewall rules..."

firewall_script="/usr/local/sbin/docker-lan-ports-firewall"
firewall_dropin="/etc/systemd/system/docker.service.d/lan-ports.conf"

sudo systemctl disable --now docker-lan-ports-firewall.service 2>/dev/null || true
sudo rm -f /etc/systemd/system/docker-lan-ports-firewall.service

sudo tee "$firewall_script" >/dev/null <<'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

iptables -w -N HOMELAB-LAN-PORTS 2>/dev/null || true
iptables -w -F HOMELAB-LAN-PORTS
iptables -w -C DOCKER-USER -j HOMELAB-LAN-PORTS 2>/dev/null ||
    iptables -w -I DOCKER-USER 1 -j HOMELAB-LAN-PORTS

for port_protocol in "tcp 8096" "udp 7359" "tcp 2283"; do
    read -r protocol port <<< "$port_protocol"

    iptables -w -A HOMELAB-LAN-PORTS \
        -s 192.168.0.0/24 \
        -p "$protocol" \
        -m conntrack --ctorigdstport "$port" \
        -j ACCEPT
    iptables -w -A HOMELAB-LAN-PORTS \
        -p "$protocol" \
        -m conntrack --ctorigdstport "$port" \
        -j DROP
done

iptables -w -A HOMELAB-LAN-PORTS -j RETURN

if ip6tables -w -nL DOCKER-USER >/dev/null 2>&1; then
    ip6tables -w -N HOMELAB-LAN-PORTS 2>/dev/null || true
    ip6tables -w -F HOMELAB-LAN-PORTS
    ip6tables -w -C DOCKER-USER -j HOMELAB-LAN-PORTS 2>/dev/null ||
        ip6tables -w -I DOCKER-USER 1 -j HOMELAB-LAN-PORTS

    for port_protocol in "tcp 8096" "udp 7359" "tcp 2283"; do
        read -r protocol port <<< "$port_protocol"

        ip6tables -w -A HOMELAB-LAN-PORTS \
            -p "$protocol" \
            -m conntrack --ctorigdstport "$port" \
            -j DROP
    done

    ip6tables -w -A HOMELAB-LAN-PORTS -j RETURN
fi
SCRIPT
sudo chmod 0755 "$firewall_script"

sudo install -d -m 0755 "$(dirname -- "$firewall_dropin")"
sudo tee "$firewall_dropin" >/dev/null <<'UNIT'
[Service]
ExecStartPost=/usr/local/sbin/docker-lan-ports-firewall
UNIT

sudo systemctl daemon-reload
sudo "$firewall_script"

# -------------------------------------------------------------------
# 9. Add current user to docker group
# -------------------------------------------------------------------

echo "==> Configuring Docker for non-root usage..."

if ! getent group docker >/dev/null; then
    sudo groupadd docker
fi

if ! id -nG "${USER}" | grep -qw docker; then
    sudo usermod -aG docker "${USER}"
fi

# -------------------------------------------------------------------
# 10. Verify Docker installation
# -------------------------------------------------------------------

echo
echo "==> Docker version:"
sudo docker --version

echo
echo "==> Docker Compose version:"
sudo docker compose version

echo
echo "==> Testing Docker..."
sudo docker run --rm hello-world

# -------------------------------------------------------------------
# 11. Finish
# -------------------------------------------------------------------

echo
echo "============================================================"
echo " Docker installation completed successfully!"
echo "============================================================"
echo
echo "Docker:"
sudo docker --version

echo
echo "Docker Compose:"
sudo docker compose version

echo
echo "IMPORTANT:"
echo "Your user was added to the 'docker' group."
echo
echo "Log out and log back in (or reboot) for the group change"
echo "to take effect."
echo
echo "After logging back in, test with:"
echo
echo "    docker run --rm hello-world"
echo