args <- commandArgs(trailingOnly=TRUE)
study <- data.frame(id = 1:5,
                    sex = c("m", "m", "f", "f", "m"),
                    score = c(51, 20, 67, 52, 42))
Sys.sleep(1200)
save(study, file="output/output.RData")
