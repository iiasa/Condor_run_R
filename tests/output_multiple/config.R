# See https://github.com/iiasa/Condor_run_R/blob/master/configuring.md
LABEL = "output_multiple"
JOBS = c(0, 1)
REQUIREMENTS = c("R")
REQUEST_MEMORY = 40
REQUEST_DISK = 40
LAUNCHER = "Rscript"
SCRIPT = "test.R"
ARGUMENTS = "%1"
BUNDLE_INCLUDE = SCRIPT
OUTPUT_FILES = c("result1.cnt", "result2.lvl")
WAIT_FOR_RUN_COMPLETION = TRUE
