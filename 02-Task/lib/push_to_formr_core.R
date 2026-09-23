# Shared across all languages -- do not copy this into a language folder.
# Pushes each freshly-built xlsx (one per formr survey part -- see
# build_formr_xlsx_core.R's header for why a language may have more than
# one) to its live formr study, so a rebuilt word set actually reaches
# formr -- rebuilding the file locally/on-server does nothing on its own
# until this runs too. formr_api_upload_survey() syncs to an existing
# study in place (confirmed). Run with the working directory set to the
# target language's folder -- file_paths resolve against that.
#
# NOTE: this hits formr's actual REST API (see
# https://formr-admin.uni-muenster.de/public/documentation#api), which is
# OAuth2 client-credentials -- the same session pull_results_core.R now
# authenticates with too (see its header). formr_connect()'s cookie-
# session login does not satisfy formr_api_upload_survey()'s session
# requirement, so this uses formr_api_authenticate() with a
# client_id/client_secret pair instead.
#
# Requires FORMR_CLIENT_ID / FORMR_CLIENT_SECRET as environment variables
# (see run_update_and_push.sh / 02-Task/.env.example) -- create them at
# admin/account#api on your formr instance with at least the survey:write
# scope.

library(formr)

push_to_formr <- function(file_paths) {
  formr_api_authenticate(
    client_id = Sys.getenv("FORMR_CLIENT_ID"),
    client_secret = Sys.getenv("FORMR_CLIENT_SECRET"),
    host = Sys.getenv("FORMR_HOST", unset = formr_last_host())
  )

  for (f in file_paths) {
    formr_api_upload_survey(file_path = f)
    cat("Pushed", f, "to formr.\n")
  }
}
