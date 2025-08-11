
suppressPackageStartupMessages({
  library(optparse); library(leaps); library(boot); library(readxl); library(dplyr); library(jsonlite)
})

opt_list <- list(
  make_option(c("-i","--input"), type="character", default=NULL),
  make_option(c("-s","--sheet"), type="character", default=NULL),
  make_option(c("-t","--target"), type="character", default="NoteRatePercent"),
  make_option(c("-f","--features"), type="character", default="TotalMonthlyIncomeAmount,PMICoveragePercent,NoteAmount,Borrower1CreditScoreValue,FIPSStateNumericCode"),
  make_option(c("--kfold"), type="integer", default=10),
  make_option(c("--nvmax"), type="integer", default=50),
  make_option(c("--seed"), type="integer", default=1)
)
opt <- parse_args(OptionParser(option_list=opt_list))
set.seed(opt$seed)

read_any <- function(path, sheet=NULL) {
  if (is.null(path)) stop("--input required")
  if (grepl("\\.xlsx?$", path, ignore.case=TRUE)) readxl::read_excel(path, sheet=sheet) else read.csv(path, stringsAsFactors=FALSE)
}

df <- read_any(opt$input, opt$sheet)
feats <- trimws(strsplit(opt$features, ",")[[1]])
needed <- unique(c(opt$target, feats))
df <- df[, needed[needed %in% names(df)], drop=FALSE]

if ("Borrower1CreditScoreValue" %in% names(df)) df$bocredit.f <- factor(df$Borrower1CreditScoreValue)
if ("FIPSStateNumericCode" %in% names(df)) df$state.f <- factor(df$FIPSStateNumericCode)
df <- na.omit(df)

k <- max(2, opt$kfold)
folds <- sample(1:k, nrow(df), replace=TRUE)
nv <- min(opt$nvmax, max(2, ncol(df)-1))
cv_errors <- matrix(NA_real_, nrow=k, ncol=nv)

for (j in 1:k) {
  train <- df[folds != j, , drop=FALSE]
  test  <- df[folds == j, , drop=FALSE]
  best_fit <- regsubsets(reformulate(setdiff(names(train), opt$target), response=opt$target), data=train, nvmax=nv, method="forward")
  test_mat <- model.matrix(reformulate(attr(best_fit$terms, "term.labels"), response=opt$target), data=test)
  for (i in 1:nv) {
    coefi <- coef(best_fit, id=i)
    pred <- as.numeric(test_mat[, names(coefi), drop=FALSE] %*% coefi)
    cv_errors[j, i] <- mean((test[[opt$target]] - pred)^2)
  }
}

mean_cv <- colMeans(cv_errors, na.rm=TRUE)
best_size <- which.min(mean_cv)
fit_all <- regsubsets(reformulate(setdiff(names(df), opt$target), response=opt$target), data=df, nvmax=best_size, method="forward")
coefs <- coef(fit_all, id=best_size)

dir.create("outputs", showWarnings=FALSE)
jsonlite::write_json(as.list(coefs), path="outputs/coefs.json", auto_unbox=TRUE, pretty=TRUE)
png("outputs/cv_mean_error.png", width=1000, height=800, res=150)
plot(mean_cv, type="b", xlab="Model size", ylab="CV MSE", main="K-fold CV — Mean Error by Model Size")
points(best_size, mean_cv[best_size], col="red", cex=2, pch=20)
dev.off()
message(sprintf("Done. Best size=%d  CV_min=%.4f", best_size, min(mean_cv)))
