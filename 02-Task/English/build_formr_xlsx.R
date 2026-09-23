# Per-language config for the shared build_formr_xlsx() in
# ../lib/build_formr_xlsx_core.R. Survey names come from survey_parts.R
# (shared with make_template.R / push_to_formr.R / pull_results.R).

source("survey_parts.R")

source("../lib/select_words.R")
source("../lib/priority_words.R")
source("../lib/build_formr_xlsx_core.R")

# Manuscript's 500-word cross-linguistic overlap component -- see
# ../lib/priority_words.R's header. English's cue words ARE the gloss
# words shared_core_top500.csv is built around, so this is exactly that
# column, unmodified (unlike other languages, whose priority set is only
# as large as their own translation coverage of those 500 concepts).
priority_cues <- load_priority_words("../../01-Stimuli/shared_core_top500.csv", "English")

build_formr_xlsx(PART_NAMES, blocks_per_part = BLOCKS_PER_PART, n_cutoff = 30,
                  priority_cues = priority_cues)
