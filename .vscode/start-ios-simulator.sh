#!/bin/zsh
# Open Simulator.app and return immediately. Flutter boots the device
# selected in the status bar. Waiting on `simctl bootstatus` (or picking
# the first "iPhone" UDID) can hang the preLaunchTask so the Dart
# debugger never attaches and the debug toolbar never appears.
set -euo pipefail
open -a Simulator
