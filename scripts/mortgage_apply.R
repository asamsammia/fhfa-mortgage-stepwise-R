suppressPackageStartupMessages({
  library(optparse)
  library(readxl)
  library(jsonlite)
})

opt_list <- list(
  make_option(c("--coef"), type="character", help="Path to outputs/coefs.json from training"),
  make_option(c("-i","--input"), type="character", help="Path to CSV/XLSX to apply"),
  make_option(c("-s","--sheet"), type="character", default=NULL, help="Excel sheet (if XLSX)"),
  make_option(c("-t","--target"), type="character", default="NoteRatePercent", help="Target column name (if present)"),
  make_option(c("-f","--features"), type="character", default="TotalMonthlyIncomeAmount,PMICoveragePercent,NoteAmount,Borrower1CreditScoreValue,FIPSStateNumericCode", help="Comma-separated predictors")
)
opt <- parse_args(OptionParser(option_list=opt_list))

if (is.null(opt$coef) || is.null(opt$input)) stop("--coef and --input are required")

coefs <- jsonlite::read_json(opt$coef, simplifyVector=TRUE)
read_any <- function(path, sheet=NULL) {
  if (grepl("\\\\.xlsx?$", path, ignore.case=TRUE)) {
    readxl::read_excel(path, sheet=sheet)
  } else {
    read.csv(path, stringsAsFactors=FALSE, check.names=TRUE)
  }
}
df <- read_any(opt$input, opt$sheet)

feats <- trimws(strsplit(opt$features, ",")[[1]])
cols <- unique(c(opt$target, feats))
df <- df[, cols[cols %in% names(df)], drop=FALSE]

if ("Borrower1CreditScoreValue" %in% names(df)) df$bocredit.f <- factor(df$Borrower1CreditScoreValue)
if ("FIPSStateNumericCode" %in% names(df)) df$state.f <- factor(df$FIPSStateNumericCode)

formula_str <- paste(opt$target, "~", paste(setdiff(names(df), opt$target), collapse=" + "))
mm <- model.matrix(as.formula(formula_str), data=df)

# Align design matrix to coefficients
keep <- intersect(colnames(mm), names(coefs))
preds <- rep(NA_real_, nrow(mm))
preds[] = as.numeric(mm[, keep, drop=FALSE] %*% coefs[keep])

out <- data.frame(predicted=preds)
if (opt$target %in% names(df)) out$actual <- df[[opt$target]]

dir.create("outputs", showWarnings=FALSE)
write.csv(out, "outputs/predicted_apply.csv", row.names=FALSE)
message("Predictions written to outputs/predicted_apply.csv")
