#!/bin/zsh
# Start the first available AVD, detached from this task so a debug
# session restart cannot kill qemu. Host GPU avoids lavapipe crashes.
set -euo pipefail

SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
ADB="$SDK/platform-tools/adb"
EMU="$SDK/emulator/emulator"
DEVICE_ID="emulator-5554"
LOG="${TMPDIR:-/tmp}/android-emulator.log"
AVD_HOME="${ANDROID_AVD_HOME:-$HOME/.android/avd}"

if [ ! -x "$ADB" ] || [ ! -x "$EMU" ]; then
  echo "Android SDK not found at $SDK. Install it from Android Studio."
  exit 1
fi

wait_for_boot() {
  "$ADB" -s "$DEVICE_ID" wait-for-device
  until [ "$("$ADB" -s "$DEVICE_ID" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do
    sleep 1
  done
}

enable_ime() {
  "$ADB" -s "$DEVICE_ID" shell settings put secure show_ime_with_hard_keyboard 1 >/dev/null
}

if "$ADB" devices | grep -q "^${DEVICE_ID}[[:space:]]"; then
  wait_for_boot
  enable_ime
  exit 0
fi

AVD="$("$EMU" -list-avds | awk 'NF { print; exit }')"
if [ -z "$AVD" ]; then
  echo "No Android Virtual Device found. Create one in Android Studio > Device Manager."
  exit 1
fi

# Leftover lock from a previous qemu crash blocks the next boot.
find "$AVD_HOME" -name 'multiinstance.lock' -delete 2>/dev/null || true

# New session: VS Code task teardown / debug restart must not SIGTERM qemu.
/usr/bin/python3 - "$EMU" "$AVD" "$LOG" <<'PY'
import os, subprocess, sys

emu, avd, log_path = sys.argv[1], sys.argv[2], sys.argv[3]
os.makedirs(os.path.dirname(log_path), exist_ok=True)
log = open(log_path, "ab", buffering=0)
subprocess.Popen(
    [emu, "-avd", avd, "-gpu", "host", "-no-snapshot-load"],
    stdout=log,
    stderr=subprocess.STDOUT,
    stdin=subprocess.DEVNULL,
    start_new_session=True,
    cwd=os.path.expanduser("~"),
)
PY

wait_for_boot
enable_ime
