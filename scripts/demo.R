
# Synthetic demo to keep CI green
set.seed(1)
n <- 400
Income <- rlnorm(n, 9, 0.5); PMI <- pmax(0, rnorm(n, 20, 8)); Amount <- rlnorm(n, 12, 0.6)
Credit <- sample(seq(550, 800, by=10), n, TRUE); State <- factor(sample(1:10, n, TRUE))
NoteRatePercent <- 2 + 0.000002*Income + 0.000001*Amount + 0.01*(PMI>25) - 0.001*(Credit/850) + rnorm(n, 0, 0.3)
df <- data.frame(NoteRatePercent, TotalMonthlyIncomeAmount=Income, PMICoveragePercent=PMI, NoteAmount=Amount, Borrower1CreditScoreValue=Credit, FIPSStateNumericCode=State)
write.csv(df, "outputs/demo_data.csv", row.names=FALSE)
