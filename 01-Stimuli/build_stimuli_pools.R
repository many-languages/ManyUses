# Many Uses: Build cross-linguistic candidate stimuli pools
#
# For each non-English target language, pool all available semanticprimeR
# concreteness datasets, POS-tag every candidate word with udpipe, restrict
# to nouns, convert concreteness to a within-source percentile rank, then
# combine ranks across sources per word. This replaces the single-source
# z-score approach in the Stage 1 draft with a method that (a) works when
# a language only has one small source and (b) scales when multiple
# sources are available, without assuming comparable scale distributions.

library(udpipe)

# Source CSVs are local copies (pulled from the semanticprimeR package's
# datasets/completed folder) so this pipeline is self-contained and
# reproducible without depending on a sibling project directory.
out_dir   <- "/Users/erinbuchanan/GitHub/Research/2_projects/ManyUses/01-Stimuli"
spr_dir   <- file.path(out_dir, "source_datasets")
model_dir <- file.path(out_dir, "udpipe_models")

# ---- 1. Manifest: language -> source datasets ------------------------------
# Sources that are just re-exports of another source already in the manifest
# are deliberately excluded (e.g., Bernabeu2018 Dutch reuses Brysbaert et al.
# 2014 concreteness values already covered by Brysbaert2014a).

manifest <- list(
  Dutch = list(
    udpipe_model = "dutch-alpino",
    sources = list(
      # No source carries an English gloss for Dutch - it cannot currently
      # participate in the gloss-matched shared core (see build_shared_core.R)
      # without a separate translation step.
      list(file = "Brysbaert2014a.csv", word_col = "word_dutch",   conc_col = "concrete_mean", source = "Brysbaert2014a"),
      list(file = "Jasmin2012.csv",     word_col = "word_dutch",   conc_col = "concrete_mean", source = "Jasmin2012")
    )
  ),
  French = list(
    udpipe_model = "french-gsd",
    sources = list(
      list(file = "Bonin2018.csv",     word_col = "word_french", conc_col = "concrete_mean", gloss_col = "translate_word_english", source = "Bonin2018"),
      list(file = "Quadflieg2014.csv", word_col = "word_french", conc_col = "concrete_mean", gloss_col = "translate_word_english", source = "Quadflieg2014")
    )
  ),
  Italian = list(
    udpipe_model = "italian-isdt",
    sources = list(
      list(file = "Montefinese2014.csv",    word_col = "word_italian", conc_col = "concrete_mean", gloss_col = "translate_word_english", source = "Montefinese2014"),
      list(file = "Montefinese2023_it.csv", word_col = "word_italian", conc_col = "concrete_mean", source = "Montefinese2023_it"),
      list(file = "Barca2002.csv",          word_col = "word_italian", conc_col = "concrete_mean", gloss_col = "translate_word_english", source = "Barca2002"),
      list(file = "DellaRosa2010.csv",      word_col = "word_italian", conc_col = "concrete_mean", gloss_col = "translate_word_english", source = "DellaRosa2010")
    )
  ),
  Portuguese = list(
    udpipe_model = "portuguese-gsd",
    sources = list(
      list(file = "Cameirao2010.csv", word_col = "word_portuguese", conc_col = "concrete_mean", gloss_col = "translate_word_english", source = "Cameirao2010"),
      list(file = "Marques2005.csv",  word_col = "word_portuguese", conc_col = "concrete_mean", source = "Marques2005"),
      list(file = "Marques2007.csv",  word_col = "word_portuguese", conc_col = "concrete_mean", gloss_col = "translate_word_english", source = "Marques2007"),
      # Soares et al. (2017)'s Minho Word Pool for 3,800 Portuguese words -
      # the exact source the Stage 1 draft already cites for Portuguese
      # concreteness. Its word column was mislabeled "word_spanish" upstream
      # in semanticprimeR (fixed at the source: datasets/completed/Soares2017.csv
      # and its model card now correctly say word_portuguese).
      list(file = "Soares2017.csv",   word_col = "word_portuguese", conc_col = "concrete_mean", gloss_col = "translate_word_english", source = "Soares2017_MinhoWordPool")
    )
  ),
  Chinese_Simplified = list(
    udpipe_model = "chinese-gsdsimp",
    sources = list(
      # Liu2025 scale runs high=abstract/low=concrete (verified directly via
      # extreme words, and confirmed empirically: Yee2017 correlates r=-.79
      # with Liu2025 on overlapping words, and Yee2017's own direction was
      # independently confirmed by inspection - so Liu2025 must be flipped
      # relative to true concreteness). Yao2017's direction was ambiguous on
      # inspection (both extremes mixed concrete/abstract items) and its
      # correlation with confirmed-inverted Liu2025 was ~0 (r=-.03, n=269),
      # which does not support inverting it - left at face value (standard
      # convention: higher concrete_mean = more concrete) but flagged as a
      # noisier source.
      list(file = "Yao2017.csv",  word_col = "word_chinese_simplified", conc_col = "concrete_mean", gloss_col = "translate_word_english", source = "Yao2017"),
      list(file = "Liu2007.csv",  word_col = "word_chinese_simplified", conc_col = "concrete_mean", source = "Liu2007"),
      list(file = "Liu2025.csv",  word_col = "word_chinese_simplified", conc_col = "concrete_mean", source = "Liu2025", invert = TRUE),
      list(file = "Yee2017.csv",  word_col = "word_chinese_simplified", conc_col = "concrete_mean", gloss_col = "translate_word_english", source = "Yee2017")
    )
  ),
  Spanish = list(
    udpipe_model = "spanish-gsd",
    sources = list(
      list(file = "Davis2005a.csv",      word_col = "word_spanish", conc_col = "concrete_mean", source = "Davis2005a"),
      list(file = "Diez-Alamo2018a.csv", word_col = "word_spanish", conc_col = "concrete_mean", gloss_col = "translate_word_english", source = "Diez-Alamo2018a"),
      list(file = "Duchon2013.csv",      word_col = "word_spanish", conc_col = "concrete_mean", source = "Duchon2013"),
      list(file = "Ferre2012.csv",       word_col = "word_spanish", conc_col = "concrete_mean", source = "Ferre2012"),
      list(file = "Guasch2016.csv",      word_col = "word_spanish", conc_col = "concrete_mean", gloss_col = "translate_word_english", source = "Guasch2016"),
      list(file = "Hinojosa2016a.csv",   word_col = "word_spanish", conc_col = "concrete_mean", source = "Hinojosa2016a")
      # NOTE: Soares2017.csv is not a Spanish source - it is Soares et al.
      # (2017)'s Portuguese Minho Word Pool (its word column was mislabeled
      # "word_spanish" upstream in semanticprimeR; now fixed at the source).
      # It lives in the Portuguese entry above.
    )
  ),
  Russian = list(
    udpipe_model = "russian-syntagrus",
    sources = list(
      list(file = "Grigoriev2026.csv", word_col = "word_russian", conc_col = "concrete_mean_grigoriev2022",    gloss_col = "translate_word_english", source = "Grigoriev2026_cmp_Grigoriev2022"),
      # Both Soloviev2022 sub-scores run high=abstract/low=concrete (e.g.,
      # korova/cow, pulya/bullet score lowest; doverie/trust, ideal/ideal
      # score highest) - opposite of Grigoriev2022 in the same file -
      # inverted before combining.
      list(file = "Grigoriev2026.csv", word_col = "word_russian", conc_col = "concrete_soloviev2022_1000",     gloss_col = "translate_word_english", source = "Grigoriev2026_cmp_Soloviev2022_1000", invert = TRUE),
      list(file = "Grigoriev2026.csv", word_col = "word_russian", conc_col = "concrete_mean_soloviev2022_500", gloss_col = "translate_word_english", source = "Grigoriev2026_cmp_Soloviev2022_500", invert = TRUE)
    )
  ),
  Chinese_Traditional = list(
    udpipe_model = "chinese-gsd",
    sources = list(
      # Su2023 (single characters) has no English gloss column - cannot
      # currently participate in gloss-matched shared core.
      list(file = "Su2023.csv", word_col = "word_chinese_traditional", conc_col = "concrete_mean", source = "Su2023")
    )
  ),
  # NOTE: Croatian deliberately excluded - the only available concreteness
  # source (Bogunovic2023) is a corpus study of English loanwords adapted
  # into Croatian, not a general-vocabulary norm set, and would bias the
  # candidate pool toward anglicisms. Revisit if a general Croatian
  # concreteness norm set becomes available.
  Turkish = list(
    udpipe_model = "turkish-imst",
    sources = list(
      list(file = "Goz2017.csv", word_col = "word_turkish", conc_col = "concrete_mean", gloss_col = "translate_word_english", source = "Goz2017")
    )
  ),
  German = list(
    udpipe_model = "german-gsd",
    sources = list(
      # Kanske2010's "concrete_mean" scale runs high=abstract/low=concrete
      # (e.g., Gabel/fork and Apfel/apple score lowest; Liebe/love and
      # Weisheit/wisdom score highest) - inverted before combining. No
      # English gloss column available for this source either. The source
      # paper (Kanske & Kotz, 2010) describes LANG as "a list of 1,000
      # German nouns" - i.e., already curated to be all nouns - so
      # assume_noun skips udpipe POS-filtering (which, without sentence
      # context, was mistagging many genuine nouns and dropping the pool
      # from 1000 to 436).
      list(file = "Kanske2010.csv", word_col = "word_german", conc_col = "concrete_mean", source = "Kanske2010", invert = TRUE, assume_noun = TRUE)
    )
  ),
  Galician = list(
    udpipe_model = "galician-ctg",
    sources = list(
      # NORGAL (Alvarez-Mosquera et al., 2026): 1,585 Galician words, ratings
      # from bilingual Galician-Spanish university students. Has its own
      # English gloss column, unlike most single-source additions.
      list(file = "AlvarezMosquera2026.csv", word_col = "word_galician", conc_col = "concrete_mean", gloss_col = "translate_word_english", source = "AlvarezMosquera2026")
    )
  ),
  Polish = list(
    udpipe_model = "polish-pdb",
    sources = list(
      # ANPW_R (Imbir, 2016): 4,905 Polish words. Has its own English gloss
      # column. See Imbir2016.yaml for the parent-dataset relationship to
      # the original 1,586-word ANPW (Imbir2015, not itself a concreteness
      # source so not otherwise usable for this pipeline).
      list(file = "Imbir2016.csv", word_col = "word_polish", conc_col = "concrete_mean", gloss_col = "translate_word_english", source = "Imbir2016")
    )
  )
)

