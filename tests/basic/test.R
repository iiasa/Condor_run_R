args <- commandArgs(trailingOnly=TRUE)
seconds_to_sleep <- as.integer(args[[1]])
study <- data.frame(id = 1:5,
                    sex = c("m", "m", "f", "f", "m"),
                    score = c(51, 20, 67, 52, 42))
Sys.sleep(seconds_to_sleep)
dir.create("output")
save(study, file="output/output.RData")
