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

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
config_source="$script_dir/nginx.conf"
site_file="/etc/nginx/sites-available/marcola-media"
site_link="/etc/nginx/sites-enabled/marcola-media"
certbot_hook="/etc/letsencrypt/renewal-hooks/deploy/reload-nginx"

if [[ ! -f "$config_source" ]]; then
    echo "ERROR: Nginx site configuration not found: $config_source" >&2
    exit 1
fi

sudo -v
sudo apt-get update
sudo apt-get install -y nginx certbot

sudo install -d -m 0755 /var/www/certbot
sudo install -d -m 0755 /etc/nginx/sites-available /etc/nginx/sites-enabled
sudo rm -f /etc/nginx/sites-enabled/default

# Serve ACME challenges before the HTTPS config can reference certificate files.
sudo tee "$site_file" >/dev/null <<'NGINX'
server {
    listen 80;
    listen [::]:80;
    server_name immich.marcola.site flix.marcola.site;

    location ^~ /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 503;
    }
}
NGINX

sudo ln -sfn "$site_file" "$site_link"
sudo nginx -t
sudo systemctl enable --now nginx
sudo systemctl reload nginx

certbot_args=(
    certonly
    --webroot
    --webroot-path /var/www/certbot
    --non-interactive
    --agree-tos
    --cert-name marcola-site
    -d immich.marcola.site
    -d flix.marcola.site
)

if [[ -n "${CERTBOT_EMAIL:-}" ]]; then
    certbot_args+=(--email "$CERTBOT_EMAIL")
else
    certbot_args+=(--register-unsafely-without-email)
    echo "WARNING: CERTBOT_EMAIL is unset; certificate expiry notifications will not be sent." >&2
fi

sudo certbot "${certbot_args[@]}"

sudo install -m 0644 "$config_source" "$site_file"
sudo nginx -t
sudo systemctl reload nginx

sudo install -d -m 0755 "$(dirname -- "$certbot_hook")"
sudo tee "$certbot_hook" >/dev/null <<'HOOK'
#!/bin/sh
systemctl reload nginx
HOOK
sudo chmod 0755 "$certbot_hook"
sudo systemctl enable --now certbot.timer

echo
echo "Nginx is configured for immich.marcola.site and flix.marcola.site."