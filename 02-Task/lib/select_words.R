# Selects the cue words for one build_formr_xlsx.R rebuild (batch-level
# randomization: called once per cron cycle, server-side -- not per
# participant). Shared across all languages -- do not copy this into a
# language folder; build_formr_xlsx.R sources it from here directly.
#
# summary: data.frame with columns cue, n_total, needs_norming, read from
#   each language's word_n_summary.csv (not yet updated automatically by
#   pull_results.R -- see pull_results_core.R's header)
# n_cutoff: minimum responses a cue needs before it's considered normed
# n_select: how many cues to show this participant (manuscript: 30)
# priority_cues: optional vector of cues (e.g. from priority_words.R's
#   load_priority_words()) to draw from first -- the manuscript's 500-word
#   cross-linguistic overlap component. Undersampled priority cues fill as
#   many of the n_select slots as they can (still inverse-N weighted
#   within that set, not a fixed order); only once they're exhausted --
#   either fully normed or fewer than n_select remain -- does selection
#   fall back to the general pool for the rest.
#
# Undersampled cues are prioritized via inverse-N weighting (weight =
# 1 / (n_total + 1)) rather than a hard sort, so selection stays random
# (manuscript: "30 randomly selected nouns, with the constraint that
# undersampled cues will be prioritized") instead of always handing out the
# same lowest-N words in the same order.
select_words <- function(summary, n_cutoff = 30, n_select = 30, priority_cues = NULL) {
  pool <- summary[summary$n_total < n_cutoff, ]

  if (nrow(pool) == 0) {
    stop("No cues below n_cutoff = ", n_cutoff, " remain — norming complete.")
  }

  weighted_draw <- function(sub_pool, n) {
    n <- min(n, nrow(sub_pool))
    if (n == 0) return(character(0))
    weights <- 1 / (sub_pool$n_total + 1)
    sample(sub_pool$cue, size = n, prob = weights)
  }

  if (!is.null(priority_cues)) {
    priority_pool <- pool[pool$cue %in% priority_cues, ]
    general_pool <- pool[!pool$cue %in% priority_cues, ]
  } else {
    priority_pool <- pool[0, ]
    general_pool <- pool
  }

  chosen <- weighted_draw(priority_pool, n_select)
  chosen <- c(chosen, weighted_draw(general_pool, n_select - length(chosen)))

  if (length(chosen) < n_select) {
    warning(
      "Only ", length(chosen), " undersampled cues remain, fewer than ",
      "n_select = ", n_select, "; returning all of them."
    )
  }

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
