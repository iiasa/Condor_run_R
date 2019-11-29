#!/usr/bin/env Rscript
# Submit a Condor run (a set of jobs). Basic version. Can be configured
# to monitor progress.
#
# Usage: invoke this script via Rscript, or, on Linux/MacOS, you can
# invoke the script directly if its execute flag is set. The working
# directory must contain the configured files and directories. To use
# non-default config settings, pass a path to a configuration file as
# an argument to this script. The format of the configuration file is
# shown in the "Default run config settings section" below.
#
# The above means that you can invoke this script with something like
#
# Rscript ..\R\Condor_run.R my_config.R
#
# either from the command prompt, shell, or using whatever your language
# of choice supports for command invocation.
#
# If you cannot invoke Rscript, you will need to add where the R binaries
# reside to your PATH environment variable. On Windows, this is typically
# C:\Program Files\R\R-x.y.z\bin\x64 (where x.y.z is the R version).
#
# A recent Condor version >= 8.5.4 is required to be installed on your
# submit machine.
#
# Also, 7z should be on-path. On Windows, this typically requires
# C:\Program Files\7-Zip to be added to your PATH environment variable.
# Use a recent 7-Zip version that can compress in parallel and supports
# the latest command line parameters. The execute hosts that you submit
# to should also have 7-Zip on-path. This is the case for the limpopo
# machines.
#
# The working directory (current directory) when invoking this script
# must be the directory that contains the configured files and paths.
#
# This script requires you to have a recent version of Condor installed.
# On Windows, the installer adds the Condor/bin directory to the PATH
# system environment variable, thus making the Condor commands available.
#
# Author: Albert Brouwer
# Based on: GLOBIOM-limpopo scripts by David Leclere
# Repository: https://github.com/iiasa/Condor_run_R

# ---- Default run config settings ----

# Remove any objects from active environment so that below it will contain only the default config
rm(list=ls())

# Override the default config settings via a run-config file passed as a first
# argument to this script. Lines with settings like the ones just below can be
# used in the config file. No settings may be omitted from the config file.
#
# To set up an initial config file, just copy-and-paste (do not cut) the below
# to a file, give it a .R extension to get nice syntax highlighting.
# -------8><----snippy-snappy----8><-----------------------------------------
# Use paths relative to the working directory, with / as path separator.
EXPERIMENT = "experiment1" # label for your run, pick something short but descriptive without spaces and valid as part of a filename
PREFIX = "_condor" # prefix for per-job .err, log, and .out files
JOBS = c(0:3,7,10)
HOST_REGEXP = "^limpopo" # a regular expression to select execute hosts from the cluster
REQUEST_MEMORY = 7800 # memory (MiB) to reserve for each job
REQUEST_CPUS = 1 # number of hardware threads to reserve for each job
LAUNCHER = "Rscript" # interpreter with which to launch the script
SCRIPT = "my_script.R" # script that comprises your job
ARGUMENTS = "%1" # arguments to the script
BUNDLE_INCLUDE_DIRS = c("input") # recursive, supports wildcards
BUNDLE_EXCLUDE_DIRS = c() # recursive, supports wildcards
BUNDLE_EXCLUDE_FILES = c("*.log") # supports wildcards
BUNDLE_ADDITIONAL_FILES = c() # additional files to add to root of bundle, can also use an absolute path for these
RETAIN_BUNDLE = FALSE
GET_OUTPUT = TRUE
OUTPUT_DIR = "output" # relative to working dir both host-side and on the submit machine
OUTPUT_FILE = "output.RData" # as produced by a job on the execute-host, will be remapped with EXPERIMENT and cluster/job numbers to avoid name collisions when transferring back to the submit machine.
WAIT_FOR_RUN_COMPLETION = TRUE
CONDOR_DIR = "Condor" # directory where Condor reference files are stored in a per-experiment subdirectory (.err, .log, .out, .job and so on files)
SEED_JOB_RELEASES = 4 # number of times to auto-release held seed jobs before giving up
JOB_RELEASES = 3 # number of times to auto-release held jobs before giving up
# -------8><----snippy-snappy----8><-----------------------------------------

# Collect the names and types of the default config settings
config_names <- ls()
if (length(config_names) == 0) {stop("Default configuration is absent! Please restore the default configuration. It is required for configuration checking, also when providing a separate configuration file.")}
config_types <- lapply(lapply(config_names, get), typeof)

# Presence of Config settings is obligatory in a config file other then for the settings listed here
OPTIONAL_CONFIG_SETTINGS <- c("CONDOR_DIR", "SEED_JOB_RELEASES", "JOB_RELEASES")

# ---- Get set ----

# Required packages
library(stringr)

# Check that the working directory is as expected and holds the required subdirectories
if (!dir.exists(CONDOR_DIR)) stop(str_glue("No {CONDOR_DIR} directory found relative to working directory {getwd()}! Is your working directory correct?"))

