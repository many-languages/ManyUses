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
# Uses the same OAuth2 REST session as push_to_formr_core.R (see that
# file's header) -- formr_api_fetch_results(), not formr_api_results(),
# is used deliberately: it skips formr's own recognise/reverse/scale-
# aggregation post-processing, which isn't meaningful yet given no real
# per-word extraction exists.
#
# Requires FORMR_CLIENT_ID / FORMR_CLIENT_SECRET as environment variables
# (see run_update_and_push.sh / 02-Task/.env.example) -- the credential
# needs the data:read scope in addition to survey:write.

library(formr)

# run_name: the formr run all of this language's survey parts belong to
# (survey_parts.R's RUN_NAME) -- formr_api_fetch_results() is run-scoped,
# not survey-scoped, so results for a given survey are fetched by asking
# for that run and filtering to one survey via `surveys`.
# survey_names: a vector -- a language may have more than one formr survey
# (see build_formr_xlsx_core.R's header for why: formr's MySQL backend has
# a row-size limit that forces splitting a large word-set into multiple
# surveys/parts). Pulls each one in turn into its own timestamped raw file.
pull_results <- function(run_name, survey_names, raw_dir, log_path = "raw_pull_log.csv") {
  formr_api_authenticate(
    client_id = Sys.getenv("FORMR_CLIENT_ID"),
    client_secret = Sys.getenv("FORMR_CLIENT_SECRET"),
    host = Sys.getenv("FORMR_HOST", unset = formr_last_host())
  )

  if (!dir.exists(raw_dir)) dir.create(raw_dir, recursive = TRUE)
  stamp <- format(Sys.time(), "%Y%m%d_%H%M%S")

  log_rows <- list()

  for (survey_name in survey_names) {
    result <- formr_api_fetch_results(run_name = run_name, surveys = survey_name, join = FALSE)
    # A single-survey filter normally comes back as one data.frame; fall
    # back to picking the matching element if formr ever returns a list
    # (e.g. alongside a "shuffles" element).
    responses <- if (is.data.frame(result)) {
      result
    } else if (survey_name %in% names(result)) {
      result[[survey_name]]
    } else {
      result[[1]]
    }

    raw_path <- file.path(raw_dir, sprintf("%s_%s.csv", survey_name, stamp))
    write.csv(responses, raw_path, row.names = FALSE)

    log_rows[[survey_name]] <- data.frame(
      pulled_at = Sys.time(),
      survey_name = survey_name,
      n_rows = nrow(responses),
      raw_file = basename(raw_path)
    )

    cat("Pulled", nrow(responses), "rows from", survey_name, "-> saved to", raw_path, "\n")
  }

  log_entry <- do.call(rbind, log_rows)
  write.table(
    log_entry, log_path,
    sep = ",", row.names = FALSE,
    col.names = !file.exists(log_path), append = file.exists(log_path)
  )

  cat("word_n_summary.csv NOT updated -- per-word cleaning still TODO.\n")

  invisible(log_entry)
}
