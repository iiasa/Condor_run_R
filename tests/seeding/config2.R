# Use paths relative to the working directory, with / as path separator.
LABEL = "seeding_inspite_of_occupation_{Sys.Date()}" # label/name for your project/experiment, pick something short but descriptive without spaces and valid as part of a filename, can use {<config>} expansion here
JOBS = c(0:19)
HOST_REGEXP = "^limpopo6" # a regular expression to select execute hosts from the cluster
REQUEST_MEMORY = 1000 # memory (MiB) to reserve for each job
REQUEST_CPUS = 1 # number of hardware threads to reserve for each job
LAUNCHER = "Rscript" # interpreter with which to launch the script
SCRIPT = "test.R" # script that comprises your job
ARGUMENTS = "%1" # arguments to the script
BUNDLE_INCLUDE_DIRS = c("input") # recursive, supports wildcards
BUNDLE_EXCLUDE_DIRS = c("Condor", "output") # recursive, supports wildcards
BUNDLE_EXCLUDE_FILES = c("*.log") # supports wildcards
BUNDLE_ADDITIONAL_FILES = c() # additional files to add to root of bundle, can also use an absolute path for these
WAIT_FOR_RUN_COMPLETION = TRUE
