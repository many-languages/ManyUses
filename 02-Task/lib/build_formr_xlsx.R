# Builds word_ratings.xlsx (the file pushed to formr) from
# word_ratings_template.xlsx (pristine, 30 placeholder hardcoded words —
# never edit this one, always regenerate FROM it, so rebuilds stay idempotent).
#
# Batch-level randomization: word selection happens HERE, once per rebuild,
# server-side — not per participant inside formr. Each cron cycle
# (run_update_and_push.sh) weight-samples N_BLOCKS words favoring the most
# undersampled, bakes them as literal text directly into the block prompts,
# and pushes the result to formr. Every participant who takes the survey
# between one push and the next sees that same word set; the next push
# picks a new one. No Run items, no external fetch, no embedded data pool —
# the words in the sheet ARE the record of what was shown (see
# word_assignment_log.csv for a timestamped audit trail of every rebuild).
#
# Coverage-speed trade-off, worth re-checking as real data comes in: with
# N_BLOCKS words refreshed every cron cycle, full coverage of the
# needs-norming pool takes (pool size / N_BLOCKS) cycles. At the current
# defaults (30 words, 2h cycle, ~2,700-word pool) that's ~90 cycles, or
# roughly 7.5 days, to touch every word once. Shorten the cron interval
# in run_update_and_push.sh if that's too slow once real recruitment
# volume is known.
#
# Shared across all languages -- do not copy this into a language folder.
# Run with the working directory set to the target language's folder (e.g.
# `Rscript ../lib/build_formr_xlsx.R` from inside 02-Task/English/), which
# is what run_update_and_push.sh does. All paths below (template, output,
# log, summary) resolve against that language's own folder; only
# select_words.R is located relative to this script itself, since it lives
# here in lib/ regardless of which language folder is the working directory.

library(readxl)
library(openxlsx)

TEMPLATE_PATH <- "word_ratings_template.xlsx"
OUTPUT_PATH <- "word_ratings.xlsx"
LOG_PATH <- "word_assignment_log.csv"
N_BLOCKS <- 30 # manuscript: 30 randomly selected nouns per participant, same for every language. Must match the template's block count (see make_template_core.R).
N_CUTOFF <- 30 # manuscript: 30 responses/cue, same for every language.

lib_dir <- dirname(sub("--file=", "", grep("--file=", commandArgs(trailingOnly = FALSE), value = TRUE)))
source(file.path(lib_dir, "select_words.R")) # select_words(): inverse-N weighted sampling, order-shuffled

summary <- read.csv("word_n_summary.csv", stringsAsFactors = FALSE)
words <- select_words(summary, n_cutoff = N_CUTOFF, n_select = N_BLOCKS)

df <- as.data.frame(read_excel(TEMPLATE_PATH, sheet = "Sheet1"), stringsAsFactors = FALSE)

for (i in seq_len(N_BLOCKS)) {
  slot <- sprintf("w%02d", i)
  prompt_idx <- which(df$name == paste0(slot, "_prompt"))
  stopifnot(length(prompt_idx) == 1)
  label <- df$label[prompt_idx]
  # Replace the template's hardcoded demo word (bolded, appears twice) with
  # this rebuild's actual selected word.
  hardcoded <- regmatches(label, regexpr("(?<=\\*\\*)[a-z]+(?=\\*\\*)", label, perl = TRUE))
  df$label[prompt_idx] <- gsub(hardcoded, words[i], label, fixed = TRUE)
}

wb <- createWorkbook()
addWorksheet(wb, "Sheet1")
writeData(wb, "Sheet1", df)
header_style <- createStyle(textDecoration = "bold", border = c("top", "bottom"),
                             borderColour = "#44B3E1", halign = "center", valign = "top")
addStyle(wb, "Sheet1", header_style, rows = 1, cols = seq_len(ncol(df)))
saveWorkbook(wb, OUTPUT_PATH, overwrite = TRUE)

# Audit trail: exactly which word landed in which slot, and its N at
# selection time, timestamped per rebuild -- this is what makes "which
# words were shown" answerable later without having to diff xlsx history.
log_entry <- data.frame(
  built_at = Sys.time(),
  slot = sprintf("w%02d", seq_len(N_BLOCKS)),
  word = words,
  n_total_at_selection = summary$n_total[match(words, summary$cue)]
)
write.table(
  log_entry, LOG_PATH,
  sep = ",", row.names = FALSE,
  col.names = !file.exists(LOG_PATH), append = file.exists(LOG_PATH)
)

cat("Wrote", nrow(df), "rows to", OUTPUT_PATH, "\n")
cat("Words this cycle:", paste(words, collapse = ", "), "\n")
