# Shared across all languages -- do not copy this into a language folder.
#
# Turns one survey part's wide pull (session x {slot}_use_01..10 columns)
# into long format (one row per session x word x use-slot-number x
# response), resolving each response to the actual word it answered.
#
# This is the "real per-word cleaning" piece flagged as TODO in
# 02-Task/lib/pull_results_core.R's header: batch-level randomization
# means slot w01's word changes every rebuild cycle, so a response can't
# be matched to its word by slot name alone -- it has to be joined
# against word_assignment_log.csv by timestamp, taking whichever
# assignment was most recently built before the session started
# (assignments are effective from their build time until superseded by
# the next rebuild).

library(dplyr)
library(tidyr)

# assignment_log: word_assignment_log.csv, read with stringsAsFactors=FALSE
# and built_at parsed as POSIXct.
resolve_word <- function(survey, slot, created, assignment_log) {
  candidates <- assignment_log[
    assignment_log$survey == survey & assignment_log$slot == slot & assignment_log$built_at <= created,
  ]
  if (nrow(candidates) == 0) return(NA_character_)
  candidates$word[which.max(candidates$built_at)]
}

# wide: one survey part's raw/synthetic pull (see 05-Data/Raw/English/ or
# 05-Data/Synthetic/English/ for the real shape).
# survey: this part's formr survey name (must match word_assignment_log's
# survey column, e.g. "English_Word_Ratings").
# assignment_log: full word_assignment_log.csv (all parts, all rebuilds).
reshape_long <- function(wide, survey, assignment_log) {
  assignment_log$built_at <- as.POSIXct(assignment_log$built_at)
  wide$created <- as.POSIXct(wide$created)

  slots <- unique(sub("_use_.*$", "", grep("_use_\\d+$", names(wide), value = TRUE)))

  long <- lapply(slots, function(slot) {
    use_cols <- grep(paste0("^", slot, "_use_\\d+$"), names(wide), value = TRUE)
    df <- wide[, c("session", "created", use_cols)]
    df <- pivot_longer(df, cols = all_of(use_cols), names_to = "use_slot", values_to = "response")
    df$use_number <- as.integer(sub(".*_use_", "", df$use_slot))
    df$slot <- slot
    df$response <- trimws(df$response)
    df[!is.na(df$response) & nzchar(df$response), c("session", "created", "slot", "use_number", "response")]
  })
  long <- bind_rows(long)

  long$word <- mapply(resolve_word, survey, long$slot, long$created,
                       MoreArgs = list(assignment_log = assignment_log))
  long$survey <- survey
  long[, c("session", "survey", "slot", "word", "use_number", "response")]
}
