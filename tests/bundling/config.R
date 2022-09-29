# See https://github.com/iiasa/Condor_run_R/blob/master/configuring.md
LABEL = "bundling_{Sys.Date()}"
JOBS = c(0)
REQUIREMENTS = c("R")
REQUEST_MEMORY = 100
LAUNCHER = "Rscript"
ARGUMENTS = "--help"
BUNDLE_INCLUDE = c("model", "data/*.bar")
BUNDLE_INCLUDE_DIRS = c("data/more_data")
BUNDLE_ADDITIONAL_FILES = c("additionals/additional.file")
BUNDLE_EXCLUDE_FILES = c("data/**/exclude_me_specifically.baz")
BUNDLE_ONLY = TRUE
WAIT_FOR_RUN_COMPLETION = FALSE
