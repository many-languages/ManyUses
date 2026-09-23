# Builds the manuscript's Table 2 ("Descriptive Statistics for Cue Word
# Concreteness as a Function of Target Language") from the actual
# selected-word pools, reflecting the pooled percentile-rank method
# (build_stimuli_pools.R / build_shared_core.R -- see README.md) that
# replaced the original single-source z-score-above-zero method the
# current manuscript table still describes (see its footnote 3).
#
# Unlike the old table -- one native rating scale, one source, per
# language -- each non-English language now pools MULTIPLE sources onto
# a common 0-1 percentile-rank scale (see README.md's "Method" section),
# so M/SD/Min/Max here are of mean_percentile, not a native Likert scale,
# and the source column lists every source key actually used across that
# language's SELECTED words (not just what's available), semicolon-
# joined per word in each *_concreteness_candidates.csv.
#
# English is unchanged from the old table's method (Maxwell et al. 2024
# + Pexman et al. 2019, not pooled/percentile-ranked -- see README.md's
# footnote-equivalent note and STIMULI_SELECTION_STATUS.md), so it's
# read from its own file and reported on its native 1-5 concreteness
# scale, exactly as the current manuscript table already does.
#
# `sources` lists dataset KEYS (e.g. "Guasch2016"); `citations` gives
# short "Author et al. (Year)" forms pulled from semanticprimeR's own
# per-dataset YAML citation metadata (github.com/SemanticPriming/
# semanticprimeR, inst/extdata/model_cards/<key>.yaml -- fetched into
# source_datasets/citations/, parsed into citation_metadata.csv). Several
# of these source datasets aren't in the manuscript's reference list yet
# -- see source_datasets/citations/citation_metadata.csv's full_cite
# column for ready-to-paste full references, and this script's stdout
# for any left as "[citation needed]" (no metadata found at all, e.g.
# Marques2005 -- semanticprimeR's own record for it says source:
# unknown).

library(dplyr)

languages <- c("Dutch", "French", "Italian", "Portuguese", "Chinese_Simplified",
               "Spanish", "Russian", "Chinese_Traditional", "Turkish", "German",
               "Galician", "Polish")

# Citation metadata pulled from semanticprimeR's own per-dataset YAML
# model cards (github.com/SemanticPriming/semanticprimeR, inst/extdata/
# model_cards/<key>.yaml) -- see source_datasets/citations/ for the raw
# YAML and citation_metadata.csv for the parsed fields this reads.
citations <- read.csv("source_datasets/citations/citation_metadata.csv", stringsAsFactors = FALSE)
# A raw source key from a *_concreteness_candidates.csv row can carry a
# suffix beyond the citation's own base key (e.g.
# "Grigoriev2026_cmp_Grigoriev2022", "Soares2017_MinhoWordPool") --
# longest-prefix match against citations$key recovers the base key those
# suffixed forms were built from.
base_key_of <- function(raw_key) {
  candidates <- citations$key[startsWith(raw_key, citations$key)]
  if (length(candidates) == 0) return(raw_key)
  candidates[which.max(nchar(candidates))]
}
short_cite_of <- function(raw_key) {
  base <- base_key_of(raw_key)
  cite <- citations$short_cite[citations$key == base]
  if (length(cite) == 0 || is.na(cite)) paste0(base, " [citation needed]") else cite
}

pooled_stats <- lapply(languages, function(lang) {
  path <- file.path(lang, paste0(lang, "_concreteness_candidates.csv"))
  df <- read.csv(path, stringsAsFactors = FALSE)
  sel <- df[df$selected == TRUE, ]

  all_sources <- unique(unlist(strsplit(sel$sources, ";")))
  base_keys <- unique(vapply(all_sources, base_key_of, character(1)))
  cites <- vapply(base_keys, short_cite_of, character(1))
  n_hack <- if ("gloss_source" %in% names(sel)) sum(sel$gloss_source == "hack_llm_translation", na.rm = TRUE) else 0L

  data.frame(
    language = lang,
    M = mean(sel$mean_percentile),
    SD = sd(sel$mean_percentile),
    Min = min(sel$mean_percentile),
    Max = max(sel$mean_percentile),
    n_words = nrow(sel),
    n_sources = length(base_keys),
    sources = paste(sort(base_keys), collapse = "; "),
    citations = paste(sort(cites), collapse = "; "),
    scale = "Percentile rank (pooled)",
    n_hack_translated_glosses = n_hack,
    stringsAsFactors = FALSE
  )
})
pooled_stats <- bind_rows(pooled_stats)

english <- read.csv("English/English_Combined_4000.csv", stringsAsFactors = FALSE)
english_row <- data.frame(
  language = "English",
  M = mean(english$con),
  SD = sd(english$con),
  Min = min(english$con),
  Max = max(english$con),
  n_words = nrow(english),
  n_sources = 2,
  sources = "Maxwell2024; Pexman2019",
  citations = "Maxwell et al. (2024); Pexman et al. (2019)",
  scale = "1 -- 5 Likert",
  n_hack_translated_glosses = 0L,
  stringsAsFactors = FALSE
)

table2 <- bind_rows(english_row, pooled_stats) %>% arrange(language)

write.csv(table2, "table2_descriptive_stats.csv", row.names = FALSE)
cat("Wrote table2_descriptive_stats.csv --", nrow(table2), "languages.\n\n")

cat("Source citations still marked [citation needed] (no metadata found\n")
cat("in semanticprimeR's model cards -- needs a manual citation):\n")
all_cites <- unique(unlist(strsplit(table2$citations, "; ")))
needed <- grep("\\[citation needed\\]", all_cites, value = TRUE)
if (length(needed)) cat(paste(needed, collapse = ", "), "\n\n") else cat("(none)\n\n")

cat("Languages with hack-translated (LLM, unverified) glosses among selected words:\n")
print(pooled_stats[pooled_stats$n_hack_translated_glosses > 0, c("language", "n_hack_translated_glosses", "n_words")])
