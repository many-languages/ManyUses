#!/usr/bin/env bash
# Shared across all languages -- do not copy this into a language folder.
# Per-language cron worker: called once per active language by
# run_all_languages.sh, e.g. `lib/run_update_and_push.sh English`. Run
# entirely on your own server.
#   1. recompute word_n_summary.csv from live formr response counts
#      (that language's own update_summary.R -- the one per-language part
#      of this whole cycle, since it needs that language's formr study
#      name/results table)
#   2. rebuild word_ratings.xlsx: weight-sample 30 words favoring the
#      most undersampled and bake them as literal text into the survey
#      (batch-level randomization -- selection happens here, once per
#      cycle, not per participant inside formr)
#   3. push the rebuilt xlsx to the live formr study (formr_api_upload_survey
#      syncs an existing study in place)
#   4. commit + push that language's word_n_summary.csv, word_ratings.xlsx,
#      and word_assignment_log.csv to GitHub for version history/audit trail
#
# Requires FORMR_EMAIL / FORMR_PASSWORD set in this shell's environment
# (e.g. sourced from a .env file below, or the server user's own profile —
# never commit credentials to this repo).

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

cd "$LANG_DIR"

# Uncomment and point at a local, untracked credentials file if you'd rather
# not rely on the server user's shell environment already having these set:
# source .env

Rscript update_summary.R
Rscript "$LIB_DIR/build_formr_xlsx.R"
Rscript "$LIB_DIR/push_to_formr.R"

cd "$REPO_ROOT"
git add "02-Task/$LANGUAGE/word_n_summary.csv" "02-Task/$LANGUAGE/word_ratings.xlsx" "02-Task/$LANGUAGE/word_assignment_log.csv"
if ! git diff --cached --quiet; then
  git commit -m "Update $LANGUAGE word N summary and rebuild formr survey"
  git push
else
  echo "$(date): no change for $LANGUAGE, skipping commit"
fi
