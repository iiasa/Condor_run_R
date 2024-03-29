# See https://github.com/iiasa/Condor_run_R/blob/master/configuring.md
LABEL = "overrides"
JOBS = c(0)
REQUIREMENTS = c("R")
REQUEST_MEMORY = 40
REQUEST_DISK = 40
LAUNCHER = "Rscript"
ARGUMENTS = "--help"
JOB_OVERRIDES = list(
  "periodic_release" = "periodic_remove = (JobStatus == {2+3})"
)
GET_OUTPUT = FALSE
WAIT_FOR_RUN_COMPLETION = TRUE
