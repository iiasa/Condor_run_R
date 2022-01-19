args <- commandArgs(trailingOnly=TRUE)
# Busy loop for a while
sum <- 0
for (i in 1:1e9) {
  sum <- sum + cos(i)^2 + sin(i)^2
}
cat(sum, "\n")
# Output dummy dataframe
study <- data.frame(id = 1:5,
                    sex = c("m", "m", "f", "f", "m"),
                    score = c(51, 20, 67, 52, 42))
save(study, file="output/output.RData")
