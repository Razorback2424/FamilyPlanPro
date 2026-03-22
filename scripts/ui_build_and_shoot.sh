#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  printf 'Usage: %s <scheme> <bundle_id> <route>\n' "${0##*/}" >&2
  printf 'Routes: suggestion, review, conflict, finalized, groceryList, settings, familySettings\n' >&2
  exit 1
fi

scheme="$1"
bundle_id="$2"
route="$3"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
artifacts_dir="$repo_root/artifacts"
derived_data_dir="$repo_root/.build/ui-screenshot"
progress_file="$repo_root/progress.md"
checklist_file="$repo_root/docs/ui_screenshot_checklist.md"
build_log="$artifacts_dir/ui-build.log"
latest_png="$artifacts_dir/ui-latest.png"
latest_json="$artifacts_dir/ui-latest.json"
valid_routes=(suggestion review conflict finalized groceryList settings familySettings)

mkdir -p "$artifacts_dir" "$derived_data_dir"

if [[ ! -f "$checklist_file" ]]; then
  printf 'Missing checklist file: %s\n' "$checklist_file" >&2
  exit 1
fi

if [[ ! -f "$progress_file" ]]; then
  {
    printf 'Original prompt: repo-local screenshot-loop plumbing setup\n'
    printf '\n'
    printf '## Loop Log\n'
  } > "$progress_file"
fi

route_is_valid=0
for valid_route in "${valid_routes[@]}"; do
  if [[ "$route" == "$valid_route" ]]; then
    route_is_valid=1
    break
  fi
done

if [[ "$route_is_valid" -ne 1 ]]; then
  printf 'Unsupported route: %s\n' "$route" >&2
  printf 'Allowed routes: %s\n' "${valid_routes[*]}" >&2
  exit 1
fi

resolve_simulator_udid() {
  local preferred_name="${SIMULATOR_DEVICE_NAME:-iPhone 17}"
  python3 - <<'PY' "$preferred_name"
import json
import subprocess
import sys

preferred_name = sys.argv[1]
data = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "-j"], text=True))

def iter_devices():
    for runtime_devices in data.get("devices", {}).values():
        for device in runtime_devices:
            yield device

booted = [d for d in iter_devices() if d.get("state") == "Booted" and d.get("isAvailable")]
if booted:
    print(booted[0]["udid"])
    raise SystemExit(0)

available = [d for d in iter_devices() if d.get("isAvailable")]
for device in available:
    if device.get("name") == preferred_name:
        print(device["udid"])
        raise SystemExit(0)

for device in available:
    if "iPhone" in device.get("name", ""):
        print(device["udid"])
        raise SystemExit(0)

raise SystemExit("Unable to resolve an available iPhone simulator.")
PY
}

write_json() {
  local simulator_udid="$1"
  local simulator_name="$2"
  cat > "$latest_json" <<JSON
{
  "scheme": "$scheme",
  "bundle_id": "$bundle_id",
  "route": "$route",
  "simulator_udid": "$simulator_udid",
  "simulator_name": "$simulator_name",
  "screenshot": "$latest_png",
  "build_log": "$build_log"
}
JSON
}

simulator_udid="$(resolve_simulator_udid)"
simulator_name="${SIMULATOR_DEVICE_NAME:-booted-or-default}"

xcrun simctl boot "$simulator_udid" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$simulator_udid" -b

xcrun simctl spawn "$simulator_udid" launchctl setenv UITEST_RESET 1
trap 'xcrun simctl spawn "$simulator_udid" launchctl unsetenv UITEST_RESET >/dev/null 2>&1 || true' EXIT

(
  cd "$repo_root"
  xcodebuild \
    -scheme "$scheme" \
    -configuration Debug \
    -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$derived_data_dir" \
    build
) | tee "$build_log"

app_path="$derived_data_dir/Build/Products/Debug-iphonesimulator/$scheme.app"
if [[ ! -d "$app_path" ]]; then
  printf 'Built app not found at %s\n' "$app_path" >&2
  exit 1
fi

xcrun simctl terminate "$simulator_udid" "$bundle_id" >/dev/null 2>&1 || true
xcrun simctl uninstall "$simulator_udid" "$bundle_id" >/dev/null 2>&1 || true
xcrun simctl install "$simulator_udid" "$app_path"
xcrun simctl launch "$simulator_udid" "$bundle_id" -ui_debug_route "$route"

sleep 2
"$script_dir/ui_screenshot_simctl.sh" "$simulator_udid" "$latest_png"
write_json "$simulator_udid" "$simulator_name"

printf -- '- %s: captured %s for %s; wrote %s and %s.\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$route" "$scheme" "$latest_png" "$latest_json" >> "$progress_file"
