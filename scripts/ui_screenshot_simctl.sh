#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  printf 'Usage: %s <simulator_udid_or_booted> <output_png>\n' "${0##*/}" >&2
  exit 1
fi

device_ref="$1"
output_png="$2"

output_dir="$(dirname "$output_png")"
mkdir -p "$output_dir"

xcrun simctl io "$device_ref" screenshot "$output_png"
