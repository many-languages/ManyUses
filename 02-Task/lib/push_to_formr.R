# Shared across all languages -- do not copy this into a language folder.
# Pushes the freshly-built word_ratings.xlsx to the live formr study, so a
# rebuilt word set actually reaches formr -- rebuilding the file
# locally/on-server does nothing on its own until this runs too.
# formr_api_upload_survey() syncs to an existing study in place (confirmed).
# Run with the working directory set to the target language's folder (see
# build_formr_xlsx.R) -- "word_ratings.xlsx" resolves against that.
#
# Requires FORMR_EMAIL / FORMR_PASSWORD as environment variables (see
# run_update_and_push.sh).

library(formr)

formr_connect(
  email = Sys.getenv("FORMR_EMAIL"),
  password = Sys.getenv("FORMR_PASSWORD"),
  host = Sys.getenv("FORMR_HOST", unset = formr_last_host())
)

formr_api_upload_survey(file_path = "word_ratings.xlsx")

cat("Pushed word_ratings.xlsx to formr.\n")
