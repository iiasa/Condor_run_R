# See https://github.com/iiasa/Condor_run_R/blob/master/configuring.md
LABEL = "bundling_{Sys.Date()}"
JOBS = c(0)
REQUIREMENTS = c("R")
REQUEST_MEMORY = 100
LAUNCHER = "Rscript"
ARGUMENTS = "--help"
BUNDLE_INCLUDE = "model"
BUNDLE_INCLUDE_DIRS = c("data/*.bar", "data/**/*.baz")
BUNDLE_EXCLUDE_FILES = c("data/**/exclude_me_specifically.baz")
BUNDLE_ADDITIONAL_FILES = c("additionals/additional.file", "additionals/subdir/*", "additionals/path1")
BUNDLE_ONLY = TRUE
WAIT_FOR_RUN_COMPLETION = FALSE
