# See https://github.com/iiasa/Condor_run_R/blob/master/configuring.md
LABEL = "basic_{Sys.Date()}"
JOBS = c(1, 2, 3, 5, 6)
REQUIREMENTS = c("R")
REQUEST_MEMORY = 1000
REQUEST_DISK = 100
LAUNCHER = "Rscript"
SCRIPT = "test.R"
ARGUMENTS = "%1"
BUNDLE_INCLUDE = SCRIPT
GET_OUTPUT = FALSE
REQUIREMENTS = 'TARGET.Machine == "limpopo$(JOB).iiasa.ac.at"'
WAIT_FOR_RUN_COMPLETION = TRUE
