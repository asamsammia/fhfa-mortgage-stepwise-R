suppressPackageStartupMessages({
  library(optparse)
  library(leaps)
  library(boot)
  library(readxl)
  library(dplyr)
})

opt_list <- list(
  make_option(c("-i","--input"), type="character", default=NULL, help="Path to CSV/XLSX dataset"),
  make_option(c("-s","--sheet"), type="character", default=NULL, help="Excel sheet name/index if XLSX"),
  make_option(c("-t","--target"), type="character", default="NoteRatePercent", help="Target column [default %default]"),
  make_option(c("-f","--features"), type="character", default="TotalMonthlyIncomeAmount,PMICoveragePercent,NoteAmount,Borrower1CreditScoreValue,FIPSStateNumericCode", help="Comma-separated predictors"),
  make_option(c("--kfold"), type="integer", default=10, help="Number of CV folds [default %default]"),
  make_option(c("--nvmax"), type="integer", default=50, help="Max subset size for regsubsets [default %default]"),
  make_option(c("--seed"), type="integer", default=1, help="Random seed [default %default]"),
  make_option(c("--demo"), action="store_true", default=FALSE, help="Run with synthetic data")
)
opt <- parse_args(OptionParser(option_list=opt_list))
set.seed(opt$seed)

# --- load data ---
read_any <- function(path, sheet=NULL) {
  if (is.null(path)) return(NULL)
  if (grepl("\\\\.xlsx?$", path, ignore.case=TRUE)) {
    readxl::read_excel(path, sheet=sheet)
  } else {
    read.csv(path, stringsAsFactors=FALSE, check.names=TRUE)
  }
}

if (opt$demo) {
  n <- 1200
  Income <- rlnorm(n, 9, 0.5)
  PMI <- pmax(0, rnorm(n, 20, 8))
  Amount <- rlnorm(n, 12, 0.6)
  Credit <- sample(seq(550, 800, by=10), n, TRUE)
  State <- factor(sample(1:10, n, TRUE))
  NoteRatePercent <- 2 + 0.000002*Income + 0.000001*Amount + 0.01*(PMI>25) - 0.001*(Credit/850) + rnorm(n, 0, 0.3)
  df <- data.frame(NoteRatePercent, TotalMonthlyIncomeAmount=Income, PMICoveragePercent=PMI, NoteAmount=Amount,
                   Borrower1CreditScoreValue=Credit, FIPSStateNumericCode=State)
} else {
  if (is.null(opt$input)) stop("--input required unless --demo")
  df <- read_any(opt$input, opt$sheet)
}

# --- build modeling frame ---
feats <- trimws(strsplit(opt$features, ",")[[1]])
needed <- unique(c(opt$target, feats))
missing <- setdiff(needed, names(df))
if (length(missing)) stop(paste("Missing columns:", paste(missing, collapse=", ")))

model_data <- df[, needed, drop=FALSE]
# Factorize credit score and state if present
if ("Borrower1CreditScoreValue" %in% names(model_data)) {
  model_data$bocredit.f <- factor(model_data$Borrower1CreditScoreValue)
}
if ("FIPSStateNumericCode" %in% names(model_data)) {
  model_data$state.f <- factor(model_data$FIPSStateNumericCode)
}

model_data <- na.omit(model_data)

# K-fold assignment
k <- max(2, opt$kfold)
folds <- sample(1:k, nrow(model_data), replace=TRUE)

# CV errors matrix
nv <- min(opt$nvmax,  max(2, ncol(model_data) - 1))  # at least 2, cap at predictors count
cv_errors <- matrix(NA_real_, nrow=k, ncol=nv, dimnames=list(NULL, paste0(1:nv)))

# CV loop
for (j in 1:k) {
  train <- model_data[folds != j, , drop=FALSE]
  test  <- model_data[folds == j, , drop=FALSE]

  best_fit <- regsubsets(reformulate(setdiff(names(train), opt$target), response=opt$target),
                         data=train, nvmax=nv, method="forward")

  test_mat <- model.matrix(reformulate(attr(best_fit$terms, "term.labels"), response=opt$target), data=test)

  for (i in 1:nv) {
    coefi <- coef(best_fit, id=i)
    pred <- as.numeric(test_mat[, names(coefi), drop=FALSE] %*% coefi)
    cv_errors[j, i] <- mean((test[[opt$target]] - pred)^2)
  }
}

mean_cv <- colMeans(cv_errors, na.rm=TRUE)
best_size <- which.min(mean_cv)

# Fit on full data with best size
best_fit_full <- regsubsets(reformulate(setdiff(names(model_data), opt$target), response=opt$target),
                            data=model_data, nvmax=best_size, method="forward")
coefs <- coef(best_fit_full, id=best_size)

dir.create("outputs", showWarnings=FALSE)
# Save coefficients
jsonlite::write_json(as.list(coefs), path="outputs/coefs.json", auto_unbox=TRUE, pretty=TRUE)

# Plots
png("outputs/cv_mean_error.png", width=1000, height=800, res=150)
plot(mean_cv, type="b", xlab="Model size", ylab="CV MSE", main="K-fold CV — Mean Error by Model Size")
points(best_size, mean_cv[best_size], col="red", cex=2, pch=20)
dev.off()

# Refit for diagnostics across sizes
fit_all <- regsubsets(reformulate(setdiff(names(model_data), opt$target), response=opt$target),
                      data=model_data, nvmax=nv, method="forward")
summ <- summary(fit_all)

png("outputs/rss.png", width=1000, height=800, res=150)
plot(summ$rss, type="l", xlab="Model size", ylab="RSS", main="RSS by Model Size")
points(which.min(summ$cp), summ$rss[which.min(summ$cp)], col="red", cex=2, pch=20)
dev.off()

png("outputs/adjr2.png", width=1000, height=800, res=150)
plot(summ$adjr2, type="l", xlab="Model size", ylab="Adj R^2", main="Adjusted R^2 by Model Size")
points(which.max(summ$adjr2), summ$adjr2[which.max(summ$adjr2)], col="red", cex=2, pch=20)
dev.off()

png("outputs/cp.png", width=1000, height=800, res=150)
plot(summ$cp, type="l", xlab="Model size", ylab="Cp", main="Mallows Cp by Model Size")
points(which.min(summ$cp), summ$cp[which.min(summ$cp)], col="red", cex=2, pch=20)
dev.off()

png("outputs/bic.png", width=1000, height=800, res=150)
plot(summ$bic, type="l", xlab="Model size", ylab="BIC", main="BIC by Model Size")
points(which.min(summ$bic), summ$bic[which.min(summ$bic)], col="red", cex=2, pch=20)
dev.off()

# Predictions (on the same data for demo)
X <- model.matrix(reformulate(attr(fit_all$terms, "term.labels"), response=opt$target), data=model_data)
yhat <- as.numeric(X[, names(coefs), drop=FALSE] %*% coefs)
out <- cbind(model_data[[opt$target]], yhat)
colnames(out) <- c("actual", "pred")
write.csv(out, "outputs/predictions.csv", row.names=FALSE)

# Metrics
mse <- mean((out[,"actual"] - out[,"pred"])^2)
corr <- suppressWarnings(cor(out[,"actual"], out[,"pred"]))
jsonlite::write_json(list(best_size=best_size, cv_min=min(mean_cv), mse=mse, corr=corr),
                     path="outputs/metrics.json", auto_unbox=TRUE, pretty=TRUE)

message(sprintf("Done. Best size=%d  CV_min=%.4f  MSE=%.4f  Corr=%.4f", best_size, min(mean_cv), mse, corr))
