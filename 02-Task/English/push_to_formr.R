# Per-language config for the shared push_to_formr() in
# ../lib/push_to_formr_core.R. Survey names come from survey_parts.R
# (shared with make_template.R / build_formr_xlsx.R / pull_results.R).

source("survey_parts.R")

source("../lib/push_to_formr_core.R")
push_to_formr(paste0(PART_NAMES, ".xlsx"))
