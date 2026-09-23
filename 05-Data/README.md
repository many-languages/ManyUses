# 05-Data

Data and processing code for the Many Uses project, collected after stimulus
selection (`01-Stimuli/`). Folder layout separates data by identifiability stage:

```
05-Data/
  Raw/            # data exactly as exported/collected (may contain identifiers), gitignored
  Synthetic/       # fake but structurally real data (same shape as Raw), for developing
                    # against before real participant data exists -- see Code/
                    # generate_synthetic_data.R / generate_synthetic_consent.R
  Deidentified/   # Raw with identifiers stripped, nothing else changed -- placeholder,
                    # not implemented yet (see below)
  Processed/      # cleaned/analysis-ready data
  Code/           # scripts that produce Processed from Raw/Synthetic
```

`Raw/` should never be committed if it contains identifying information — check
`.gitignore` covers it before adding files.

**Current pipeline goes straight `Raw`/`Synthetic` → `Processed`, skipping
`Deidentified/`** — `Code/process_responses.R` (reshape to long format,
resolve each response to the word actually shown via
`word_assignment_log.csv`, drop non-answers, spellcheck, lemmatize/POS-tag;
see its own header and `lib/`'s files) doesn't strip any identifiers,
because survey responses in this project don't carry participant identity
in the first place — that only enters once the consent form (still
unbuilt, see `06-Visualization/README.md`) exists. Revisit whether a real
`Deidentified/` stage is needed once consent data actually flows in.
