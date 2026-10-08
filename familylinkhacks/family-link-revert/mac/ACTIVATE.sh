#!/bin/sh
# Activates the Family Link bypass on the Samsung S10 (SM-G973F) — macOS.
# Covers BOTH the daily screen-time limit AND individual per-app limits:
# both are measured by Google Play Services' kids module through the
# GET_USAGE_STATS app-op, and 'ignore' mode makes those queries return empty
# data — no usage accrues, so no limit can newly trigger, and Play Services
# stays stable (no crashes).
#
# IMPORTANT: use 'ignore', NOT 'deny' — 'deny' throws a SecurityException
# that makes Play Services (and the Family Link app with it) crash-loop.
#
# NOTE: apps already blocked by a limit that fired BEFORE activation stay
# blocked until the daily reset (midnight) or parent action; they also
# disappear from the launcher while suspended. No NEW blocks occur while
# bypassed. Remaining blocked apps are listed at the end.

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

# --- Activate ----------------------------------------------------------
adb shell appops set --uid com.google.android.gms GET_USAGE_STATS ignore

# Best-effort: lift any app blocks currently applied (clears suspensions
# not owned by Family Link; Family Link-owned ones clear at midnight):
SUSPENDED=$(adb shell dumpsys package | awk '/^  Package \[/ {p=$2} /^    User 0: / && /suspended=true/ {print p}' | tr -d '[]:' | tr -d '\r')
if [ -n "$SUSPENDED" ]; then
  adb shell pm unsuspend $SUSPENDED
fi

# Nudge a limit-check re-evaluation (briefly opens the Family Link UI):
adb shell am start -n com.google.android.gms/com.google.android.gms.kids.settings.KidsSettingsActivity

echo "--- Verify (should show: Uid mode: GET_USAGE_STATS: ignore) ---"
adb shell appops get com.google.android.gms GET_USAGE_STATS

echo "--- Still suspended (clears at midnight / via parent; no new blocks) ---"
adb shell dumpsys package | awk '/^  Package \[/ {p=$2} /^    User 0: / && /suspended=true/ {print p}' | tr -d '[]:' | tr -d '\r'
