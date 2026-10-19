#!/bin/sh
# Forges a believable day on the Family Link dashboard — Linux.
# Samsung S10 (SM-G973F), phone connected via ADB.
#
# While the bypass is active, Android still RECORDS all real usage —
# Play Services just can't see it (GET_USAGE_STATS: ignore). FORGE.sh
# flips the app-op back to 'allow' just long enough to nudge the
# Family Link UI (same nudge as ACTIVATE.sh — forces an immediate
# usage check), then re-blinds. The kids module measures the usage
# accrued so far today and reports it: the parent's dashboard then
# shows real app usage instead of a suspicious zero. Nothing is faked —
# the parent sees what was really used, just under-reported.
#
# IMPORTANT: ALL usage accrued while bypassed is revealed at once. If it
# exceeds the daily/per-app limits, those blocks latch until midnight
# (normal enforcement — same as running with no bypass). Check the table
# printed first; Ctrl-C during the countdown to abort.
#
# Usage: ./FORGE.sh [seconds]   optional extra hold while un-blinded
#                              (default: none — just the nudge)

HOLD="${1:-0}"
GMS=com.google.android.gms

case "$HOLD" in
  *[!0-9]*) echo "ERROR: seconds must be a number." >&2; exit 1 ;;
esac

# --- Preflight ---------------------------------------------------------
if ! command -v adb >/dev/null 2>&1; then
  echo "ERROR: adb not found in PATH." >&2
  echo "Install Android platform-tools:  apt: sudo apt install adb | Fedora: sudo dnf install android-tools | Arch: sudo pacman -S android-tools" >&2
  exit 1
fi
if ! adb get-state >/dev/null 2>&1; then
  echo "ERROR: no connected/authorized device. Run 'adb devices' to check." >&2
  echo "If not detected, install udev rules:  sudo apt install android-sdk-platform-tools-common (or distro equivalent)" >&2
  exit 1
fi

MODE=$(adb shell appops get $GMS GET_USAGE_STATS | tr -d '\r')
if ! echo "$MODE" | grep -q "Uid mode: GET_USAGE_STATS: ignore"; then
  echo "ERROR: bypass is not active — nothing to forge:" >&2
  echo "$MODE" >&2
  echo "Run ACTIVATE.sh first (if tracking is meant to be on, just leave it)." >&2
  exit 1
fi

# --- What will be revealed ----------------------------------------------
echo "--- Usage recorded today (what Play Services will measure) ---"
USAGE=$(adb shell dumpsys usagestats 2>/dev/null | tr -d '\r' | awk '
  /^  In-memory daily stats/ {sec=1; next}
  /^    configurations/ {sec=0}
  sec && /totalTimeUsed=/ {
    pkg=$0; sub(/^.*package=/,"",pkg); sub(/ .*/,"",pkg)
    if (match($0, /totalTimeUsed="[0-9:]+"/)) {
      t=substr($0, RSTART+15, RLENGTH-16); n=split(t, a, ":")
      s=(n==3 ? a[1]*3600+a[2]*60+a[3] : a[1]*60+a[2])
      if (s>0) printf "%d %s\n", s, pkg
    }
  }')
if [ -z "$USAGE" ]; then
  echo "  (nothing recorded yet — the dashboard would still show ~zero)"
else
  echo "$USAGE" | sort -rn | awk '{
      m=int($1/60); s=$1%60
      if (m>0) printf "  %dm%02ds  %s\n", m, s, $2; else printf "  %ds  %s\n", s, $2
      tot+=$1
    } END { printf "  ------\n  total: %dm%02ds\n", int(tot/60), tot%60 }'
  TOTAL=$(echo "$USAGE" | awk '{t+=$1} END {print t+0}')
  if [ "$TOTAL" -gt 7200 ]; then
    echo "*** WARNING: over 2h recorded — if that is past the parent's limits,"
    echo "    those app blocks latch until midnight once Play Services sees it."
  fi
fi

# --- Un-blind, nudge, re-blind ------------------------------------------
echo "[i] Un-blinding in 5s (Ctrl-C to abort)..."
sleep 5

adb shell appops set --uid $GMS GET_USAGE_STATS allow
forge_reblind() {
  adb shell appops set --uid $GMS GET_USAGE_STATS ignore >/dev/null 2>&1
  exit 1
}
trap forge_reblind INT TERM
trap 'adb shell appops set --uid $GMS GET_USAGE_STATS ignore >/dev/null 2>&1' EXIT

echo "[*] Nudging the Family Link UI (forces an immediate usage check)..."
adb shell am start -n $GMS/com.google.android.gms.kids.settings.KidsSettingsActivity >/dev/null 2>&1
sleep 8
adb shell input keyevent KEYCODE_HOME >/dev/null 2>&1

if [ "$HOLD" -gt 0 ]; then
  echo "[*] Extra hold requested: ${HOLD}s un-blinded (usage now counts)..."
  LEFT=$HOLD
  while [ "$LEFT" -gt 0 ]; do
    sleep 60
    LEFT=$((LEFT-60))
    [ "$LEFT" -gt 0 ] && echo "  ... ${LEFT}s left"
  done
fi

if adb shell appops set --uid $GMS GET_USAGE_STATS ignore; then
  trap - INT TERM EXIT
  echo "--- Verify (should show: Uid mode: GET_USAGE_STATS: ignore) ---"
  adb shell appops get $GMS GET_USAGE_STATS
else
  echo "[!] Could not re-blind (device gone?). Once reconnected, restore with:"
  echo "      adb shell appops set --uid com.google.android.gms GET_USAGE_STATS ignore"
  echo "    (or just run REVERT.sh followed by ACTIVATE.sh)"
fi

echo "[i] Done — the parent dashboard should now show today's usage (table above)."
echo "[i] If it did not update, run again (optionally with a hold: ./FORGE.sh 300)."
