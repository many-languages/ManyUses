# Per-language config for the shared pull_results() in
# ../lib/pull_results_core.R. Survey names come from survey_parts.R
# (shared with make_template.R / build_formr_xlsx.R / push_to_formr.R).
#
# Pulls raw formr results into 05-Data/Raw/English/ and logs the row counts
# to raw_pull_log.csv. word_n_summary.csv is updated by update_word_counts.R
# after 05-Data/Code/process_responses.R cleans this pull (see
# ../lib/run_update_and_push.sh).

source("survey_parts.R")
RAW_DIR <- "../../05-Data/Raw/English"

source("../lib/pull_results_core.R")
pull_results(RUN_NAME, PART_NAMES, RAW_DIR)