# Determine the platform file separator and the temp directory with R-default separators
temp_dir <- tempdir()
fsep <- ifelse(str_detect(temp_dir, fixed("\\") ), "\\", ".Platform$file.sep") # Get the platform file separator: .Platform$file.sep is set to / on Windows
temp_dir <- str_replace_all(temp_dir, fixed(fsep), .Platform$file.sep)
temp_dir_parent <- dirname(temp_dir) # Remove the R-session-specific random subdirectory: identical between sessions

# ---- Process environment and run config settings ----

# Read config file if specified via an argument, check presence and types.
args <- commandArgs(trailingOnly=TRUE)
#args <- c("..\\R\\config.R")
if (length(args) == 0) {
  warning("No config file argument supplied, using default run settings.")
} else if (length(args) == 1) {
  rm(list=config_names[!(config_names %in% OPTIONAL_CONFIG_SETTINGS)])
  source(args[1], local=TRUE, echo=FALSE)
  for (i in seq_along(config_names))  {
    name <- config_names[i]
    if (!exists(name)) stop(str_glue("{name} not set in {args[1]}!"))
    type <- typeof(get(name))
    if (type != config_types[[i]] &&
        name != "JOBS" && # R has no stable numerical type
        type != "NULL" && # allow for configured vector being empty
        config_types[[i]] != "NULL" # allow for default vector being empty
    ) stop(str_glue("{name} set to wrong type in {args[1]}, type should be {config_types[[i]]}"))
  }
} else {
  stop("Multiple arguments provided! Expecting at most a single config file argument.")
}

# Copy/write configuration to a file in the temp directory for reference early to minimize the risk of it being edited in the mean time
temp_config_file <- file.path(temp_dir, str_glue("config.R"))
if (length(args) > 0) {
  if (!file.copy(args[1], temp_config_file, overwrite=TRUE)) {
    invisible(file.remove(bundle_path))
    stop(str_glue("Cannot copy the configuration file {args[1]} to {run_dir}"))
  }
} else {
  # No configuration file provided, write default configuration defined above (definition order is lost)
  config_conn<-file(temp_config_file, open="wt")
  for (i in seq_along(config_names)) {
    if (config_types[i] == "character") {
      writeLines(str_glue('{config_names[i]} = "{get(config_names[i])}"'), job_conn)
    } else {
      writeLines(str_glue('{config_names[i]} = {get(config_names[i])}'), job_conn)
    }
  }
  close(config_conn)
}

# Check and massage specific config settings
if (str_detect(EXPERIMENT, '[<>|:?*" \\t/\\\\]')) stop(str_glue("Configured EXPERIMENT label for run has forbidden character(s)!"))
if (str_detect(PREFIX, '[<>|:?*" \\t/\\\\]')) stop(str_glue("Configured PREFIX has forbidden character(s)!"))
if (!is.numeric(JOBS)) stop("JOBS does not list job numbers!")
if (length(JOBS) < 1) stop("There should be at least one job in JOBS!")
if (!all(JOBS == floor(JOBS))) stop("Job numbers in JOBS must be whole numbers!")
if (!all(JOBS < 1e6)) stop("Job numbers in JOBS must be less than 1000000 (one million)!")
if (!all(JOBS >= 0)) stop("Job numbers in JOBS may not be negative!")
if (!(REQUEST_MEMORY > 0)) stop("REQUEST_MEMORY should be larger than zero!")
if (!all(!duplicated(JOBS))) stop("Duplicate JOB numbers listed in JOBS!")
if (!(file.exists(SCRIPT))) stop(str_glue('Configured SCRIPT "{SCRIPT}" does not exist relative to working directory!'))
if (str_detect(SCRIPT, '[<>|:?*" \\t/\\\\]')) stop(str_glue("Configured SCRIPT has forbidden character(s)!"))
if (!str_detect(ARGUMENTS, fixed("%1"))) stop("Configured ARGUMENTS lack a %1 batch file argument expansion that must be used for passing the job number with which the job-specific (e.g. scenario) can be selected.")
for (file in BUNDLE_ADDITIONAL_FILES) {
  if (!(file.exists(file.path(file)))) stop(str_glue('Misconfigured BUNDLE_ADDITIONAL_FILES: "{file}" does not exist!'))
}
if (!(file.exists(OUTPUT_DIR))) stop(str_glue('Configured OUTPUT_DIR "{OUTPUT_DIR}" does not exist!'))
if (str_detect(OUTPUT_DIR, "^/") || str_detect(OUTPUT_DIR, "^.:")) stop(str_glue("Configured OUTPUT_DIR must be located under the working directory: absolute paths not allowed!"))
if (str_detect(OUTPUT_DIR, fixed("../"))) stop(str_glue("Configured OUTPUT_DIR must be located under the working directory: you may not go up to parent directories using ../"))
if (str_detect(OUTPUT_DIR, '[<>|:?*" \\t\\\\]')) stop(str_glue("Configured OUTPUT_DIR has forbidden character(s)! Use / as path separator."))
if (str_detect(OUTPUT_FILE, '[<>|:?*" \\t/\\\\]')) stop(str_glue("Configured OUTPUT_FILE has forbidden character(s)!"))
output_prefix <- tools::file_path_sans_ext(OUTPUT_FILE)
output_extension <- tools::file_ext(OUTPUT_FILE)
script_prefix <- tools::file_path_sans_ext(SCRIPT)
script_extension <- tools::file_ext(SCRIPT)

