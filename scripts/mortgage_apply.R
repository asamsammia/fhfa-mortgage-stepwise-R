
suppressPackageStartupMessages({ library(optparse); library(readxl); library(jsonlite) })
opt <- parse_args(OptionParser(option_list=list(
  make_option(c("--coef"), type="character"),
  make_option(c("-i","--input"), type="character"),
  make_option(c("-s","--sheet"), type="character", default=NULL),
  make_option(c("-t","--target"), type="character", default="NoteRatePercent")
)))
if (is.null(opt$coef) || is.null(opt$input)) stop("--coef and --input required")
coefs <- jsonlite::read_json(opt$coef, simplifyVector=TRUE)
read_any <- function(path, sheet=NULL) if (grepl("\\.xlsx?$", path, ignore.case=TRUE)) readxl::read_excel(path, sheet=sheet) else read.csv(path, stringsAsFactors=FALSE)
df <- read_any(opt$input, opt$sheet)
if ("Borrower1CreditScoreValue" %in% names(df)) df$bocredit.f <- factor(df$Borrower1CreditScoreValue)
if ("FIPSStateNumericCode" %in% names(df)) df$state.f <- factor(df$FIPSStateNumericCode)
form <- as.formula(paste(opt$target, "~ ."))
mm <- model.matrix(form, data=df)
keep <- intersect(colnames(mm), names(coefs))
pred <- as.numeric(mm[, keep, drop=FALSE] %*% coefs[keep])
dir.create("outputs", showWarnings=FALSE)
write.csv(data.frame(predicted=pred), "outputs/predicted_apply.csv", row.names=FALSE)
