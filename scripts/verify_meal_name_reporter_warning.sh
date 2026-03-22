#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
log_dir="$repo_root/.build/reporter-warning"
mkdir -p "$log_dir"

simulator_udid="$(
python3 - <<'PY'
import json
import subprocess

data = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "-j"], text=True))
devices = [
    device
    for runtime_devices in data.get("devices", {}).values()
    for device in runtime_devices
    if device.get("isAvailable")
]

for device in devices:
    if device.get("state") == "Booted" and "iPhone" in device.get("name", ""):
        print(device["udid"])
        raise SystemExit(0)

for device in devices:
    if device.get("name") == "iPhone 17":
        print(device["udid"])
        raise SystemExit(0)

for device in devices:
    if "iPhone" in device.get("name", ""):
        print(device["udid"])
        raise SystemExit(0)

raise SystemExit("Unable to resolve an available iPhone simulator.")
PY
)"

xcrun simctl boot "$simulator_udid" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$simulator_udid" -b

log_file="$log_dir/reporter-warning.log"
test_log="$log_dir/xcodebuild.log"
: > "$log_file"
: > "$test_log"

capture_pid=""
cleanup() {
    if [[ -n "$capture_pid" ]]; then
        kill "$capture_pid" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT

xcrun simctl spawn "$simulator_udid" log stream \
    --style compact \
    --level debug \
    --predicate 'eventMessage CONTAINS "Reporter disconnected"' \
    > "$log_file" 2>&1 &
capture_pid="$!"

(
    cd "$repo_root"
    xcodebuild \
        -scheme FamilyPlanProUI \
        -configuration Debug \
        -destination 'platform=iOS Simulator,name=iPhone 17' \
        test \
        -only-testing:FamilyPlanProUITests/FamilyPlanProUITests/testMealNameFieldFocusDoesNotTriggerReporterDisconnectWarning
) | tee "$test_log"

kill "$capture_pid" >/dev/null 2>&1 || true
capture_pid=""

if rg -n -F 'Reporter disconnected. { function=sendMessage' "$log_file"; then
    printf 'Reporter disconnect warning still present. See %s\n' "$log_file" >&2
    exit 1
fi

printf 'No reporter disconnect warning captured.\n'