# Get username in a way that works on MacOS, Linux, and Windows
username <- Sys.getenv("USERNAME")
if (username == "") username <- Sys.getenv("USER")
if (username == "") stop("Cannot determine the username!")

# Ensure that the run directory to hold the .out/.err/.log and so on results exists
run_dir <- file.path(CONDOR_DIR, EXPERIMENT)
if (!dir.exists(run_dir)) dir.create(run_dir)

# ---- Define some helper functions ----

# Check and sanitize 7zip output and return the overal byte size of the input files
handle_7zip <- function(out) {
  if (!is.null(attr(out, "status")) && attr(out, "status") != 0) {
    cat(out, sep="\n")
    stop("7zip compression failed!", call.=FALSE)
  }
  else {
    cat(out[grep("^Scanning the drive:", out)+1], sep="\n")
    size_line <- grep("^Archive size:", out, value=TRUE)
    cat(size_line, sep="\n")
    byte_size <- as.double(str_match(size_line, "^Archive size: (\\d+) bytes")[2])
    if (is.na(byte_size)) stop("7zip archive size extraction failed!", call.=FALSE) # 7zip output format has changed?
    return(byte_size)
  }
}

# Remove a file if it exists
remove_if_exists <- function(dir_path, file_name) {
  file_path <- file.path(dir_path, file_name)
  if (file.exists(file_path)) file.remove(file_path)
}

# Monitor jobs by waiting for them to finish while reporting queue totals changes and sending reschedule commands to the local schedd
monitor <- function(clusters) {
  warn <- FALSE
  regexp <- "Total for query: (\\d+) jobs; (\\d+) completed, (\\d+) removed, (\\d+) idle, (\\d+) running, (\\d+) held, (\\d+) suspended"
  #regexp <- "(\\d+) jobs; (\\d+) completed, (\\d+) removed, (\\d+) idle, (\\d+) running, (\\d+) held, (\\d+) suspended$"
  reschedule_invocations <- 200 # limit the number of reschedules so it is only done early on to push out the jobs quickly
  changes_since_reschedule <- FALSE
  iterations_since_reschedule <- 0
  prior_jobs      <- -1
  prior_completed <- -1
  prior_removed   <- -1
  prior_idle      <- -1
  prior_running   <- -1
  prior_held      <- -1
  prior_suspended <- -1
  while (prior_jobs != 0) {
    # Collect Condor queue information via condor_q
    outerr <- system2("condor_q", args=c("-totals", "-wide", clusters), stdout=TRUE, stderr=TRUE)
    if (!is.null(attr(outerr, "status")) && attr(outerr, "status") != 0) {
      cat(outerr, sep="\n")
      stop("Invocation of condor_q failed! Are you running a too old (< V8.5.4) Condor version?", call.=FALSE)
    }
    # Extract the totals line and parse it out
    match <- str_match(grep(regexp, outerr, value=TRUE), regexp)
    if (is.na(match[1])) {
      cat(outerr, sep="\n")
      stop("Monitoring Condor queue status with condor_q failed: unexpected output! Are you running a too old (< V8.5.4) Condor version?", call.=FALSE)
    }
    jobs      <- as.integer(match[2])
    completed <- as.integer(match[3])
    removed   <- as.integer(match[4])
    idle      <- as.integer(match[5])
    running   <- as.integer(match[6])
    held      <- as.integer(match[7])
    suspended <- as.integer(match[8])
    # Handle state changes
    if (jobs      != prior_jobs ||
        idle      != prior_idle ||
        running   != prior_running ||
        held      != prior_held ||
        suspended != prior_suspended
    ) {
      # State changes occurred, report
      cat(str_sub(str_glue('{jobs} jobs:{ifelse(completed==0, "", str_glue(" {completed} completed,"))}{ifelse(removed==0, "", str_glue(" {removed} removed;"))}{ifelse(idle==0, "", str_glue(" {idle} idle (queued),"))}{ifelse(running==0, "", str_glue(" {running} running,"))}{ifelse(held==0, "", str_glue(" {held} held,"))}{ifelse(suspended==0, "", str_glue(" {suspended} suspended,"))}'), 1, -2), sep="\n")
      changes_since_reschedule <- TRUE
    }
    # Warn when there are held jobs for the first time
    if (held > 0 && !warn) {
      cat("Jobs are held! These may be automatically released (see SEED_JOB_RELEASES and JOB_RELEASES config settings) or released manually via condor_release. If released jobs keep on returning to the held state, there is a persistent error that should be investigated. You can remove the held jobs using condor_rm.\n")
      warn <- TRUE
    }
    # Request rescheduling early
    if (idle > 0 && idle == prior_idle &&
        reschedule_invocations > 0 &&
        running <= prior_running
        && ((changes_since_reschedule) || iterations_since_reschedule >= 10)
    ) {
      outerr <- system2("condor_reschedule", args=c("reschedule"), stdout=TRUE, stderr=TRUE) # R-on-Windows issue?: the seemingly superflous args=c("reschedule") is needed because R seems to call some underlying generic exe that needs a parameter to resolve which command it should behave as
      if (!is.null(attr(outerr, "status")) && attr(outerr, "status") != 0) {
        warning(str_c(c("Invocation of condor_reschedule failed with the following output:", outerr), collapse='\n'), call.=FALSE)
      }
      reschedule_invocations <- reschedule_invocations-1
      changes_since_reschedule <- FALSE
      iterations_since_reschedule <- 0
    } else {
      iterations_since_reschedule <- iterations_since_reschedule+1
    }
    # Remember state for next iteration
    prior_jobs      <- jobs
    prior_completed <- completed
    prior_removed   <- removed
    prior_idle      <- idle
    prior_running   <- running
    prior_held      <- held
    prior_suspended <- suspended
    # Sleep before iterating
    Sys.sleep(1)
  }
}

