# Single source of truth for this language's formr survey names, sourced
# by make_template.R, build_formr_xlsx.R, push_to_formr.R, and
# pull_results.R -- so the same names never have to be typed four times
# and risk drifting out of sync with each other or with formr itself.
#
# Split into 3 parts of 10 words each (not one 30-word survey) because a
# single ~390-item survey hit formr's own MySQL row-size limit on import
# ("Row size too large (> 8126)") -- see
# ../lib/build_formr_xlsx_core.R's header for the full explanation.
# These names must exactly match the survey names created in formr
# (formr derives the survey name from the uploaded file's name).

RUN_NAME <- "manyuses-english" # documentation only; not used in any formr API call
PART_NAMES <- c("English_Word_Ratings", "English_Word_Ratings_2", "English_Word_Ratings_3")
BLOCKS_PER_PART <- 10
