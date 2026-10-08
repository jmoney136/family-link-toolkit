#!/bin/sh
# Reverts the Family Link screen-time bypass on the Samsung S10 (SM-G973F).
# Phone must be connected via ADB (USB debugging authorized).
#
# Only ONE change was made to the phone:
#   uid-scoped app-op GET_USAGE_STATS = ignore for Google Play Services
#   (com.google.android.gms), which blinded Family Link's usage tracking.
#
# This restores normal tracking (daily screen-time AND per-app limits):

adb shell appops set --uid com.google.android.gms GET_USAGE_STATS allow

echo "--- Verify (no 'Uid mode: ignore' line / mode allow) ---"
adb shell appops get com.google.android.gms GET_USAGE_STATS
