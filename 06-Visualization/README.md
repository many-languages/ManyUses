# 06-Visualization

`shinydashboard` progress dashboard for the Many Uses project. Reads only
local files already produced by the `02-Task` and `05-Data` pipelines --
no live formr calls or credentials needed to run it.

```
06-Visualization/
  app.R          the dashboard (ui + server)
  R/
    load_data.R    all data-loading logic, kept separate from app.R so it
                    can be tested/sourced on its own (see its own header
                    comments for what each function reads and why)
```

## Run it

```r
shiny::runApp("06-Visualization")
```

or open `app.R` in RStudio and click **Run App**.

## Tabs

- **Overview** — overall percent completed (across active languages'
  word pools, capped at 100% per word so an over-normed word doesn't
  inflate the total), number of subjects, and a participants-by-lab
  summary table.
- **Participant Codes** — a searchable table (date/time, lab ID, code)
  so researchers can check their own participants' codes against what
  was actually recorded.
- **Languages** — one subtab per language (from
  `02-Task/languages_status.csv`), each a searchable table of every cue
  word in that language's pool with a valid-response progress bar
  (target: `select_words.R`'s own `n_cutoff`, 30 responses/cue).

## Data sources, and what's still a placeholder

- Word progress: `02-Task/<Language>/word_n_summary.csv` for the full
  cue list, joined against `05-Data/Processed/<Language>/processed_*.csv`
  (the cleaned, non-answer-filtered output of
  `05-Data/Code/process_responses.R`) for actual valid-response counts —
  **not** `word_n_summary.csv`'s own `n_total`, which isn't auto-updated
  yet (see `02-Task/English/README.md`).
- **Participant codes / lab IDs are a placeholder.** The consent form
  that will actually produce this data doesn't exist yet. Right now
  `R/load_data.R`'s `load_consent_codes()` reads
  `05-Data/Raw/<Language>/consent_codes.csv` if present, else falls back
  to a synthetic demo file
  (`05-Data/Synthetic/<Language>/consent_codes_synthetic.csv`, from
  `05-Data/Code/generate_synthetic_consent.R`) so the dashboard has
  something to show. **TODO once the consent form is built:** replace
  `load_consent_codes()`'s body with a formr pull (mirroring
  `02-Task/English/pull_results.R`'s pattern) against wherever consent
  data lands — the function's return shape (`timestamp`, `lab_id`,
  `participant_code`, `language`) is deliberately kept the same either
  way, so nothing downstream of it (the Overview/Participant Codes tabs)
  needs to change.
