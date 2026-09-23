# Shared across all languages -- do not copy this into a language folder.
#
# Rebuilds one xlsx per formr survey "part" from that part's own pristine
# <survey>_template.xlsx, given a language's own vector of formr survey
# names. Split into multiple parts (multiple formr surveys chained in one
# run) because a single ~30-block survey (~390 items: prompt + 10 use-boxes
# + more-button + submit, per word) hit formr's own MySQL backend row-size
# limit ("Row size too large (> 8126)") when importing the item table --
# formr stores one column per item, and ~390 columns of VARCHAR overflows
# InnoDB's row-size ceiling. Each part's own item count needs to stay
# comfortably under that; 10 blocks/part (~130 items) is the current
# choice (see each language's build_formr_xlsx.R for its part_names).
#
# Batch-level randomization: word selection happens HERE, once per rebuild,
# server-side -- not per participant inside formr. All blocks_per_part *
# length(part_names) words are drawn together in ONE weighted sample (not
# per-part separately), so prioritization stays correct across the whole
# set, then split evenly across parts. Each cron cycle
# (run_update_and_push.sh) bakes them as literal text directly into the
# block prompts and pushes the result to formr. Every participant who
# takes the survey between one push and the next sees that same word set;
# the next push picks a new one. No Run items, no external fetch, no
# embedded data pool -- the words in each sheet ARE the record of what was
# shown (see word_assignment_log.csv for a timestamped audit trail of
# every rebuild, including which survey/part each slot belonged to).
#
# Coverage-speed trade-off, worth re-checking as real data comes in: with
# (blocks_per_part * length(part_names)) words refreshed every cron cycle,
# full coverage of the needs-norming pool takes (pool size / that number)
# cycles. At the current defaults (30 words total, 2h cycle, ~2,700-word
# pool) that's ~90 cycles, or roughly 7.5 days, to touch every word once.
# Shorten the cron interval in run_update_and_push.sh if that's too slow
# once real recruitment volume is known.

library(readxl)
library(openxlsx)

build_formr_xlsx <- function(part_names, blocks_per_part = 10, n_cutoff = 30,
                              log_path = "word_assignment_log.csv") {
  n_total <- blocks_per_part * length(part_names)

  summary <- read.csv("word_n_summary.csv", stringsAsFactors = FALSE)
  words <- select_words(summary, n_cutoff = n_cutoff, n_select = n_total)

  log_rows <- list()

  for (p in seq_along(part_names)) {
    survey <- part_names[p]
    part_words <- words[((p - 1) * blocks_per_part + 1):(p * blocks_per_part)]

    template_path <- paste0(survey, "_template.xlsx")
    output_path <- paste0(survey, ".xlsx")

    df <- as.data.frame(read_excel(template_path, sheet = "Sheet1"), stringsAsFactors = FALSE)

    for (i in seq_len(blocks_per_part)) {
      slot <- sprintf("w%02d", i)
      prompt_idx <- which(df$name == paste0(slot, "_prompt"))
      stopifnot(length(prompt_idx) == 1)
      label <- df$label[prompt_idx]
      # Replace the template's hardcoded demo word (bolded, appears twice)
      # with this rebuild's actual selected word.
      hardcoded <- regmatches(label, regexpr("(?<=\\*\\*)[a-z]+(?=\\*\\*)", label, perl = TRUE))
      df$label[prompt_idx] <- gsub(hardcoded, part_words[i], label, fixed = TRUE)
    }

    wb <- createWorkbook()
    addWorksheet(wb, "Sheet1")
    writeData(wb, "Sheet1", df)
    header_style <- createStyle(textDecoration = "bold", border = c("top", "bottom"),
                                 borderColour = "#44B3E1", halign = "center", valign = "top")
    addStyle(wb, "Sheet1", header_style, rows = 1, cols = seq_len(ncol(df)))
    saveWorkbook(wb, output_path, overwrite = TRUE)

    log_rows[[p]] <- data.frame(
      built_at = Sys.time(),
      survey = survey,
      slot = sprintf("w%02d", seq_len(blocks_per_part)),
      word = part_words,
      n_total_at_selection = summary$n_total[match(part_words, summary$cue)]
    )

    cat("Wrote", nrow(df), "rows to", output_path, "\n")
    cat("  words:", paste(part_words, collapse = ", "), "\n")
  }

  # Audit trail: exactly which word landed in which slot of which survey,
  # and its N at selection time, timestamped per rebuild -- this is what
  # makes "which words were shown, and where" answerable later without
  # having to diff xlsx history.
  log_entry <- do.call(rbind, log_rows)
  write.table(
    log_entry, log_path,
    sep = ",", row.names = FALSE,
    col.names = !file.exists(log_path), append = file.exists(log_path)
  )

  invisible(words)
}
