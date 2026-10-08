#!/bin/bash
#
# tz-set.sh - Shift the connected Android device's timezone using Chronolink.
#
# WHY: Google Family Link (profile owner) sets the user restriction
#      no_config_date_time, which makes `settings put global time_zone` and
#      `setprop persist.sys.timezone` fail. Chronolink sets the timezone via the
#      AlarmManager binder directly, which is NOT gated by that restriction.
#      Moving the clock out of a scheduled downtime window can keep services alive.
#
# USAGE:
#   ./tz-set.sh [TIMEZONE]        # default target: America/New_York
#   ./tz-set.sh Europe/London
#
# REVERT: ./tz-revert.sh
#
# Everything is reversible and survives reboot (persist.sys.timezone).
# The device's ORIGINAL timezone is saved to /tmp/.tz_state on first run.
#
set -euo pipefail

TARGET_TZ="${1:-America/New_York}"
CHRONO="/data/local/tmp/chronolink"
STATE="/tmp/.tz_state"
URL="https://github.com/rifting/chronolink/releases/download/v2.0.0/chronolink-aarch64"

# --- preflight ---
command -v adb >/dev/null 2>&1 || { echo "[!] adb not found in PATH"; exit 1; }
adb get-state >/dev/null 2>&1 || { echo "[!] No Android device connected/authorized"; exit 1; }

# --- save original timezone once ---
if [ ! -f "$STATE" ]; then
  ORIG="$(adb shell getprop persist.sys.timezone | tr -d '\r')"
  echo "$ORIG" > "$STATE"
  echo "[+] Original timezone saved to $STATE : $ORIG"
else
  echo "[i] Original timezone already saved: $(cat "$STATE")"
fi

# --- push Chronolink if not already on device ---
if ! adb shell "[ -x $CHRONO ]" >/dev/null 2>&1; then
  echo "[*] Downloading Chronolink (aarch64) and pushing to device..."
  TMP="$(mktemp)"
  curl -fsSL --max-time 60 -o "$TMP" "$URL"
  adb push "$TMP" "$CHRONO" >/dev/null
  rm -f "$TMP"
  adb shell chmod +x "$CHRONO"
  echo "[+] Chronolink installed at $CHRONO"
else
  echo "[i] Chronolink already present on device"
fi

# --- apply timezone ---
echo "[*] Setting device timezone -> $TARGET_TZ"
adb shell "$CHRONO" "$TARGET_TZ"

echo "[+] Device date : $(adb shell date | tr -d '\r')"
echo "[+] Device tz   : $(adb shell getprop persist.sys.timezone | tr -d '\r')"
echo "[i] Revert with: ./tz-revert.sh"
