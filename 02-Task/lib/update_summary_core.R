# Shared across all languages -- do not copy this into a language folder.
# The generic recompute logic behind every language's update_summary.R:
# pulls live response counts from a formr study, merges them onto that
# language's immutable n_previous seed, and writes word_n_summary.csv.
#
# THIS IS A SKELETON, not tested against a real formr study: the exact
# results-table shape (one row per participant-cue response, with a `cue`
# column) is unverified. Confirm against the real survey's results table
# once it exists, and adjust the aggregation below if the actual schema
# differs (e.g. one column per possible cue instead of long format).
#
# Requires FORMR_EMAIL / FORMR_PASSWORD as environment variables on the
# server (never committed to this repo — see run_update_and_push.sh).

library(formr)

update_summary <- function(study_name, results_table,
                            seed_path = "word_n_seed.csv",
                            out_path = "word_n_summary.csv",
                            cutoff = 30) {
  formr_connect(
    email = Sys.getenv("FORMR_EMAIL"),
    password = Sys.getenv("FORMR_PASSWORD")
  )

  responses <- formr_results(study_name, results_table)

  # One row per (participant, cue) response, assumed long format with a
  # `cue` column identifying which word was shown.
  new_counts <- aggregate(
    list(n_new = responses$cue),
    by = list(cue = responses$cue),
    FUN = length
  )

  seed <- read.csv(seed_path, stringsAsFactors = FALSE) # the original n_previous snapshot, kept immutable

  summary <- merge(seed, new_counts, by = "cue", all.x = TRUE)
  summary$n_new[is.na(summary$n_new)] <- 0
  summary$n_total <- summary$n_previous + summary$n_new
  summary$needs_norming <- ifelse(summary$n_total < cutoff, "Yes", "No")

  write.csv(
    summary[, c("cue", "n_total", "needs_norming")],
    out_path,
    row.names = FALSE
  )

  cat(
    sum(summary$needs_norming == "Yes"), "of", nrow(summary),
    "cues still need norming.\n"
  )

  invisible(summary)
}
