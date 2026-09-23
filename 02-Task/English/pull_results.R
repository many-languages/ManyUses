# Per-language config for the shared pull_results() in
# ../lib/pull_results_core.R. formr_raw_results() (and formr_results())
# take a single survey/item-table name -- RUN_NAME ("manyuses-english")
# is not passed to that call at all; kept here only as documentation of
# which formr run this survey lives under.
#
# DELIBERATELY SIMPLIFIED: does not update word_n_summary.csv yet. Just
# pulls raw formr results into 05-Data/Raw/English/ and logs the row count
# to raw_pull_log.csv. See ../lib/pull_results_core.R's header for why.

RUN_NAME <- "manyuses-english"          # documentation only; not used in the pull call
SURVEY_NAME <- "English_Word_Ratings"   # this is what formr_raw_results() actually takes
RAW_DIR <- "../../05-Data/Raw/English"

source("../lib/pull_results_core.R")
pull_results(SURVEY_NAME, RAW_DIR)