# folder name -> output subfolder name (Chinese_Simplified etc. already match)
folder_name <- function(lang) lang

# ---- 2. Helper: load + clean one source -------------------------------------
load_source <- function(spec) {
  path <- file.path(spr_dir, spec$file)
  df <- read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  if (!(spec$word_col %in% names(df)) || !(spec$conc_col %in% names(df))) {
    warning(sprintf("Missing column in %s (word_col=%s, conc_col=%s) - skipping",
                     spec$file, spec$word_col, spec$conc_col))
    return(NULL)
  }
  word <- trimws(as.character(df[[spec$word_col]]))
  conc_raw <- suppressWarnings(as.numeric(df[[spec$conc_col]]))
  # some sources (verified by inspecting known concrete/abstract words at
  # each end of the scale) run high=abstract/low=concrete; flip those here
  # (for ranking only) so "higher = more concrete" holds uniformly before
  # percentile ranking. Keep the untouched raw value for display.
  conc <- if (isTRUE(spec$invert)) -conc_raw else conc_raw
  if (!is.null(spec$gloss_col) && spec$gloss_col %in% names(df)) {
    gloss <- tolower(trimws(as.character(df[[spec$gloss_col]])))
    gloss[gloss == ""] <- NA
  } else {
    gloss <- rep(NA_character_, nrow(df))
  }
  keep <- !is.na(word) & word != "" & !is.na(conc)
  out <- data.frame(word = word[keep], concrete = conc[keep], concrete_raw_display = conc_raw[keep],
                     gloss_english = gloss[keep], stringsAsFactors = FALSE)
  if (nrow(out) == 0) return(NULL)
  # collapse duplicate words within a single source (average concreteness,
  # keep first non-missing gloss)
  agg_num <- aggregate(cbind(concrete, concrete_raw_display) ~ word, data = out, FUN = mean)
  agg_gloss <- aggregate(gloss_english ~ word, data = out,
                          FUN = function(x) { x <- x[!is.na(x)]; if (length(x)) x[1] else NA_character_ },
                          na.action = na.pass)
  agg <- merge(agg_num, agg_gloss, by = "word", all.x = TRUE)
  agg$source <- spec$source
  # some sources are themselves curated noun lists (per the source paper),
  # so isolated single-token udpipe tagging - which lacks sentence context
  # and can mistag genuine nouns - is skipped for them (see assume_noun in
  # the manifest)
  attr(agg, "assume_noun") <- isTRUE(spec$assume_noun)
  agg
}