# Get the return values of job log files, or NA when a job did not terminate normally.
get_return_values <- function(log_directory, log_file_names) {
  return_values <- c()
  return_value_regexp <- "\\(1\\) Normal termination \\(return value (\\d+)\\)"
  for (name in log_file_names) {
    loglines <- readLines(file.path(log_directory, name))
    return_value <- as.integer(str_match(tail(grep(return_value_regexp, loglines, value=TRUE), 1), return_value_regexp)[2])
    return_values <- c(return_values, return_value)
  }
  return(return_values)
}

# Summarize job numbers by using ranges
summarize_jobs <- function(jobs) {
  ranging <- FALSE
  prior <- NULL
  for (job in sort(jobs)) {
    if (is.null(prior)) {
      summary <- c(job)
    } else {
      if (job-prior == 1) {
        ranging <- TRUE
      } else {
        if (ranging) {
          summary <- c(summary, "-", prior)
          ranging <- FALSE
        }
        summary <- c(summary, ",", job)
      }
    }
    prior <- job
  }
  if (ranging) summary <- c(summary, "-", job)
  return(str_c(summary, collapse=""))
}

# A function that for all given jobs tests if a file exists and is not empty.
# The file_template is a template of the filename that is run through str_glue
# and can make use of variables defined in the calling context. The dir parameter
# indicates the directory containing the files.
#
# Warnings are generated when files are absent or empty.
# The boolean return value is TRUE when all files exist and are not empty.
all_exist_and_not_empty <- function(dir, file_template, file_type) {
  absentees <- c()
  empties <- c()
  for (job in JOBS) {
    path <- file.path(dir, str_glue(file_template))
    absent <- !file.exists(path)
    absentees <- c(absentees, absent)
    if (absent) {
      empties <- c(empties, FALSE)
    } else {
      empty <- file.info(path)$size == 0
      if (empty) file.remove(path)
      empties <- c(empties, empty)
    }
  }
  if (any(absentees)) {
    warning(str_glue("No {file_type} files returned for job(s) {summarize_jobs(JOBS[absentees])}!"), call.=FALSE)
  }
  if (any(empties)) {
    warning(str_glue("Empty {file_type} files resulting from job(s) {summarize_jobs(JOBS[empties])}! These empty files were removed."), call.=FALSE)
  }
  return(!(any(absentees) || any(empties)))
}

# ---- Check status of execute hosts ----

# Show status summary of selected execute hosts
error_code <- system2("condor_status", args=c("-compact", "-constraint", str_glue('"regexp(\\"{HOST_REGEXP}\\",machine)"')))
if (error_code > 0) stop("Cannot show Condor pool status! Are you running a too old (< V8.5.4) Condor version?")
cat("\n")

