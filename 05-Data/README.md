# 05-Data

Data and processing code for the Many Uses project, collected after stimulus
selection (`01-Stimuli/`). Folder layout separates data by identifiability stage:

```
05-Data/
  Raw/            # data exactly as exported/collected (may contain identifiers)
  Deidentified/   # Raw with identifiers stripped, nothing else changed
  Processed/      # cleaned/scored/analysis-ready data, derived from Deidentified
  Code/           # scripts that produce Deidentified from Raw, and Processed from Deidentified
```

`Raw/` should never be committed if it contains identifying information — check
`.gitignore` covers it before adding files. `Deidentified/` and `Processed/`
should be reproducible from `Raw/` by re-running the scripts in `Code/`.
