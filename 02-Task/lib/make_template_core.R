# Shared across all languages -- do not copy this into a language folder.
# Generic structural builder behind every language's make_template.R: given
# N words and that language's translated instructional text, produces the
# pristine word_ratings_template.xlsx (word-blocks with placeholder
# hardcoded words -- build_formr_xlsx.R always overwrites them per rebuild).
# The block structure itself (prompt/use-1-5/more/use-6-10/submit) is
# identical across languages per the manuscript's design; only the text
# strings differ, so translation happens entirely in each language's own
# thin make_template.R, which supplies those strings to this function.

library(openxlsx)

make_template <- function(words,
                           instructions_label,
                           prompt_fn,
                           begin_label = "Begin",
                           more_label = "Have you listed all the different uses you can think of?",
                           more_choice1 = "Yes, I'm finished",
                           more_choice2 = "No, I can think of a few more",
                           use_label_fn = function(u) paste("Use", u),
                           next_label = "Next",
                           out_path) {
  # out_path has no default deliberately: it must match <SurveyName>.xlsx
  # (or _template.xlsx) for that language's real formr survey name -- see
  # each language's make_template.R for its actual value.
  n_blocks <- length(words)
  block_ids <- sprintf("%02d", seq_len(n_blocks)) # zero-padded so string-sort order matches block order; "letters" only covers 26

  cols <- c("explanations", "class", "type", "optional", "name", "showif", "label",
            paste0("choice", 1:12), "value", "block_order", "item_order")

  rows <- list()
  add_row <- function(...) {
    r <- as.list(rep(NA, length(cols)))
    names(r) <- cols
    args <- list(...)
    for (n in names(args)) r[[n]] <- args[[n]]
    rows[[length(rows) + 1]] <<- r
  }

  add_row(type = "note", name = "general_instructions", label = instructions_label)
  add_row(type = "submit", name = "general_submit", label = begin_label)

  for (i in seq_along(words)) {
    slot <- sprintf("w%02d", i)
    L <- block_ids[i]
    w <- words[i]

    add_row(class = "left100 right600", type = "note", name = paste0(slot, "_prompt"),
            label = prompt_fn(w), block_order = L, item_order = "1")

    for (u in 1:5) {
      add_row(class = "left100 right600", type = "text 120", optional = "*",
              name = sprintf("%s_use_%02d", slot, u), label = use_label_fn(u),
              block_order = L, item_order = as.character(u + 1))
    }

    add_row(class = "left100 right600", type = "mc_button", name = paste0(slot, "_more"),
            label = more_label,
            choice1 = more_choice1, choice2 = more_choice2,
            block_order = L, item_order = "7")

    for (u in 6:10) {
      add_row(class = "left100 right600", type = "text 120", optional = "*",
              name = sprintf("%s_use_%02d", slot, u), label = use_label_fn(u),
              showif = paste0(slot, "_more == 2"),
              block_order = L, item_order = as.character(u + 2))
    }

    add_row(type = "submit", name = paste0(slot, "_submit"), label = next_label,
            block_order = L, item_order = "13")
  }

  df <- do.call(rbind.data.frame, c(lapply(rows, as.data.frame, stringsAsFactors = FALSE),
                                     list(stringsAsFactors = FALSE)))
  names(df) <- cols
  stopifnot(nrow(df) == 2 + n_blocks * 13)

  wb <- createWorkbook()
  addWorksheet(wb, "Sheet1")
  writeData(wb, "Sheet1", df)
  header_style <- createStyle(textDecoration = "bold", border = c("top", "bottom"),
                               borderColour = "#44B3E1", halign = "center", valign = "top")
  addStyle(wb, "Sheet1", header_style, rows = 1, cols = seq_len(ncol(df)))
  saveWorkbook(wb, out_path, overwrite = TRUE)

  cat("Wrote pristine template:", nrow(df), "rows to", out_path, "\n")
  invisible(df)
}
