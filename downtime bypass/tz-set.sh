#!/bin/bash
#
# tz-set.sh - Set device timezone via Chronolink and keep it enforced
#             by a background daemon running on the device.
#
# USAGE: ./tz-set.sh [TIMEZONE] [INTERVAL_SECONDS]
#   defaults: America/New_York, 60 seconds, minimum 5 seconds
#
# REVERT: ./tz-revert.sh
#         (also run: adb shell pkill -f tz-daemon)
#
set -euo pipefail

TARGET_TZ="${1:-America/New_York}"
INTERVAL="${2:-60}"
CHRONO="/data/local/tmp/chronolink"
DAEMON="/data/local/tmp/.tz-daemon.sh"
DAEMON_TAG="tz-daemon"
URL="https://github.com/rifting/chronolink/releases/download/v2.0.0/chronolink-aarch64"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE="$SCRIPT_DIR/.tz_state"

if ! [[ "$INTERVAL" =~ ^[0-9]+$ ]] || [ "$INTERVAL" -lt 5 ]; then
  INTERVAL=5
fi

# --- preflight ---
command -v adb >/dev/null 2>&1 || { echo "[!] adb not found in PATH"; exit 1; }
adb get-state >/dev/null 2>&1 || { echo "[!] No Android device connected"; exit 1; }

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
  echo "[*] Downloading Chronolink and pushing to device..."
  TMP="$(mktemp)"
  curl -fsSL --max-time 60 -o "$TMP" "$URL"
  adb push "$TMP" "$CHRONO" >/dev/null
  rm -f "$TMP"
  adb shell chmod +x "$CHRONO"
  echo "[+] Chronolink installed at $CHRONO"
else
  echo "[i] Chronolink already present on device"
fi

# --- apply timezone once, in the foreground ---
echo "[*] Setting device timezone -> $TARGET_TZ"
adb shell "$CHRONO" "$TARGET_TZ"

# --- stop any daemon from a previous run ---
adb shell "pkill -f $DAEMON_TAG" >/dev/null 2>&1 || true
sleep 1

# --- generate and push the enforcement daemon ---
echo "[*] Installing timezone enforcement daemon every ${INTERVAL}s..."
DAEMON_SRC="$(mktemp)"
cat > "$DAEMON_SRC" <<EOF
#!/system/bin/sh
# $DAEMON_TAG -- keeps timezone pinned to $TARGET_TZ
# stop with: pkill -f $DAEMON_TAG
while true; do
  "$CHRONO" "$TARGET_TZ" >/dev/null 2>&1
  sleep "$INTERVAL"
done
EOF
adb push "$DAEMON_SRC" "$DAEMON" >/dev/null
rm -f "$DAEMON_SRC"
adb shell chmod +x "$DAEMON"

# --- launch detached so it survives the adb shell closing ---
adb shell "setsid sh $DAEMON" >/dev/null 2>&1 < /dev/null &

sleep 1
if adb shell "pgrep -f $DAEMON_TAG" >/dev/null 2>&1; then
  echo "[+] Daemon running with PID $(adb shell pgrep -f "$DAEMON_TAG" | tr -d '\r' | head -n1)"
else
  echo "[!] Daemon may not have started; timezone was still applied once."
fi

echo "[+] Device date : $(adb shell date | tr -d '\r')"
echo "[+] Device tz   : $(adb shell getprop persist.sys.timezone | tr -d '\r')"
echo "[i] Daemon enforcing $TARGET_TZ every ${INTERVAL}s"
echo "[i] Revert with ./tz-revert.sh plus: adb shell pkill -f $DAEMON_TAG"

