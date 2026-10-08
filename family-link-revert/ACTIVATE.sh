#!/bin/sh
# Activates the Family Link bypass on the Samsung S10 (SM-G973F).
# Phone must be connected via ADB (USB debugging authorized).
#
# Covers BOTH the daily total screen-time limit AND individual per-app
# limits: both are measured by Google Play Services' kids module through the
# GET_USAGE_STATS app-op, and 'ignore' mode makes those queries return empty
# data — no usage accrues, so no limit can newly trigger, and Play Services
# stays stable (no crashes).
#
# IMPORTANT: use 'ignore', NOT 'deny'. 'deny' also blinds tracking but
# throws a SecurityException that makes Play Services (and the Family Link
# app with it) crash on every limit check.
#
# NOTE: apps already blocked by a limit that fired BEFORE activation stay
# blocked until the daily reset (midnight) or parent action — those blocks
# are latched inside Play Services, which is protected from ADB changes
# (pm unsuspend/disable/reinstall cycles don't clear them). They are listed
# at the end of this script; no NEW blocks will occur while bypassed.

# 1) Blind the usage tracking:
adb shell appops set --uid com.google.android.gms GET_USAGE_STATS ignore

# 2) Best-effort: lift any app blocks currently applied (clears suspensions
#    not owned by Family Link; Family Link-owned ones clear at midnight):
SUSPENDED=$(adb shell dumpsys package | awk '/^  Package \[/ {p=$2} /^    User 0: / && /suspended=true/ {print p}' | tr -d '[]:' | tr -d '\r')
if [ -n "$SUSPENDED" ]; then
  adb shell pm unsuspend $SUSPENDED
fi

# 3) Nudge a limit-check re-evaluation (briefly opens the Family Link UI):
adb shell am start -n com.google.android.gms/com.google.android.gms.kids.settings.KidsSettingsActivity

echo "--- Verify (should show: Uid mode: GET_USAGE_STATS: ignore) ---"
adb shell appops get com.google.android.gms GET_USAGE_STATS

echo "--- Still suspended (clears at midnight / via parent; no new blocks) ---"
adb shell dumpsys package | awk '/^  Package \[/ {p=$2} /^    User 0: / && /suspended=true/ {print p}' | tr -d '[]:' | tr -d '\r'
