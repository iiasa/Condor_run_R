#!/usr/bin/env Rscript
# Submit a Condor run (a set of jobs). Expanded version for GAMS jobs. Can
# be configured to monitor progress and merge gdx output on completion.
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
# Rscript Condor_run.R my_config.R
#
# either from the command prompt, shell, via the GAMS $call or execute
# facilities, or using whatever your language of choice supports for
# command invocation.
#
# When invoking this script, the working directory (current directory)
# must contain the the files to be bundled up with 7-zip. The bundle is
# sent over to the remote execute hosts and is unpacked there at the
# start of each job. The GAMS file to run for a job should be contained
# in the bundle and configured with GAMS_FILE_PATH. If this GAMS file
# must run from a different working directory, set the GAMS_CURDIR config
# option accordingly.
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
# When using MERGE_GDX_OUTPUT=TRUE, the gdxmerge executable should be
# on-path. This can be done by adding your local GAMS installation
# directory to PATH.
#
# This script requires you to have a recent version of Condor installed.
# On Windows, the installer adds the Condor/bin directory to the PATH
# system environment variable, thus making the Condor commands available.
#
# BEWARE: gdxmerge is limited. It sometimes gives "Symbol is too large"
# errors, and neither the big= (MERGE_BIG configuration setting) nor
# running gdxmerge on a large-memory machine can avoid that. Moreover,
# no non-zero return code results in case of such errors.
#
# Author: Albert Brouwer
# Based on: GLOBIOM-limpopo scripts by David Leclere
# Repository: https://github.com/iiasa/Condor_run_R
#
# Todo:
# - Parse errors from gdxmerge output to work around 0 return code.

# ---- Default run config settings ----

# Remove any objects from active environment so that below it will contain only the default config
rm(list=ls())

# Override the default config settings via a run-config file passed as a first
# argument to this script. Lines with settings like the ones just below can be
# used in the config file. Only settings marked as optional can be omitted from
# the config file.
#
# To set up an initial config file, just copy-and-paste (DO NOT CUT) the below
# to a file, give it a .R extension to get nice syntax highlighting.
#
# Note that in the below defaults, an output GDX is produced via the gdx= GAMS
# command line parameter. However, you may wish to limit what goes into the
# GDX by instead using EXECUTE_UNLOAD from GAMS.
#
# Use paths with / as path separator.
# Unless otherwise specified, paths are relative to the current working directory.
# .......8><....snippy.snappy....8><.........................................
EXPERIMENT = "test" # label for your run, pick something short but descriptive without spaces and valid as part of a filename
PREFIX = "_globiom" # prefix for per-job .err, log, .lst, and .out files
JOBS = c(0:3,7,10)
HOST_REGEXP = "^limpopo" # a regular expression to select execute hosts from the cluster
REQUEST_MEMORY = 7800 # memory (MiB) to reserve for each job
REQUEST_CPUS = 1 # number of hardware threads to reserve for each job
GAMS_CURDIR = "" # optional, working directory for GAMS and its arguments relative to working directory, "" defaults to the working directory
GAMS_FILE_PATH = "6_scenarios_limpopo.gms" # path to GAMS file to run for each job, relative to GAMS_CURDIR
GAMS_VERSION = "24.4" # must be installed on all execute hosts
GAMS_ARGUMENTS = "gdx={GDX_OUTPUT_DIR}/{GDX_OUTPUT_FILE} //nsim='%1' PC=2 PS=0 PW=130" # additional GAMS arguments, can use {<config>} expansion here
BUNDLE_INCLUDE = "*" # optional, recursive, what to include in bundle, can be a wildcard
BUNDLE_INCLUDE_DIRS = c() # optional, further directories to include recursively, added to root of bundle, supports wildcards
BUNDLE_EXCLUDE_DIRS = c(".git", ".svn", "225*") # optional, recursive, supports wildcards
BUNDLE_EXCLUDE_FILES = c("**/*.~*", "**/*.log", "**/*.log~*", "**/*.lxi", "**/*.lst") # optional, supports wildcards
BUNDLE_ADDITIONAL_FILES = c() # optional, additional files to add to root of bundle, can also use an absolute path for these
RETAIN_BUNDLE = FALSE # optional
RESTART_FILE_PATH = "" # optional, included in bundle if set, relative to GAMS_CURDIR
G00_OUTPUT_DIR = "t" # relative to GAMS_CURDIR both host-side and on the submit machine, excluded from bundle
G00_OUTPUT_FILE = "a6_out.g00" # host-side, will be remapped with EXPERIMENT and cluster/job numbers to avoid name collisions when transferring back to the submit machine.
GET_G00_OUTPUT = FALSE
GDX_OUTPUT_DIR = "gdx" # relative to GAMS_CURDIR both host-side and on the submit machine, excluded from bundle
GDX_OUTPUT_FILE = "output.gdx" # as produced on the host-side by gdx= GAMS parameter or execute_unload, will be remapped with EXPERIMENT and cluster/job numbers to avoid name collisions when transferring back to the submit machine.
GET_GDX_OUTPUT = TRUE
WAIT_FOR_RUN_COMPLETION = TRUE
MERGE_GDX_OUTPUT = FALSE # optional
MERGE_BIG = NULL # optional, symbol size cutoff beyond which GDXMERGE writes symbols one-by-one to avoid running out of memory.
MERGE_ID = NULL # optional, comma-separated list of symbols to include in the merge, defaults to all
MERGE_EXCLUDE = NULL # optional, comma-separated list of symbols to exclude from the merge, defaults to none
REMOVE_MERGED_GDX_FILES = FALSE # optional
CONDOR_DIR = "Condor" # optional, directory where Condor reference files are stored in a per-experiment subdirectory (.err, .log, .out, .job and so on files), excluded from bundle
SEED_JOB_RELEASES = 4 # optional, number of times to auto-release (retry) held seed jobs before giving up
JOB_RELEASES = 3 # optional, number of times to auto-release (retry) held jobs before giving up
RUN_AS_OWNER = TRUE # optional, if TRUE, jobs will run as you and have access to your account-specific environment. If FALSE, jobs will run under a functional user account.
NOTIFICATION = "Never" # optional, when to send notification emails. Alternatives are "Complete": job completes; "Error": job errors or goes on hold; "Always": job completes or reaches checkpoint.
EMAIL_ADDRESS= NULL # optional, set with your email if you don't receive notifications. Typically not needed as Condor by default tries to infer your emmail from your username.
# .......8><....snippy.snappy....8><.........................................

