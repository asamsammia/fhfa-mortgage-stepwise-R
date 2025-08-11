suppressPackageStartupMessages({
  library(optparse); library(leaps); library(boot); library(readxl);
  library(dplyr); library(jsonlite)
})

# ---------- CLI ----------
opt_list <- list(
  make_option(c("-i","--input"), type="character", default=NULL, help="Path to CSV/XLSX dataset"),
  make_option(c("-s","--sheet"), type="character", default=NULL, help="Excel sheet if XLSX"),
  make_option(c("-t","--target"), type="character", default="NoteRatePercent", help="Target column [default %default]"),
  make_option(c("-f","--features"), type="character",
              default="TotalMonthlyIncomeAmount,PMICoveragePercent,NoteAmount,Borrower1CreditScoreValue,FIPSStateNumericCode",
              help="Comma-separated predictors"),
  make_option(c("--kfold"), type="integer", default=10, help="CV folds [default %default]"),
  make_option(c("--nvmax"), type="integer", default=50, help="Max subset size [default %default]"),
  make_option(c("--seed"), type="integer", default=1, help="Random seed [default %default]")
)
opt <- parse_args(OptionParser(option_list=opt_list))
set.seed(opt$seed)

# ---------- IO helpers ----------
read_any <- function(path, sheet=NULL) {
  if (is.null(path)) stop("--input required")
  if (grepl("\\.xlsx?$", path, ignore.case=TRUE)) readxl::read_excel(path, sheet=sheet)
  else read.csv(path, stringsAsFactors=FALSE, check.names=TRUE)
}
dir.create("outputs", showWarnings=FALSE)

# ---------- Load & prepare ----------
df <- read_any(opt$input, opt$sheet)

feats <- trimws(strsplit(opt$features, ",")[[1]])
needed <- unique(c(opt$target, feats))
missing <- setdiff(needed, names(df))
if (length(missing)) stop(paste("Missing columns:", paste(missing, collapse=", ")))

model_data <- df[, needed, drop=FALSE]
if ("Borrower1CreditScoreValue" %in% names(model_data)) {
  model_data$bocredit.f <- factor(model_data$Borrower1CreditScoreValue)
}
if ("FIPSStateNumericCode" %in% names(model_data)) {
  model_data$state.f <- factor(model_data$FIPSStateNumericCode)
}
model_data <- stats::na.omit(model_data)

# ---------- K-fold CV across subset sizes ----------
k <- max(2, opt$kfold)
folds <- sample(1:k, nrow(model_data), replace=TRUE)

nv <- min(opt$nvmax, max(2, ncol(model_data) - 1))
cv_errors <- matrix(NA_real_, nrow=k, ncol=nv, dimnames=list(NULL, paste0(1:nv)))

for (j in 1:k) {
  train <- model_data[folds != j, , drop=FALSE]
  test  <- model_data[folds == j, , drop=FALSE]

  best_fit <- regsubsets(
    reformulate(setdiff(names(train), opt$target), response=opt$target),
    data=train, nvmax=nv, method="forward"
  )

  # Design matrix for test set uses discovered terms
  test_terms <- attr(best_fit$terms, "term.labels")
  test_mat <- model.matrix(reformulate(test_terms, response=opt$target), data=test)

  for (i in 1:nv) {
    coefi <- coef(best_fit, id=i)
    pred  <- as.numeric(test_mat[, names(coefi), drop=FALSE] %*% coefi)
    cv_errors[j, i] <- mean((test[[opt$target]] - pred)^2)
  }
}

mean_cv   <- colMeans(cv_errors, na.rm=TRUE)
best_size <- which.min(mean_cv)

# ---------- Fit best model on full data ----------
fit_full <- regsubsets(
  reformulate(setdiff(names(model_data), opt$target), response=opt$target),
  data=model_data, nvmax=best_size, method="forward"
)
coefs <- coef(fit_full, id=best_size)
jsonlite::write_json(as.list(coefs), path="outputs/coefs.json", auto_unbox=TRUE, pretty=TRUE)

# ---------- Standard diagnostics ----------
png("outputs/cv_mean_error.png", width=1000, height=800, res=150)
plot(mean_cv, type="b", xlab="Model size", ylab="CV MSE",
     main="K-fold CV — Mean Error by Model Size")
points(best_size, mean_cv[best_size], col="red", cex=2, pch=20)
dev.off()

fit_all <- regsubsets(
  reformulate(setdiff(names(model_data), opt$target), response=opt$target),
  data=model_data, nvmax=nv, method="forward"
)
summ <- summary(fit_all)

png("outputs/rss.png", width=1000, height=800, res=150)
plot(summ$rss, type="l", xlab="Number of Variables", ylab="RSS"); points(which.min(summ$cp), summ$rss[which.min(summ$cp)], col="red", pch=20, cex=2)
dev.off()
png("outputs/adjr2.png", width=1000, height=800, res=150)
plot(summ$adjr2, type="l", xlab="Number of Variables", ylab="Adjusted R^2"); points(which.max(summ$adjr2), summ$adjr2[which.max(summ$adjr2)], col="red", pch=20, cex=2)
dev.off()
png("outputs/cp.png", width=1000, height=800, res=150)
plot(summ$cp, type="l", xlab="Number of Variables", ylab="Cp"); points(which.min(summ$cp), summ$cp[which.min(summ$cp)], col="red", pch=20, cex=2)
dev.off()
png("outputs/bic.png", width=1000, height=800, res=150)
plot(summ$bic, type="l", xlab="Number of Variables", ylab="BIC"); points(which.min(summ$bic), summ$bic[which.min(summ$bic)], col="red", pch=20, cex=2)
dev.off()

# ---------- NEW: Predicted vs Actual & panel with CV ----------
form_full <- reformulate(setdiff(names(model_data), opt$target), response = opt$target)
mm_full   <- model.matrix(form_full, data = model_data)
keep <- intersect(colnames(mm_full), names(coefs))
yhat <- as.numeric(mm_full[, keep, drop = FALSE] %*% coefs[keep])
yact <- model_data[[opt$target]]

# scatter only
png("outputs/pred_vs_actual.png", width = 1000, height = 800, res = 150)
plot(yact, yhat, xlab = paste("Actual", opt$target), ylab = "Predicted", pch = 1, cex = 0.6)
abline(0, 1, col = "red", lwd = 2, lty = 2)
dev.off()

# cv + scatter two-panel
png("outputs/cv_and_scatter.png", width = 1400, height = 700, res = 150)
op <- par(mfrow = c(1, 2), mar = c(4, 4, 2, 1))
plot(mean_cv, type = "b", xlab = "Model size", ylab = "mean CV errors")
points(best_size, mean_cv[best_size], col = "red", pch = 20, cex = 1.5)
plot(yact, yhat, xlab = paste("Actual", opt$target), ylab = "Predicted", pch = 1, cex = 0.6)
abline(0, 1, col = "red", lwd = 2, lty = 2)
par(op); dev.off()

# ---------- Optional: save predictions + simple metrics ----------
out <- cbind(actual = yact, pred = yhat)
write.csv(out, "outputs/predictions.csv", row.names = FALSE)
mse  <- mean((yact - yhat)^2)
corr <- suppressWarnings(cor(yact, yhat))
jsonlite::write_json(list(best_size = best_size, cv_min = min(mean_cv), mse = mse, corr = corr),
                     path = "outputs/metrics.json", auto_unbox = TRUE, pretty = TRUE)
message(sprintf("Done. Best size=%d  CV_min=%.4f  MSE=%.4f  Corr=%.4f", best_size, min(mean_cv), mse, corr))
