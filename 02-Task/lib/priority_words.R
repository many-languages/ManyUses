# Shared across all languages -- do not copy this into a language folder.
#
# Loads this language's cue words from the 500-word cross-linguistic
# overlap set (01-Stimuli/build_shared_core.R's shared_core_top500.csv --
# see 01-Stimuli/README.md's "Cross-linguistic overlap" section), for
# biasing select_words() toward norming those first (the manuscript's
# priority component).
#
# English is the gloss language shared_core_top500.csv itself is built
# around (gloss_english IS the English word -- see its header), so
# English's priority words are exactly that column, unchanged. Every
# other language's actual cue words are its own TRANSLATION of each
# concept, not the English gloss -- those live in the "words" column as
# "Language:word;Language:word;..." pairs, one row per concept, present
# only for languages that concept happens to have translation coverage
# for (see n_languages_covered/languages_covered). So a non-English
# language's priority set is only as large as its own coverage in that
# column, extracted here rather than assumed to be all 500.
load_priority_words <- function(shared_core_path, language) {
  df <- read.csv(shared_core_path, stringsAsFactors = FALSE)

  if (language == "English") {
    words <- df$gloss_english
  } else {
    extract_one <- function(words_str) {
      pairs <- trimws(strsplit(words_str, ";")[[1]])
      hit <- startsWith(pairs, paste0(language, ":"))
      if (!any(hit)) return(NA_character_)
      sub(paste0("^", language, ":"), "", pairs[hit][1])
    }
    words <- vapply(df$words, extract_one, character(1), USE.NAMES = FALSE)
  }

  words <- tolower(trimws(words))
  unique(words[!is.na(words) & nzchar(words)])
}
