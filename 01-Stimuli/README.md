# Many Uses: Cross-Linguistic Stimuli Selection

This folder documents and implements the stimulus-selection pipeline for the Many
Uses affordance-norming project (Stage 1 registered report). It covers two
separate jobs: (1) picking each language's own candidate concrete nouns, and
(2) finding which concepts overlap across languages, for cross-linguistic
comparisons (Aim 4) and the SPAML priming match (Aim 3).

## Folder layout

```
01-Stimuli/
  English/
    English_Previous_Maxwell2024.csv   # the 2825 nouns from Maxwell et al. (2024), with N and needs_norming
    English_Combined_4000.csv          # full 4000-cue English set (Old + New), with N and needs_norming
  {Language}/
    {Language}_concreteness_candidates.csv   # one output file per non-English language (see below)
  source_datasets/                     # local copies of the raw semanticprimeR CSVs used as inputs
  udpipe_models/                       # downloaded POS-tagging models (auto-populated, not source-controlled data)
  build_stimuli_pools.R                # main pipeline: per-language candidate selection
  build_shared_core.R                  # cross-linguistic overlap analysis
  apply_hack_translations.py           # patches in English glosses for languages whose sources lack one
  stimuli_pool_summary.csv             # one-line-per-language summary of build_stimuli_pools.R's output
  shared_core_candidates.csv           # every English-gloss concept found, with per-language coverage
  shared_core_top500.csv               # the 500 most cross-linguistically shared concepts
```

## English (handled separately from the pipeline below)

English follows the Stage 1 manuscript's own plan rather than the concreteness-pooling
algorithm used for the other languages, because it starts from Maxwell et al. (2024)'s
already-collected data rather than raw concreteness norms:

- `English_Previous_Maxwell2024.csv`: the 2825 nouns Maxwell et al. (2024) already normed,
  with each word's actual participant count (`n_previous`, pulled from their `Cue Table.csv`)
  and a `needs_norming` flag (`n_previous < 30`).
- `English_Combined_4000.csv`: those 2825 words plus 1175 new nouns from Pexman et al.'s
  (2019) BOI norms, giving the full 4000-cue target set with the same N/needs_norming info.
  1524 of the 2825 original words fall under 30 responses and need topping up; the 1175 new
  words need full norming from scratch. Total: 2699 cues need data collection.

## Non-English languages: `build_stimuli_pools.R`

### Why this exists

The Stage 1 draft originally proposed selecting per-language concreteness norms with a
single source per language and a z-score-above-zero cutoff. Two problems with that:
source pools were wildly uneven in size across languages (a few hundred words for some,
tens of thousands for others), and z-scoring assumes distribution shapes that don't hold
up well for small or skewed samples. This script replaces that with a pooled,
percentile-rank approach that degrades gracefully when a language only has one thin source.

### Method, step by step

1. **Pool every available concreteness source per language.** Where semanticprimeR has
   multiple concreteness datasets for a language (e.g., Spanish has 6, Italian has 4),
   all of them are used rather than picking just one — this was the single biggest fix
   for languages the Stage 1 draft under-served (Chinese Simplified went from one
   150-word source to a 2,581-word pool; Portuguese from ~1,700 to 2,872).

2. **POS-tag every candidate word with `udpipe`**, restricting to nouns (a word is only
   kept if it tokenizes to a single token tagged `NOUN`). This replaces relying on
   whatever POS information a source happened to provide (or didn't).

3. **Percentile-rank concreteness within each source**, not raw z-scores. A word's rank
   is its position (0-1) among the nouns in that specific source. This is what lets
   sources on different scales (1-5, 1-7, 1-9 Likert) combine sensibly.

4. **Correct scale-direction inversions.** Three sources were found, by inspection and
   cross-source correlation, to run *high = abstract / low = concrete* — the opposite
   of the field's usual convention: Kanske2010 (German), Liu2025 (Chinese Simplified),
   and both Soloviev2022 sub-scores inside Grigoriev2026 (Russian). These are flipped
   (`invert = TRUE` in the manifest) before ranking. Yao2017 (Chinese Simplified) looked
   ambiguous on inspection but showed ~zero correlation with a confirmed-inverted source,
   so it was left un-flipped rather than guessed at.

4b. **Skip POS-filtering for sources that are already curated noun lists.** udpipe tags
   each candidate word in isolation, with no sentence context, which can mistag genuine
   nouns (this dropped Kanske2010's German pool from 1000 to 436 before the fix). If a
   source's own paper explicitly describes it as an all-noun list (verify this - don't
   assume), flag it `assume_noun = TRUE` in the manifest to skip tagging for that source
   entirely. Kanske2010 is the current example: LANG's own paper describes it as "a list
   of 1,000 German nouns," so all 1000 are now kept rather than the udpipe-filtered 436.

5. **Combine ranks across sources per word** (case-insensitive match on the word form).
   A word's `mean_percentile` is the average of its ranks across every source it appears
   in de-duplicated); `n_sources` and `sources` record how many/which sources contributed.

6. **Select.** `tier` is `"core"` if `mean_percentile > 0.4`, else `"extended"` (a relaxed
   version of "above the mean/median" that leaves more candidates available than a strict
   0.5 cutoff would, particularly for thin-pool languages). `selected` takes every `core`
   word, capped at 4000 if the core tier exceeds that (currently only binds for Dutch).
   For every other language, `selected` == the entire core tier — i.e., languages take as
   many decent-concreteness words as they have, rather than being artificially capped
   below what's available.

### Known data-quality fixes made along the way (see inline comments in the script)

- `Soares2017.csv`'s word column was mislabeled `word_spanish` in semanticprimeR itself;
  it is actually Soares et al. (2017)'s **Portuguese** Minho Word Pool. Fixed at the
  source (both in semanticprimeR and here) and moved from the Spanish to the Portuguese
  source list.
- `Diez-Alamo2018a.csv`'s gloss column had a typo (`translte_word_english`); fixed at
  the source.
- Croatian was considered but excluded: the only available "concreteness" source
  (Bogunovic2023) is a corpus study of English loanwords adapted into Croatian, not a
  general-vocabulary norm set, and would have biased the pool toward anglicisms.
- Chinese Traditional's only source (Su2023) rates single *characters*, not multi-character
  words — a different unit than the word-level norms used elsewhere. Included anyway
  (many single characters are standalone concrete nouns) but worth remembering when
  comparing pool sizes/composition against the other languages.

### Current language set and pool sizes

Run `Rscript build_stimuli_pools.R` to regenerate; current output (`stimuli_pool_summary.csv`):

| Language | Sources pooled | Pooled nouns | Selected |
|---|---|---|---|
| Dutch | 2 | 14,464 | 4,000 (capped) |
| Polish | 1 | 2,826 | 1,689 |
| Chinese Traditional | 1 | 2,793 | 1,664 |
| Portuguese | 4 | 2,872 | 1,712 |
| Chinese Simplified | 4 | 2,581 | 1,560 |
| Spanish | 6 | 2,199 | 1,294 |
| Russian | 3 | 1,752 | 1,068 |
| Galician | 1 | 1,034 | 624 |
| French | 2 | 1,177 | 714 |
| Italian | 4 | 1,137 | 661 |
| Turkish | 1 | 367 | 221 |
| German | 1 | 1,000 | 600 |

Dutch and Turkish are the two extremes: Dutch's source (Brysbaert et al., 2014) alone
has ~30,000 rated words, while Turkish rests on a single ~570-word source. Pool size
differences of this kind are a real constraint on the cross-linguistic "shared core"
(see below), not an artifact of the selection method. German initially looked similarly
thin (436 nouns from a 1000-word source) until the assume_noun fix above revealed the
gap was a tagging artifact, not a true data limitation - Kanske2010 (LANG) is a fully
curated 1000-word noun list, all of which are now included.

## Cross-linguistic overlap: `build_shared_core.R`

Picking each language's own best words does not, by itself, guarantee any given concept
exists across multiple languages — two independent top-concreteness lists don't
naturally overlap much. This script instead groups every *selected* candidate word by
its English gloss and reports how many languages share each concept.

### English-gloss coverage

Several source datasets include their own `translate_word_english` (or equivalent)
column, which is used directly. Three languages' sources had no such column at all —
**Dutch, German, and Chinese Traditional** — so their top-ranked candidates (up to 300
each, or all 263 for German) were given "hack" English glosses based on the model's own
linguistic knowledge (`apply_hack_translations.py`), **not** a verified dictionary or
native-speaker check. These are flagged `gloss_source = hack_llm_translation` in the
per-language CSVs and `includes_hack_translation = TRUE` in the shared-core output.
Treat any shared-core row touching one of these three languages as needing a real
translator's sign-off before being locked into the design.

### Output

- `shared_core_candidates.csv`: every distinct English gloss found, with
  `n_languages_covered`, which languages, whether it's already in English's 4000-cue
  list, and the actual word in each language.
- `shared_core_top500.csv`: the same table's top 500 rows, ranked by (1) how many
  languages share the concept, then (2) how concreteness-central it is on average
  across those languages. This is the list to use when picking which concepts should
  be prioritized for guaranteed cross-linguistic coverage.

### What this revealed

Genuine full-overlap-across-every-language concepts are rare — with 12 gloss-matchable
languages, **zero** concepts are shared by all of them (max is 10/12, "train"). This
isn't a bug: it's the expected result of combining independent, partial-vocabulary
samples (each source only rates a few hundred to a few thousand words), and it means
the Stage 1 draft's original plan of finding organic overlap across every target
language's own norms won't produce a usable "core" set. The practical fix, if a fuller
shared core is needed, is to go the other direction: start from a chosen base list
(e.g., the top of `shared_core_top500.csv`, or English's own 4000) and translate it
outward into every target language, rather than relying on pre-existing native norm
coverage for the exact translated form.

## Reproducing this from scratch

```r
# 1. Build each language's own candidate pool
Rscript build_stimuli_pools.R

# 2. Patch in English glosses for Dutch/German/Chinese Traditional (no native gloss source)
```
```bash
python3 apply_hack_translations.py
```
```r
# 3. Build the cross-linguistic shared-core analysis
Rscript build_shared_core.R
```

Re-running step 1 regenerates every `{Language}_concreteness_candidates.csv` from the
raw sources in `source_datasets/`, which wipes the hack-translation columns for
Dutch/German/Chinese Traditional — always re-run step 2 immediately after step 1, and
step 3 after that, in that order.

## Adding a new language or source

1. Add the raw CSV to `source_datasets/` (copy from semanticprimeR's `datasets/completed/`).
2. Add an entry to the `manifest` list in `build_stimuli_pools.R`: the language's udpipe
   model name (see `udpipe::udpipe_download_model`'s language list for valid names), and
   one `list(file=..., word_col=..., conc_col=..., source=...)` per concreteness source.
   Add `gloss_col = "translate_word_english"` (or whatever the source calls it) if the
   source provides one. Add `invert = TRUE` if you find the source's scale runs
   high=abstract (check by looking at the words with the highest and lowest raw values —
   don't assume the column name "concrete" means the polarity is correct). Add
   `assume_noun = TRUE` if the source paper itself describes the word list as already
   restricted to nouns (check the paper, don't assume) - otherwise isolated single-token
   udpipe tagging can mistag genuine nouns and silently shrink the pool.
3. Add the language's output folder (`mkdir 01-Stimuli/{Language}`).
4. Add the language name to the `languages` vector at the top of `build_shared_core.R`
   if you want it included in cross-linguistic matching.
5. Re-run all three steps above, in order.

Before treating a new source as usable, check: does it measure general vocabulary
concreteness (not a narrow corpus like loanwords or a single semantic domain)? Does its
scale direction actually match "higher = more concrete" (verify with known concrete/
abstract words, don't assume)? Is it a distinct dataset, not a duplicate/re-export of
something already in the manifest?
