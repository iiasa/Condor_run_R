#!/usr/bin/env Rscript
# Submit a Condor run (a set of jobs). Can be configured to monitor
# progress and merge gdx output on completion.
#
# Usage: invoke this script via Rscript, or, on Linux/MacOS, you can
# invoke the script directly if its execute flag is set. The working
# directory must contain the configured files and directories. To use
# non-default config settings, pass a path to a configuration file as
# an argument to this script. The format of the configuration file is
# shown in the "Default run config settings section" below.
#
# If you cannot invoke Rscript, you will need to add where the R binaries
# reside to your PATH environment variable. On Windows, this is typically
# C:\Program Files\R\R-x.y.z\bin\x64 (where x.y.z is the R version).
#
# A fairly recent version of Condor is required to be installed on your
# submit machine. Version 8.2 is definitely too old.
#
# Also, 7z should be on-path. On Windows, this typically requires
# C:\Program Files\7-Zip to be added to your PATH environment variable.
# Use a recent 7-Zip version that can compress in parallel and supports
# the latest command line parameters. The execute hosts that you submit
# to should also have 7-Zip on-path. This is the case for the limpopo
# machines.
#
# When using MERGE_GDX_OUTPUT=TRUE, the gdxmerge executable shoud be
# on-path. This can be done by adding your local GAMS installation
# directory to PATH.
#
# The working directory (current directory) when invoking this script
# must be the directory that contains the configured files and paths.
# For GLOBIOM this will be the Model directory.
#
# To adapt this script to submit non-GLOBIOM jobs, change what is
# bundled, revise the templates, and adapt the output checking and
# handling.
#
# This script requires you to have a recent version of Condor installed.
# On Windows, the installer adds the Condor/bin directory to the PATH
# system environment variable, thus making the Condor commands available.
#
# Based on: GLOBIOM-limpopo scripts by David Leclere
#
# Author: Albert Brouwer
#
# Todo:
# - Don't merge a single file?
# - Condor is balky when transferring large (>= 2GB) bundles
# - limpopo1 has an issue with largish request_disk
# - Sometimes, limpopo1 partitionable slots are not filled whereas for the other limpopos they are.
# - Test on Linux (condor_reschedule is probably going to be an issue)
# - Cache and merge gdx files on the execute hosts?
#  * not if low-memory merge has a slow fallback
#  * complication: distributed over hosts after main run

rm(list=ls())

# ---- Default run config settings ----

# You can replace these via a run-config file passed as a first argument
# to this script. Lines with settings like the ones just below can be used
# in the config file. No settings may be omitted from the config file.
# To set up an initial config file, just copy-and-paste the below to a
# file, give it a .R extension to get nice syntax highlighting.
# -------><8----snippy-snappy---------------------------------------------
# Use paths relative to the working directory, with / as path separator.
EXPERIMENT = "test" # label for your experiment, pick something without spaces and valid as part of a filename
PREFIX = "_globiom" # prefix for per-job .err, log, .lst, and .out files
JOBS = c(0:3,7,10)
HOST_REGEXP = "^limpopo" # a regular expression to select execute hosts from the cluster
REQUEST_MEMORY = 7800 # memory (MiB) to reserve for each job
REQUEST_CPUS = 1 # number of hardware threads to reserve for each job
GAMS_FILE = "6_scenarios_limpopo.gms" # the GAMS file to run for each job
RESTART_FILE_PATH = "t/a4_limpopo.g00"
GAMS_VERSION = "24.4" # must be installed on all execute hosts
GAMS_ARGUMENTS = "//nsim='%1' //ssp=SSP2 //scen_type=feedback //price_exo=0 //dem_fix=0 //irri_dem=1 //water_bio=0 //yes_output=1 cErr=5 pageWidth=100"
BUNDLE_INCLUDE_DIRS = c("finaldata") # recursive, supports wildcards
BUNDLE_EXCLUDE_DIRS = c("225*", "Demand", "graphs", "output", "trade", "SIMBIOM") # recursive, supports wildcards
BUNDLE_EXCLUDE_FILES = c("*.~*", "*.exe", "*.log", "*.lxi", "*.lst", "*.zip", "test*.gdx") # supports wildcardss
BUNDLE_ADDITIONAL_FILES = c() # additional files to add to root of bundle, can also use an absolute path for these
RETAIN_BUNDLE = FALSE
GET_G00_OUTPUT = FALSE
G00_OUTPUT_DIR = "t" # relative to working dir both host-side and on the submit machine
G00_OUTPUT_FILE = "a6_out.g00" # host-side, will be remapped with EXPERIMENT and cluster/job numbers to avoid name collisions when transferring back to the submit machine.
GET_GDX_OUTPUT = TRUE
GDX_OUTPUT_DIR = "gdx" # relative to working dir both host-side and on the submit machine
GDX_OUTPUT_FILE = "output.gdx" # as produced by execute_unload on the host-side, will be remapped with EXPERIMENT and cluster/job numbers to avoid name collisions when transferring back to the submit machine.
WAIT_FOR_RUN_COMPLETION = TRUE
MERGE_GDX_OUTPUT = TRUE
REMOVE_MERGED_GDX_FILES = TRUE
# -------><8----snippy-snappy---------------------------------------------

