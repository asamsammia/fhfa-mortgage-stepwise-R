# FHFA Mortgage Rate Prediction — Forward Stepwise (R)

Clean R version of your **midterm** project: forward subset selection with **10‑fold CV** on the FHFA 2023 PUD.
It reproduces the workflow (no hardcoded `setwd`, works with CSV/XLSX) and saves plots & metrics.

**Reported results (from your midterm):**
- Min CV error: **0.3389**
- Correlation (actual vs. predicted, 2023 apply): **0.2334**

## Quickstart
```r
# Install packages
pkgs <- c("optparse","leaps","boot","readxl","dplyr")
to_install <- pkgs[!pkgs %in% rownames(installed.packages())]
if (length(to_install)) install.packages(to_install, repos="https://cloud.r-project.org")

# Demo run (synthetic data, for CI)
Rscript scripts/mortgage_stepwise_cv.R --demo

# Real data (XLSX)
Rscript scripts/mortgage_stepwise_cv.R       --input "data/2023-pudb.xlsx" --sheet 1       --target NoteRatePercent       --features TotalMonthlyIncomeAmount,PMICoveragePercent,NoteAmount,Borrower1CreditScoreValue,FIPSStateNumericCode       --kfold 10 --nvmax 50

# Apply coefficients to new year (re-train on training split then predict on provided file)
Rscript scripts/mortgage_apply.R       --coef "outputs/coefs.json"       --input "data/2024-pudb.xlsx" --sheet 1       --target NoteRatePercent       --features TotalMonthlyIncomeAmount,PMICoveragePercent,NoteAmount,Borrower1CreditScoreValue,FIPSStateNumericCode
```

## What it does
- Builds design matrix with factor-ized credit score and state columns
- K-fold CV over best-subset sizes using `leaps::regsubsets`
- Plots: CV error by model size; RSS / AdjR² / Cp / BIC
- Saves: selected coefficients (`outputs/coefs.json`), predictions (`outputs/predictions.csv`), metrics (`outputs/metrics.json`)

## Files
- `scripts/mortgage_stepwise_cv.R` — training + CV + plots
- `scripts/mortgage_apply.R` — apply saved coefficients to a new dataset
- `.github/workflows/r-ci.yml` — CI runs `--demo` so it always passes
- `outputs/` — artifacts (gitignored)
