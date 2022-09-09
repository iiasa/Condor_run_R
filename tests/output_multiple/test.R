args <- commandArgs(trailingOnly=TRUE)

result1 <- data.frame(count = c(5, 8, 3))
save(result1, file="output/result1.cnt")
result2 <- data.frame(level = c(12.5, 6.4, 11.8)) 
save(result2, file="output/result2.lvl")
