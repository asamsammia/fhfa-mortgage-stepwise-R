![Banner](assets/fhfa-mortgage-stepwise-R.png)

# FHFA Mortgage Rate Prediction — Forward Stepwise (R)

    Clean R version of your **midterm** project: forward subset selection with **10‑fold CV** on FHFA PUD 2023.

    ## Quickstart
    ```r
    # install
    pkgs <- c("optparse","leaps","boot","readxl","dplyr","jsonlite")
    to_install <- pkgs[!pkgs %in% rownames(installed.packages())]
    if (length(to_install)) install.packages(to_install, repos="https://cloud.r-project.org")

    # demo
    Rscript scripts/demo.R
    ```

    ## Scripts
    - `scripts/mortgage_stepwise_cv.R` — training + K-fold CV + plots + coef export
    - `scripts/mortgage_apply.R` — apply saved coefs to a new dataset
    - `scripts/demo.R` — synthetic demo so CI always runs green

    ---

    ## Results
    ### Results — FHFA Mortgage (Midterm)
- Samples evaluated: **34273**
- Correlation (Actual vs. Predicted): **0.2334**
- RMSE: **0.5808**
- MSE: **0.3373**
- MAE: **0.4476**


---

## How to Cite
**APA (suggested):**  
Samih, A. (2025). *FHFA Mortgage Rate Prediction — Forward Stepwise (R)*. GitHub repository. https://github.com/asamsammia/fhfa-mortgage-stepwise-R

**BibTeX:**
```bibtex
@software{Samih2025-fhfa-mortgage-stepwise-R,
  author  = {Abdul Samih},
  title   = {FHFA Mortgage Rate Prediction — Forward Stepwise (R)},
  year    = {2025},
  url     = {https://github.com/asamsammia/fhfa-mortgage-stepwise-R}
}
```

## Limitations
- **Subset selection instability:** Forward best-subsets can be sensitive to small data changes.
- **Omitted macro factors:** No explicit macroeconomic controls (e.g., CPI, Fed Funds) are modeled.
- **Linear structure:** The baseline is linear; non‑linearities/interactions may be underfit.
- **Encoding:** `state` and credit score are factor-encoded; alternative encodings may shift coefficients.
- **CV randomness:** 10‑fold assignment introduces variance; set a seed to replicate.