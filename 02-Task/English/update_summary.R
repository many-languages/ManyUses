# Per-language config for the shared update_summary() in
# ../lib/update_summary_core.R. This is the one real piece of per-language
# info this whole step needs -- everything else is generic.
#
# TODO: STUDY_NAME / RESULTS_TABLE are placeholders until the actual
# English survey exists in formr -- fill in once known (see
# ../lib/update_summary_core.R's header for the results-table shape this
# assumes).

STUDY_NAME <- "many_uses_english"
RESULTS_TABLE <- "norming_task"

source("../lib/update_summary_core.R")
update_summary(STUDY_NAME, RESULTS_TABLE)
