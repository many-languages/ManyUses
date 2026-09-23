# Shared across all languages -- do not copy this into a language folder.
#
# DELIBERATELY SIMPLIFIED FOR NOW: matching each response row to which word
# it actually answered (since batch-level randomization means the word in
# slot wNN changes every rebuild cycle) requires joining formr's raw rows
# against that language's word_assignment_log.csv by timestamp -- real
# cleaning, not yet built. Until that exists, this step does NOT touch
# word_n_summary.csv. It only pulls the raw results, saves an untouched
# copy for later cleaning, and logs how many rows exist so far.
#
# formr_raw_results() (not formr_results()) is used deliberately: it skips
# formr's own value-coding/scale-aggregation post-processing, which isn't
# meaningful yet given no real per-word extraction exists.
#
# Requires FORMR_EMAIL / FORMR_PASSWORD as environment variables (see
# run_update_and_push.sh / 02-Task/.env.example).

library(formr)

pull_results <- function(survey_name, raw_dir, log_path = "raw_pull_log.csv") {
  formr_connect(
    email = Sys.getenv("FORMR_EMAIL"),
    password = Sys.getenv("FORMR_PASSWORD"),
    host = Sys.getenv("FORMR_HOST", unset = formr_last_host())
  )

  responses <- formr_raw_results(survey_name = survey_name)

  if (!dir.exists(raw_dir)) dir.create(raw_dir, recursive = TRUE)
  stamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  raw_path <- file.path(raw_dir, sprintf("%s_%s.csv", survey_name, stamp))
  write.csv(responses, raw_path, row.names = FALSE)

  log_entry <- data.frame(
    pulled_at = Sys.time(),
    survey_name = survey_name,
    n_rows = nrow(responses),
    raw_file = basename(raw_path)
  )
  write.table(
    log_entry, log_path,
    sep = ",", row.names = FALSE,
    col.names = !file.exists(log_path), append = file.exists(log_path)
  )

  cat(
    "Pulled", nrow(responses), "rows from", survey_name, "-> saved to", raw_path, "\n",
    "word_n_summary.csv NOT updated -- per-word cleaning still TODO.\n"
  )

  invisible(responses)
}