# ---- 3. Helper: udpipe noun filter ------------------------------------------
tag_nouns <- function(words, model_path) {
  model <- udpipe_load_model(model_path)
  ann <- udpipe_annotate(model, x = words, doc_id = seq_along(words), tagger = "default", parser = "none")
  ann <- as.data.frame(ann)
  # keep only words that tokenize to a single token tagged NOUN
  n_tokens <- table(ann$doc_id)
  single_tok_ids <- names(n_tokens)[n_tokens == 1]
  noun_ids <- ann$doc_id[ann$doc_id %in% single_tok_ids & ann$upos == "NOUN"]
  as.integer(noun_ids)
}

# ---- 4. Run pipeline per language -------------------------------------------
summary_rows <- list()

for (lang in names(manifest)) {
  cfg <- manifest[[lang]]
  cat("\n===", lang, "===\n")

  loaded <- lapply(cfg$sources, load_source)
  loaded <- Filter(Negate(is.null), loaded)
  if (length(loaded) == 0) {
    cat("  no usable sources, skipping\n")
    next
  }

  # ensure udpipe model is available
  model_file <- list.files(model_dir, pattern = paste0("^", cfg$udpipe_model, "-.*\\.udpipe$"), full.names = TRUE)
  if (length(model_file) == 0) {
    dl <- udpipe_download_model(language = cfg$udpipe_model, model_dir = model_dir)
    model_file <- dl$file_model
  } else {
    model_file <- model_file[1]
  }

  # tag nouns per source (word lists differ by source, so tag each source's
  # unique words once). Sources flagged assume_noun (curated noun lists per
  # their source paper) skip udpipe tagging entirely, since isolated
  # single-token tagging without sentence context can mistag genuine nouns.
  filtered <- lapply(loaded, function(src) {
    if (isTRUE(attr(src, "assume_noun"))) {
      cat(sprintf("  %-30s raw=%5d  nouns=%5d (assumed noun list, no POS filter)\n",
                  unique(src$source), nrow(src), nrow(src)))
      return(src)
    }
    uw <- unique(src$word)
    noun_idx <- tag_nouns(uw, model_file)
    noun_words <- uw[noun_idx]
    src_noun <- src[src$word %in% noun_words, ]
    cat(sprintf("  %-30s raw=%5d  nouns=%5d\n", unique(src$source), nrow(src), nrow(src_noun)))
    src_noun
  })
  filtered <- Filter(function(x) nrow(x) > 0, filtered)
  if (length(filtered) == 0) {
    cat("  no nouns survived tagging, skipping\n")
    next
  }

  # percentile rank within each source (higher concreteness -> higher pctile)
  ranked <- lapply(filtered, function(src) {
    src$percentile <- rank(src$concrete, ties.method = "average") / nrow(src)
    src
  })
  long <- do.call(rbind, ranked)

  # combine across sources per word (case-insensitive key for matching)
  long$word_key <- tolower(long$word)
  combined <- aggregate(percentile ~ word_key, data = long, FUN = mean)
  names(combined)[2] <- "mean_percentile"
  n_src <- aggregate(source ~ word_key, data = long, FUN = function(x) length(unique(x)))
  names(n_src)[2] <- "n_sources"
  src_list <- aggregate(source ~ word_key, data = long, FUN = function(x) paste(sort(unique(x)), collapse = ";"))
  names(src_list)[2] <- "sources"
  conc_list <- aggregate(concrete_raw_display ~ word_key, data = long, FUN = function(x) mean(x))
  names(conc_list)[2] <- "mean_raw_concreteness"
  gloss_list <- aggregate(gloss_english ~ word_key, data = long,
                           FUN = function(x) { x <- x[!is.na(x)]; if (length(x)) names(sort(table(x), decreasing = TRUE))[1] else NA_character_ },
                           na.action = na.pass)
  # keep one display form of the word (first occurrence, original case)
  display <- long[!duplicated(long$word_key), c("word_key", "word")]

  final <- Reduce(function(a, b) merge(a, b, by = "word_key"),
                   list(display, combined, n_src, src_list, conc_list, gloss_list))
  final <- final[order(-final$mean_percentile), ]
  final$word_key <- NULL

  # Selection: "core" tier uses a slightly relaxed cutoff below the strict
  # median (CORE_THRESHOLD, below) so thin-pool languages aren't reduced to
  # a tiny quality-controlled set, while still excluding the bottom of the
  # pool rather than taking literally everything regardless of concreteness.
  # "selected" = core tier, capped at 4000 (only binds for Dutch). This does
  # NOT pull in translated words from other languages - see
  # build_shared_core.R for the cross-linguistic overlap via gloss matching.
  CORE_THRESHOLD <- 0.4
  final$tier <- ifelse(final$mean_percentile > CORE_THRESHOLD, "core", "extended")
  n_keep <- min(sum(final$tier == "core"), 4000)
  final$selected <- FALSE
  final$selected[order(-final$mean_percentile)[seq_len(n_keep)]] <- TRUE

  out_path <- file.path(out_dir, folder_name(lang), paste0(lang, "_concreteness_candidates.csv"))
  write.csv(final, out_path, row.names = FALSE)

  cat(sprintf("  TOTAL pooled nouns=%d | core(above-median)=%d | selected(core+extended, capped 4000)=%d -> %s\n",
              nrow(final), sum(final$tier == "core"), sum(final$selected), out_path))

  summary_rows[[lang]] <- data.frame(
    language = lang,
    n_sources = length(filtered),
    pooled_nouns = nrow(final),
    core_tier = sum(final$tier == "core"),
    extended_tier_selected = sum(final$selected & final$tier == "extended"),
    selected = sum(final$selected),
    n_with_gloss = sum(!is.na(final$gloss_english) & final$selected)
  )
}

summary_df <- do.call(rbind, summary_rows)
write.csv(summary_df, file.path(out_dir, "stimuli_pool_summary.csv"), row.names = FALSE)
cat("\n\n=== SUMMARY ===\n")
print(summary_df)
