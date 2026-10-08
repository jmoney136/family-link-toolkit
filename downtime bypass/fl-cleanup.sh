#!/bin/bash
#
# fl-cleanup.sh - Remove engagement traces from this Mac.
#
# Scrubs lines matching engagement keywords from:
#   * ~/.zsh_history
#   * ~/.zsh_sessions/*.history and *.historynew
# and removes transient bookkeeping files.
#
# USAGE:
#   ./fl-cleanup.sh           # dry run: report what WOULD change
#   ./fl-cleanup.sh --apply   # actually edit files (in place)
#
set -uo pipefail

APPLY=0
[ "${1:-}" = "--apply" ] && APPLY=1

# Engagement-specific keywords only (deliberately narrow; does not touch
# unrelated history such as generic adb/dumpsys usage).
PAT='chronolink|everyproxy|familylink|fl_watchdog|fl-off|fl-on|fl_state|hai_kidlock|GET_USAGE_STATS'

TARGETS=()
while IFS= read -r f; do TARGETS+=("$f"); done < <(
  { [ -f "$HOME/.zsh_history" ] && echo "$HOME/.zsh_history"
    ls "$HOME"/.zsh_sessions/*.history "$HOME"/.zsh_sessions/*.historynew 2>/dev/null
  } | sort -u
)

echo "=== fl-cleanup ($( [ $APPLY -eq 1 ] && echo APPLY || echo DRY-RUN )) ==="

total_before=0
changed=0
for f in "${TARGETS[@]}"; do
  n=$(grep -cE "$PAT" "$f" 2>/dev/null || true)
  total_before=$((total_before + n))
  if [ "$n" -gt 0 ]; then
    if [ "$APPLY" -eq 1 ]; then
      LC_ALL=C /usr/bin/sed -i '' -E "/$PAT/d" "$f"
      after=$(grep -cE "$PAT" "$f" 2>/dev/null || true)
      printf '  scrubbed %-3s lines -> %-3s left : %s\n' "$n" "$after" "${f/#$HOME/~}"
      [ "$after" -eq 0 ] && changed=$((changed + 1))
    else
      printf '  would scrub %-3s lines : %s\n' "$n" "${f/#$HOME/~}"
    fi
  fi
done

# Transient bookkeeping
for extra in /tmp/.hai_zbak /tmp/.tz_state; do
  if [ -e "$extra" ]; then
    if [ "$APPLY" -eq 1 ]; then rm -f "$extra"; echo "  removed $extra"; else echo "  would remove $extra"; fi
  fi
done

echo "---"
echo "Total keyword lines found : $total_before"
if [ "$APPLY" -eq 1 ]; then
  remaining=$(grep -rEc "$PAT" "$HOME/.zsh_history" "$HOME"/.zsh_sessions/*.history "$HOME"/.zsh_sessions/*.historynew 2>/dev/null | grep -v ':0$' | wc -l | tr -d ' ')
  echo "Files still containing keywords : $remaining"
  echo "[+] Cleanup complete."
else
  echo "Re-run with --apply to perform the changes."
fi
