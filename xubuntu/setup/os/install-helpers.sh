#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
helpers_dir="$(cd -- "$script_dir/../../helpers" && pwd)"
bin_dir="$HOME/.local/bin"
profile_file="$HOME/.profile"
path_marker="# Added by xubuntu/setup/os/install-helpers.sh"
legacy_path_marker="# Added by xubuntu/setup/install-helpers.sh"

shopt -s nullglob
helper_scripts=("$helpers_dir"/*.sh)

if [[ ${#helper_scripts[@]} -eq 0 ]]; then
    echo "ERROR: No shell helper scripts found in $helpers_dir" >&2
    exit 1
fi

mkdir -p "$bin_dir"

for helper_script in "${helper_scripts[@]}"; do
    if [[ ! -x "$helper_script" ]]; then
        echo "ERROR: Helper script is not executable: $helper_script" >&2
        exit 1
    fi

    destination="$bin_dir/$(basename -- "$helper_script")"

    if [[ -L "$destination" ]] &&
        [[ "$(readlink -- "$destination")" == "$helper_script" ]]; then
        echo "Already installed: $destination"
    elif [[ -e "$destination" || -L "$destination" ]]; then
        echo "ERROR: Refusing to overwrite existing file: $destination" >&2
        exit 1
    else
        ln -s -- "$helper_script" "$destination"
        echo "Installed: $destination"
    fi
done

if ! grep -Fq "$path_marker" "$profile_file" 2>/dev/null &&
    ! grep -Fq "$legacy_path_marker" "$profile_file" 2>/dev/null; then
    {
        printf '\n%s\n' "$path_marker"
        printf 'case ":$PATH:" in\n'
        printf '    *":$HOME/.local/bin:"*) ;;\n'
        printf '    *) PATH="$HOME/.local/bin:$PATH" ;;\n'
        printf 'esac\n'
        printf 'export PATH\n'
    } >>"$profile_file"
    echo "Added $bin_dir to PATH in $profile_file"
else
    echo "PATH setup already present in $profile_file"
fi

echo "Done. Run 'source ~/.profile' or start a new login shell to use the helpers."
