[README.md](https://github.com/user-attachments/files/34702007/README.md)
# Multilingual children in Québec: survey data preparation and analyses

This repository contains the R Markdown workflow used to prepare and analyse parent-report data on children's multilingual language exposure, active language use, interlocutor matching, family practices, and societal language context in Québec. The analyses include descriptive summaries, correlations, mixed-effects models, logistic regression models, exploratory analyses of societal/Community versus Heritage languages, and figures and tables for the manuscript and supplementary materials.

> **Important reproducibility requirement:** Before running the main analysis, obtain **Statistics Canada's 2021 Census Table 98-10-0216-01** (*Knowledge of languages by age and gender: Canada, provinces and territories, census divisions and census subdivisions*). The main R Markdown currently reads a **local Parquet copy** of that table from an absolute Windows path. The Census file is **not automatically supplied by this repository**, and the analysis will stop if the path is not updated. See [Census setup](#census-setup-required) below.

## Workflow and scripts

Run the scripts in this order from the root of the RStudio project (`2025_Census_paper.Rproj`):

1. **`First_collection_clean.Rmd`** — processes the first survey collection, applies exclusions and recodes variables to align with the subsequent collection, and writes `Anonymized_data/first_collection_w_predictors.csv`.
2. **`2025_census_analyses.Rmd`** — imports the later survey collection and the cleaned first collection; combines and checks the data; derives Census-division multilingualism rates and language-specific regional speaker rates; then performs the descriptive and inferential analyses and exports figures and Word tables.

A separate `2025_analyses_no_AOA.Rmd` may be present in the working folder. It is not one of the two scripts reviewed for this README and is not required in the documented execution sequence.

### Input files

The reviewed scripts refer to the following files (filenames and capitalization are significant on Linux and macOS):

| File | Used by | Description |
| --- | --- | --- |
| `Anonymized_data/full_first_collection.xlsx` | `First_collection_clean.Rmd` | First-wave survey export |
| `first_collection_cols_clean.csv` | `First_collection_clean.Rmd` | Column-name mapping for the first-wave survey |
| `Anonymized_data/census_data_w_language.xlsx` | `2025_census_analyses.Rmd` | Later-wave survey export |
| `column_clean_names.csv` | `2025_census_analyses.Rmd` | Column-name mapping for the later-wave survey |
| `Anonymized_data/first_collection_w_predictors.csv` | `2025_census_analyses.Rmd` | Output of the first script; input to the second |
| Statistics Canada Table 98-10-0216-01 (English Parquet copy) | `2025_census_analyses.Rmd` | Public Census data used to calculate regional multilingualism rates |

**Folder-name cleanup:** The first script uses `Anonymized_Data/` when reading but `Anonymized_data/` when writing; the main script uses `Anonymized_Data/` when reading. Standardize these references to the actual folder name (for example `Anonymized_data/`) before running on a case-sensitive system. Similarly, verify that both column-mapping CSV files are available: their names differ between scripts.

Survey files may contain sensitive or restricted research information. Do **not** commit participant-level raw or processed data unless your ethics approval, consent, and institutional data-sharing rules explicitly allow it. Consider a separate approved repository or controlled-access process for datasets needed for reproduction.

## Census setup (required)

### Which dataset?

**Statistics Canada, 2021 Census, Table 98-10-0216-01:**

**[Official table and download page](https://www150.statcan.gc.ca/t1/tbl1/en/tv.action?pid=9810021601)**  
**[Download the entire English table (CSV ZIP)](https://www150.statcan.gc.ca/n1/tbl/csv/98100216-eng.zip)**

The table is based on the 2021 Census 25% sample and contains the *Knowledge of languages* measures across Canadian geographies. The analysis filters it to relevant Québec Census Divisions, all ages, all genders, and count statistics. The table can be very large: plan for disk space and downloading time.

### How the supplied code currently opens it

In `2025_census_analyses.Rmd`, find the section that creates `knowledge_con` (near the comment **“Access the locally cached Statistics Canada table”**). The version inspected for this README contains a **hard-coded, user-specific Windows path**:

```r
knowledge_con <- arrow::open_dataset(
  "C:/Users/<USERNAME>/cansim_cache/cansim_98100216_parquet_eng/98100216-eng.parquet"
)
```

That path is not portable. **Simply downloading the ZIP is not sufficient**: the current code expects a Parquet dataset with the column names produced by the `cansim`-cached table (e.g., `Age (7)`, `Gender (3)`, and `Knowledge of languages (324)`). A raw CSV ZIP and a Parquet file are not interchangeable without an import/conversion step and validation of the schema.

**Recommended way to obtain the compatible Parquet cache (when the Statistics Canada service is working):**

```r
install.packages(c("cansim", "arrow"))

# Download/cache the complete table using cansim's large-table interface.
# A successful call creates a cached dataset; confirm its location.
knowledge_con <- cansim::get_cansim_connection(
  "98-10-0216-01",
  language = "english",
  format = "parquet",
  cache_path = "cansim_cache"
)
```

The original analysis used this function but temporarily switched to opening a previously cached Parquet file directly after an API response error. If downloading through `cansim` fails, use the official Statistics Canada download link above, and **convert/import the downloaded table to a compatible Parquet dataset**, checking that its column names and values match the fields used immediately after `knowledge_con` is created. Do not assume a direct CSV-to-Parquet conversion will recreate the `cansim` schema exactly.

**Recommended portable local configuration:** once a verified compatible Parquet file is available, place it at:

```text
census_cache/98100216-eng.parquet
```

Then replace the hard-coded path in the main R Markdown with:

```r
census_parquet <- here::here("census_cache", "98100216-eng.parquet")
stopifnot(file.exists(census_parquet))
knowledge_con <- arrow::open_dataset(census_parquet)
```

Keep the large `census_cache/` directory out of Git; its contents can be reobtained from Statistics Canada. If keeping the default `cansim` cache folder instead, adjust the local path accordingly.

### Census API access and credentials

In addition to the large Statistics Canada table, the analysis uses the `cancensus` package to retrieve Québec Census Division geography, language knowledge counts, and denominator values. **A CensusMapper API key is required for the `cancensus` calls.** Obtain your own credentials via the [CensusMapper / cancensus documentation](https://mountainmath.github.io/cancensus/), and store the key privately, rather than embedding it in `.Rmd` files. For example, put this in your local, untracked `.Renviron`:

```text
CANCENSUS_API_KEY=your_private_key_here
```

Then load it at the beginning of the relevant R Markdown files:

```r
options(cancensus.api_key = Sys.getenv("CANCENSUS_API_KEY"))
```

**Before publishing:** Remove the API key currently hard-coded in the reviewed scripts and rotate/revoke that key if it is still active or has been shared. Do not put keys, `.Renviron`, or project-specific credentials on GitHub.

## R environment

The scripts are written for R and RStudio. Their main package dependencies include:

```r
install.packages(c(
  "tidyverse", "tidylog", "janitor", "broom", "lubridate",
  "readxl", "here", "cancensus", "cansim", "arrow",
  "lme4", "lmerTest", "performance", "DHARMa",
  "psych", "corrplot", "modelsummary", "broom.mixed",
  "flextable", "officer", "patchwork", "scales",
  "sandwich", "lmtest", "emmeans"
))
```

Additional packages may be used in particular analysis chunks. Use a recent version of R compatible with these packages. A package lockfile (`renv`) is not currently documented here, so exact package versions are not yet pinned.

## Running the analyses

1. Clone/download the project and open `2025_Census_paper.Rproj` in RStudio.
2. Place the permitted input data and mapping CSVs in the expected paths; correct the folder capitalization if needed.
3. Download/configure the required Census table and set up your private CensusMapper API key.
4. Run `First_collection_clean.Rmd`, and confirm that `Anonymized_data/first_collection_w_predictors.csv` is written.
5. Run `2025_census_analyses.Rmd` from a **clean R session**. Confirm its data-quality checks, sample counts, model diagnostics, and outputs before interpreting results.
6. Inspect output figures, tables, and any model warnings. Some exploratory mixed models have known modeling caveats documented in the manuscript/audit notes (including bounded outcomes and, in one exploratory binomial mixed model, a singular random effect).

Because some generated outputs currently use relative filenames (rather than dedicated subdirectories), files may appear in the project root. The figures can be reorganized as described below.

## Figures and tables

The scripts create manuscript and supplementary figures (histograms, language-combination plots, outcome distributions, correlation plots, and exploratory analyses) as well as editable Word tables. Some figure files are already written to `Figures/`, while other `ggsave()` calls write directly to the project root. The same is true for Word-table exports.

**Recommended layout:**

```text
2025_Census_paper.Rproj
README.md
First_collection_clean.Rmd
2025_census_analyses.Rmd
first_collection_cols_clean.csv           # share only if permitted
column_clean_names.csv                  # share only if permitted
Anonymized_data/                       # do not commit without approval
census_cache/                          # downloaded separately; not committed
Figures/                               # manuscript/supplementary figures
Tables/                                # generated Word tables
```

At the beginning of the main analysis, create output folders if necessary:

```r
dir.create(here::here("Figures"), showWarnings = FALSE, recursive = TRUE)
dir.create(here::here("Tables"), showWarnings = FALSE, recursive = TRUE)
```

Then use explicit paths when saving:

```r
ggplot2::ggsave(
  filename = here::here("Figures", "FigureS1_predictor_distributions.pdf"),
  plot = figureS1, width = 12, height = 15, bg = "white"
)

flextable::save_as_docx(
  "Active use models" = table_active,
  path = here::here("Tables", "active_use_models.docx")
)
```

**Do not rely solely on manually moving output files.** You may move the existing PDFs/PNGs to `Figures/` now, but if you do not also update their `ggsave()` paths, the next R Markdown run will create new copies in the project root. After updating save paths, rerun the relevant chunks and delete only confirmed duplicates. Keep any figure files referenced elsewhere in the manuscript or `.Rmd` at their expected paths.

## Interpretation and reproducibility notes

- **Observations and grouping:** Language-specific datasets contain repeated child-by-language observations; mixed-effects models use child-level random intercepts.
- **Outcome scales:** Active use is recorded on a 0–3 ordered scale; interlocutor matching is a percentage (0–100). Gaussian models for these bounded outcomes require care when interpreting residual diagnostics or out-of-range fitted values.
- **Exploratory analyses:** Tests of language-status moderation and threshold comparisons are exploratory. Read confidence intervals and model comparisons alongside p-values; avoid causal interpretations.
- **Data exclusions:** Exclusion rules and sample counts are implemented in the scripts; consult the applicable ethics protocol and manuscript before releasing any participant-level information.
- **Reproducibility:** The workflow currently depends on external Census downloads, a CensusMapper credential, local data files, and some manually configured paths. This README records those dependencies but does not imply that the repository runs end-to-end on a new machine without the input data and path updates.

## Data source citation

Statistics Canada. **Table 98-10-0216-01**. *Knowledge of languages by age and gender: Canada, provinces and territories, census divisions and census subdivisions*. https://doi.org/10.25318/9810021601-eng
