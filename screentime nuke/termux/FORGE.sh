#!/bin/sh
# Forge usage data to make today appear used on Family Link dashboard.
# The bypass blinds Play Services' usage QUERIES, but Android still records
# all real usage on the device. This script flips the app-op back to
# 'allow' just long enough to nudge the Family Link UI (forces an immediate
# usage check while un-blinded), then re-blinds. The kids module measures
# the usage accrued so far today and reports it, so the parent's dashboard
# shows real app usage instead of a suspicious zero.
#
# USAGE:
#   ./FORGE.sh              # default ~15 second un-blinded window
#   ./FORGE.sh 300          # hold un-blinded for 300 seconds (5 min)
#
# Run while the device is connected. It prints what will be revealed first.
# If that is already past the parent's limits, those blocks latch until
# midnight once measured — forge while under the limit, or accept the block.

HOLD_SECONDS="${1:-15}"

# --- Preflight ---------------------------------------------------------
if ! command -v adb >/dev/null 2>&1; then
  echo "ERROR: adb not found in PATH." >&2
  echo "Install: pkg update && pkg install -y android-tools" >&2
  exit 1
fi
if ! adb get-state >/dev/null 2>&1; then
  echo "ERROR: no connected/authorized device. Run 'adb devices' to check." >&2
  exit 1
fi

# Show current usage that will be revealed
echo "--- Current usage stats (this will be revealed to parent dashboard) ---"
adb shell dumpsys usagestats | head -50

echo "[*] Will hold un-blinded for $HOLD_SECONDS seconds..."
echo "[*] During this time, usage is measured normally."
echo "[*] Press Ctrl+C to abort early."

# Un-blind temporarily
adb shell appops set --uid com.google.android.gms GET_USAGE_STATS allow

# Nudge the Family Link UI to force a usage check
adb shell am start -n com.google.android.gms/com.google.android.gms.kids.settings.KidsSettingsActivity

# Hold for the specified duration
sleep "$HOLD_SECONDS"

# Re-blind
adb shell appops set --uid com.google.android.gms GET_USAGE_STATS ignore

echo "[+] Re-blinded. Parent dashboard now shows measured usage."
echo "--- Verify (should show: Uid mode: GET_USAGE_STATS: ignore) ---"
adb shell appops get com.google.android.gms GET_USAGE_STATS
