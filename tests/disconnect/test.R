args <- commandArgs(trailingOnly=TRUE)
# Fail job early with 20% probably. It will after a delay be release from the
# held state, and this will occur until thejob succeeds.
#
# This servers to test that submitting with a cached bundle for input
# suffices also for jobs that are held and released at a later stage.
if (runif(1) < 0.10) abort("A transient random error occurred!")
seconds_to_sleep <- as.integer(args[[1]])
study <- data.frame(id = 1:5,
                    sex = c("m", "m", "f", "f", "m"),
                    score = c(51, 20, 67, 52, 42))
Sys.sleep(120)
save(study, file="output/output.RData")
