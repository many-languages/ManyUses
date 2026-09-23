# Synthetic data for developing the data-cleaning/processing pipeline
# before real participant data exists. Matches the exact column structure
# pull_results.R actually pulls from formr (see 05-Data/Raw/English/*.csv
# for the real shape) -- session, created, current_position,
# general_instructions (part 1 only), then per word slot w01..w10:
# {slot}_prompt, {slot}_use_01..05, {slot}_more, and {slot}_use_06..10
# only for sessions that asked for more uses.
#
# Response text is sampled from the old Affordance Norms project's
# already-cleaned response pool (02-Collector/.../Affordance Norms
# Final.csv) -- that study asked one free-text box per cue, later split
# into one response per row; this study asks for one response per box
# from the start, so that same pool of short, plausible-looking
# word/phrase responses is a good stand-in for realistic (if not
# semantically matched) synthetic answers, in place of obviously-fake
# placeholder text like "thank the formr monkey".
#
# A share of responses are deliberately junk, patterned after what the
# old project's own cleaning scripts (4 Example Cleaning Code/clean
# affordance norms.R, Remove idk.R) actually had to handle: "idk"/"not
# sure"/"no idea" style non-answers (with the same realistic typos and
# stray whitespace/tabs seen in Remove idk.R's literal match list, which
# is exactly why this is generated instead of copied verbatim -- a
# cleaning script tested only against that literal list would silently
# pass), bare punctuation, off-topic junk, and algorithmically-misspelled
# real words (character swap/drop) -- so the new pipeline's cleaning
# script has real messiness to prove itself against, not just clean text.
#
# Output: 05-Data/Synthetic/English/<Survey>_synthetic.csv, one file per
# survey part, mirroring 05-Data/Raw/English/'s naming so the processing
# script can point at either interchangeably.

library(dplyr)

set.seed(20260923)

REPO_ROOT <- "/Users/erinbuchanan/GitHub/Research/2_projects/ManyUses"
N_SESSIONS <- 25

response_pool <- read.csv(
  file.path(REPO_ROOT, "Affordance_Norms_OSF-main/1 Norm Set/Affordance Norms Final.csv"),
  stringsAsFactors = FALSE
)$response
response_pool <- unique(trimws(response_pool))
response_pool <- response_pool[nzchar(response_pool)]

# "Don't know" / non-answer junk -- patterned after (not copied from)
# Remove idk.R's literal match list: same categories and same realistic
# noise (typos, stray/leading/trailing whitespace, tabs, mixed case), so
# a cleaning script has to actually generalize, not just match a list.
idk_core <- c(
  "idk", "i don't know", "i dont know", "i dont knwo", "dont know",
  "not sure", "im not sure", "i'm not sure", "not sure what this is",
  "no idea", "no idea what this is", "no clue", "unfamiliar with word",
  "don't know what this is", "i don't know what that is"
)
idk_noise <- function(x) {
  x <- sample(c(x, toupper(x), tools::toTitleCase(x)), 1)
  wrap <- sample(c("%s", " %s", "%s ", " %s ", "\t%s", "%s\t"), 1)
  sprintf(wrap, x)
}
junk_idk <- function(n) vapply(sample(idk_core, n, replace = TRUE), idk_noise, character(1))

junk_punct <- c("?", "??", ".", "-", "n/a", "na", "", " ")
junk_offtopic <- c("lol", "wtf is this", "nothing", "asdf", "asdfgh", "zzz", "no comment")

# Character-swap/drop typo of a real sampled word -- exercises the spell-
# check step the way real typed responses do, rather than always giving
# already-clean text.
misspell <- function(word) {
  if (nchar(word) < 3) return(word)
  chars <- strsplit(word, "")[[1]]
  op <- sample(c("swap", "drop"), 1)
  i <- sample(seq_len(length(chars) - 1), 1)
  if (op == "swap") {
    chars[c(i, i + 1)] <- chars[c(i + 1, i)]
  } else {
    chars <- chars[-i]
  }
  paste(chars, collapse = "")
}

JUNK_PROB <- 0.15 # share of individual use-box responses that are junk

sample_responses <- function(n) {
  clean <- sample(response_pool, n, replace = TRUE)
  is_junk <- runif(n) < JUNK_PROB
  if (any(is_junk)) {
    junk_type <- sample(c("idk", "punct", "offtopic", "misspelled"), sum(is_junk),
                         replace = TRUE, prob = c(0.5, 0.2, 0.15, 0.15))
    clean[is_junk] <- vapply(seq_along(junk_type), function(k) {
      switch(junk_type[k],
             idk = junk_idk(1),
             punct = sample(junk_punct, 1),
             offtopic = sample(junk_offtopic, 1),
             misspelled = misspell(clean[is_junk][k]))
    }, character(1))
  }
  clean
}

# Current slot -> word assignment, from the most recent build for each
# survey part (word_assignment_log.csv logs every rebuild; take the last
# row per survey/slot so this matches whatever's actually live).
log <- read.csv(file.path(REPO_ROOT, "02-Task/English/word_assignment_log.csv"), stringsAsFactors = FALSE)
latest_assignment <- log %>%
  group_by(survey, slot) %>%
  slice_tail(n = 1) %>%
  ungroup()

part_names <- unique(latest_assignment$survey)

random_session_id <- function() {
  paste0(sample(c(letters, LETTERS, 0:9), 64, replace = TRUE), collapse = "")
}

# One session id (and a small per-session offset) shared across all three
# part files, to simulate real chained-run behavior where the same
# participant appears once per part.
session_ids <- replicate(N_SESSIONS, random_session_id())
base_time <- as.POSIXct("2026-09-23 09:00:00", tz = "UTC")

for (survey in part_names) {
  slots <- latest_assignment %>% filter(survey == !!survey) %>% arrange(slot)
  slot_words <- setNames(slots$word, slots$slot)
  slot_names <- names(slot_words)

  rows <- vector("list", N_SESSIONS)

  for (i in seq_len(N_SESSIONS)) {
    row <- list(
      session = session_ids[i],
      created = format(base_time + i * 300 + which(part_names == survey) * 60, "%Y-%m-%d %H:%M:%S"),
      current_position = length(slot_names)
    )
    if (survey == part_names[1]) {
      row$general_instructions <- 1
    }

    for (slot in slot_names) {
      row[[paste0(slot, "_prompt")]] <- 1

      wants_more <- sample(c(TRUE, FALSE), 1, prob = c(0.3, 0.7))
      n_uses <- if (wants_more) sample(6:10, 1) else sample(2:5, 1)

      uses <- sample_responses(n_uses)
      for (u in 1:5) {
        row[[sprintf("%s_use_%02d", slot, u)]] <- if (u <= n_uses) uses[u] else NA
      }
      row[[paste0(slot, "_more")]] <- if (wants_more) 2 else 1
      if (wants_more) {
        for (u in 6:10) {
          row[[sprintf("%s_use_%02d", slot, u)]] <- if (u <= n_uses) uses[u] else NA
        }
      }
    }
    rows[[i]] <- as.data.frame(row, stringsAsFactors = FALSE)
  }

  df <- bind_rows(rows)
  out_path <- file.path(REPO_ROOT, "05-Data/Synthetic/English", paste0(survey, "_synthetic.csv"))
  write.csv(df, out_path, row.names = FALSE, na = "NA")
  cat("Wrote", nrow(df), "synthetic rows to", out_path, "\n")
}
