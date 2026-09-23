# Per-language config for the shared build_formr_xlsx() in
# ../lib/build_formr_xlsx_core.R. Survey names come from survey_parts.R
# (shared with make_template.R / push_to_formr.R / pull_results.R).

source("survey_parts.R")

source("../lib/select_words.R")
source("../lib/build_formr_xlsx_core.R")

build_formr_xlsx(PART_NAMES, blocks_per_part = BLOCKS_PER_PART, n_cutoff = 30)