# Collect available execute hosts including domain
hostdoms <- unique(system2("condor_status", c("-compact", "-autoformat", "Machine", "-constraint", str_glue('"regexp(\\"{HOST_REGEXP}\\",machine)"')), stdout=TRUE))
if (!is.null(attr(hostdoms, "status")) && attr(hostdoms, "status") != 0) stop("Cannot show Condor pool status! Are you running a too old (< V8.5.4) Condor version?")
if (length(hostdoms) == 0) stop("No execute hosts matching HOST_REGEXP are available!")

# ---- Bundle the model ----

# Set R-default and platform-specific paths to the bundle
bundle <- "job_bundle.7z"
unique_bundle <- str_glue('bundle_{str_replace_all(Sys.time(), "[- :]", "")}.7z') # To keep multiple cached bundles separate
bundle_path <- file.path(temp_dir_parent, bundle) # Identical between sessions
bundle_platform_path <- str_replace_all(bundle_path, fixed(.Platform$file.sep), fsep)
if (file.exists(bundle_path)) stop(str_glue("{bundle_path} already exists! Is there another submission ongoing? If so, let that submission end first. If not, remove the file and try again."))

cat("Compressing model files into bundle...\n")
model_byte_size <- handle_7zip(system2("7z", stdout=TRUE, stderr=TRUE,
  args=unlist(lapply(c("a", "-mx1", "-bb0",
    unlist(lapply(BUNDLE_INCLUDE_DIRS, function(p) return(str_glue("-ir!", p)))),
    unlist(lapply(BUNDLE_EXCLUDE_DIRS, function(p) return(str_glue("-xr!", p)))),
    unlist(lapply(BUNDLE_EXCLUDE_FILES, function(p) return(str_glue("-x!", p)))),
    "-xr!{CONDOR_DIR}",
    "-xr!{OUTPUT_DIR}",
    "{bundle_platform_path}",
    "*"
  ), str_glue))
))
cat("\n")

additional_byte_size <- 0
if (length(BUNDLE_ADDITIONAL_FILES) != 0) {
  cat("Bundle any additional files...\n")
  additional_byte_size <- handle_7zip(system2("7z", stdout=TRUE, stderr=TRUE,
    args=unlist(lapply(c("a",
      "{bundle_platform_path}",
      BUNDLE_ADDITIONAL_FILES
    ), str_glue))
  ))
  cat("\n")
}

# Estimate the amount of disk to request for run, in KiB
# decompressed bundle content + 2GiB for output files
request_disk <- ceiling((model_byte_size+additional_byte_size)/1024)+2*1024*1024

# Determine the bundle size in KiB
bundle_size <- floor(file.info(bundle_path)$size/1024)

# ---- Seed available execute hosts with the bundle ----

# Define the template for the .bat that caches the transferred bundle on the execute host side
bat_template <- c(
  "@echo off",
  'set bundle_dir=e:\\condor\\bundles\\{username}',
  "if not exist %bundle_dir%\\ mkdir %bundle_dir% || exit /b %errorlevel%",
  "@echo on",
  "move /Y {bundle} %bundle_dir%\\{unique_bundle}"
)

# Apply settings to bat template and write the .bat file
seed_bat <- file.path(temp_dir, str_glue("_seed.bat"))
bat_conn<-file(seed_bat, open="wt")
writeLines(unlist(lapply(bat_template, str_glue)), bat_conn)
close(bat_conn)

# Transfer bundle to each available execute host
cluster_regexp <- "submitted to cluster (\\d+)[.]$"
clusters <- c()
hostnames <- c()
for (hostdom in hostdoms) {

  hostname <- str_extract(hostdom, "^[^.]*")
  hostnames <- c(hostnames, hostname)
  cat(str_glue("Starting transfer of bundle to {hostname}."), sep="\n")

  # Define the Condor .job file template for bundle seeding
  job_template <- c(
    "executable = {seed_bat}",
    "universe = vanilla",
    "",
    "# Job log, stdout, and stderr files",
    "log = {run_dir}/_seed_{hostname}.log",
    "output = {run_dir}/_seed_{hostname}.out",
    "error = {run_dir}/_seed_{hostname}.err",
    "",
    "periodic_release = (NumJobStarts < {SEED_JOB_RELEASES}) && ((CurrentTime - EnteredCurrentStatus) > 30)", # if seed job goes on hold, release up to 5 times after 30 seconds
    "",
    "requirements = \\",
    '  ( (Arch =="INTEL")||(Arch =="X86_64") ) && \\',
    '  ( (OpSys == "WINDOWS")||(OpSys == "WINNT61") ) && \\',
    "  ( GLOBIOM =?= True ) && \\",
    '  ( TARGET.Machine == "{hostdom}" )',
    "",
    "request_memory = 0",
    "request_cpus = 0", # We want this to get scheduled even when all CPUs are in-use, but current Condor still waits when all CPUs are partitioned.
    "request_disk = {2*bundle_size+500}", # KiB, twice needed for move, add some for the extra files
    "",
    '+IIASAGroup = "ESM"',
    "run_as_owner = True",
    "",
    "should_transfer_files = YES",
    'transfer_input_files = {bundle_path}',
    "",
    "queue 1"
  )

  # Apply settings to job template and write the .job file to use for submission
  job_file <- file.path(temp_dir, str_glue("_seed_{hostname}.job"))
  job_conn<-file(job_file, open="wt")
  writeLines(unlist(lapply(job_template, str_glue)), job_conn)
  close(job_conn)

  # Remove any job output left over from an aborted prior run
  remove_if_exists(run_dir, str_glue("_seed_{hostname}.log"))
  remove_if_exists(run_dir, str_glue("_seed_{hostname}.out"))
  remove_if_exists(run_dir, str_glue("_seed_{hostname}.err"))

  outerr <- system2("condor_submit", args=str_glue("{job_file}"), stdout=TRUE, stderr=TRUE)
  if (!is.null(attr(outerr, "status")) && attr(outerr, "status") != 0) {
    cat(outerr, sep="\n")
    invisible(file.remove(bundle_path))
    stop("Submission of bundle seed job failed!")
  }
  cluster <- as.integer(str_match(tail(grep(cluster_regexp, outerr, value=TRUE), 1), cluster_regexp)[2])
  if (is.na(cluster)) {
    invisible(file.remove(bundle_path))
    stop("Cannot extract cluster number from condor_submit output!")
  }
  clusters <- c(clusters, cluster)
}

