# Shared across all languages -- do not copy this into a language folder
# (mirrors 02-Task/lib's pattern: shared logic in Code/lib, thin per-run
# config here).
#
# End-to-end: wide per-part pulls -> long format resolved to the actual
# word shown (lib/reshape_long.R) -> non-answers dropped
# (lib/detect_nonanswer.R) -> spell-corrected -> lemmatized/POS-tagged
# (lib/clean_text.R) -> one processed long-format CSV.
#
# Usage: Rscript process_responses.R <raw_dir> <language> <assignment_log_path> <out_path>
# e.g. against synthetic data:
#   Rscript process_responses.R ../Synthetic/English English ../../02-Task/English/word_assignment_log.csv ../Processed/English/processed_synthetic.csv
# against a real pull:
#   Rscript process_responses.R ../Raw/English English ../../02-Task/English/word_assignment_log.csv ../Processed/English/processed_<date>.csv

library(dplyr)

source("lib/reshape_long.R")
source("lib/detect_nonanswer.R")
source("lib/clean_text.R")

args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 4) {
  stop("Usage: Rscript process_responses.R <raw_dir> <language> <assignment_log_path> <out_path>")
}
raw_dir <- args[1]
language <- args[2]
assignment_log_path <- args[3]
out_path <- args[4]

assignment_log <- read.csv(assignment_log_path, stringsAsFactors = FALSE)

# One file per survey part; for a real Raw/ pull directory (which
# accumulates a timestamped file per pull_results.R run -- see
# raw_pull_log.csv) this takes the most recent pull per survey.
files <- list.files(raw_dir, pattern = "\\.csv$", full.names = TRUE)
survey_of <- function(path) sub("(_\\d{8}_\\d{6})?(_synthetic)?\\.csv$", "", basename(path))
files_df <- data.frame(path = files, survey = survey_of(files), stringsAsFactors = FALSE)
latest_files <- files_df %>% group_by(survey) %>% slice_max(path, n = 1) %>% ungroup()

long_all <- lapply(seq_len(nrow(latest_files)), function(i) {
  wide <- read.csv(latest_files$path[i], stringsAsFactors = FALSE, na.strings = "NA")
  reshape_long(wide, latest_files$survey[i], assignment_log)
})
long_all <- bind_rows(long_all)

cat("Reshaped to", nrow(long_all), "responses across", n_distinct(long_all$session), "sessions,",
    n_distinct(long_all$word), "words.\n")

long_all$response_clean <- tolower(trimws(long_all$response))
long_all$is_nonanswer <- is_nonanswer(long_all$response_clean)
cat(sum(long_all$is_nonanswer), "non-answers flagged and dropped (",
    round(100 * mean(long_all$is_nonanswer), 1), "%).\n")

answered <- long_all[!long_all$is_nonanswer, ]

dir.create(dirname(out_path), showWarnings = FALSE, recursive = TRUE)
review_path <- file.path(dirname(out_path), paste0("spell_review_", language, ".csv"))
correction_map <- spell_correct(answered$response_clean, review_path = review_path)
answered$response_corrected <- correction_map[answered$response_clean]

pos <- lemmatize_pos(answered$response_corrected)
# udpipe can split one response into multiple tokens (e.g. "hula hoop");
# collapse back to one row per response with lemma/POS concatenated, so
# the output stays at the response level like the input.
pos_by_doc <- pos %>%
  group_by(doc_id) %>%
  summarise(lemma = paste(lemma, collapse = " "), upos = paste(upos, collapse = " "), .groups = "drop") %>%
  arrange(as.integer(doc_id))
answered$lemma <- pos_by_doc$lemma
answered$upos <- pos_by_doc$upos

out <- answered %>% select(session, survey, slot, word, use_number, response, response_corrected, lemma, upos)
dir.create(dirname(out_path), showWarnings = FALSE, recursive = TRUE)
write.csv(out, out_path, row.names = FALSE)
cat("Wrote", nrow(out), "processed responses to", out_path, "\n")
