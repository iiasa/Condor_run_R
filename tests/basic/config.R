# See https://github.com/iiasa/Condor_run_R/blob/master/configuring.md
LABEL = "basic_{Sys.Date()}"
JOBS = c(0:149)
REQUIREMENTS = c("R")
REQUEST_MEMORY = 1000
REQUEST_DISK = 200
LAUNCHER = "Rscript"
SCRIPT = "test.R"
ARGUMENTS = "%1"
BUNDLE_INCLUDE = SCRIPT
OUTPUT_DIR_SUBMIT = "output/{LABEL}"
WAIT_FOR_RUN_COMPLETION = TRUE