# Predict the cluster number for the actual run
predicted_cluster <- cluster+1

# Wait until all execute hosts are seeded with a bundle
cat("Waiting for bundle seeding to complete...\n")
monitor(clusters)
return_values <- get_return_values(run_dir, lapply(hostnames, function(hostname) return(str_glue("_seed_{hostname}.log"))))
if (any(is.na(return_values))) {
  invisible(file.remove(bundle_path))
  stop(str_glue("Abnormal termination of seeding job(s) for {str_c(hostnames[is.na(return_values)], collapse=', ')}! For details, see the _seed_* files in {run_dir}"))
}
if (any(return_values != 0)) {
  invisible(file.remove(bundle_path))
  stop(str_glue("Seeding job(s) for {str_c(hostnames[return_values != 0], collapse=', ')} returned a non-zero return value! For details, see the _seed_* files in {run_dir}"))
}
cat("Seeding done: execute hosts have received and cached the bundle.\n")
cat("\n")

# Remove seeding temp files

invisible(file.remove(seed_bat))
for (hostdom in hostdoms) {
  hostname <- str_extract(hostdom, "^[^.]*")
  file.remove(file.path(temp_dir, str_glue("_seed_{hostname}.job")))
  file.remove(file.path(run_dir, str_glue("_seed_{hostname}.log")))
  file.remove(file.path(run_dir, str_glue("_seed_{hostname}.out")))
  file.remove(file.path(run_dir, str_glue("_seed_{hostname}.err")))
}

# ---- Prepare files for run ----

# Move the configuration from the temp to the run directory so as to have a persistent reference
config_file <- file.path(run_dir, str_glue("_config_{EXPERIMENT}_{predicted_cluster}.R"))
if (!file.copy(temp_config_file, config_file, overwrite=TRUE)) {
  invisible(file.remove(bundle_path))
  stop(str_glue("Cannot copy the configuration from {temp_config_file} to {run_dir}"))
}
invisible(file.remove(temp_config_file))

# Copy the SCRIPT to the run directory for reference
if (!file.copy(file.path(SCRIPT), file.path(run_dir, str_glue("{script_prefix}_{EXPERIMENT}_{predicted_cluster}.{script_extension}")), overwrite=TRUE)) {
  invisible(file.remove(bundle_path))
  stop(str_glue("Cannot copy the configured SCRIPT file to {run_dir}"))
}

# Define the template for the .bat file that specifies what should be run on the execute host side for each job.
# Note that the use of POSIX commands: requires MKS Toolkit or GAMS gbin to be on-path on Windows execute hosts.
# Execute-host-side automated bundle cleanup is assumed to be active:
# https://mis.iiasa.ac.at/portal/page/portal/IIASA/Content/TicketS/Ticket?defpar=1%26pWFLType=24%26pItemKey=103034818402942720
bat_template <- c(
  "@echo off",
  'grep "^Machine = " .machine.ad || exit /b %errorlevel%',
  "echo _CONDOR_SLOT = %_CONDOR_SLOT%",
  'md "{OUTPUT_DIR}" 2>NUL || exit /b %errorlevel%',
  "@echo on",
  "touch e:\\condor\\bundles\\{username}\\{unique_bundle} 2>NUL", # postpone automated cleanup of bundle, can fail when another job is using the bundle but that's fine as the touch will already have happened
  '7z x e:\\condor\\bundles\\{username}\\{unique_bundle} -y >NUL || exit /b %errorlevel%',
  "{LAUNCHER} {SCRIPT} {ARGUMENTS}",
  "set script_errorlevel=%errorlevel%",
  "@echo off",
  "if %script_errorlevel% neq 0 (",
  "  echo ERROR: script failed with error code %script_errorlevel% 1>&2",
  ")",
  "sleep 1", # Make it less likely that the .out file is truncated.
  "exit /b %script_errorlevel%"
)

