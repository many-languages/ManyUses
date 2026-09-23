# Per-language content for the shared make_template() in
# ../lib/make_template_core.R: English instructional text and 30 English
# placeholder words (never actually shown -- build_formr_xlsx.R always
# overwrites them at rebuild time). Not part of the regular cron pipeline —
# only re-run this if N_BLOCKS or the instructional text needs to change.

source("../lib/make_template_core.R")

words <- c(
  "ball", "brick", "cup", "key", "paperclip", "rope", "spoon", "towel", "box", "chair",
  "hammer", "bottle", "pencil", "umbrella", "wallet", "mirror", "blanket", "kettle", "ladder", "bucket",
  "scissors", "candle", "broom", "basket", "glove", "whistle", "anchor", "drum", "lantern", "compass"
)
stopifnot(length(words) == 30) # manuscript: 30 randomly selected nouns per participant

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

make_template(
  words = words,
  instructions_label = instructions_label,
  prompt_fn = prompt_fn,
  out_path = "word_ratings_template.xlsx"
)
