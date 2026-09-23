#!/usr/bin/env bash
# The actual cron entry point (point crontab here, not at lib/run_update_and_push.sh
# directly). Runs the shared lib/run_update_and_push.sh once per active
# language, skipping any marked "done" in languages_status.csv -- so as
# language surveys finish data collection, mark them done here rather than
# removing their cron wiring.
#
# Install (crontab -e), every 2 hours:
#   0 */2 * * * /path/to/02-Task/run_all_languages.sh >> /path/to/02-Task/update.log 2>&1
#
# Add a new language: see 02-Task/README.md's "Adding a language" checklist.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
MANIFEST="languages_status.csv"

tail -n +2 "$MANIFEST" | while IFS=, read -r language status; do
  status="$(echo "$status" | tr -d '[:space:]')"
  language="$(echo "$language" | tr -d '[:space:]')"
  [ -z "$language" ] && continue

  if [ "$status" = "done" ]; then
    echo "$(date): $language marked done, skipping"
    continue
  fi

  if [ ! -d "$language" ]; then
    echo "$(date): $language has no folder yet, skipping"
    continue
  fi

  echo "$(date): running $language"
  lib/run_update_and_push.sh "$language" || echo "$(date): $language FAILED (continuing to next language)"
done