# Apply settings to bat template and write the .bat file
job_bat <- file.path(temp_dir_parent, str_glue("job_{EXPERIMENT}_{predicted_cluster}.bat"))
bat_conn<-file(job_bat, open="wt")
writeLines(unlist(lapply(bat_template, str_glue)), bat_conn)
close(bat_conn)

# Define the Condor .job file template for the run
job_template <- c(
  "executable = {job_bat}",
  "arguments = $(job)",
  "universe = vanilla",
  "",
  "# Job log, output, and error files",
  "log = {run_dir}/{PREFIX}_{EXPERIMENT}_$(cluster).$(job).log", # don't use $$() expansion here: Condor creates the log file before it can resolve the expansion
  "output = {run_dir}/{PREFIX}_{EXPERIMENT}_$(cluster).$(job).out",
  "stream_output = True",
  "error = {run_dir}/{PREFIX}_{EXPERIMENT}_$(cluster).$(job).err",
  "stream_error = True",
  "",
  "periodic_release =  (NumJobStarts < {JOB_RELEASES}) && ((CurrentTime - EnteredCurrentStatus) > 120)", # if job goes on hold, release up to 5 times after 2 minutes
  "",
  "requirements = \\",
  '  ( (Arch =="INTEL")||(Arch =="X86_64") ) && \\',
  '  ( (OpSys == "WINDOWS")||(OpSys == "WINNT61") ) && \\',
  "  ( GLOBIOM =?= True ) && \\",
  "  ( ( TARGET.Machine == \"{str_c(hostdoms, collapse='\" ) || ( TARGET.Machine == \"')}\") )",
  "request_memory = {REQUEST_MEMORY}",
  "request_cpus = {REQUEST_CPUS}", # Number of "CPUs" (hardware threads) to reserve for each job
  "request_disk = {request_disk}",
  "",
  '+IIASAGroup = "ESM"', # Identifies you as part of the group allowed to use ESM cluster
  "run_as_owner = True", # If True, jobs will run as you and have access to your account-specific configuration such as your H: drive. If False, jobs will run under a functional user account.
  "",
  "should_transfer_files = YES",
  "when_to_transfer_output = ON_EXIT",
  'transfer_output_files = {ifelse(GET_OUTPUT, str_glue("{OUTPUT_DIR}/{OUTPUT_FILE}"), "")}',
  'transfer_output_remaps = "{ifelse(GET_OUTPUT, str_glue("{OUTPUT_FILE}={OUTPUT_DIR}/{output_prefix}_{EXPERIMENT}_$(cluster).$$([substr(strcat(string(0),string(0),string(0),string(0),string(0),string(0),string($(job))),-6)]).{output_extension}"), "")}"',
  "",
  "notification = Error", # Per-job, so you'll get spammed setting it to Always or Complete.
  "",
  "queue job in ({str_c(JOBS,collapse=',')})"
)

# Apply settings to job template and write the .job file to use for submission
job_file <- file.path(run_dir, str_glue("submit_{EXPERIMENT}_{predicted_cluster}.job"))
job_conn<-file(job_file, open="wt")
writeLines(unlist(lapply(job_template, str_glue)), job_conn)
close(job_conn)

# ---- Submit the run and clean up temp files ----

outerr <- system2("condor_submit", args=str_glue("{run_dir}/submit_{EXPERIMENT}_{predicted_cluster}.job"), stdout=TRUE, stderr=TRUE)
cat(outerr, sep="\n")
if (!is.null(attr(outerr, "status")) && attr(outerr, "status") != 0) {
  invisible(file.remove(bundle_path))
  stop("Submission of Condor run failed!")
}
cluster <- as.integer(str_match(tail(grep(cluster_regexp, outerr, value=TRUE), 1), cluster_regexp)[2])
if (is.na(cluster)) {
  invisible(file.remove(bundle_path))
  stop("Cannot extract cluster number from condor_submit output!")
}
if (cluster != predicted_cluster) {
  # system2("condor_rm", args=str_glue("{cluster}")) # should do this, but it does not work due to some weird Condor/R/Windows bug.
  invisible(file.remove(bundle_path))
  stop(str_glue("Submission cluster number {cluster} not equal to prediction {predicted_cluster}! You probably submitted something else via Condor while this submission was ongoing, causing the cluster number (sequence count of your submissions) to increment. As a result, log files have been named with a wrong cluster number.\n\nPlease do not submit additional Condor jobs until after a submission has completed. Note that this does not mean that you have to wait for the run to complete before submitting further runs, just wait for the submission to make it to the point where the execute hosts have been handed the jobs. Please try again.\n\nYou should first remove the run's jobs with: condor_rm {cluster}."))
}

