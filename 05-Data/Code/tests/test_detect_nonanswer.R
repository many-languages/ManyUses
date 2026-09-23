# Run with: Rscript tests/test_detect_nonanswer.R (from 05-Data/Code/)
#
# Regression tests for lib/detect_nonanswer.R, covering exactly the junk
# categories injected by Code/generate_synthetic_data.R (idk-variants
# with typos/whitespace, bare punctuation, off-topic gibberish,
# misspelled real words) plus the real-word false-positive cases found
# while building this against the synthetic data (words that merely
# CONTAIN a trigger substring, like "knowledge"/"treasure"/"measure",
# and short words near-but-not-actually junk like "snow").

library(testthat)
source("lib/detect_nonanswer.R")

test_that("idk-style non-answers are flagged, including typos/whitespace/case", {
  expect_true(is_nonanswer("idk"))
  expect_true(is_nonanswer("IDK"))
  expect_true(is_nonanswer("\tidk"))
  expect_true(is_nonanswer("i don't know"))
  expect_true(is_nonanswer("i dont know"))
  expect_true(is_nonanswer("I Dont Knwo")) # real typo seen in generated data
  expect_true(is_nonanswer("not sure"))
  expect_true(is_nonanswer("im not sure"))
  expect_true(is_nonanswer("no idea"))
  expect_true(is_nonanswer("no clue"))
})

test_that("bare punctuation and empty/n-a responses are flagged", {
  expect_true(is_nonanswer(""))
  expect_true(is_nonanswer(" "))
  expect_true(is_nonanswer("?"))
  expect_true(is_nonanswer("??"))
  expect_true(is_nonanswer("n/a"))
  expect_true(is_nonanswer("na"))
})

test_that("off-topic filler is flagged", {
  expect_true(is_nonanswer("lol"))
  expect_true(is_nonanswer("nothing"))
  expect_true(is_nonanswer("asdf"))
  expect_true(is_nonanswer("asdfgh"))
  expect_true(is_nonanswer("wtf is this"))
})

test_that("real words are never flagged, even when they contain a trigger substring", {
  expect_false(is_nonanswer("knowledge"))
  expect_false(is_nonanswer("acknowledge"))
  expect_false(is_nonanswer("treasure"))
  expect_false(is_nonanswer("measure"))
  expect_false(is_nonanswer("leisure"))
  expect_false(is_nonanswer("ensure"))
  expect_false(is_nonanswer("reassure"))
  expect_false(is_nonanswer("idea")) # standalone -- "no idea" is junk, "idea" alone is a real response
  expect_false(is_nonanswer("snow")) # close to "know" but no negation present -- must not fire alone
})

test_that("real plausible use-responses are never flagged", {
  expect_false(is_nonanswer("throw"))
  expect_false(is_nonanswer("hammer"))
  expect_false(is_nonanswer("paperweight"))
  expect_false(is_nonanswer("hula hoop"))
})
