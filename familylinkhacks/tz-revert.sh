#!/bin/bash
#
# tz-revert.sh - Restore the device's original timezone and remove ALL
#                Chronolink artifacts created by tz-set.sh.
#
# WHAT IT UNDOES:
#   1. Sets timezone back to the saved original (default Australia/Sydney).
#   2. Clears any `settings global time_zone` override that may have been set.
#   3. Ensures `auto_time_zone` = 1 (original network-synced state).
#   4. Deletes /data/local/tmp/chronolink from the device.
#   5. Deletes the local /tmp/.tz_state bookkeeping file.
#
# USAGE:  ./tz-revert.sh
#
set -euo pipefail

CHRONO="/data/local/tmp/chronolink"
STATE="/tmp/.tz_state"
DEFAULT_ORIG="Australia/Sydney"

# --- preflight ---
command -v adb >/dev/null 2>&1 || { echo "[!] adb not found in PATH"; exit 1; }
adb get-state >/dev/null 2>&1 || { echo "[!] No Android device connected/authorized"; exit 1; }

# --- determine original timezone ---
ORIG="$DEFAULT_ORIG"
if [ -f "$STATE" ]; then
  ORIG="$(cat "$STATE")"
  echo "[i] Restoring saved timezone: $ORIG"
else
  echo "[i] No saved state; using default: $ORIG"
fi

# --- restore timezone ---
echo "[*] Setting device timezone -> $ORIG"
if adb shell "[ -x $CHRONO ]" >/dev/null 2>&1; then
  adb shell "$CHRONO" "$ORIG"
else
  echo "[!] Chronolink not found on device; trying setprop fallback"
  if ! adb shell setprop persist.sys.timezone "$ORIG" 2>/dev/null; then
    echo "[!] setprop blocked (no_config_date_time). Push Chronolink and re-run,"
    echo "    or disable auto-time and set the zone in Settings manually."
  fi
fi

# --- clear overrides we may have written ---
adb shell settings delete global time_zone >/dev/null 2>&1 || true
adb shell settings put global auto_time_zone 1 >/dev/null 2>&1 || true

# --- remove artifacts ---
adb shell rm -f "$CHRONO" 2>/dev/null || true
rm -f "$STATE"

# --- verify ---
echo "[+] Device date : $(adb shell date | tr -d '\r')"
echo "[+] Device tz   : $(adb shell getprop persist.sys.timezone | tr -d '\r')"
echo "[+] auto_time_zone: $(adb shell settings get global auto_time_zone | tr -d '\r')"
echo "[+] chronolink on device: $(adb shell '[ -e /data/local/tmp/chronolink ] && echo PRESENT || echo removed' | tr -d '\r')"
echo "[+] Revert complete - no traces left by this script."