# Retain the bundle if so requested, then remove it from temp
if (RETAIN_BUNDLE) {
  success <- file.copy(bundle_path, file.path(run_dir, str_glue("bundle_{EXPERIMENT}_{cluster}.7z")))
  if (!success) warning("Could not make a reference copy of bundle!")
}
invisible(file.remove(bundle_path)) # Removing the bundle unblocks this script for another submission
cat(str_glue('Run "{EXPERIMENT}" has been submitted, it is now possible to submit additional runs while waiting for it to complete.'), sep="\n")

# Remove dated job batch files that are almost certainly no longer in use (older than 10 days)
# Needed because Windows does not periodically clean up TEMP and because the current job batch
# file is not deleted unless you make this script wait for the run to complete.
for (bat_path in list.files(path=temp_dir_parent, pattern=str_glue("job_.*_\\d+.bat"), full.names=TRUE)) {
  if (difftime(Sys.time(), file.info(bat_path)$ctime, unit="days") > 10) invisible(file.remove(bat_path))
}

# ---- Handle run results ----

if (WAIT_FOR_RUN_COMPLETION) {
  # Monitor the run until it completes
  cat(str_glue('Waiting for run "{EXPERIMENT}" to complete...'), sep="\n")
  monitor(cluster)

  # Remove the job batch file. This is done after waiting for the run to complete
  # because jobs can continue to be scheduled well after the initial submission when
  # there are more jobs in the run than available slot partitions.
  invisible(file.remove(job_bat))

  # Check that result files exist and are not empty, warn otherwise and remove empty files
  if (GET_OUTPUT) {
    output_files_complete <- all_exist_and_not_empty(OUTPUT_DIR, 'output_{EXPERIMENT}_{cluster}.{sprintf("%06d", job)}.{output_extension}', output_extension)
  }

  return_values <- get_return_values(run_dir, lapply(JOBS, function(job) return(str_glue("{PREFIX}_{EXPERIMENT}_{cluster}.{job}.log"))))
  if (any(is.na(return_values))) {
    stop(str_glue("Abnormal termination of job(s) {summarize_jobs(JOBS[is.na(return_values)])}! For details, see the {PREFIX}_{EXPERIMENT}_{cluster}.* files in {run_dir}"))
  }
  if (any(return_values != 0)) {
    stop(str_glue("Job(s) {summarize_jobs(JOBS[return_values != 0])} returned a non-zero return value! For details, see the {PREFIX}_{EXPERIMENT}_{cluster}.* files in {run_dir}"))
  }
  cat("All jobs are done.\n")

  # Warn when REQUEST_MEMORY turns out to have been set too low or significantly too high
  max_memory_use <- -1
  max_memory_job <- -1
  memory_use_regexp <- "^\\s+Memory \\(MB\\)\\s+:\\s+(\\d+)\\s+"
  for (job in JOBS) {
    job_lines <- readLines(file.path(run_dir, str_glue("{PREFIX}_{EXPERIMENT}_{cluster}.{job}.log")))
    memory_use <- as.double(str_match(tail(grep(memory_use_regexp, job_lines, value=TRUE), 1), memory_use_regexp)[2])
    if (!is.na(memory_use) && memory_use > max_memory_use) {
      max_memory_use <- memory_use
      max_memory_job <- job
    }
  }
  if (max_memory_job >= 0 && max_memory_use > REQUEST_MEMORY) {
    warning(str_glue("The job ({max_memory_job}) with the highest memory use ({max_memory_use} MiB) exceeded the REQUEST_MEMORY config."))
  }
  if (max_memory_job >= 0 && max_memory_use/REQUEST_MEMORY < 0.75 && max_memory_use > 1000) {
    warning(str_glue("REQUEST_MEMORY ({REQUEST_MEMORY} MiB) is significantly larger than the memory use ({max_memory_use} MiB) of the job ({max_memory_job}) using the most memory, you can request less."))
  }

  # Make a bit of noise to notify the user of completion (works from RScript but not RStudio)
  alarm()
  Sys.sleep(1)
  alarm()
} else {
  cat(str_glue("You can monitor progress of the run with: condor_q {cluster}."), sep="\n")
  cat(str_glue("After the run completes, you can find the output files at: {OUTPUT_DIR}/{output_prefix}_{EXPERIMENT}_{cluster}.*"), sep="\n")
}
