# See https://github.com/iiasa/Condor_run_R/blob/master/configuring.md
LABEL = "seed_overrides"
JOBS = c(0)
REQUIREMENTS = c("R")
REQUEST_MEMORY = 40
REQUEST_DISK = 40
LAUNCHER = "Rscript"
ARGUMENTS = "--help"
RETAIN_SEED_ARTIFACTS = TRUE
SEED_JOB_OVERRIDES = list(
  "periodic_remove" = "periodic_remove = (JobStatus == 1) && (time() - EnteredCurrentStatus > 333 )"
)
GET_OUTPUT = FALSE
WAIT_FOR_RUN_COMPLETION = FALSE
