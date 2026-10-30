#!/usr/bin/env bash

for disk in /dev/sd{a,b,c,d}; do
  temp=$(sudo smartctl -A "$disk" 2>/dev/null \
    | grep 'Temperature_Celsius' \
    | sed -E 's/.*- +([0-9]+).*/\1/')

  printf "%s: %s°C\n" "$disk" "${temp:-N/A}"
done
