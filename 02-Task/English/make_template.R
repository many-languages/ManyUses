# Per-language content for the shared make_template() in
# ../lib/make_template_core.R: English instructional text and 30 English
# placeholder words (never actually shown -- build_formr_xlsx.R always
# overwrites them at rebuild time), split across this language's survey
# parts (survey_parts.R -- shared with build_formr_xlsx.R / push_to_formr.R
# / pull_results.R). One <survey>_template.xlsx is generated per part.
# Not part of the regular cron pipeline — only re-run this if BLOCKS_PER_PART,
# PART_NAMES, or the instructional text needs to change.

source("survey_parts.R")
source("../lib/make_template_core.R")

words <- c(
  "ball", "brick", "cup", "key", "paperclip", "rope", "spoon", "towel", "box", "chair",
  "hammer", "bottle", "pencil", "umbrella", "wallet", "mirror", "blanket", "kettle", "ladder", "bucket",
  "scissors", "candle", "broom", "basket", "glove", "whistle", "anchor", "drum", "lantern", "compass"
)
stopifnot(length(words) == length(PART_NAMES) * BLOCKS_PER_PART) # manuscript: 30 randomly selected nouns per participant

instructions_label <- paste(
  "## Instructions",
  " ",
  "In this section, you will be presented with a series of object words. For each word, please list as many possible uses as you can think of.",
  " ",
  "Please keep in mind that a single object can have more than one use. For example, a ball can be thrown, bounced, kicked, or stepped on.",
  " ",
  "On each page, put **one different use in each box**. Avoid listing the same use in different words.",
  " ",
  "You will see five boxes first. If you can think of more uses, you can add up to five additional boxes, one at a time.",
  sep = "\n"
)

prompt_fn <- function(word) {
  paste0("### Word: **", word, "**\n \n Please name all of the ways someone could use a **",
         word, "**. Put one different use in each box.")
}

for (p in seq_along(PART_NAMES)) {
  part_words <- words[((p - 1) * BLOCKS_PER_PART + 1):(p * BLOCKS_PER_PART)]
  make_template(
    words = part_words,
    # Parts are chained into one formr run -- instructions belong on the
    # first part only, not repeated on every part.
    instructions_label = if (p == 1) instructions_label else NULL,
    prompt_fn = prompt_fn,
    out_path = paste0(PART_NAMES[p], "_template.xlsx")
  )
}
