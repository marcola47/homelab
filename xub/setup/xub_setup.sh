#!/usr/bin/env bash

set -euo pipefail

if [[ $EUID -eq 0 ]]; then
    echo "ERROR: Run setup.sh as your normal user, not root." >&2
    exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
    echo "ERROR: sudo is required." >&2
    exit 1
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Keep each group in dependency order.
os_scripts=(
    os/install-helpers.sh
    os/env.sh
    os/ssh-server.sh
    os/btrfs.sh
    os/mergerfs.sh
    os/desktop.sh
    os/keyd.sh
)

app_scripts=(
    apps/docker.sh
    apps/nginx.sh
    apps/sunshine.sh
)

docker_compose_files=(
    docker/immich.yml
    docker/jellyfin.yml
)

run_scripts() {
    local script script_path

    for script in "$@"; do
        script_path="$script_dir/$script"

        if [[ ! -f "$script_path" ]]; then
            echo "ERROR: Setup script not found: $script_path" >&2
            exit 1
        fi

        echo
        echo "==> Running $script..."
        bash "$script_path"
    done
}

run_scripts "${os_scripts[@]}"
run_scripts "${app_scripts[@]}"
mkdir -p "$HOME/.jellyfin/config" "$HOME/.jellyfin/cache" "$HOME/.immich"

for compose_file in "${docker_compose_files[@]}"; do
    compose_path="$script_dir/$compose_file"

    if [[ ! -f "$compose_path" ]]; then
        echo "ERROR: Docker Compose file not found: $compose_path" >&2
        exit 1
    fi

    echo
    echo "==> Starting Docker Compose project $compose_file..."
    sudo docker compose -f "$compose_path" up -d
done

echo
echo "All setup scripts and Docker Compose projects completed successfully."