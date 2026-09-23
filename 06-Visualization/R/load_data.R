# Data-loading functions for the dashboard. All local-file-based (no
# live formr calls on dashboard load -- see DATA_MODE in app.R) so the
# dashboard loads fast and doesn't need OAuth credentials of its own.
#
# TARGET_N here must match select_words.R's own n_cutoff default (30) --
# it's the manuscript's "considered normed" cutoff per cue, so progress
# bars mean the same 30 this codebase already uses everywhere else.
TARGET_N <- 30

library(dplyr)

repo_root <- function() normalizePath(file.path(dirname(getwd()))) # 06-Visualization's parent

# Every language with a folder under 02-Task/, whether active or done --
# 02-Task/languages_status.csv is the source of truth for status.
load_languages <- function(root = repo_root()) {
  status <- read.csv(file.path(root, "02-Task/languages_status.csv"), stringsAsFactors = FALSE)
  status
}

# Per-word valid-response counts for one language, from the cleaned,
# non-answer-filtered output of 05-Data/Code/process_responses.R (every
# row there already passed is_nonanswer() -- see that pipeline's own
# README/comments) -- NOT word_n_summary.csv's n_total, which isn't
# auto-updated yet (see 02-Task/English/README.md). Falls back to all-
# zero counts if no processed file exists yet for this language, rather
# than erroring, so a language with no data yet still renders (just
# empty progress bars).
load_word_progress <- function(language, root = repo_root(), target_n = TARGET_N) {
  summary_path <- file.path(root, "02-Task", language, "word_n_summary.csv")
  cues <- read.csv(summary_path, stringsAsFactors = FALSE)$cue

  processed_dir <- file.path(root, "05-Data/Processed", language)
  processed_files <- if (dir.exists(processed_dir)) list.files(processed_dir, pattern = "^processed_.*\\.csv$", full.names = TRUE) else character(0)

  if (length(processed_files) == 0) {
    n_valid <- setNames(rep(0L, length(cues)), cues)
  } else {
    # Most recent processed file (by filename, which sorts chronologically
    # for real dated pulls; a single "_synthetic" file sorts fine too).
    latest <- processed_files[which.max(file.info(processed_files)$mtime)]
    processed <- read.csv(latest, stringsAsFactors = FALSE)
    counts <- processed %>% count(word, name = "n") %>% tibble::deframe()
    n_valid <- setNames(as.integer(counts[cues]), cues)
    n_valid[is.na(n_valid)] <- 0L
  }

  data.frame(
    cue = cues,
    n_valid = as.integer(n_valid),
    target_n = target_n,
    pct = pmin(as.integer(n_valid) / target_n, 1),
    stringsAsFactors = FALSE
  ) %>% arrange(cue)
}

# Participant codes + lab assignment. PLACEHOLDER -- the consent form
# that actually produces this data doesn't exist yet (per-participant
# lab_id + participant_code will come from it, pulled from formr the
# same way 02-Task/English/pull_results.R pulls survey results).
# TODO once that survey exists: replace this function's body with a
# formr pull (mirroring pull_results_core.R's pattern) against wherever
# consent data lands, keeping this same return shape (timestamp, lab_id,
# participant_code, language) so nothing downstream needs to change.
# For now, reads 05-Data/Raw/<Language>/consent_codes.csv if a real one
# exists, else falls back to the synthetic demo file so the dashboard
# has something to show.
load_consent_codes <- function(language, root = repo_root()) {
  cols <- c("timestamp", "lab_id", "participant_code", "language")
  real_path <- file.path(root, "05-Data/Raw", language, "consent_codes.csv")
  synthetic_path <- file.path(root, "05-Data/Synthetic", language, "consent_codes_synthetic.csv")

  path <- if (file.exists(real_path)) real_path else if (file.exists(synthetic_path)) synthetic_path else NA

  if (is.na(path)) {
    return(setNames(data.frame(matrix(nrow = 0, ncol = length(cols))), cols))
  }
  read.csv(path, stringsAsFactors = FALSE)[, cols]
}

load_all_consent_codes <- function(languages, root = repo_root()) {
  bind_rows(lapply(languages, load_consent_codes, root = root))
}

# One row per lab, participant counts by language plus a total.
summarize_by_lab <- function(consent_codes) {
  if (nrow(consent_codes) == 0) {
    return(data.frame(lab_id = character(0), n_participants = integer(0)))
  }
  consent_codes %>%
    count(lab_id, name = "n_participants") %>%
    arrange(desc(n_participants))
}

# Overall completion: sum of (capped-at-target valid responses) over
# (target * number of words), across every language passed in -- so a
# fully-normed word contributes 100%, an over-normed one still only
# counts as 100% (not more), matching what a researcher actually wants
# to know ("how close to done are we"), not raw response volume.
overall_completion <- function(languages, root = repo_root(), target_n = TARGET_N) {
  progress <- bind_rows(lapply(languages, function(l) load_word_progress(l, root, target_n)))
  if (nrow(progress) == 0) return(0)
  sum(pmin(progress$n_valid, target_n)) / (target_n * nrow(progress))
}