# Collect the names and types of the default config settings
config_names <- ls()
if (length(config_names) == 0) {stop("Default configuration is absent! Please restore the default configuration. It is required for configuration checking, also when providing a separate configuration file.")}
config_types <- lapply(lapply(config_names, get), typeof)

# Presence of Config settings is obligatory in a config file other then for the settings listed here
OPTIONAL_CONFIG_SETTINGS <- c(
  "BUNDLE_INCLUDE",
  "BUNDLE_INCLUDE_DIRS",
  "BUNDLE_EXCLUDE_DIRS",
  "BUNDLE_EXCLUDE_FILES",
  "BUNDLE_ADDITIONAL_FILES",
  "RETAIN_BUNDLE",
  "GAMS_CURDIR",
  "RESTART_FILE_PATH",
  "MERGE_GDX_OUTPUT",
  "MERGE_BIG",
  "MERGE_ID",
  "MERGE_EXCLUDE",
  "REMOVE_MERGED_GDX_FILES",
  "CONDOR_DIR",
  "SEED_JOB_RELEASES",
  "JOB_RELEASES",
  "RUN_AS_OWNER",
  "NOTIFICATION",
  "EMAIL_ADDRESS"
)

# ---- Get set ----

# Required packages
library(stringr)

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
  # Remove mandatatory config defaults from the global scope
  rm(list=config_names[!(config_names %in% OPTIONAL_CONFIG_SETTINGS)])

  # Source the config file, should add mandatory config settings to the global scope
  source(args[1], local=TRUE, echo=FALSE)

  # Check that no-longer-supported config setting does not exist
  if (exists("GAMS_FILE")) stop(str_glue("Config setting GAMS_FILE is no longer supported, but is present in config file {args[1]}. Please use GAMS_FILE_PATH instead."))

  # Check that all config settings exist, this catches mandatory settings missing in the config file
  for (i in seq_along(config_names))  {
    name <- config_names[i]
    if (!exists(name)) stop(str_glue("Mandatory config setting {name} is not set in config file {args[1]}!"))
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

# Define a function to turn a path relative to GAMS_CURDIR into a path relative to the working directory when GAMS_CURDIR is set.
in_gams_curdir <- function(path) {
  if (GAMS_CURDIR == "") {
    return(path)
  } 
  else {
    return(file.path(GAMS_CURDIR, path))
  }
}

# Check and massage specific config settings
EXECUTE_HOST_GAMS_VERSIONS = c("24.2", "24.4", "25.1")
if (GAMS_CURDIR != "" && !dir.exists(GAMS_CURDIR)) stop(str_glue("No {GAMS_CURDIR} directory as configured in GAMS_CURDIR found relative to working directory {getwd()}!"))
if (!dir.exists(CONDOR_DIR)) stop(str_glue("No {CONDOR_DIR} directory as configured in CONDOR_DIR found relative to working directory {getwd()}!"))
if (str_detect(EXPERIMENT, '[<>|:?*" \\t/\\\\]')) stop(str_glue("Configured EXPERIMENT label for run has forbidden character(s)!"))
if (str_detect(PREFIX, '[<>|:?*" \\t/\\\\]')) stop(str_glue("Configured PREFIX has forbidden character(s)!"))
if (!is.numeric(JOBS)) stop("JOBS does not list job numbers!")
if (length(JOBS) < 1) stop("There should be at least one job in JOBS!")
if (!all(JOBS == floor(JOBS))) stop("Job numbers in JOBS must be whole numbers!")
if (!all(JOBS < 1e6)) stop("Job numbers in JOBS must be less than 1000000 (one million)!")
if (!all(JOBS >= 0)) stop("Job numbers in JOBS may not be negative!")
if (!(REQUEST_MEMORY > 0)) stop("REQUEST_MEMORY should be larger than zero!")
if (!all(!duplicated(JOBS))) stop("Duplicate JOB numbers listed in JOBS!")
if (str_sub(GAMS_FILE_PATH, -4) != ".gms") stop(str_glue("Configured GAMS_FILE_PATH has no .gms extension!"))
if (!(file.exists(in_gams_curdir(GAMS_FILE_PATH)))) stop(str_glue('Configured GAMS_FILE_PATH "{GAMS_FILE_PATH}" does not exist relative to GAMS_CURDIR!'))
if (str_detect(GAMS_FILE_PATH, '[<>|:?*" \\t\\\\]')) stop(str_glue("Configured GAMS_FILE_PATH has forbidden character(s)! Use / as path separator."))
  if (RESTART_FILE_PATH != "") {
  if (!(file.exists(in_gams_curdir(RESTART_FILE_PATH)))) stop(str_glue('Configured RESTART_FILE_PATH "{RESTART_FILE_PATH}" does not exist relative to GAMS_CURDIR!'))
  if (str_detect(RESTART_FILE_PATH, "^/") || str_detect(RESTART_FILE_PATH, "^.:")) stop(str_glue("Configured RESTART_FILE_PATH must be located under the working directory for proper bundling: absolute paths not allowed!"))
  if (str_detect(RESTART_FILE_PATH, fixed("../"))) stop(str_glue("Configured RESTART_FILE_PATH must be located under the working directory for proper bundling: you may not go up to parent directories using ../"))
  if (str_detect(RESTART_FILE_PATH, '[<>|:?*" \\t\\\\]')) stop(str_glue("Configured RESTART_FILE_PATH has forbidden character(s)! Use / as path separator."))
}
version_match <- str_match(GAMS_VERSION, "^(\\d+)[.](\\d+)$")
if (any(is.na(version_match))) stop(str_glue('Invalid GAMS_VERSION "{GAMS_VERSION}"! Format must be "<major>.<minor>".'))
if (!(GAMS_VERSION %in% EXECUTE_HOST_GAMS_VERSIONS)) stop(str_glue('Invalid GAMS_VERSION "{GAMS_VERSION}"! The execute hosts have only these GAMS versions installed: {str_c(EXECUTE_HOST_GAMS_VERSIONS, collapse=" ")}')) # {cat(EXECUTE_HOST_GAMS_VERSIONS)}
dotless_version <- str_glue(version_match[2], version_match[3])
if (!str_detect(GAMS_ARGUMENTS, fixed("%1"))) stop("Configured GAMS_ARGUMENTS lack a %1 batch file argument expansion that must be used for passing the job number with which the job-specific (e.g. scenario) can be selected.")
for (file in BUNDLE_ADDITIONAL_FILES) {
  if (!(file.exists(file.path(file)))) stop(str_glue('Misconfigured BUNDLE_ADDITIONAL_FILES: "{file}" does not exist!'))
}
if (!(GET_G00_OUTPUT || GET_GDX_OUTPUT)) stop("Neither GET_G00_OUTPUT nor GET_GDX_OUTPUT are TRUE! A run without output is pointless.")
if (!(file.exists(in_gams_curdir(G00_OUTPUT_DIR)))) stop(str_glue('Configured G00_OUTPUT_DIR "{G00_OUTPUT_DIR}" does not exist relative to GAMS_CURDIR!'))
if (str_detect(G00_OUTPUT_DIR, "^/") || str_detect(G00_OUTPUT_DIR, "^.:")) stop(str_glue("Configured G00_OUTPUT_DIR must be located under the working directory: absolute paths not allowed!"))
if (str_detect(G00_OUTPUT_DIR, fixed("../"))) stop(str_glue("Configured G00_OUTPUT_DIR must be located under the working directory: you may not go up to parent directories using ../"))
if (str_detect(G00_OUTPUT_DIR, '[<>|:?*" \\t\\\\]')) stop(str_glue("Configured G00_OUTPUT_DIR has forbidden character(s)! Use / as path separator."))
if (str_sub(G00_OUTPUT_FILE, -4) != ".g00") stop(str_glue("Configured G00_OUTPUT_FILE has no .g00 extension!"))
if (str_length(G00_OUTPUT_FILE) <= 4) stop(str_glue("Configured G00_OUTPUT_FILE needs more than an extension!"))
if (str_detect(G00_OUTPUT_FILE, '[<>|:?*" \\t/\\\\]')) stop(str_glue("Configured G00_OUTPUT_FILE has forbidden character(s)!"))
g00_prefix <- str_sub(G00_OUTPUT_FILE, 1, -5)
if (!(file.exists(in_gams_curdir(GDX_OUTPUT_DIR)))) stop(str_glue('Configured GDX_OUTPUT_DIR "{GDX_OUTPUT_DIR}" does not exist relative to GAMS_CURDIR!'))
if (str_detect(GDX_OUTPUT_DIR, "^/") || str_detect(GDX_OUTPUT_DIR, "^.:")) stop(str_glue("Configured GDX_OUTPUT_DIR must be located under the working directory: absolute paths not allowed!"))
if (str_detect(GDX_OUTPUT_DIR, fixed("../"))) stop(str_glue("Configured GDX_OUTPUT_DIR must be located under the working directory: you may not go up to parent directories using ../"))
if (str_detect(GDX_OUTPUT_DIR, '[<>|:?*" \\t\\\\]')) stop(str_glue("Configured GDX_OUTPUT_DIR has forbidden character(s)! Use / as path separator."))
if (str_sub(GDX_OUTPUT_FILE, -4) != ".gdx") stop(str_glue("Configured GDX_OUTPUT_FILE has no .gdx extension!"))
if (str_length(GDX_OUTPUT_FILE) <= 4) stop(str_glue("Configured GDX_OUTPUT_FILE needs more than an extension!"))
if (str_detect(GDX_OUTPUT_FILE, '[<>|:?*" \\t/\\\\]')) stop(str_glue("Configured GDX_OUTPUT_FILE has forbidden character(s)!"))
gdx_prefix <- str_sub(GDX_OUTPUT_FILE, 1, -5)
if (MERGE_GDX_OUTPUT && !GET_GDX_OUTPUT) stop("Cannot MERGE_GDX_OUTPUT without first doing GET_GDX_OUTPUT!")
if (MERGE_GDX_OUTPUT && !WAIT_FOR_RUN_COMPLETION) stop("Cannot MERGE_GDX_OUTPUT without first doing WAIT_FOR_RUN_COMPLETION!")
if (REMOVE_MERGED_GDX_FILES && !MERGE_GDX_OUTPUT) stop("Cannot REMOVE_MERGED_GDX_FILES without first doing MERGE_GDX_OUTPUT!")

# Determine GAMS version used to generate RESTART_FILE_PATH, verify that it is <= GAMS_VERSION
if (RESTART_FILE_PATH != "") {
  conn <- file(in_gams_curdir(RESTART_FILE_PATH), "rb")
  byte_count <- min(4000, file.info(in_gams_curdir(RESTART_FILE_PATH))$size)
  invisible(seek(conn, where=-byte_count, origin="end"))
  tail_bytes <- readBin(conn, what=integer(), size=1, n=byte_count)
  close(conn)
  tail_bytes[tail_bytes <= 0] <- 32
  tail <-  rawToChar(as.raw(tail_bytes))
  restart_version <- str_match(tail, "\x0AWEX(\\d\\d\\d)-\\d\\d\\d")[2]
  if (is.na(restart_version)) {
    warning(str_glue("Cannot determine GAMS version that saved {in_gams_curdir{(RESTART_FILE_PATH)}"))
  } else {
    if (dotless_version < restart_version) {
      stop("The configured host-side GAMS_VERSION is older than the GAMS version that saved the configured restart file (RESTART_FILE_PATH). GAMS will fail!")
    }
  }
}

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
  q_errors        <- 0
  prior_jobs      <- -1
  prior_completed <- -1
  prior_removed   <- -1
  prior_idle      <- -1
  prior_running   <- -1
  prior_held      <- -1
  prior_suspended <- -1
  while (prior_jobs != 0) {
    Sys.sleep(1)

    # Collect Condor queue information via condor_q
    outerr <- system2("condor_q", args=c("-totals", "-wide", clusters), stdout=TRUE, stderr=TRUE)
    if (!is.null(attr(outerr, "status")) && attr(outerr, "status") != 0) {
      q_errors <- q_errors+1
      if (q_errors >= 10) {
        # 10 consecutive condor_q errors, probably not transient, report and stop
        cat(outerr, sep="\n")
        stop("Invocation of condor_q failed! Are you running a too old (< V8.5.4) Condor version?", call.=FALSE)
      } else {
        # Fewer than 10 consecutive condor_q errors, retry
        next
      }
    }
    q_errors <- 0

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
bundle_path <- file.path(temp_dir_parent, bundle) # Invariant so that it can double-duty as a lock file blocking interfering parallel submisisons
bundle_platform_path <- str_replace_all(bundle_path, fixed(.Platform$file.sep), fsep)
if (file.exists(bundle_path)) stop(str_glue("{bundle_path} already exists! Is there another submission ongoing? If so, let that submission end first. If not, remove the file and try again."))

cat("Compressing model files into bundle...\n")
model_byte_size <- handle_7zip(system2("7z", stdout=TRUE, stderr=TRUE,
  args=unlist(lapply(c("a", "-mx1", "-bb0",
    unlist(lapply(BUNDLE_INCLUDE_DIRS, function(p) return(str_glue("-ir!", p)))),
    unlist(lapply(BUNDLE_EXCLUDE_DIRS, function(p) return(str_glue("-xr!", p)))),
    unlist(lapply(BUNDLE_EXCLUDE_FILES, function(p) return(str_glue("-x!", p)))),
    "-xr!{CONDOR_DIR}",
    "-xr!{in_gams_curdir(G00_OUTPUT_DIR)}",
    "-xr!{in_gams_curdir(GDX_OUTPUT_DIR)}",
    "{bundle_platform_path}",
    "{BUNDLE_INCLUDE}"
  ), str_glue))
))
cat("\n")

additional_byte_size <- 0
if (RESTART_FILE_PATH != "" || length(BUNDLE_ADDITIONAL_FILES) != 0) {
  cat("Bundling additional files...\n")
  args <- c("a", bundle_platform_path)
  if (RESTART_FILE_PATH != "") args <- c(args, in_gams_curdir(RESTART_FILE_PATH))
  if (length(BUNDLE_ADDITIONAL_FILES) != 0) args <- c(args, BUNDLE_ADDITIONAL_FILES)
  additional_byte_size <- handle_7zip(system2("7z", stdout=TRUE, stderr=TRUE, args=args))
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
  seed_job_template <- c(
    "executable = {seed_bat}",
    "universe = vanilla",
    "",
    "# Job log, stdout, and stderr files",
    "log = {run_dir}/_seed_{hostname}.log",
    "output = {run_dir}/_seed_{hostname}.out",
    "error = {run_dir}/_seed_{hostname}.err",
    "",
    "periodic_release = (NumJobStarts < {SEED_JOB_RELEASES}) && ((CurrentTime - EnteredCurrentStatus) > 60)", # if seed job goes on hold for more than 1 minute, release it up to SEED_JOB_RELEASES times
    "",
    "requirements = \\",
    '  ( (Arch =="INTEL")||(Arch =="X86_64") ) && \\',
    '  ( (OpSys == "WINDOWS")||(OpSys == "WINNT61") ) && \\',
    "  ( GLOBIOM =?= True ) && \\",
    '  ( TARGET.Machine == "{hostdom}" )',
    "",
    "periodic_remove = (JobStatus == 1) && (CurrentTime - EnteredCurrentStatus > 120 )", # if seed job remains idle for more than 2 minutes, remove it as presumably the execute host is not responding
    "",
    "request_memory = 0",
    "request_cpus = 0", # We want this to get scheduled even when all CPUs are in-use, but current Condor still waits when all CPUs are partitioned.
    "request_disk = {2*bundle_size+500}", # KiB, twice needed for move, add some for the extra files
    "",
    '+IIASAGroup = "ESM"',
    "run_as_owner = False",
    "",
    "should_transfer_files = YES",
    'transfer_input_files = {bundle_path}',
    "",
    "queue 1"
  )

  # Apply settings to seed job template and write the .job file to use for submission
  seed_job_file <- file.path(temp_dir, str_glue("_seed_{hostname}.job"))
  seed_job_conn<-file(seed_job_file, open="wt")
  writeLines(unlist(lapply(seed_job_template, str_glue)), seed_job_conn)
  close(seed_job_conn)
  rm(seed_job_template, seed_job_conn)

  # Remove any job output left over from an aborted prior run
  remove_if_exists(run_dir, str_glue("_seed_{hostname}.log"))
  remove_if_exists(run_dir, str_glue("_seed_{hostname}.out"))
  remove_if_exists(run_dir, str_glue("_seed_{hostname}.err"))

  outerr <- system2("condor_submit", args=seed_job_file, stdout=TRUE, stderr=TRUE)
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

# Wait until seed jobs complete
cat("Waiting for bundle seeding to complete...\n")
monitor(clusters)
return_values <- get_return_values(run_dir, lapply(hostnames, function(hostname) return(str_glue("_seed_{hostname}.log"))))
rm(clusters)

# Check whether seed jobs terminated abnormally
if (all(is.na(return_values))) {
  invisible(file.remove(bundle_path))
  stop(str_glue("All seeding jobs terminated abnormally! For details, see the _seed_* files in {run_dir}. The likely cause is explained here: https://github.com/iiasa/Condor_run_R/blob/master/README.md#all-seeding-jobs-remain-idle-and-then-abort-through-the-periodicremove-expression"))
}
if (any(is.na(return_values))) {
  if (length(return_values[is.na(return_values)]) == 1) {
    warning(str_glue("A seeding job terminated abnormally, will refrain from scheduling jobs on the affected execute host {hostnames[is.na(return_values)]}. Probably, this host is currently unavailable."))
  } else {
    warning(str_glue("Seeding jobs terminated abnormally, will refrain from scheduling jobs on the affected execute hosts {str_c(hostnames[is.na(return_values)], collapse=', ')}. Probably, these hosts are currently unavailable."))
  }
  hostdoms <- hostdoms[!is.na(return_values)]
  hostnames <- hostnames[!is.na(return_values)]
  return_values <- return_values[!is.na(return_values)]
}

# Check whether seed jobs returned a non-zero return value
if (any(return_values != 0)) {
  invisible(file.remove(bundle_path))
  stop(str_glue("Seeding job(s) for {str_c(hostnames[return_values != 0], collapse=', ')} returned a non-zero return value! For details, see the _seed_* files in {run_dir}"))
}
rm(return_values)

# Remove seeding log files of normally terminated seed jobs
invisible(file.remove(seed_bat))
for (hostname in hostnames) {
  file.remove(file.path(temp_dir, str_glue("_seed_{hostname}.job")))
  file.remove(file.path(run_dir, str_glue("_seed_{hostname}.log")))
  file.remove(file.path(run_dir, str_glue("_seed_{hostname}.out")))
  file.remove(file.path(run_dir, str_glue("_seed_{hostname}.err")))
}

# Report that seeding is done
if (length(hostnames) == 1) {
  cat(str_glue("Seeding done: execute host {hostnames} has received and cached the bundle.\n"))
} else {
  cat(str_glue("Seeding done: execute hosts {str_c(hostnames, collapse=', ')} have received and cached the bundle.\n"))
}
cat("\n")
rm(hostnames)

# ---- Prepare files for run ----

# Move the configuration from the temp to the run directory so as to have a persistent reference
config_file <- file.path(run_dir, str_glue("_config_{EXPERIMENT}_{predicted_cluster}.R"))
if (!file.copy(temp_config_file, config_file, overwrite=TRUE)) {
  invisible(file.remove(bundle_path))
  stop(str_glue("Cannot copy the configuration from {temp_config_file} to {run_dir}"))
}
invisible(file.remove(temp_config_file))

# Copy the GAMS file to the run directory for reference
if (!file.copy(file.path(in_gams_curdir(GAMS_FILE_PATH)), file.path(run_dir, str_glue("{str_sub(basename(GAMS_FILE_PATH), 1, -5)}_{EXPERIMENT}_{predicted_cluster}.gms")), overwrite=TRUE)) {
  invisible(file.remove(bundle_path))
  stop(str_glue("Cannot copy the configured GAMS_FILE_PATH file to {run_dir}"))
}

# Define the template for the .bat file that specifies what should be run on the execute host side for each job.
# Note the use of POSIX commands: requires MKS Toolkit or GAMS gbin to be on-path on Windows execute hosts.
# Execute-host-side automated bundle cleanup is assumed to be active:
# https://mis.iiasa.ac.at/portal/page/portal/IIASA/Content/TicketS/Ticket?defpar=1%26pWFLType=24%26pItemKey=103034818402942720
bat_template <- c(
  "@echo off",
  'grep "^Machine = " .machine.ad || exit /b %errorlevel%',
  "echo _CONDOR_SLOT = %_CONDOR_SLOT%",
  'mkdir "{in_gams_curdir(G00_OUTPUT_DIR)}" 2>NUL || exit /b %errorlevel%',
  'mkdir "{in_gams_curdir(GDX_OUTPUT_DIR)}" 2>NUL || exit /b %errorlevel%',
  "@echo on",
  "touch e:\\condor\\bundles\\{username}\\{unique_bundle} 2>NUL", # postpone automated cleanup of bundle, can fail when another job is using the bundle but that's fine as the touch will already have happened
  '7z x e:\\condor\\bundles\\{username}\\{unique_bundle} -y >NUL || exit /b %errorlevel%',
  "set GDXCOMPRESS=1", # causes GAMS to compress the GDX output file
  'C:\\GAMS\\win64\\{GAMS_VERSION}\\gams.exe "{GAMS_FILE_PATH}" -logOption=3 {ifelse(GAMS_CURDIR != "", str_glue("curDir=\\"{GAMS_CURDIR}\\" "), "")}{ifelse(RESTART_FILE_PATH != "", str_glue("restart=\\"{RESTART_FILE_PATH}\\" "), "")}save="{G00_OUTPUT_DIR}/{g00_prefix}" {str_glue(GAMS_ARGUMENTS)}',
  "set gams_errorlevel=%errorlevel%",
  "@echo off",
  "if %gams_errorlevel% neq 0 (",
  "  echo ERROR: GAMS failed with error code %gams_errorlevel% 1>&2",
  "  echo See https://www.gams.com/latest/docs/UG_GAMSReturnCodes.html#UG_GAMSReturnCodes_ListOfErrorCodes 1>&2",
  ")",
  "sleep 1", # Make it less likely that the .out file is truncated.
  "exit /b %gams_errorlevel%"
)

# Apply settings to bat template and write the .bat file
job_bat <- file.path(temp_dir_parent, str_glue("job_{EXPERIMENT}_{predicted_cluster}.bat"))
bat_conn<-file(job_bat, open="wt")
writeLines(unlist(lapply(bat_template, str_glue)), bat_conn)
close(bat_conn)
rm(bat_template, bat_conn)

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
  "periodic_release =  (NumJobStarts < {JOB_RELEASES}) && ((CurrentTime - EnteredCurrentStatus) > 120)", # if seed job goes on hold for more than 2 minutes, release it up to JOB_RELEASES times
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
  "run_as_owner = {ifelse(RUN_AS_OWNER, 'True', 'False')}",
  "",
  "should_transfer_files = YES",
  "when_to_transfer_output = ON_EXIT",
  'transfer_output_files = {str_sub(in_gams_curdir(GAMS_FILE_PATH), 1, -5)}.lst{ifelse(GET_G00_OUTPUT, str_glue(",{in_gams_curdir(G00_OUTPUT_DIR)}/{G00_OUTPUT_FILE}"), "")}{ifelse(GET_GDX_OUTPUT, str_glue(",{in_gams_curdir(GDX_OUTPUT_DIR)}/{GDX_OUTPUT_FILE}"), "")}',
  'transfer_output_remaps = "{str_sub(GAMS_FILE_PATH, 1, -5)}.lst={run_dir}/{PREFIX}_{EXPERIMENT}_$(cluster).$(job).lst{ifelse(GET_G00_OUTPUT, str_glue(";{G00_OUTPUT_FILE}={in_gams_curdir(G00_OUTPUT_DIR)}/{g00_prefix}_{EXPERIMENT}_$(cluster).$(job).g00"), "")}{ifelse(GET_GDX_OUTPUT, str_glue(";{GDX_OUTPUT_FILE}={in_gams_curdir(GDX_OUTPUT_DIR)}/{gdx_prefix}_{EXPERIMENT}_$(cluster).$$([substr(strcat(string(0),string(0),string(0),string(0),string(0),string(0),string($(job))),-6)]).gdx"), "")}"',
  "",
  "notification = {NOTIFICATION}",
  '{ifelse(is.null(EMAIL_ADDRESS), "", str_glue("notify_user = {EMAIL_ADDRESS}"))}',
  "",
  "queue job in ({str_c(JOBS,collapse=',')})"
)

# Apply settings to job template and write the .job file to use for submission
job_file <- file.path(run_dir, str_glue("submit_{EXPERIMENT}_{predicted_cluster}.job"))
job_conn<-file(job_file, open="wt")
writeLines(unlist(lapply(job_template, str_glue)), job_conn)
close(job_conn)
rm(job_template, job_conn)

# ---- Submit the run and clean up temp files ----

outerr <- system2("condor_submit", args=job_file, stdout=TRUE, stderr=TRUE)
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

# Retain the bundle if so requested, then remove it from temp so that further submissions are no longer blocked
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
  lsts_complete <- all_exist_and_not_empty(run_dir, "{PREFIX}_{EXPERIMENT}_{cluster}.{job}.lst", ".lst")
  if (GET_G00_OUTPUT) {
    g00s_complete <- all_exist_and_not_empty(in_gams_curdir(G00_OUTPUT_DIR), "{g00_prefix}_{EXPERIMENT}_{cluster}.{job}.g00", "work (.g00)")
  }
  if (GET_GDX_OUTPUT) {
    gdxs_complete <- all_exist_and_not_empty(in_gams_curdir(GDX_OUTPUT_DIR), 'output_{EXPERIMENT}_{cluster}.{sprintf("%06d", job)}.gdx', "GDX")
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

  # Merge returned GDX files (implies GET_GDX_OUTPUT and WAIT_FOR_RUN_COMPLETION)
  if (MERGE_GDX_OUTPUT) {
    if (!gdxs_complete) {
      warning("MERGE_GDX_OUTPUT was set but not honored: no complete set of GDX files was returned.")
    } else {
      cat("Merging the returned GDX files...\n")
      prior_wd <- getwd()
      setwd(in_gams_curdir(GDX_OUTPUT_DIR))
      Sys.setenv(GDXCOMPRESS=1) # Causes the merged GDX file to be compressed, it will be usable as a regular GDX,
      # Compile arguments for gdxmerge
      merge_args <- c()
      if (exists("MERGE_BIG") && !is.null(MERGE_BIG) && (MERGE_BIG != "")) {
        merge_args <- c(merge_args, str_glue("big={MERGE_BIG}"))
      }
      if (exists("MERGE_ID") && !is.null(MERGE_ID) && (MERGE_ID != "")) {
        merge_args <- c(merge_args, str_glue("id={MERGE_ID}"))
      }
      if (exists("MERGE_EXCLUDE") && !is.null(MERGE_EXCLUDE) && (MERGE_EXCLUDE != "")) {
        merge_args <- c(merge_args, str_glue("exclude={MERGE_EXCLUDE}"))
      }
      merge_args <- c(merge_args, str_glue("{gdx_prefix}_{EXPERIMENT}_{cluster}.*.gdx"))
      merge_args <- c(merge_args, str_glue("output={gdx_prefix}_{EXPERIMENT}_{cluster}_merged.gdx"))
      # Invoke GDX merge
      error_code <- system2("gdxmerge", args=merge_args)
      setwd(prior_wd)
      if (error_code > 0) stop("Merging failed!")
      # Remove merged GDX files if so requested
      if (REMOVE_MERGED_GDX_FILES) {
        for (job in JOBS) {
          file.remove(file.path(in_gams_curdir(GDX_OUTPUT_DIR), str_glue('{gdx_prefix}_{EXPERIMENT}_{cluster}.{sprintf("%06d", job)}.gdx')))
        }
      }
    }
  }
  # Make a bit of noise to notify the user of completion (works from RScript but not RStudio)
  alarm()
  Sys.sleep(1)
  alarm()
} else {
  cat(str_glue("You can monitor progress of the run with: condor_q {cluster}."), sep="\n")
  cat(str_glue("After the run completes, you can find the GDX results at: {in_gams_curdir(GDX_OUTPUT_DIR)}/{gdx_prefix}_{EXPERIMENT}_{cluster}.*.gdx"), sep="\n")
}
