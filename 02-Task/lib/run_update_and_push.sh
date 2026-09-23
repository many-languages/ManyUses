#!/usr/bin/env bash
# Shared across all languages -- do not copy this into a language folder.
# Per-language cron worker: called once per active language by
# run_all_languages.sh, e.g. `lib/run_update_and_push.sh English`. Run
# entirely on your own server.
#   1. pull_results.R (per-language: formr survey names, from
#      survey_parts.R) -- pulls raw formr results for each survey part into
#      05-Data/Raw/<Language>/ and logs the row counts. DELIBERATELY
#      SIMPLIFIED for now: does not update word_n_summary.csv (see
#      pull_results_core.R's header) -- real per-word cleaning is still
#      TODO, so word_n_summary.csv stays whatever it last was.
#   2. build_formr_xlsx.R (per-language: survey_parts.R again) -- weight-
#      samples all words for this cycle together, splits them across this
#      language's survey parts, and bakes them as literal text into each
#      part's survey (batch-level randomization -- selection happens here,
#      once per cycle, not per participant inside formr)
#   3. push_to_formr.R (per-language) -- pushes each part's rebuilt xlsx to
#      its live formr study (formr_api_upload_survey syncs an existing
#      study in place)
#   4. commit + push that language's word_n_summary.csv, every survey
#      part's xlsx, word_assignment_log.csv, and raw_pull_log.csv to GitHub
#      for version history/audit trail (raw response data itself is NOT
#      committed -- it lands in 05-Data/Raw/, which is gitignored)
#
# Why per-language build/push/pull scripts, not fully shared like
# select_words.R: each language may have a different number of formr
# survey "parts" (see build_formr_xlsx_core.R's header -- formr's own
# MySQL backend forces splitting large word-sets into multiple surveys),
# so each language's own survey_parts.R is the single source of truth for
# its survey names, sourced by all four per-language scripts.
#
# Requires FORMR_CLIENT_ID / FORMR_CLIENT_SECRET (OAuth2 API credentials,
# used by both pull_results.R and push_to_formr.R; see
# push_to_formr_core.R's header) set in this shell's environment.
# Credentials are shared across every language, not per-language -- see
# 02-Task/.env.example for the template; copy it to 02-Task/.env (gitignored)
# and fill in real values, or set these in the server user's own profile.

# Deliberately NOT `set -e`: if any one R step below fails partway through
# (e.g. build_formr_xlsx.R errors after pull_results.R already wrote a new
# raw_pull_log.csv row), the commit+push at the end must still run so
# whatever WAS produced reaches GitHub -- since this repo lives on the
# server, a log update that only exists in the server's local working
# copy and never gets pushed is as good as lost. Each step is best-effort;
# the script still exits non-zero at the end if anything failed, so
# run_all_languages.sh's per-language failure handling still sees it.
set -uo pipefail

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
if [ -f "$TASK_DIR/.env" ]; then
  source "$TASK_DIR/.env"
fi

cd "$LANG_DIR"

STEP_FAILED=0
Rscript pull_results.R || { echo "$(date): $LANGUAGE pull_results.R failed"; STEP_FAILED=1; }
Rscript build_formr_xlsx.R || { echo "$(date): $LANGUAGE build_formr_xlsx.R failed"; STEP_FAILED=1; }
Rscript push_to_formr.R || { echo "$(date): $LANGUAGE push_to_formr.R failed"; STEP_FAILED=1; }

# Always attempt to commit+push whatever exists on disk, regardless of
# which step(s) above failed -- see the note at the top of this file.
cd "$REPO_ROOT"
for f in "02-Task/$LANGUAGE"/*.xlsx "02-Task/$LANGUAGE/word_n_summary.csv" "02-Task/$LANGUAGE/word_assignment_log.csv" "02-Task/$LANGUAGE/raw_pull_log.csv"; do
  if [ -f "$f" ]; then
    git add "$f"
  fi
done
if ! git diff --cached --quiet; then
  git commit -m "Update $LANGUAGE word N summary and rebuild formr survey"
  git push
else
  echo "$(date): no change for $LANGUAGE, skipping commit"
fi

if [ "$STEP_FAILED" -eq 1 ]; then
  exit 1
fi
