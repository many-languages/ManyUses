# Per-SOURCE raw concreteness descriptive stats (M/SD/Min/Max), restricted
# to each language's actually-SELECTED words -- a supplement to
# build_table2_stats.R's pooled percentile-rank stats.
#
# Deliberately NOT pooled/averaged across sources onto one raw number per
# language: different sources use different native scales (1-5/1-7/1-9
# Likert, and at least one -- DellaRosa2010, Italian -- uses something
# like a 0-700 scale, not documented in build_stimuli_pools.R's manifest
# and not rescaled there), so averaging raw values across sources without
# correcting for that first would silently mix incompatible numbers (e.g.
# Italian's naive mean_raw_concreteness maxes out at 700). Percentile-rank
# is still the right way to POOL across sources (see build_table2_stats.R
# and README.md) -- this script is for reporting each source's own
# internally-consistent raw numbers, not for re-pooling.
#
# Extracts just the `manifest` list from build_stimuli_pools.R (word_col/
# conc_col/invert per source) rather than duplicating it by hand, without
# running that script's own (slow, udpipe-based) selection pipeline.

lines <- readLines("build_stimuli_pools.R")
manifest_start <- grep("^manifest <- list\\(", lines)
manifest_end <- grep("^folder_name <- function", lines)[1] - 3 # back up past the blank line + comment
manifest_code <- paste(lines[manifest_start:manifest_end], collapse = "\n")
eval(parse(text = manifest_code))

languages <- c("Dutch", "French", "Italian", "Portuguese", "Chinese_Simplified",
               "Spanish", "Russian", "Chinese_Traditional", "Turkish", "German",
               "Galician", "Polish")

all_rows <- list()

for (lang in languages) {
  candidates <- read.csv(file.path(lang, paste0(lang, "_concreteness_candidates.csv")), stringsAsFactors = FALSE)
  selected_words <- candidates$word[candidates$selected == TRUE]

  for (spec in manifest[[lang]]$sources) {
    src_path <- file.path("source_datasets", spec$file)
    src <- read.csv(src_path, stringsAsFactors = FALSE)
    if (!spec$word_col %in% names(src)) next

    sel_rows <- src[src[[spec$word_col]] %in% selected_words, ]
    vals <- sel_rows[[spec$conc_col]]
    vals <- suppressWarnings(as.numeric(vals))
    vals <- vals[!is.na(vals)]
    if (length(vals) == 0) next

    all_rows[[length(all_rows) + 1]] <- data.frame(
      language = lang,
      source = spec$source,
      n_words_matched = length(vals),
      M = mean(vals),
      SD = sd(vals),
      Min = min(vals),
      Max = max(vals),
      inverted_in_pooling = isTRUE(spec$invert),
      stringsAsFactors = FALSE
    )
  }
}

raw_stats <- do.call(rbind, all_rows)
write.csv(raw_stats, "table2_raw_stats_by_source.csv", row.names = FALSE)
cat("Wrote table2_raw_stats_by_source.csv --", nrow(raw_stats), "language x source rows.\n\n")
print(raw_stats, digits = 3)

cat("\nFlagging any source whose Max looks like a non-standard scale\n")
cat("(i.e. not in a plausible 1-10ish range):\n")
print(raw_stats[raw_stats$Max > 10, c("language", "source", "Min", "Max")])

# ---- Formatted markdown, one row per language x source --------------------
citations <- read.csv("source_datasets/citations/citation_metadata.csv", stringsAsFactors = FALSE)
base_key_of <- function(raw_key) {
  candidates <- citations$key[startsWith(raw_key, citations$key)]
  if (length(candidates) == 0) return(raw_key)
  candidates[which.max(nchar(candidates))]
}
raw_stats$base_key <- vapply(raw_stats$source, base_key_of, character(1))
raw_stats$citation <- citations$short_cite[match(raw_stats$base_key, citations$key)]
raw_stats$citation[is.na(raw_stats$citation)] <- raw_stats$base_key[is.na(raw_stats$citation)]

# Distinguish same-paper comparison variants (e.g. Grigoriev2026's three
# rater-group comparisons) so identically-cited rows with very different
# numbers don't look like a contradiction.
has_cmp <- grepl("_cmp_", raw_stats$source)
raw_stats$variant <- mapply(function(src, base, flag) {
  if (!flag) return("")
  sub(paste0("^", base, "_cmp_"), "", src)
}, raw_stats$source, raw_stats$base_key, has_cmp)
raw_stats$citation_display <- ifelse(nzchar(raw_stats$variant),
                                      paste0(raw_stats$citation, " [", raw_stats$variant, "]"),
                                      raw_stats$citation)

raw_stats <- raw_stats[order(raw_stats$language, raw_stats$source), ]

md_lines <- c(
  "| Language | Source | n words | M (SD) | Min | Max | Note |",
  "|---|---|---|---|---|---|---|"
)
for (i in seq_len(nrow(raw_stats))) {
  r <- raw_stats[i, ]
  note <- if (r$source == "DellaRosa2010") {
    "**Scale mismatch -- 0-700ish, not comparable to other Italian sources' 1-9 range**"
  } else if (isTRUE(r$inverted_in_pooling)) {
    "Raw scale runs high=abstract (inverted during pooling) -- low raw values here mean MORE concrete, opposite of every other row"
  } else ""
  md_lines <- c(md_lines, sprintf(
    "| %s | %s | %d | %.2f (%.2f) | %.2f | %.2f | %s |",
    gsub("_", " ", r$language), r$citation_display, r$n_words_matched, r$M, r$SD, r$Min, r$Max, note
  ))
}
writeLines(md_lines, "table2_raw_stats_by_source.md")
cat("\nWrote table2_raw_stats_by_source.md\n")