# ---- Process environment and run config settings ----

# Collect the names and types of the config settings
config_names <- ls()
config_types <- lapply(lapply(config_names, get), typeof)

# Required packages
library(stringr)

# Check that the working directory is as expected and holds the required subdirectories
condor_dir <- "Condor" # where run reference files are stored in a per-experiment subdirectory (.err, .log, .lst, .out, and so on files)
if (!dir.exists(condor_dir)) stop(str_glue("No {condor_dir} directory found relative to working directory {getwd()}! Is your working directory correct?"))

# Read config file if specified via an argument, check presence and types.
args <- commandArgs(trailingOnly=TRUE)
#args <- c("..\\R\\config.R")
if (length(args) == 0) {
  warning("No config file argument supplied, using default run settings.")
} else if (length(args) == 1) {
  rm(list=config_names)
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

# Check and massage specific config settings
EXECUTE_HOST_GAMS_VERSIONS = c("24.2", "24.4", "25.1")
if (str_detect(EXPERIMENT, '[<>|:?*" \\t/\\\\]')) stop(str_glue("Configured EXPERIMENT name has forbidden character(s)!"))
if (str_detect(PREFIX, '[<>|:?*" \\t/\\\\]')) stop(str_glue("Configured PREFIX has forbidden character(s)!"))
if (!is.numeric(JOBS)) stop("JOBS does not list job numbers!")
if (length(JOBS) < 1) stop("There should be at least one job in JOBS!")
if (!all(JOBS == floor(JOBS))) stop("Job numbers in JOBS must be whole numbers!")
if (!all(JOBS < 1e6)) stop("Job numbers in JOBS must be less than 1000000 (one million)!")
if (!all(JOBS >= 0)) stop("Job numbers in JOBS may not be negative!")
if (!(REQUEST_MEMORY > 0)) stop("REQUEST_MEMORY should be larger than zero!")
if (!all(!duplicated(JOBS))) stop("Duplicate JOB numbers listed in JOBS!")
if (str_sub(GAMS_FILE, -4) != ".gms") stop(str_glue("Configured GAMS_FILE has no .gms extension!"))
if (!(file.exists(GAMS_FILE))) stop(str_glue('Configured GAMS_FILE "{GAMS_FILE}" does not exist relative to working directory!'))
if (str_detect(GAMS_FILE, '[<>|:?*" \\t/\\\\]')) stop(str_glue("Configured GAMS_FILE has forbidden character(s)!"))
if (!(file.exists(RESTART_FILE_PATH))) stop(str_glue('Configured RESTART_FILE_PATH "{RESTART_FILE_PATH}" does not exist!'))
if (str_detect(RESTART_FILE_PATH, "^/") || str_detect(RESTART_FILE_PATH, "^.:")) stop(str_glue("Configured RESTART_FILE_PATH must be located under the working directory for proper bundling: absolute paths not allowed!"))
if (str_detect(RESTART_FILE_PATH, fixed("../"))) stop(str_glue("Configured RESTART_FILE_PATH must be located under the working directory for proper bundling: you may not go up to parent directories using ../"))
if (str_detect(RESTART_FILE_PATH, '[<>|:?*" \\t\\\\]')) stop(str_glue("Configured RESTART_FILE_PATH has forbidden character(s)! Use / as path separator."))
version_match <- str_match(GAMS_VERSION, "^(\\d+)[.](\\d+)$")
if (any(is.na(version_match))) stop(str_glue('Invalid GAMS_VERSION "{GAMS_VERSION}"! Format must be "<major>.<minor>".'))
if (!(GAMS_VERSION %in% EXECUTE_HOST_GAMS_VERSIONS)) stop(str_glue('Invalid GAMS_VERSION "{GAMS_VERSION}"! The execute hosts have only these GAMS versions installed: {str_c(EXECUTE_HOST_GAMS_VERSIONS, collapse=" ")}')) # {cat(EXECUTE_HOST_GAMS_VERSIONS)}
dotless_version <- str_glue(version_match[2], version_match[3])
if (!str_detect(GAMS_ARGUMENTS, fixed("%1"))) stop("Configured GAMS_ARGUMENTS lack a %1 batch file argument expansion that must be used for passing the job number with which the job-specific (e.g. scenario) can be selected.")
for (file in BUNDLE_ADDITIONAL_FILES) {
  if (!(file.exists(file.path(file)))) stop(str_glue('Misconfigured BUNDLE_ADDITIONAL_FILES: "{file}" does not exist!'))
}
if (!(GET_G00_OUTPUT || GET_GDX_OUTPUT)) stop("Neither GET_G00_OUTPUT nor GET_GDX_OUTPUT are TRUE! A run without output is pointless.")
if (!(file.exists(G00_OUTPUT_DIR))) stop(str_glue('Configured G00_OUTPUT_DIR "{G00_OUTPUT_DIR}" does not exist!'))
if (str_detect(G00_OUTPUT_DIR, "^/") || str_detect(G00_OUTPUT_DIR, "^.:")) stop(str_glue("Configured G00_OUTPUT_DIR must be located under the working directory: absolute paths not allowed!"))
if (str_detect(G00_OUTPUT_DIR, fixed("../"))) stop(str_glue("Configured G00_OUTPUT_DIR must be located under the working directory: you may not go up to parent directories using ../"))
if (str_detect(G00_OUTPUT_DIR, '[<>|:?*" \\t\\\\]')) stop(str_glue("Configured G00_OUTPUT_DIR has forbidden character(s)! Use / as path separator."))
if (str_sub(G00_OUTPUT_FILE, -4) != ".g00") stop(str_glue("Configured G00_OUTPUT_FILE has no .g00 extension!"))
if (str_length(G00_OUTPUT_FILE) <= 4) stop(str_glue("Configured G00_OUTPUT_FILE needs more than an extension!"))
if (str_detect(G00_OUTPUT_FILE, '[<>|:?*" \\t/\\\\]')) stop(str_glue("Configured G00_OUTPUT_FILE has forbidden character(s)!"))
g00_prefix <- str_sub(G00_OUTPUT_FILE, 1, -5)
if (!(file.exists(GDX_OUTPUT_DIR))) stop(str_glue('Configured GDX_OUTPUT_DIR "{GDX_OUTPUT_DIR}" does not exist!'))
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
conn <- file(RESTART_FILE_PATH, "rb")
byte_count <- min(4000, file.info(RESTART_FILE_PATH)$size)
seek(conn, where=-byte_count, origin="end")
tail_bytes <- readBin(conn, what=integer(), size=1, n=byte_count)
close(conn)
tail_bytes[tail_bytes <= 0] <- 32
tail <-  rawToChar(as.raw(tail_bytes))
restart_version <- str_match(tail, "\x0AWEX(\\d\\d\\d)-\\d\\d\\d")[2]
if (is.na(restart_version)) {
  warning(str_glue("Cannot determine GAMS version that saved {RESTART_FILE_PATH}"))
} else {
  if (dotless_version < restart_version) {
    stop("The configured host-side GAMS_VERSION is older than the GAMS version that saved the configured restart file (RESTART_FILE_PATH). GAMS will fail!")
  }
}

# Get username in a way that works on MacOS, Linux, and Windows
username <- Sys.getenv("USERNAME")
if (username == "") username <- Sys.getenv("USER")
if (username == "") stop("Cannot determine the username!")

# Ensure that the experiment directory to hold the .out/.err/.log/.lst and so on results exists
experiment_dir <- file.path(condor_dir, EXPERIMENT)
if (!dir.exists(experiment_dir)) dir.create(experiment_dir)

# ---- Define some helper functions ----

# Check and sanitize 7zip output and return the overal byte size of the input files
handle_7zip <- function(out) {
  if (!is.null(attr(out, "status")) && attr(out, "status") != 0) {
    cat(out, sep="\n")
    stop("7zip compression failed!")
  } 
  else {
    cat(out[grep("^Scanning the drive:", out)+1], sep="\n")
    size_line <- grep("^Archive size:", out, value=TRUE)
    cat(size_line, sep="\n")
    byte_size <- as.double(str_match(size_line, "^Archive size: (\\d+) bytes")[2])
    if (is.na(byte_size)) stop("7zip archive size extraction failed!") # 7zip output format has changed?
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
  regexp <- "(\\d+) jobs; (\\d+) completed, (\\d+) removed, (\\d+) idle, (\\d+) running, (\\d+) held, (\\d+) suspended$"
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
      stop("Invocation of condor_q failed! Are you running an old Condor version? Old versions of Condor do not support condor_q -totals.")
    }
    # Extract the totals line and parse it out
    match <- str_match(grep(regexp, outerr, value=TRUE), regexp)
    if (is.na(match[1])) {
      cat(outerr, sep="\n")
      stop("Monitoring Condor queue status with condor_q failed: unexpected output! Are you running an old Condor version?")
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
      cat(str_sub(str_glue('{jobs} jobs:{ifelse(completed==0, "", str_glue(" {completed} completed,"))}{ifelse(removed==0, "", str_glue(" {removed} removed;"))}{ifelse(idle==0, "", str_glue(" {idle} idle (queued),"))}{ifelse(running==0, "", str_glue(" {running} running,"))}{ifelse(held==0, "", str_glue(" {held} held (execution error?),"))}{ifelse(suspended==0, "", str_glue(" {suspended} suspended,"))}'), 1, -2), sep="\n")
      changes_since_reschedule <- TRUE
    }
    # Warn when there are held jobs for the first time
    if (held > 0 && !warn) {
      cat("Jobs are held! Likely an execution error occurred, investigate and remove with condor_rm.\n")
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
        cat(outerr, sep="\n")
        stop("Invocation of condor_reschedule failed!")
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
    warning(str_glue("No {file_type} files returned for job(s) {summarize_jobs(JOBS[absentees])}!"))
  }
  if (any(empties)) {
    warning(str_glue("Empty {file_type} files resulting from job(s) {summarize_jobs(JOBS[empties])}! These empty files were removed."))
  }
  return(!(any(absentees) || any(empties)))
}

# ---- Check status of execute hosts ----

# Show status summary of selected execute hosts
error_code <- system2("condor_status", args=c("-compact", "-constraint", str_glue('"regexp(\\"{HOST_REGEXP}\\",machine)"')))
if (error_code > 0) stop("Cannot show Condor pool status! You may have an old Condor installed for which condor_status does not support the -compact option yet. If so, install a new Condor or remove -compact from the parameter list.")
cat("\n")

# Collect available execute hosts including domain
hostdoms <- unique(system2("condor_status", c("-compact", "-autoformat", "Machine", "-constraint", str_glue('"regexp(\\"{HOST_REGEXP}\\",machine)"')), stdout=TRUE))
if (!is.null(attr(hostdoms, "status")) && attr(hostdoms, "status") != 0) stop("Cannot get Condor pool status! You may have an old Condor installed for which condor_status does not support the -compact option yet. If so, install a new Condor or remove -compact from the parameter list.")
if (length(hostdoms) == 0) stop("No execute hosts matching HOST_REGEXP are available!")

# ---- Bundle the model ----

# Determine the platform file separator and the temp directory with R-default separators
temp_dir <- tempdir()
fsep <- ifelse(str_detect(temp_dir, fixed("\\") ), "\\", ".Platform$file.sep") # Get the platform file separator: .Platform$file.sep is set to / on Windows
temp_dir <- str_replace_all(temp_dir, fixed(fsep), .Platform$file.sep)
temp_dir_parent <- dirname(temp_dir) # Remove the R-session-specific random subdirectory: identical between sessions

# Set R-default and platform-specific paths to the job bundle
bundle <- "job_bundle.7z"
unique_bundle <- str_glue('bundle_{str_replace_all(Sys.time(), "[- :]", "")}.7z') # To keep multiple cached bundles separate
bundle_path <- file.path(temp_dir_parent, bundle) # Identical between sessions
bundle_platform_path <- str_replace_all(bundle_path, fixed(.Platform$file.sep), fsep)
if (file.exists(bundle_path)) stop(str_glue("{bundle_path} already exists! Is there another submission ongoing?"))

cat("Compressing model files into job bundle...\n")
model_byte_size <- handle_7zip(system2("7z", stdout=TRUE, stderr=TRUE,
  args=unlist(lapply(c("a", "-mx1", "-bb0",
    unlist(lapply(BUNDLE_INCLUDE_DIRS, function(p) return(str_glue("-ir!", p)))),
    unlist(lapply(BUNDLE_EXCLUDE_DIRS, function(p) return(str_glue("-xr!", p)))),
    unlist(lapply(BUNDLE_EXCLUDE_FILES, function(p) return(str_glue("-x!", p)))),
    "-xr!{condor_dir}",
    "-xr!{G00_OUTPUT_DIR}",
    "-xr!{GDX_OUTPUT_DIR}",
    "{bundle_platform_path}",
    "*"
  ), str_glue))
))
cat("\n")

cat("Bundle restart file and any additional files...\n")
restart_byte_size <- handle_7zip(system2("7z", stdout=TRUE, stderr=TRUE,
  args=unlist(lapply(c("a",
    "{bundle_platform_path}",
    "{RESTART_FILE_PATH}",
    BUNDLE_ADDITIONAL_FILES
  ), str_glue))
))
cat("\n")

# Estimate the amount of disk to request for run, in KiB
# decompressed bundle content + 2GiB for output (.g00, .gdx, .lst, ...)
request_disk <- ceiling((model_byte_size+restart_byte_size)/1024)+2*1024*1024

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
    "# -- Job log, stdout, and stderr files",
    "log = {experiment_dir}/_seed_{hostname}.log",
    "output = {experiment_dir}/_seed_{hostname}.out",
    "error = {experiment_dir}/_seed_{hostname}.err",
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
  remove_if_exists(experiment_dir, str_glue("_seed_{hostname}.log"))
  remove_if_exists(experiment_dir, str_glue("_seed_{hostname}.out"))
  remove_if_exists(experiment_dir, str_glue("_seed_{hostname}.err"))

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
return_values <- get_return_values(experiment_dir, lapply(hostnames, function(hostname) return(str_glue("_seed_{hostname}.log"))))
if (any(is.na(return_values))) {
  invisible(file.remove(bundle_path))
  stop(str_glue("Abnormal termination of seeding job(s) for {str_c(hostnames[is.na(return_values)], collapse=', ')}! For details, see the _seed_* files in {experiment_dir}"))
}
if (any(return_values != 0)) {
  invisible(file.remove(bundle_path))
  stop(str_glue("Seeding job(s) for {str_c(hostnames[return_values != 0], collapse=', ')} returned a non-zero return value! For details, see the _seed_* files in {experiment_dir}"))
}
cat("Seeding done: execute hosts have received and cached the bundle.\n")
cat("\n")

# Remove seeding temp files

invisible(file.remove(seed_bat))
for (hostdom in hostdoms) {
  hostname <- str_extract(hostdom, "^[^.]*")
  file.remove(file.path(temp_dir, str_glue("_seed_{hostname}.job")))
  file.remove(file.path(experiment_dir, str_glue("_seed_{hostname}.log")))
  file.remove(file.path(experiment_dir, str_glue("_seed_{hostname}.out")))
  file.remove(file.path(experiment_dir, str_glue("_seed_{hostname}.err")))
}

# ---- Prepare files for run ----

# Copy the configuration to the experiment directory for reference
config_file <- file.path(experiment_dir, str_glue("_config_{EXPERIMENT}_{predicted_cluster}.txt"))
if (length(args) > 0) {
  if (!file.copy(args[1], config_file, overwrite=TRUE)) {
    invisible(file.remove(bundle_path))
    stop(str_glue("Cannot copy the configuration file {args[1]} to {experiment_dir}")) 
  }
} else {
  # No configuration file provided, write default configuration defined above (definition order is lost)
  config_conn<-file(config_file, open="wt")
  for (i in seq_along(config_names)) {
    if (config_types[i] == "character") {
      writeLines(str_glue('{config_names[i]} = "{get(config_names[i])}"'), job_conn) 
    } else {
      writeLines(str_glue('{config_names[i]} = {get(config_names[i])}'), job_conn) 
    }
  }
  close(config_conn)
}

# Copy the GAMS file to the experiment directory for reference
if (!file.copy(file.path(GAMS_FILE), file.path(experiment_dir, str_glue("{str_sub(GAMS_FILE, 1, -5)}_{EXPERIMENT}_{predicted_cluster}.gms")), overwrite=TRUE)) {
  invisible(file.remove(bundle_path))
  stop(str_glue("Cannot copy the configured GAMS_FILE file to {experiment_dir}")) 
}

# Define the template for the .bat file that specifies what should be run on the execute host side for each job.
# Note that the use of POSIX commands: requires MKS Toolkit or GAMS gbin to be on-path on Windows execute hosts.
# Execute-host-side automated bundle cleanup is assumed to be active:
# https://mis.iiasa.ac.at/portal/page/portal/IIASA/Content/TicketS/Ticket?defpar=1%26pWFLType=24%26pItemKey=103034818402942720
bat_template <- c(
  "@echo off",
  'grep "^Machine = " .machine.ad || exit /b %errorlevel%',
  "echo _CONDOR_SLOT = %_CONDOR_SLOT%",
  'md "{G00_OUTPUT_DIR}" 2>NUL || exit /b %errorlevel%',
  'md "{GDX_OUTPUT_DIR}" 2>NUL || exit /b %errorlevel%',
  "@echo on",
  "touch e:\\condor\\bundles\\{username}\\{unique_bundle} 2>NUL", # postpone automated cleanup of bundle, can fail when another job is using the bundle but that's fine as the touch will already have happened
  '7z x e:\\condor\\bundles\\{username}\\{unique_bundle} -y >NUL || exit /b %errorlevel%',
  "set GDXCOMPRESS=1", # causes GAMS to compress the GDX output file
  "C:\\GAMS\\win64\\{GAMS_VERSION}\\gams.exe {GAMS_FILE} -logOption=3 restart={RESTART_FILE_PATH} save={G00_OUTPUT_DIR}/{g00_prefix} {GAMS_ARGUMENTS}",
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

# Define the Condor .job file template for the run
job_template <- c(
  "executable = {job_bat}",
  "arguments = $(job)",
  "universe = vanilla",
  "",
  "# -- Job log, output, and error files",
  "log = {experiment_dir}/{PREFIX}_{EXPERIMENT}_$(cluster).$(job).log", # don't use $$() expansion here: Condor creates the log file before it can resolve the expansion
  "output = {experiment_dir}/{PREFIX}_{EXPERIMENT}_$(cluster).$(job).out",
  "stream_output = True",
  "error = {experiment_dir}/{PREFIX}_{EXPERIMENT}_$(cluster).$(job).err",
  "stream_error = True",
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
  "run_as_owner = True", # Jobs will run as you, so you'll have access to H: and your own temp space
  "",
  "should_transfer_files = YES",
  "when_to_transfer_output = ON_EXIT",
  'transfer_output_files = {str_sub(GAMS_FILE, 1, -5)}.lst{ifelse(GET_G00_OUTPUT, str_glue(",{G00_OUTPUT_DIR}/{G00_OUTPUT_FILE}"), "")}{ifelse(GET_GDX_OUTPUT, str_glue(",{GDX_OUTPUT_DIR}/{GDX_OUTPUT_FILE}"), "")}',
  'transfer_output_remaps = "{str_sub(GAMS_FILE, 1, -5)}.lst={experiment_dir}/{PREFIX}_{EXPERIMENT}_$(cluster).$(job).lst{ifelse(GET_G00_OUTPUT, str_glue(";{G00_OUTPUT_FILE}={G00_OUTPUT_DIR}/{g00_prefix}_{EXPERIMENT}_$(cluster).$(job).g00"), "")}{ifelse(GET_GDX_OUTPUT, str_glue(";{GDX_OUTPUT_FILE}={GDX_OUTPUT_DIR}/{gdx_prefix}_{EXPERIMENT}_$(cluster).$$([substr(strcat(string(0),string(0),string(0),string(0),string(0),string(0),string($(job))),-6)]).gdx"), "")}"',
  "",
  "notification = Error", # Per-job, so you'll get spammed setting it to Always or Complete. And Error does not seem to catch many execution errors.
  "",
  "queue job in ({str_c(JOBS,collapse=',')})"
)

# Apply settings to job template and write the .job file to use for submission
job_file <- file.path(experiment_dir, str_glue("submit_{EXPERIMENT}_{predicted_cluster}.job"))
job_conn<-file(job_file, open="wt")
writeLines(unlist(lapply(job_template, str_glue)), job_conn)
close(job_conn)

# ---- Submit the run and clean up temp files ----

outerr <- system2("condor_submit", args=str_glue("{experiment_dir}/submit_{EXPERIMENT}_{predicted_cluster}.job"), stdout=TRUE, stderr=TRUE)
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
if (cluster != predicted_cluster) warning(str_glue("Cluster {cluster} not equal to prediction {predicted_cluster}!"))

# Retain the bundle if so requested, then remove it from temp
if (RETAIN_BUNDLE) {
  success <- file.copy(bundle_path, file.path(experiment_dir, str_glue("bundle_{EXPERIMENT}_{predicted_cluster}.7z")))
  if (!success) warning("Could not make a reference copy of bundle!")
} 
invisible(file.remove(bundle_path)) # Removing the bundle unblocks this script for another submission

# Remove dated job batch files that are almost certainly no longer in use (older than 10 days)
# Needed because Windows does not periodically clean up TEMP and because the current job batch
# file is not deleted unless you make this script wait for the run to complete.
for (bat_path in list.files(path=temp_dir_parent, pattern=str_glue("job_.*_\\d+.bat"), full.names=TRUE)) {
  if (difftime(Sys.time(), file.info(bat_path)$ctime, unit="days") > 10) invisible(file.remove(bat_path))
}

# ---- Handle run results ----

if (WAIT_FOR_RUN_COMPLETION) {
  # Monitor the run until it completes
  cat(str_glue('Waiting for experiment "{EXPERIMENT}" to complete...'), sep="\n")
  monitor(cluster)

  # Remove the job batch file. This is done after waiting for the run to complete
  # because jobs can continue to be scheduled well after the initial submission when
  # there are more jobs in the run than available slot partitions.
  invisible(file.remove(job_bat))

  # Check that result files exist and are not empty, warn otherwise and remove empty files
  lsts_complete <- all_exist_and_not_empty(experiment_dir, "{PREFIX}_{EXPERIMENT}_{cluster}.{job}.lst", ".lst")
  if (GET_G00_OUTPUT) {
    g00s_complete <- all_exist_and_not_empty(G00_OUTPUT_DIR, "{g00_prefix}_{EXPERIMENT}_{cluster}.{job}.g00", "work (.g00)")
  }
  if (GET_GDX_OUTPUT) {
    gdxs_complete <- all_exist_and_not_empty(GDX_OUTPUT_DIR, 'output_{EXPERIMENT}_{cluster}.{sprintf("%06d", job)}.gdx', "GDX")
  }

  return_values <- get_return_values(experiment_dir, lapply(JOBS, function(job) return(str_glue("{PREFIX}_{EXPERIMENT}_{cluster}.{job}.log"))))
  if (any(is.na(return_values))) {
    stop(str_glue("Abnormal termination of job(s) {summarize_jobs(JOBS[is.na(return_values)])}! For details, see the {PREFIX}_{EXPERIMENT}_{cluster}.* files in {experiment_dir}"))
  }
  if (any(return_values != 0)) {
    stop(str_glue("Job(s) {summarize_jobs(JOBS[return_values != 0])} returned a non-zero return value! For details, see the {PREFIX}_{EXPERIMENT}_{cluster}.* files in {experiment_dir}"))
  }
  cat("All jobs are done.\n")

  # Warn when REQUEST_MEMORY turns out to have been set too low or significantly too high
  max_memory_use <- -1
  max_memory_job <- -1
  memory_use_regexp <- "^\\s+Memory \\(MB\\)\\s+:\\s+(\\d+)\\s+"
  for (job in JOBS) {
    job_lines <- readLines(file.path(experiment_dir, str_glue("{PREFIX}_{EXPERIMENT}_{cluster}.{job}.log")))
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
      setwd(GDX_OUTPUT_DIR)
      Sys.setenv(GDXCOMPRESS=1) # Causes the merged GDX file to be compressed, it will be usable as a regular GDX,
      error_code <- system2("gdxmerge", args=c(str_glue("{gdx_prefix}_{EXPERIMENT}_{cluster}.*.gdx"), str_glue("output={gdx_prefix}_{EXPERIMENT}_{cluster}_merged.gdx")))
      setwd(prior_wd)
      if (error_code > 0) stop("Merging failed!")
      # Remove merged GDX files if so requested
      if (REMOVE_MERGED_GDX_FILES) {
        for (job in JOBS) {
          file.remove(file.path(GDX_OUTPUT_DIR, str_glue('{gdx_prefix}_{EXPERIMENT}_{cluster}.{sprintf("%06d", job)}.gdx')))
        }
      }
    }
  }
  # Make a bit of noise to notify the user of completion (works from RScript but not RStudio)
  alarm()
  Sys.sleep(1)
  alarm()
} else {
  cat("Query progress with: condor_q.\n")
  cat(str_glue("Merge results with: gdxmerge {gdx_prefix}_{EXPERIMENT}_{cluster}.*.gdx output={gdx_prefix}_{EXPERIMENT}_{cluster}_merged.gdx", sep="\n"))
}
