# Selects the cue words for one build_formr_xlsx.R rebuild (batch-level
# randomization: called once per cron cycle, server-side -- not per
# participant). Shared across all languages -- do not copy this into a
# language folder; build_formr_xlsx.R sources it from here directly.
#
# summary: data.frame with columns cue, n_total, needs_norming (as written by
#   each language's update_summary.R / word_n_summary.csv)
# n_cutoff: minimum responses a cue needs before it's considered normed
# n_select: how many cues to show this participant (manuscript: 30)
#
# Undersampled cues are prioritized via inverse-N weighting (weight =
# 1 / (n_total + 1)) rather than a hard sort, so selection stays random
# (manuscript: "30 randomly selected nouns, with the constraint that
# undersampled cues will be prioritized") instead of always handing out the
# same lowest-N words in the same order.
select_words <- function(summary, n_cutoff = 30, n_select = 30) {
  pool <- summary[summary$n_total < n_cutoff, ]

  if (nrow(pool) == 0) {
    stop("No cues below n_cutoff = ", n_cutoff, " remain — norming complete.")
  }
  if (nrow(pool) < n_select) {
    warning(
      "Only ", nrow(pool), " undersampled cues remain, fewer than ",
      "n_select = ", n_select, "; returning all of them."
    )
    n_select <- nrow(pool)
  }

  weights <- 1 / (pool$n_total + 1)
  chosen <- sample(pool$cue, size = n_select, prob = weights)

  sample(chosen) # re-shuffle presentation order
}

if (sys.nframe() == 0) {
  # Local smoke test against a real language's data, e.g.:
  #   Rscript select_words.R ../English/word_n_summary.csv
  summary_path <- commandArgs(trailingOnly = TRUE)[1]
  if (is.na(summary_path)) stop("Usage: Rscript select_words.R <path/to/word_n_summary.csv>")
  summary <- read.csv(summary_path, stringsAsFactors = FALSE)
  words <- select_words(summary, n_cutoff = 30, n_select = 30)
  cat(length(words), "words selected:\n")
  print(words)
}
