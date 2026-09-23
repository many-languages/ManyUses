#!/usr/bin/env bash
# Shared across all languages -- do not copy this into a language folder.
# Per-language cron worker: called once per active language by
# run_all_languages.sh, e.g. `lib/run_update_and_push.sh English`. Run
# entirely on your own server.
#   1. pull_results.R (per-language: formr survey name) -- pulls raw formr
#      results into 05-Data/Raw/<Language>/ and logs the row count.
#      DELIBERATELY SIMPLIFIED for now: does not update word_n_summary.csv
#      (see pull_results_core.R's header) -- real per-word cleaning is
#      still TODO, so word_n_summary.csv stays whatever it last was.
#   2. rebuild word_ratings.xlsx: weight-sample 30 words favoring the
#      most undersampled and bake them as literal text into the survey
#      (batch-level randomization -- selection happens here, once per
#      cycle, not per participant inside formr)
#   3. push the rebuilt xlsx to the live formr study (formr_api_upload_survey
#      syncs an existing study in place)
#   4. commit + push that language's word_n_summary.csv, word_ratings.xlsx,
#      word_assignment_log.csv, and raw_pull_log.csv to GitHub for version
#      history/audit trail (raw response data itself is NOT committed --
#      it lands in 05-Data/Raw/, which is gitignored)
#
# Requires FORMR_EMAIL / FORMR_PASSWORD set in this shell's environment.
# Credentials are shared across every language, not per-language -- see
# 02-Task/.env.example for the template; copy it to 02-Task/.env (gitignored)
# and fill in real values, or set these in the server user's own profile.

set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: run_update_and_push.sh <LanguageFolderName>" >&2
  exit 1
fi
LANGUAGE="$1"

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TASK_DIR="$(dirname "$LIB_DIR")"          # 02-Task/
REPO_ROOT="$(dirname "$TASK_DIR")"
LANG_DIR="$TASK_DIR/$LANGUAGE"

if [ ! -d "$LANG_DIR" ]; then
  echo "No such language folder: $LANG_DIR" >&2
  exit 1
fi

# Shared across every language -- see 02-Task/.env.example.
[ -f "$TASK_DIR/.env" ] && source "$TASK_DIR/.env"

cd "$LANG_DIR"

Rscript pull_results.R
Rscript "$LIB_DIR/build_formr_xlsx.R"
Rscript "$LIB_DIR/push_to_formr.R"

cd "$REPO_ROOT"
for f in word_n_summary.csv word_ratings.xlsx word_assignment_log.csv raw_pull_log.csv; do
  if [ -f "02-Task/$LANGUAGE/$f" ]; then
    git add "02-Task/$LANGUAGE/$f"
  fi
done
if ! git diff --cached --quiet; then
  git commit -m "Update $LANGUAGE word N summary and rebuild formr survey"
  git push
else
  echo "$(date): no change for $LANGUAGE, skipping commit"
fi
