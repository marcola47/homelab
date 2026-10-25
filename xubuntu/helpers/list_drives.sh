#!/usr/bin/env bash
set -Eeuo pipefail

lsblk --exclude 7 -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS