# Per-language config for the shared pull_results() in
# ../lib/pull_results_core.R. Survey names come from survey_parts.R
# (shared with make_template.R / build_formr_xlsx.R / push_to_formr.R).
#
# DELIBERATELY SIMPLIFIED: does not update word_n_summary.csv yet. Just
# pulls raw formr results into 05-Data/Raw/English/ and logs the row
# counts to raw_pull_log.csv. See ../lib/pull_results_core.R's header for
# why.

source("survey_parts.R")
RAW_DIR <- "../../05-Data/Raw/English"

source("../lib/pull_results_core.R")
pull_results(RUN_NAME, PART_NAMES, RAW_DIR)
