# Synthetic lab/participant-code data for developing 06-Visualization
# before the real consent form exists.
#
# TODO once the consent form is built: this whole file goes away. The
# real source will be a formr pull (like 02-Task/English/pull_results.R,
# but against whatever survey the consent form lives in), not a static
# CSV -- see 06-Visualization/R/load_data.R's load_consent_codes(), which
# is written against this same column shape (timestamp, lab_id,
# participant_code, language) specifically so swapping the loader's
# source later doesn't require changing anything downstream of it.
#
# Output: 05-Data/Synthetic/<Language>/consent_codes_synthetic.csv

set.seed(20260923)

REPO_ROOT <- "/Users/erinbuchanan/GitHub/Research/2_projects/ManyUses"
LANGUAGE <- "English"
N_PARTICIPANTS <- 47
LABS <- c("MSU", "UNT", "Remote", "PsySciAcc-Partner1")

random_code <- function() paste0(sample(c(LETTERS, 0:9), 8, replace = TRUE), collapse = "")

base_time <- as.POSIXct("2026-09-01 09:00:00", tz = "UTC")
df <- data.frame(
  timestamp = format(base_time + sort(sample(0:(60 * 60 * 24 * 20), N_PARTICIPANTS)), "%Y-%m-%d %H:%M:%S"),
  lab_id = sample(LABS, N_PARTICIPANTS, replace = TRUE, prob = c(0.35, 0.25, 0.3, 0.1)),
  participant_code = replicate(N_PARTICIPANTS, random_code()),
  language = LANGUAGE,
  stringsAsFactors = FALSE
)

out_path <- file.path(REPO_ROOT, "05-Data/Synthetic", LANGUAGE, "consent_codes_synthetic.csv")
write.csv(df, out_path, row.names = FALSE)
cat("Wrote", nrow(df), "synthetic consent codes to", out_path, "\n")
