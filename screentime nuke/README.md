# Family Link screen-time bypass — Samsung S10 (SM-G973F), Android 12

## Background
Family Link supervision on this phone is enforced by **Google Play Services**
(`com.google.android.gms`), which holds the "Family Link parental controls"
profile-owner admin (`com.google.android.gms/.kids.account.receiver.ProfileOwnerReceiver`).
Its kids module (`kids.features.appusage.AppUsageLimitCheckingIntentOperation`)
measures usage via the `GET_USAGE_STATS` app-op and blocks apps when limits
are reached. That is why disabling the Family Link app
(`com.google.android.apps.kids.familylinkhelper`, which has no launchable
activity — its UI is Play Services' KidsSettingsActivity) had no effect.

## The change (single, reversible)
    adb shell appops set --uid com.google.android.gms GET_USAGE_STATS ignore

Play Services' usage queries now return empty data, so screen time reads as
zero, never accrues, and limits never trigger. This covers BOTH the daily
total screen-time limit AND individual per-app limits — verified there are no
system-side observers (`dumpsys usagestats` → "Observed Entities:" is
empty), so all limit checking goes through this blinded path. The Family Link
app opens normally (no crash).

**Do not use `deny` mode.** It also blinds tracking, but the kids module
doesn't handle the resulting SecurityException — Play Services crash-loops on
every limit check, which also kills the Family Link app when opened.

## Scripts
Use the folder for your platform — each contains `ACTIVATE.sh`,
`REVERT.sh` and `requirements.txt` (dependencies + install commands):
- `mac/`   — macOS (tested)
- `linux/` — same logic, Linux-specific install hints and udev note

Baseline dumps taken before any changes: `device-policy-BEFORE.txt`,
`disabled-packages-BEFORE.txt`, `appops-gms-BEFORE.txt`

## Already-blocked apps (known limitation)
An app block that fired BEFORE activation (e.g. Instagram, Slack at the time
of testing) is latched inside Play Services and clears only at the daily
reset (midnight) or via parent action ("grant more time"/remove limit).
While suspended, such apps ALSO disappear from the launcher (suspended apps
are excluded from launcher queries — verified with Slack, untouched by ADB);
they reappear when unblocked. No NEW blocks occur while the bypass is
active. ADB cannot lift these blocks: `pm unsuspend` is overridden for
admin-set suspensions, disable/enable and uninstall/reinstall
(`pm uninstall -k --user 0` + `install-existing`) cycles keep the flag, and
`pm clear com.google.android.gms` is blocked (protected package).

## Notes
- Change survives reboots; re-check anytime with:
  `adb shell appops get com.google.android.gms GET_USAGE_STATS` → `Uid mode: GET_USAGE_STATS: ignore`
- Bedtime (if the parent set one) is clock-based and still applies. This
  bypass targets usage-based limits. (See `familylinkhacks/tz-set.sh` for
  a timezone-based approach to clock-based downtime.)
- While active, the parent's dashboard will show little/no usage for this device.
- Approaches tried and safely rejected (no changes resulted): removing the
  profile owner via `dpm` (blocked for non-test admins), uninstalling Play
  Services for user 0 (blocked: profile owner), disabling it (blocked:
  protected package), `deny` app-op mode (blinds tracking but crash-loops
  Play Services).
