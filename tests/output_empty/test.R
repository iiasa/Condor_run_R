args <- commandArgs(trailingOnly=TRUE)
job_number <- as.integer(args[[1]])

result1 <- data.frame(count = c(5, 8, 3))
save(result1, file="output/result1.cnt")
if (job_number == 0) {
  fs::file_touch("output/result2.lvl")
} else {
  result2 <- data.frame(level = c(12.5, 6.4, 11.8)) 
  save(result2, file="output/result2.lvl")
}
