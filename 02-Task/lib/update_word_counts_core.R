# Shared across all languages -- do not copy this into a language folder.
#
# Recomputes a language's word_n_summary.csv from its immutable seed
# (word_n_seed.csv: each cue's n_previous, from Maxwell et al. 2024 /
# Pexman et al. 2019) plus the number of NEW participants who gave at
# least one valid response to that cue, taken from the cleaned output of
# 05-Data/Code/process_responses.R (every row in it already passed
# is_nonanswer(), so a participant who only skipped/"don't know"-ed a cue
# does not count toward it).
#
#   n_total = n_previous + (distinct sessions with >= 1 valid response to the cue)
#
# "n" is participants per cue, not individual uses, matching how
# Maxwell et al. (2024) counted n and the manuscript's 30-participants-
# per-cue criterion.
#
# Recomputed from scratch from the seed every run (never incremented from
# the previous word_n_summary.csv), because each pull_results.R run
# re-downloads ALL responses so far -- incrementing would double-count.
# This is what select_words.R's inverse-N weighting and n_cutoff read, so
# it must run after pull + process_responses.R and before
# build_formr_xlsx.R (see run_update_and_push.sh).
#
# Cues are matched case-insensitively. Processed rows for words not in
# the seed are ignored with a warning (e.g. a word assigned from an old
# placeholder template).

update_word_counts <- function(seed_path, processed_path, summary_path, n_cutoff = 30) {
  seed <- read.csv(seed_path, stringsAsFactors = FALSE)
  seed$key <- tolower(trimws(seed$cue))

  n_new <- setNames(integer(0), character(0))
  if (file.exists(processed_path)) {
    processed <- read.csv(processed_path, stringsAsFactors = FALSE)
    processed <- processed[!is.na(processed$word) & nzchar(processed$word), ]
    processed$key <- tolower(trimws(processed$word))
    unknown <- setdiff(unique(processed$key), seed$key)
    if (length(unknown)) {
      warning(length(unknown), " processed word(s) not in the seed list, ignored: ",
              paste(head(unknown, 5), collapse = ", "), if (length(unknown) > 5) ", ...")
    }
    per_cue <- unique(processed[processed$key %in% seed$key, c("session", "key")])
    n_new <- table(per_cue$key)
  } else {
    message("No processed file at ", processed_path, " -- word_n_summary.csv = seed only.")
  }

  new_counts <- as.integer(n_new[seed$key])
  new_counts[is.na(new_counts)] <- 0L

  out <- data.frame(
    cue = seed$cue,
    n_total = seed$n_previous + new_counts,
    needs_norming = ifelse(seed$n_previous + new_counts < n_cutoff, "Yes", "No"),
    stringsAsFactors = FALSE
  )
  write.csv(out, summary_path, row.names = FALSE)
  cat(sprintf("Wrote %s: %d cues, %d new participant-cue responses counted, %d cues still below %d.\n",
              summary_path, nrow(out), sum(new_counts), sum(out$n_total < n_cutoff), n_cutoff))
  invisible(out)
}
