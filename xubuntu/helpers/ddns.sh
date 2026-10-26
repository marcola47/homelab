#!/usr/bin/env bash

set -euo pipefail

domain="marcola.site"
ttl=300
config_dir="${HOME}/.config/ddns"
token_file="$config_dir/token"
unit_dir="${HOME}/.config/systemd/user"
script_path="$(readlink -f -- "${BASH_SOURCE[0]}")"

usage() {
    echo "Usage:"
    echo "  $0 install <hostinger-api-token>"
    echo "  $0 update"
}

get_public_ipv6() {
    ip -6 -o addr show scope global |
        awk '
            $3 == "inet6" {
                split($4, parts, "/")
                address = tolower(parts[1])
                flags = " " $0 " "

                if (flags ~ / temporary / || flags ~ / deprecated / ||
                    flags ~ / tentative / || flags ~ / dadfailed /) {
                    next
                }

                if (address ~ /^(fc|fd|fe80:|ff|2001:0:|::ffff:)/) {
                    next
                }

                preferred = -1
                valid = -1
                for (i = 5; i < NF; i++) {
                    if ($i == "preferred_lft") {
                        preferred = $(i + 1)
                    } else if ($i == "valid_lft") {
                        valid = $(i + 1)
                    }
                }

                if (preferred == "forever") {
                    preferred = 1e15
                } else {
                    sub(/sec$/, "", preferred)
                    preferred += 0
                }

                if (valid == "forever") {
                    valid = 1e15
                } else {
                    sub(/sec$/, "", valid)
                    valid += 0
                }

                if (preferred <= 0 || valid <= 0) {
                    next
                }

                if (selected == "" || preferred > selected_preferred ||
                    (preferred == selected_preferred && valid > selected_valid)) {
                    selected = parts[1]
                    selected_preferred = preferred
                    selected_valid = valid
                }
            }
            END {
                if (selected != "") {
                    print selected
                }
            }
        '
}

update_records() {
    local api_token ipv6 zone_url current_zone payload

    for command in curl jq ip awk; do
        if ! command -v "$command" >/dev/null 2>&1; then
            echo "ERROR: Required command not found: $command" >&2
            return 1
        fi
    done

    if [[ ! -r "$token_file" ]]; then
        echo "ERROR: Token file not found: $token_file" >&2
        echo "Run '$0 install <hostinger-api-token>' first." >&2
        return 1
    fi

    api_token="$(<"$token_file")"
    if [[ -z "$api_token" ]]; then
        echo "ERROR: Hostinger API token is empty." >&2
        return 1
    fi

    ipv6="$(get_public_ipv6)"
    if [[ -z "$ipv6" ]]; then
        echo "ERROR: No stable public IPv6 address was found." >&2
        return 1
    fi

    zone_url="https://developers.hostinger.com/api/dns/v1/zones/$domain"
    current_zone="$(
        curl --fail --silent --show-error \
            --header "Authorization: Bearer $api_token" \
            --header 'Accept: application/json' \
            "$zone_url"
    )"

    payload="$(
        jq -ce --arg ipv6 "$ipv6" --argjson ttl "$ttl" '
            def zone_records:
                if type == "array" then .
                elif type == "object" and (.zone | type == "array") then .zone
                elif type == "object" and (.data | type == "array") then .data
                elif type == "object" and (.records | type == "array") then .records
                else error("unexpected DNS zone response format")
                end;

            zone_records
            | map(select(
                (.name != "immich" and .name != "flix") or .type != "AAAA"
            ))
            + [
                {
                    name: "immich",
                    type: "AAAA",
                    ttl: $ttl,
                    records: [{content: $ipv6}]
                },
                {
                    name: "flix",
                    type: "AAAA",
                    ttl: $ttl,
                    records: [{content: $ipv6}]
                }
            ]
            | {overwrite: true, zone: .}
        ' <<<"$current_zone"
    )"

    curl --fail --silent --show-error \
        --request PUT \
        --header "Authorization: Bearer $api_token" \
        --header 'Accept: application/json' \
        --header 'Content-Type: application/json' \
        --data "$payload" \
        "$zone_url" >/dev/null

    printf 'Updated immich.%s and flix.%s to %s\n' "$domain" "$domain" "$ipv6"
}

install_timer() {
    local api_token="$1"

    if [[ -z "$api_token" ]]; then
        echo "ERROR: Provide a Hostinger API token." >&2
        return 1
    fi

    for command in systemctl sudo loginctl; do
        if ! command -v "$command" >/dev/null 2>&1; then
            echo "ERROR: Required command not found: $command" >&2
            return 1
        fi
    done

    mkdir -p "$config_dir" "$unit_dir"
    chmod 0700 "$config_dir"
    (umask 077; printf '%s\n' "$api_token" >"$token_file")
    chmod 0600 "$token_file"

    cat >"$unit_dir/ddns.service" <<UNIT
[Unit]
Description=Update Hostinger IPv6 records for Immich and Jellyfin

[Service]
Type=oneshot
Environment=HOME=$HOME
ExecStart=/usr/bin/env bash "$script_path" update
UNIT

    cat >"$unit_dir/ddns.timer" <<'UNIT'
[Unit]
Description=Periodically update Hostinger IPv6 records

[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
Unit=ddns.service

[Install]
WantedBy=timers.target
UNIT

    sudo loginctl enable-linger "$USER"
    systemctl --user daemon-reload
    systemctl --user enable --now ddns.timer

    echo "Scheduled IPv6 updates every five minutes for immich.$domain and flix.$domain."
    echo "The API token is stored in $token_file with owner-only permissions."
}

case "${1:-}" in
    install)
        if [[ $# -ne 2 ]]; then
            usage >&2
            exit 2
        fi
        install_timer "$2"
        ;;
    update)
        if [[ $# -ne 1 ]]; then
            usage >&2
            exit 2
        fi
        update_records
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac