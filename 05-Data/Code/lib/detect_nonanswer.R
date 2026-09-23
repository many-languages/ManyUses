# Shared across all languages -- do not copy this into a language folder.
#
# Generalized replacement for the old Affordance Norms project's
# Remove idk.R, which matched ~70 literal strings ("idk", "i dont know",
# "not sure what this is", ...) -- brittle by construction: any typo,
# stray whitespace, or phrasing not already in the list silently passed
# through as a real response. This instead matches on the underlying
# signal (negated knowledge/certainty, or a small set of catch-all
# junk/filler answers), so it generalizes to variants the literal list
# never saw.
#
# Deliberately conservative: flags NON-ANSWERS (participant saying they
# don't know/aren't sure/have no response), not merely unusual or
# low-frequency responses -- an odd-but-real use ("paperweight" for a
# brick) must never be flagged here. When in doubt, don't flag.

library(stringr)

is_nonanswer <- function(response) {
  x <- str_squish(tolower(response))

  # Pure punctuation, empty, or bare "n/a"/"na" with nothing else.
  bare_junk <- x %in% c("", "n/a", "na") | str_detect(x, "^[[:punct:][:space:]]+$")

  # "don't/dont/do not know", "not sure", "no idea/clue" -- with or
  # without a leading "i/i'm/im" and a trailing "what this/that is"
  # style tail. \\bknow\\b etc. so this doesn't fire on unrelated
  # responses that happen to contain a substring like "knowledge".
  negated_knowledge <- str_detect(x, "\\b(don'?t|do not|dont)\\s+know\\b") |
    str_detect(x, "\\bno\\s+(idea|clue)\\b") |
    str_detect(x, "\\bnot\\s+sure\\b") |
    x == "idk" | x == "ikd" # ikd: a real typo seen in the source data this pattern is modeled on

  # Same negated-knowledge signal, but typo-tolerant: a negation word
  # (don't/dont/not/no) plus a token within edit distance 2 of one of
  # the core trigger words (know/sure/idea/clue) -- catches "i dont
  # knwo" without needing it spelled correctly. Requiring BOTH the
  # negation word AND the fuzzy match (not the fuzzy match alone) is
  # what keeps this from firing on real short responses like "snow"
  # that happen to be close to "know" in isolation.
  has_negation <- str_detect(x, "\\b(don'?t|do not|dont|not|no)\\b")
  fuzzy_know <- vapply(str_split(x, "\\s+"), function(toks) {
    toks <- toks[nchar(toks) >= 3 & nchar(toks) <= 7]
    if (!length(toks)) return(FALSE)
    any(vapply(toks, function(t) min(adist(t, c("know", "sure", "idea", "clue"))) <= 2, logical(1)))
  }, logical(1))
  negated_knowledge_fuzzy <- has_negation & fuzzy_know

  # Gibberish/keyboard-mash: a token with no vowels is essentially never
  # a real English use-response ("asdf", "zzz", "wtf") -- length >= 3
  # avoids flagging real short vowel-less words like "by"/"my".
  gibberish <- str_detect(x, "^[^aeiou\\s]{3,}$")

  # Short catch-all filler that isn't a real use response. Includes a
  # couple of common keyboard-mash strings ("asdf", "asdfgh") that the
  # vowel-less gibberish check above can't catch on its own since they
  # happen to contain a vowel letter despite being meaningless.
  filler <- x %in% c("lol", "nothing", "none", "no comment", "unfamiliar with word", "unsure",
                      "asdf", "asdfgh") |
    str_detect(x, "^wtf\\b")

  bare_junk | negated_knowledge | negated_knowledge_fuzzy | gibberish | filler
}
