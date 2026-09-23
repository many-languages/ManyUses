# Shared across all languages -- do not copy this into a language folder.
#
# Spell-check + lemmatize/POS-tag a vector of already-nonanswer-filtered
# response strings. Unlike the old Affordance Norms pipeline (hunspell
# suggestions written to spell_check_raw.csv for a REQUIRED manual open-
# in-Excel-and-confirm pass before continuing), this auto-accepts
# hunspell's top suggestion -- responses are single short words/phrases,
# not free text, so suggestion quality is high and a blocking manual step
# doesn't scale to an always-on cron pipeline. spell_review.csv is still
# written every run for optional spot-checking; nothing reads it back in.

library(hunspell)
library(udpipe)
library(stringr)

# words: unique already-lowercased/trimmed response strings to correct.
# review_path: where to write the human-checkable (word -> suggestion)
# table; NULL to skip writing it.
spell_correct <- function(words, review_path = "spell_review.csv") {
  words <- unique(words)
  # Multi-word responses (e.g. "hula hoop") are checked token-by-token;
  # hunspell on the whole phrase would flag it as one long misspelled
  # word.
  tokens <- unique(unlist(str_split(words, "\\s+")))
  tokens <- tokens[nzchar(tokens)]

  bad <- tokens[!hunspell_check(tokens, dict = dictionary("en_US"))]
  suggestions <- hunspell_suggest(bad, dict = dictionary("en_US"))
  suggestions <- vapply(suggestions, function(s) if (length(s)) tolower(s[1]) else NA_character_, character(1))

  dict <- setNames(suggestions, bad)
  dict <- dict[!is.na(dict)]

  if (!is.null(review_path) && length(dict)) {
    write.csv(data.frame(misspelled = names(dict), suggestion = dict), review_path, row.names = FALSE)
  }

  correct_one <- function(w) {
    toks <- str_split(w, "\\s+")[[1]]
    toks <- ifelse(toks %in% names(dict), dict[toks], toks)
    paste(toks, collapse = " ")
  }
  setNames(vapply(words, correct_one, character(1)), words)
}

# corrected: vector of already spell-corrected response strings.
# Returns a data.frame with one row per (response, token), its lemma
# and POS tag -- callers join back to the response by row position
# (udpipe preserves input order via doc_id).
lemmatize_pos <- function(corrected, model = NULL, model_dir = "../.udpipe_models") {
  if (is.null(model)) {
    # Cached under 05-Data/ (gitignored -- see .gitignore), not
    # tempdir() -- otherwise every run re-downloads the ~15MB model.
    # Relative to Code/ (this repo's scripts assume that working
    # directory -- see how 02-Task/English/*.R are run).
    dir.create(model_dir, showWarnings = FALSE, recursive = TRUE)
    existing <- list.files(model_dir, pattern = "\\.udpipe$", full.names = TRUE)
    model_file <- if (length(existing)) existing[1] else {
      udpipe_download_model(language = "english", model_dir = model_dir)$file_model
    }
    model <- udpipe_load_model(model_file)
  }
  ann <- udpipe_annotate(model, x = corrected, doc_id = seq_along(corrected))
  as.data.frame(ann)[, c("doc_id", "token", "lemma", "upos")]
}
