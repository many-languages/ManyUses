# Many Uses: Build the cross-linguistic shared core via gloss matching
#
# The per-language pools in build_stimuli_pools.R answer "what are this
# language's own best concrete-noun candidates?". This script answers a
# different question: "which concepts can we plausibly norm in MULTIPLE
# languages at once?" - the set the manuscript's back-translation step and
# Aims 3/4 actually need.
#
# Method: for every selected candidate word that has an English gloss
# (several sources provide translate_word_english directly), group by that
# gloss across all languages plus the existing English 4000-cue list. A
# gloss covered by many languages is a strong shared-core candidate; a gloss
# covered by only 1-2 languages is not.
#
# UPDATE: Dutch, Chinese Traditional, and German originally had no source
# with an English gloss. Their top candidates (300/300/263 words, the ones
# most likely to matter for cross-linguistic overlap) were given "hack"
# glosses in-place in their candidate CSVs (gloss_source="hack_llm_translation")
# based on the model's own linguistic knowledge, NOT a verified dictionary or
# native-speaker check - see scratch_translations.py. Treat these three
# languages' presence in the shared core as lower-confidence than the other
# 7, which use glosses provided directly by the source datasets.

out_dir <- "/Users/erinbuchanan/GitHub/Research/2_projects/ManyUses/01-Stimuli"

languages <- c("French", "Italian", "Portuguese", "Chinese_Simplified",
               "Spanish", "Russian", "Chinese_Traditional", "Turkish", "German", "Dutch",
               "Galician", "Polish")

# ---- 1. Load each language's selected candidates with a gloss --------------
lang_tables <- list()
for (lang in languages) {
  path <- file.path(out_dir, lang, paste0(lang, "_concreteness_candidates.csv"))
  if (!file.exists(path)) next
  df <- read.csv(path, stringsAsFactors = FALSE)
  df <- df[df$selected & !is.na(df$gloss_english) & df$gloss_english != "", ]
  if (nrow(df) == 0) next
  df$gloss_english <- tolower(trimws(df$gloss_english))
  if (!("gloss_source" %in% names(df))) df$gloss_source <- ""
  lang_tables[[lang]] <- df[, c("word", "gloss_english", "mean_percentile", "tier", "gloss_source")]
}

cat("Languages with gloss-matchable candidates:", paste(names(lang_tables), collapse = ", "), "\n")
cat("Languages with NO gloss data (excluded from this matching):",
    paste(setdiff(languages, names(lang_tables)), collapse = ", "), "\n\n")

# ---- 2. Load English's own 4000-cue list ------------------------------------
english_cues <- read.csv(file.path(out_dir, "English", "English_Combined_4000.csv"),
                          stringsAsFactors = FALSE)
english_glosses <- tolower(trimws(english_cues$cues))

# ---- 3. Build long table: gloss, language, word -----------------------------
long <- do.call(rbind, lapply(names(lang_tables), function(lang) {
  df <- lang_tables[[lang]]
  data.frame(gloss = df$gloss_english, language = lang, word = df$word,
             percentile = df$mean_percentile, tier = df$tier,
             gloss_source = df$gloss_source, stringsAsFactors = FALSE)
}))

# collapse to one row per gloss x language (keep the best-ranked word if a
# gloss somehow maps to >1 word in the same language)
long <- long[order(long$gloss, long$language, -long$percentile), ]
long <- long[!duplicated(long[, c("gloss", "language")]), ]

# ---- 4. Summarize coverage per gloss ----------------------------------------
gloss_ids <- unique(long$gloss)
summary_list <- lapply(gloss_ids, function(g) {
  rows <- long[long$gloss == g, ]
  langs_covered <- rows$language
  in_english <- g %in% english_glosses
  any_hack <- any(rows$gloss_source == "hack_llm_translation")
  avg_percentile <- mean(rows$percentile)
  data.frame(
    gloss_english = g,
    n_languages_with_gloss_data = length(lang_tables),
    n_languages_covered = length(langs_covered),
    languages_covered = paste(sort(langs_covered), collapse = ";"),
    in_english_4000 = in_english,
    n_languages_covered_plus_english = length(langs_covered) + as.integer(in_english),
    includes_hack_translation = any_hack,
    avg_percentile_across_covering_langs = avg_percentile,
    words = paste(sprintf("%s:%s", rows$language, rows$word), collapse = ";"),
    stringsAsFactors = FALSE
  )
})
shared <- do.call(rbind, summary_list)
# rank by breadth of cross-linguistic coverage first, then by how
# concreteness-central the word is on average in the languages that have it
shared <- shared[order(-shared$n_languages_covered_plus_english,
                        -shared$avg_percentile_across_covering_langs,
                        shared$gloss_english), ]

out_path <- file.path(out_dir, "shared_core_candidates.csv")
write.csv(shared, out_path, row.names = FALSE)

# ---- 4b. Top-500 "most shared" concepts -------------------------------------
top500 <- head(shared, 500)
top500_path <- file.path(out_dir, "shared_core_top500.csv")
write.csv(top500, top500_path, row.names = FALSE)

# ---- 5. Report ---------------------------------------------------------------
n_gloss_langs <- length(lang_tables)
cat("Total distinct English glosses across gloss-matchable languages:", nrow(shared), "\n\n")

cat("Coverage distribution (how many of the", n_gloss_langs, "gloss-matchable languages share each concept):\n")
print(table(shared$n_languages_covered))

cat("\nOf those, how many are ALSO already in the English 4000-cue list:\n")
tab_incl_en <- table(shared$n_languages_covered[shared$in_english_4000])
print(tab_incl_en)

full_overlap <- shared[shared$n_languages_covered == n_gloss_langs, ]
cat(sprintf("\nConcepts shared by ALL %d gloss-matchable languages: %d\n", n_gloss_langs, nrow(full_overlap)))
cat(sprintf("...of which also already in English's 4000 cues: %d\n", sum(full_overlap$in_english_4000)))

cat("\nSample of full-overlap concepts also in English's list:\n")
print(head(full_overlap[full_overlap$in_english_4000, c("gloss_english","words")], 15))

cat(sprintf("\nTop-500 coverage distribution (of the %d languages with gloss data):\n", n_gloss_langs))
print(table(top500$n_languages_covered))
cat(sprintf("Top-500 concepts that include a hack-translated word: %d\n", sum(top500$includes_hack_translation)))
cat(sprintf("Top-500 concepts already in English's 4000 cues: %d\n", sum(top500$in_english_4000)))

cat(sprintf("\nWrote %d rows to %s\n", nrow(shared), out_path))
cat(sprintf("Wrote top %d rows to %s\n", nrow(top500), top500_path))
