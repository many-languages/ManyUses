# Per-language config for the shared update_word_counts() in
# ../lib/update_word_counts_core.R. Run after pull_results.R and
# 05-Data/Code/process_responses.R (see ../lib/run_update_and_push.sh),
# before build_formr_xlsx.R.

source("../lib/update_word_counts_core.R")
update_word_counts(
  seed_path = "word_n_seed.csv",
  processed_path = "../../05-Data/Processed/English/processed_latest.csv",
  summary_path = "word_n_summary.csv"
)
