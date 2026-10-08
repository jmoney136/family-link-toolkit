#!/bin/sh
# Reverts the Family Link bypass on the Samsung S10 (SM-G973F) — macOS.
# Phone must be connected via ADB (USB debugging authorized).
#
# Only ONE change was made to the phone:
#   uid-scoped app-op GET_USAGE_STATS = ignore for Google Play Services
#   (com.google.android.gms), which blinded Family Link's usage tracking.
#
# This restores normal tracking (daily screen-time AND per-app limits):

# --- Preflight ---------------------------------------------------------
if ! command -v adb >/dev/null 2>&1; then
  echo "ERROR: adb not found in PATH." >&2
  echo "Install Android platform-tools:  brew install --cask android-platform-tools" >&2
  exit 1
fi
if ! adb get-state >/dev/null 2>&1; then
  echo "ERROR: no connected/authorized device. Run 'adb devices' to check." >&2
  exit 1
fi

# --- Revert ------------------------------------------------------------
adb shell appops set --uid com.google.android.gms GET_USAGE_STATS allow

echo "--- Verify (no 'Uid mode: ignore' line / mode allow) ---"
adb shell appops get com.google.android.gms GET_USAGE_STATS
