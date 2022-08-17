#!/usr/bin/env Rscript
# Submit a Condor run (a set of jobs). Basic version. Can be configured
# to monitor progress.
#
# Installation: https://github.com/iiasa/Condor_run_R#installation
# Use:          https://github.com/iiasa/Condor_run_R#use
#
# Author:   Albert Brouwer
# Based on: GLOBIOM-limpopo scripts by David Leclere
# Release:  https://github.com/iiasa/Condor_run_R/releases/tag/v2022-07-29

# Remove any objects from active environment so that below it will contain only the default configuration
rm(list=ls())

# ---- Configuration parameters, mandatory ----

# DO NOT EDIT HERE!
# Copy all of these to a separate configuration file and adapt their values.
# .......8><....snippy.snappy....8><.........................................
# See https://github.com/iiasa/Condor_run_R/blob/master/configuring.md
JOBS = c()
REQUEST_MEMORY = 100
LAUNCHER = "Rscript"
ARGUMENTS = "%1"
WAIT_FOR_RUN_COMPLETION = TRUE
# .......8><....snippy.snappy....8><.........................................
mandatory_config_names <- ls()

# ---- Configuration parameters, optional ----

# DO NOT EDIT HERE!
# Add to a separate configuration file the parameters that you need to override.
# See https://github.com/iiasa/Condor_run_R/blob/master/configuring.md
LABEL = "{Sys.Date()}"
SCRIPT = ""
BUNDLE_INCLUDE = "*"
BUNDLE_INCLUDE_DIRS = c()
BUNDLE_EXCLUDE_DIRS = c(".git", ".svn")
BUNDLE_INCLUDE_FILES = c()
BUNDLE_EXCLUDE_FILES = c("**/*.log")
BUNDLE_ADDITIONAL_FILES = c()
BUNDLE_ONLY = FALSE
RETAIN_BUNDLE = FALSE
SEED_JOB_RELEASES = 0
JOB_RELEASES = 3
JOB_RELEASE_DELAY = 120
HOST_REGEXP = ".*"
REQUIREMENTS = c()
REQUEST_CPUS = 1
REQUEST_DISK = 1000000 # KiB
CONDOR_DIR = "Condor"
GET_OUTPUT = TRUE
OUTPUT_DIR = "output"
OUTPUT_DIR_SUBMIT = NULL
OUTPUT_FILE = "output.RData"
RUN_AS_OWNER = TRUE
NOTIFICATION = "Never"
EMAIL_ADDRESS = NULL
NICE_USER = FALSE
CLUSTER_NUMBER_LOG = ""
CLEAR_LINES = TRUE
PREFIX = "job"

# ---- Configuration parameters, optional templates ----

# When customizing how jobs are submitted and how execution points launch them,
# you may need to add adapted versions of these to your configuration file.
JOB_TEMPLATE <- c(
  "executable = {bat_path}",
  "arguments = $(job)",
  "universe = vanilla",
  "",
  "nice_user = {ifelse(NICE_USER, 'True', 'False')}",
  "",
  "# Job log, output, and error files",
  "log = {log_dir}/{PREFIX}_$(cluster).$(job).log", # don't use $$() expansion here: Condor creates the log file before it can resolve the expansion
  "output = {log_dir}/{PREFIX}_$(cluster).$(job).out",
  "stream_output = True",
  "error = {log_dir}/{PREFIX}_$(cluster).$(job).err",
  "stream_error = True",
  "", # If a job goes on hold for more than JOB_RELEASE_DELAY seconds, release it up to JOB_RELEASES times
  "periodic_release =  (NumJobStarts <= {JOB_RELEASES}) && ((time() - EnteredCurrentStatus) > {JOB_RELEASE_DELAY})",
  "",
  "{build_requirements_expression(REQUIREMENTS, hostdoms)}",
  "request_memory = {REQUEST_MEMORY}",
  "request_cpus = {REQUEST_CPUS}", # Number of "CPUs" (hardware threads) to reserve for each job
  "request_disk = {request_disk}",
  "",
  '+IIASAGroup = "ESM"', # Identifies you as part of the group allowed to use ESM cluster
  "run_as_owner = {ifelse(RUN_AS_OWNER, 'True', 'False')}",
  "",
  "should_transfer_files = YES",
  "when_to_transfer_output = ON_EXIT",
  'transfer_output_files = {ifelse(GET_OUTPUT, str_glue("{OUTPUT_DIR}/{OUTPUT_FILE}"), "")}',
  'transfer_output_remaps = "{ifelse(GET_OUTPUT, str_glue("{OUTPUT_FILE}={OUTPUT_DIR_SUBMIT}/{output_prefix}_{LABEL}_$(cluster).$$([substr(strcat(string(0),string(0),string(0),string(0),string(0),string(0),string($(job))),-6)]).{output_extension}"), "")}"',
  "",
  "notification = {NOTIFICATION}",
  '{ifelse(is.null(EMAIL_ADDRESS), "", str_glue("notify_user = {EMAIL_ADDRESS}"))}',
  "",
  "queue job in ({str_c(JOBS,collapse=',')})"
)
BAT_TEMPLATE <- c(
  '@echo off',
  'if not "%~1"=="" goto continue',
  'echo This batch file runs on an execution point with a job number as only argument.',
  'exit /b 1',
  ':continue',
  'grep "^Machine = " .machine.ad || exit /b %errorlevel%',
  "echo _CONDOR_SLOT = %_CONDOR_SLOT%",
  "cd",
  'mkdir "{OUTPUT_DIR}" 2>NUL || exit /b %errorlevel%',
  "set bundle_root=d:\\condor\\bundles",
  "if not exist %bundle_root% set bundle_root=e:\\condor\\bundles",
  "@echo on",
  "touch %bundle_root%\\{username}\\{unique_bundle} 2>NUL", # postpone automated cleanup of bundle, can fail when another job is using the bundle but that's fine as the touch will already have happened
  '7z x %bundle_root%\\{username}\\{unique_bundle} -y >NUL || exit /b %errorlevel%',
  "{LAUNCHER} {SCRIPT} {ARGUMENTS}",
  "set script_errorlevel=%errorlevel%",
  "@echo off",
  "if %script_errorlevel% neq 0 (",
  "  echo ERROR: script failed with error code %script_errorlevel% 1>&2",
  ")",
  "sleep 1", # Make it less likely that the .out file is truncated.
  "exit /b %script_errorlevel%"
)
SEED_JOB_TEMPLATE <- c(
  "executable = {seed_bat}",
  "universe = vanilla",
  "",
  "# Job log, stdout, and stderr files",
  "log = {log_dir}/_seed_{hostname}.log",
  "output = {log_dir}/_seed_{hostname}.out",
  "error = {log_dir}/_seed_{hostname}.err",
  "",
  "periodic_release = (NumJobStarts <= {SEED_JOB_RELEASES}) && ((time() - EnteredCurrentStatus) > 60)", # if seed job goes on hold for more than 1 minute, release it up to SEED_JOB_RELEASES times
  "periodic_remove = (JobStatus == 1) && (time() - EnteredCurrentStatus > 120 )", # if seed job remains idle for more than 2 minutes, remove it as presumably the execution point is not responding
  "",
  "{build_requirements_expression(REQUIREMENTS, hostdom)}",
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
SEED_BAT_TEMPLATE <- c(
  "@echo off",
  "set bundle_root=d:\\condor\\bundles",
  "if not exist %bundle_root% set bundle_root=e:\\condor\\bundles",
  "set bundle_dir=%bundle_root%\\{username}",
  "if not exist %bundle_dir%\\ mkdir %bundle_dir% || exit /b %errorlevel%",
  "@echo on",
  "move /Y {bundle} %bundle_dir%\\{unique_bundle}"
)

# ---- Get set ----

# Collect the names and types of the default config settings
config_names <- ls()
config_names <- config_names[!(config_names %in% "mandatory_config_names")]
if (length(config_names) == 0) {stop("Default configuration is absent! Please restore the default configuration. It is required for configuration checking, also when providing a separate configuration file.")}
config_types <- lapply(lapply(config_names, get), typeof)

# Load required packages
suppressWarnings(library(fs))
suppressWarnings(library(stringr))

# Determine the platform file separator and the temp directory with R-default separators
temp_dir <- tempdir()
fsep <- ifelse(str_detect(temp_dir, fixed("\\") ), "\\", ".Platform$file.sep") # Get the platform file separator: .Platform$file.sep is set to / on Windows
temp_dir <- str_replace_all(temp_dir, fixed(fsep), .Platform$file.sep)
temp_dir_parent <- dirname(temp_dir) # Move up from the R-session-specific random sub directory to get a temp dir identical between sessions

# ---- Define some helper functions ----

# Check that the given binaries are on-path
check_on_path <- function(binaries) {
  where <- Sys.which(binaries)
  for (bin in binaries) {
    if (where[bin] == "") {
      stop(str_glue("Required binary/executable '{bin}' was not found! Please add its containing directory to the PATH environment variable."), call.=FALSE)
    }
  }
}

# Bundle files with 7-Zip, check success and output, and return the overall byte size of the input files
bundle_with_7z <- function(args_for_7z) {
  check_on_path("7z")
  if (BUNDLE_ONLY) {
    message("Invoking 7-Zip via the following command line:")
    message(str_c(c("7z", args_for_7z), collapse = " "))
  }
  out <- system2("7z", stdout=TRUE, stderr=TRUE, args=args_for_7z)
  if (!is.null(attr(out, "status")) && attr(out, "status") != 0) {
    message("7z failed, likely because of erroneous or too many arguments.\nThe arguments for 7z derived from the BUNDLE_* config options were as follows:")
    message(paste(args_for_7z, collapse='\n'))
    message("\nThe invocation of 7z returned:")
    message(paste(out, collapse='\n'))
    stop("Bundling failed!", call.=FALSE)
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

# List content of a 7-Zip archive
list_7z <- function(archive_path) {
  check_on_path("7z")
  out <- system2("7z", stdout=TRUE, stderr=TRUE, args=c("l", archive_path))
  if (!is.null(attr(out, "status")) && attr(out, "status") != 0) {
    stop(str_glue("Failed to list content of {archive_path}"), call.=FALSE)
  }
  return(out)
}

# Delete a file if it exists
delete_if_exists <- function(dir_path, file_name) {
  file_path <- path(dir_path, file_name)
  if (file_exists(file_path)) file_delete(file_path)
}

# Clear text displayed on current line and reset cursor to start of line
# provided that CLEAR_LINES has been configured to be TRUE. Otherwise,
# issue a line feed to move on to the start of the next line.
clear_line <- function() {
  if (CLEAR_LINES)
    cat("\r                                                                     \r")
  else
    cat("\n")
}

# Search requirements expressions for bare ClassId identifiers and
# convert those to `<identifier> =?= True' expressions.
express_identifiers <- function(requirements) {
  if (length(requirements) == 0) return(c())
  m <- str_match(requirements, "^[_.a-zA-Z0-9]+$")
  for (i in seq_along(m)) {
    if (!is.na(m[[i]])) {
      requirements[[i]] <- str_c(requirements[[i]], " =?= True")
    }
  }
  return(requirements)
}

# Turn requirements into multiple '-constraint <expression>' arguments
# that can be passed to condor_status via system2(). Requires removal
# of spaces from expressions and escaping of " with backslashes.
#
# Tested on Windows and Linux.
constraints <- function(requirements) {
  if (length(requirements) == 0) return(c())
  requirements <- express_identifiers(requirements)
  requirements <- str_remove_all(requirements, " ")
  requirements <- str_replace_all(requirements, '"', '\\\\"')
  str_c("-constraint ", requirements)
}

# Build a combined pretty-printed expression from zero or more requirements
# expressions as well as a list of zero or more names of execution points to
# which the submission should be limited. The build expression can be
# included in a .job description file.
#
# The input requirement expressions are surrounded with ( and ) and
# concatenated with &&, so all must be true for the combined expression
# to be true.
#
# Any bare ClassId identifiers found in the requirements will be converted
# to '<identifier> =?= True' expressions for convenience.
#
# The input host domain names are concatined with ||.
build_requirements_expression <- function(requirements, hostdoms) {
  h <- ""
  if (length(hostdoms) > 0) {
    h <- str_c(
      "  ( \\\n",
      '    (TARGET.Machine == \"',
      str_c(hostdoms, collapse = '\") || \\\n    (TARGET.Machine == \"'),
      "\") \\\n",
      "  )\n"
    )
  }
  requirements <- express_identifiers(requirements)
  r <- ""
  if (length(requirements) > 0) {
    r <- str_c(
      "  (",
      str_c(requirements, collapse = '\") && \\\n  (')
    )
    if (h == "")
      r <- str_c(r, ")\n")
    else
      r <- str_c(r, ") && \\\n")
  }
  if (r == "" && h == "") {
    return("")
  }
  str_c("requirements = \\\n", r, h)
}

# Monitor jobs by waiting for them to finish while reporting queue totals changes and sending reschedule commands to the local schedd
monitor <- function(clusters) {
  warn <- FALSE
  regexp <- "Total for query: (\\d+) jobs; (\\d+) completed, (\\d+) removed, (\\d+) idle, (\\d+) running, (\\d+) held, (\\d+) suspended"
  #regexp <- "(\\d+) jobs; (\\d+) completed, (\\d+) removed, (\\d+) idle, (\\d+) running, (\\d+) held, (\\d+) suspended$"
  reschedule_invocations <- 200 # limit the number of reschedules so it is only done early on to push out the jobs quickly
  # initial values before first iteration
  changes_since_reschedule <- FALSE
  iterations_since_reschedule <- 0
  q_errors <- 0
  prior_idle <- -1
  prior_running <- -1
  q <- "" # to hold formatted condor_q query result
  repeat {
    Sys.sleep(1)
    
    # Collect Condor queue information via condor_q
    outerr <- system2("condor_q", args=c("-totals", "-wide", clusters), stdout=TRUE, stderr=TRUE)
    if (!is.null(attr(outerr, "status")) && attr(outerr, "status") != 0) {
      q_errors <- q_errors+1
      if (q_errors >= 10) {
        # 10 consecutive condor_q errors, probably not transient, report and stop
        cat(outerr, sep="\n")
        stop("Invocation of condor_q failed! Are you running a too old (< V8.7.2) Condor version?", call.=FALSE)
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
      stop("Monitoring Condor queue status with condor_q failed: unexpected output! Are you running a too old (< V8.7.2) Condor version?", call.=FALSE)
    }
    jobs       <- as.integer(match[2])
    completed  <- as.integer(match[3])
    removed    <- as.integer(match[4])
    idle       <- as.integer(match[5])
    running    <- as.integer(match[6])
    held       <- as.integer(match[7])
    suspended  <- as.integer(match[8])
    
    # Format condor_q result
    new_q <- str_sub(str_glue('{jobs} jobs:{ifelse(completed==0, "", str_glue(" {completed} completed,"))}{ifelse(removed==0, "", str_glue(" {removed} removed;"))}{ifelse(idle==0, "", str_glue(" {idle} idle (queued),"))}{ifelse(running==0, "", str_glue(" {running} running,"))}{ifelse(held==0, "", str_glue(" {held} held,"))}{ifelse(suspended==0, "", str_glue(" {suspended} suspended,"))}'), 1, -2)
    
    # Display condor_q result when changed, overwriting old one
    if (new_q != q) {
      clear_line()
      q <- new_q
      cat(q)
      flush.console()
      
      changes_since_reschedule <- TRUE
    }
    # Warn when there are held jobs for the first time
    if (held > 0 && !warn) {
      clear_line()
      message("Jobs are held!")
      message("To see what this means please read: https://github.com/iiasa/Condor_run_R/blob/master/troubleshooting.md#jobs-do-not-run-but-instead-go-on-hold")
      cat(q)
      flush.console()
      warn <- TRUE
    }
    # Request rescheduling early
    if (idle > 0 && idle == prior_idle &&
        reschedule_invocations > 0 &&
        running <= prior_running
        && ((changes_since_reschedule) || iterations_since_reschedule >= 10)
    ) {
      outerr <- suppressWarnings(system2("condor_reschedule", stdout=TRUE, stderr=TRUE))
      if (!is.null(attr(outerr, "status")) && attr(outerr, "status") != 0) {
        # Try to workaround issue with a seemingly superfluous args=c("reschedule") parameter
        # because R seems to sometimes call some underlying generic exe that needs a parameter to
        # resolve which command it should behave as.
        outerr2 <- suppressWarnings(system2("condor_reschedule", args=c("reschedule"), stdout=TRUE, stderr=TRUE))
        if (!is.null(attr(outerr2, "status")) && attr(outerr2, "status") != 0) {
          # Warn about the first error, not the also-failed workaround
          clear_line()
          warning(str_c(c("Invocation of condor_reschedule failed with the following output:", outerr), collapse='\n'), call.=FALSE)
          cat(q)
          flush.console()
        }
      }
      reschedule_invocations <- reschedule_invocations-1
      changes_since_reschedule <- FALSE
      iterations_since_reschedule <- 0
    } else {
      iterations_since_reschedule <- iterations_since_reschedule+1
    }
    # Store state for next iteration
    prior_idle <- idle
    prior_running <- running
    # Stop if all jobs done
    if (jobs == 0) {
      clear_line()
      flush.console()
      break
    }
  }
}

# Get the return values of job log files, or NA when a job did not terminate normally.
get_return_values <- function(log_file_paths) {
  return_values <- c()
  return_value_regexp <- "\\(1\\) Normal termination \\(return value (\\d+)\\)"
  for (lfp in log_file_paths) {
    tryCatch({
        loglines <- readLines(lfp)
        return_value <- as.integer(str_match(tail(grep(return_value_regexp, loglines, value=TRUE), 1), return_value_regexp)[2])
        return_values <- c(return_values, return_value)
      },
      error=function(cond) {
        return_values <- c(return_values, NA)
      }
    )
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
# Empty files are deleted.
#
# The file_template is a template of the filename that is run through str_glue
# and can make use of variables defined in the calling context. The dir parameter
# indicates the directory containing the files.
#
# Warnings are generated when files are absent or empty.
# The boolean return value is TRUE when all files exist and are not empty.
all_exist_and_not_empty <- function(dir, file_template, file_type, warn=TRUE) {
  absentees <- c()
  empties <- c()
  for (job in JOBS) {
    path <- path(dir, str_glue(file_template))
    absent <- !file_exists(path)
    absentees <- c(absentees, absent)
    if (absent) {
      empties <- c(empties, FALSE)
    } else {
      empty <- file_size(path) == 0
      if (empty) file_delete(path)
      empties <- c(empties, empty)
    }
  }
  if (warn && any(absentees)) {
    warning(str_glue("No {file_type} files returned for job(s) {summarize_jobs(JOBS[absentees])}!"), call.=FALSE)
  }
  if (warn && any(empties)) {
    warning(str_glue("Empty {file_type} files resulting from job(s) {summarize_jobs(JOBS[empties])}! These empty files were deleted."), call.=FALSE)
  }
  return(!(any(absentees) || any(empties)))
}

# ---- Process environment and run config settings ----

# Read config file if specified via an argument, check presence and types.
args <- commandArgs(trailingOnly=TRUE)
if (length(args) == 0) {
  stop("No configuration file argument supplied. For usage information, see: https://github.com/iiasa/Condor_run_R#use")
} else if (length(args) == 1) {
  # Check that the specified config file exists
  config_file_arg <- args[1]
  if (!(file_exists(config_file_arg))) stop(str_glue('Invalid command line argument: specified configuration file "{config_file}" does not exist!'))

  # Remove mandatory config defaults from the global scope
  rm(list=config_names[config_names %in% mandatory_config_names])
  rm(mandatory_config_names)

  # Source the config file, should add mandatory config settings to the global scope
  source(config_file_arg, local=TRUE, echo=FALSE)

  # Check that all config settings exist and have no weird value type
  for (i in seq_along(config_names))  {
    name <- config_names[i]
    if (!exists(name)) stop(str_glue("Mandatory config setting {name} is not set in config file {config_file_arg}!"))
    type <- typeof(get(name))
    if (type != config_types[[i]] &&
        type != "integer" && # R has no stable numerical type
        type != "double" && # R has no stable numerical type
        type != "NULL" && # allow for NULL
        config_types[[i]] != "NULL" # allow for default vector being empty
    ) stop(str_glue("{name} set to wrong type in {config_file_arg}, type should be {config_types[[i]]}"))
  }
} else {
  stop("Multiple arguments provided! Expecting at most a single configuration file argument.")
}

# Copy/write configuration to a file in the temp directory for reference early to minimize the risk of it being edited in the mean time
temp_config_file <- path(temp_dir, str_glue("config.R"))
if (length(args) > 0) {
  tryCatch(
    file_copy(config_file_arg, temp_config_file, overwrite=TRUE),
    error=function(cond) {
      file_delete(bundle_path)
      message(cond)
      stop(str_glue("Cannot make a copy of the configuration file {config_file_arg}!"))
    }
  )
} else {
  # No configuration file provided, write default configuration defined above (definition order is lost)
  config_conn<-file(temp_config_file, open="wt")
  for (i in seq_along(config_names)) {
    if (config_types[i] == "character") {
      writeLines(str_glue('{config_names[i]} = "{get(config_names[i])}"'), config_conn)
    } else {
      writeLines(str_glue('{config_names[i]} = {get(config_names[i])}'), config_conn)
    }
  }
  close(config_conn)
}

# Check and massage specific config settings
if (exists("NAME")) LABEL <- NAME # allowed synonym
if (exists("EXPERIMENT")) LABEL <- EXPERIMENT # allowed synonym
if (exists("PROJECT")) LABEL <- PROJECT # allowed synonym
LABEL <- str_glue(LABEL)
if (str_detect(LABEL, '[<>|:?*" \\t/\\\\]')) stop(str_glue("Configured LABEL/NAME/PROJECT/EXPERIMENT for run has forbidden character(s)!"))
if (str_detect(PREFIX, '[<>|:?*" \\t/\\\\]')) stop(str_glue("Configured PREFIX has forbidden character(s)!"))
if (!is.numeric(JOBS)) stop("JOBS does not list job numbers!")
if (length(JOBS) < 1) stop("There should be at least one job in JOBS!")
if (!all(JOBS == floor(JOBS))) stop("Job numbers in JOBS must be whole numbers!")
if (!all(JOBS < 1e6)) stop("Job numbers in JOBS must be less than 1000000 (one million)!")
if (!all(JOBS >= 0)) stop("Job numbers in JOBS may not be negative!")
if (length(JOBS) > 200 && !NICE_USER) warning(str_glue("You are submitting {length(JOBS)} jobs. That's a lot. Consider being nice by configuring NICE_USER = TRUE so as to give jobs of other users priority."))
if (!(REQUEST_MEMORY > 0)) stop("REQUEST_MEMORY should be larger than zero!")
if (!(REQUEST_DISK > 0)) stop("REQUEST_DISK should be larger than zero!")
if (!all(!duplicated(JOBS))) stop("Duplicate JOB numbers listed in JOBS!")
if (SCRIPT != "" && !(file_exists(SCRIPT))) stop(str_glue('Configured SCRIPT "{SCRIPT}" does not exist relative to working directory!'))
if (str_detect(SCRIPT, '[<>|:?*" \\t/\\\\]')) stop(str_glue("Configured SCRIPT has forbidden character(s)!"))
if (length(JOBS) > 1 && !str_detect(ARGUMENTS, fixed("%1"))) stop("Configured ARGUMENTS lack a %1 batch file argument expansion of the job number with which the job-specific (e.g. scenario) can be selected.")
for (file in BUNDLE_ADDITIONAL_FILES) {
  if (!(file_exists(path(file)))) stop(str_glue('Misconfigured BUNDLE_ADDITIONAL_FILES: "{file}" does not exist!'))
}
if (str_detect(CONDOR_DIR, '[<>|?*" \\t\\\\]')) stop(str_glue("Configured CONDOR_DIR has forbidden character(s)! Use / as path separator."))
if (GET_OUTPUT) {
  if (is.null(OUTPUT_DIR_SUBMIT)) {
    # Use OUTPUT_DIR on the submit machine side as well.
    if (!(file_exists(OUTPUT_DIR))) stop(str_glue('Configured OUTPUT_DIR "{OUTPUT_DIR}" does not exist!'))
    OUTPUT_DIR_SUBMIT <- OUTPUT_DIR
  } else {
    # Use a separate OUTPUT_DIR_SUBMIT configuration on the submit machine side.
    if (str_detect(OUTPUT_DIR_SUBMIT, '[<>|?*" \\t\\\\]')) stop(str_glue("Configured OUTPUT_DIR_SUBMIT has forbidden character(s)! Use / as path separator."))
    if (!(file_exists(OUTPUT_DIR_SUBMIT))) stop(str_glue('Configured OUTPUT_DIR_SUBMIT "{OUTPUT_DIR_SUBMIT}" does not exist!'))
  }
  if (str_detect(OUTPUT_DIR, "^/") || str_detect(OUTPUT_DIR, "^.:")) stop(str_glue("Configured OUTPUT_DIR must be located under the working directory: absolute paths not allowed!"))
  if (str_detect(OUTPUT_DIR, fixed("../"))) stop(str_glue("Configured OUTPUT_DIR must be located under the working directory: you may not go up to parent directories using ../"))
  if (str_detect(OUTPUT_DIR, '[<>|:?*" \\t\\\\]')) stop(str_glue("Configured OUTPUT_DIR has forbidden character(s)! Use / as path separator."))
  if (str_detect(OUTPUT_FILE, '[<>|:?*" \\t/\\\\]')) stop(str_glue("Configured OUTPUT_FILE has forbidden character(s)!"))
}
output_prefix <- tools::file_path_sans_ext(OUTPUT_FILE)
output_extension <- tools::file_ext(OUTPUT_FILE)
script_prefix <- tools::file_path_sans_ext(SCRIPT)
script_extension <- tools::file_ext(SCRIPT)

# Get username in a way that works on MacOS, Linux, and Windows
username <- Sys.getenv("USERNAME")
if (username == "") username <- Sys.getenv("USER")
if (username == "") stop("Cannot determine the username!")

# Ensure that a log directory to hold the .log/.err/.out files and other artifacts exists for the run
if (!dir_exists(CONDOR_DIR)) dir_create(CONDOR_DIR)
log_dir <- path(CONDOR_DIR, LABEL)
if (!dir_exists(log_dir)) dir_create(log_dir)

# ---- Check status of execution points ----

# Check that required Condor binaries are available
check_on_path(c("condor_submit", "condor_status", "condor_q", "condor_reschedule"))

# Construct clause stating what execution points are selected by
selected_by <- str_glue(
  "{ifelse(HOST_REGEXP == '.*', '', ' matching HOST_REGEXP')}",
  "{ifelse(HOST_REGEXP == '.*' || length(REQUIREMENTS) == 0,'', ' and')}",
  "{ifelse(length(REQUIREMENTS) == 0, '', ' meeting REQUIREMENTS')}"
)

cat(str_glue("Available resources on execution points{selected_by}:"), sep="\n")
error_code <- system2("condor_status", args=c("-compact", constraints(REQUIREMENTS), "-constraint", str_glue('"regexp(\\"{HOST_REGEXP}\\",machine)"')))
if (error_code > 0) stop("Cannot show Condor pool status! Probably, your submit machine is unable to connect to the central manager. Possibly, you are running a too-old (< V8.7.2) Condor version.")
cat("\n")

# Collect host name and domain of available execution points matching HOST_REGEXP and meeting REQUIREMENTS
hostdoms <- unique(system2("condor_status", c("-compact", "-autoformat", "Machine", constraints(REQUIREMENTS), "-constraint", str_glue('"regexp(\\"{HOST_REGEXP}\\",machine)"')), stdout=TRUE))
if (!is.null(attr(hostdoms, "status")) && attr(hostdoms, "status") != 0) stop("Cannot show Condor pool status! Are you running a too old (< V8.7.2) Condor version?")
if (length(hostdoms) == 0) {
  stop(str_glue("No available execution points{selected_by}!"))
}

# ---- Bundle the files needed to run the jobs ----

# Set R-default and platform-specific paths to the bundle
bundle <- "_bundle.7z"
unique_bundle <- str_glue('bundle_{str_replace_all(Sys.time(), "[- :]", "")}.7z') # To keep multiple cached bundles separate
bundle_path <- path(temp_dir_parent, bundle) # Invariant so that it can double-duty as a lock file blocking interfering parallel submissions
bundle_platform_path <- str_replace_all(bundle_path, fixed(.Platform$file.sep), fsep)
if (file_exists(bundle_path)) stop(str_glue("{bundle_path} already exists! Is there another submission ongoing? If so, let that submission end first. If not, delete the file and try again."))

args_for_7z <- unlist(lapply(c(
  "a",
  "-mx1",
  "-bb0",
  unlist(lapply(BUNDLE_INCLUDE_DIRS,  function(p) return(str_glue("-ir!", p)))),
  unlist(lapply(BUNDLE_INCLUDE_FILES, function(p) return(str_glue("-i!",  p)))),
  unlist(lapply(BUNDLE_EXCLUDE_DIRS,  function(p) return(str_glue("-xr!", p)))),
  unlist(lapply(BUNDLE_EXCLUDE_FILES, function(p) return(str_glue("-x!",  p)))),
  "-xr!{CONDOR_DIR}",
  ifelse(OUTPUT_DIR_SUBMIT != "", "-xr!{OUTPUT_DIR_SUBMIT}", ""),
  bundle_platform_path,
  "{BUNDLE_INCLUDE}"
), str_glue))
cat("Compressing files into bundle...\n")
byte_size <- bundle_with_7z(args_for_7z)
cat("\n")

added_size <- 0
if (length(BUNDLE_ADDITIONAL_FILES) != 0) {
  cat("Bundling additional files...\n")
  args_for_7z <- c("a", bundle_platform_path, BUNDLE_ADDITIONAL_FILES)
  added_size <- bundle_with_7z(args_for_7z)
  cat("\n")
}

if (BUNDLE_ONLY) {
  message(str_glue("BUNDLE_ONLY = TRUE: copying bundle into {log_dir} for inspection and quitting."))
  tryCatch(
    file_copy(bundle_path, path(log_dir, str_glue("_bundle.7z")), overwrite = TRUE),
    error=function(cond) {
      message(cond)
      warning("Could not make a reference copy of the bundle!")
    }
  )
  file_delete(bundle_path) # Delete the copied bundle in the temp directory
  q(save = "no")
}

# Add uncompressed bundle size to the disk request in KiB
request_disk <- REQUEST_DISK + ceiling((byte_size + added_size) / 1024)

# Determine the bundle size in KiB
bundle_size <- floor(file_size(bundle_path) / 1024)

# ---- Seed available execution points with the bundle ----

# Apply settings to  template and write batch file / shell script that launches jobs on the execution point 
seed_bat <- path(temp_dir, str_glue("_seed.bat"))
bat_conn<-file(seed_bat, open="wt")
writeLines(unlist(lapply(SEED_BAT_TEMPLATE, str_glue)), bat_conn)
close(bat_conn)
rm(bat_conn)

# Transfer bundle to each available execution point
# Execute-host-side automated bundle cleanup is assumed to be active:
# https://mis.iiasa.ac.at/portal/page/portal/IIASA/Content/TicketS/Ticket?defpar=1%26pWFLType=24%26pItemKey=103034818402942720
cluster_regexp <- "submitted to cluster (\\d+)[.]$"
clusters <- c()
hostnames <- c()
for (hostdom in hostdoms) {

  hostname <- str_extract(hostdom, "^[^.]*")
  hostnames <- c(hostnames, hostname)
  cat(str_glue("Starting transfer of bundle to {hostname}."), sep="\n")

  # Apply settings to seed job template and write the .job file to use for submission
  seed_job_file <- path(temp_dir, str_glue("_seed_{hostname}.job"))
  seed_job_conn<-file(seed_job_file, open="wt")
  writeLines(unlist(lapply(SEED_JOB_TEMPLATE, str_glue)), seed_job_conn)
  close(seed_job_conn)
  rm(seed_job_conn)

  # Delete any job output left over from an aborted prior run
  delete_if_exists(log_dir, str_glue("_seed_{hostname}.log"))
  delete_if_exists(log_dir, str_glue("_seed_{hostname}.out"))
  delete_if_exists(log_dir, str_glue("_seed_{hostname}.err"))

  outerr <- system2("condor_submit", args=seed_job_file, stdout=TRUE, stderr=TRUE)
  if (!is.null(attr(outerr, "status")) && attr(outerr, "status") != 0) {
    cat(outerr, sep="\n")
    file_delete(bundle_path)
    stop("Submission of bundle seed job failed!")
  }
  rm(seed_job_file)
  cluster <- as.integer(str_match(tail(grep(cluster_regexp, outerr, value=TRUE), 1), cluster_regexp)[2])
  if (is.na(cluster)) {
    file_delete(bundle_path)
    stop("Cannot extract cluster number from condor_submit output!")
  }
  clusters <- c(clusters, cluster)
}

# Predict the cluster number for the actual run
predicted_cluster <- cluster+1

# Wait until seed jobs complete
cat("Waiting for bundle seeding to complete...\n")
monitor(clusters)
rm(clusters)

# Check if any seed jobs produced .log files
if (!any(file_exists(path(log_dir, str_glue("_seed_{hostnames}.log"))))) {
  message("None of the seed jobs produced a .log file!")
  file_delete(bundle_path)
  stop(str_glue("Aborting, see https://github.com/iiasa/Condor_run_R/blob/master/troubleshooting.md#seeding-fails-or-jobs-go-on-hold-without-producing-matching-log-files for possible solutions."))
}

# Determine which seed jobs failed
return_values <- get_return_values(path(log_dir, str_glue("_seed_{hostnames}.log")))
err_file_sizes <-  file_size(path(log_dir, str_glue("_seed_{hostnames}.err")))
failed_seeds <- is.na(return_values) | return_values != 0 | err_file_sizes != 0
rm(return_values, err_file_sizes)

# Check whether seed jobs failed
if (all(failed_seeds)) {
  file_delete(bundle_path)
  stop(str_glue("All seeding jobs failed! For details, see the _seed_* files in {log_dir}. The likely cause is explained here: https://github.com/iiasa/Condor_run_R/blob/master/troubleshooting.md#all-seeding-jobs-remain-idle-and-then-abort-through-the-periodicremove-expression"))
}
if (any(failed_seeds)) {
  if (length(failed_seeds[failed_seeds == TRUE]) == 1) {
    warning(str_glue("A seeding job failed, will refrain from scheduling jobs on the affected execution point {hostnames[failed_seeds]}."))
  } else {
    warning(str_glue("Seeding jobs failed, will refrain from scheduling jobs on the affected execution points {str_c(hostnames[failed_seeds], collapse=', ')}."))
  }
  hostdoms <- hostdoms[!failed_seeds]
  hostnames <- hostnames[!failed_seeds]
}
rm(failed_seeds)

# Delete seeding log files of normally terminated seed jobs
file_delete(seed_bat)
rm(seed_bat)
for (hostname in hostnames) {
  delete_if_exists(temp_dir, str_glue("_seed_{hostname}.job"))
  delete_if_exists(log_dir, str_glue("_seed_{hostname}.log"))
  delete_if_exists(log_dir, str_glue("_seed_{hostname}.out"))
  delete_if_exists(log_dir, str_glue("_seed_{hostname}.err"))
}

# Report that seeding is done
if (length(hostnames) == 1) {
  cat(str_glue("Seeding done: execution point {hostnames} has received and cached the bundle.\n"))
} else {
  cat(str_glue("Seeding done: execution points {str_c(hostnames, collapse=', ')} have received and cached the bundle.\n"))
}
cat("\n")
rm(hostnames)

# ---- Prepare files for run ----

# Move the configuration from the temp to the log directory so as to have a persistent reference
config_file <- path(log_dir, str_glue("_config_{predicted_cluster}.R"))
tryCatch(
  file_copy(temp_config_file, config_file, overwrite=TRUE),
  error=function(cond) {
    file_delete(bundle_path)
    message(cond)
    stop(str_glue("Cannot copy the configuration from {temp_config_file} to {log_dir}!"))
  }
)
file_delete(temp_config_file)

# Copy the SCRIPT to the log directory for reference
if (SCRIPT != "") {
  tryCatch(
    file_copy(SCRIPT, path(log_dir, str_glue("_{script_prefix}_{predicted_cluster}.{script_extension}")), overwrite=TRUE),
    error=function(cond) {
      file_delete(bundle_path)
      message(cond)
      stop(str_glue("Cannot copy the configured SCRIPT file to {log_dir}!"))
    }
  )
}

# Apply settings to BAT_TEMPLATE and write the batch file / shell script to launch jobs with
bat_path <- path(log_dir, str_glue("_launch_{predicted_cluster}.bat"))
bat_conn<-file(bat_path, open="wt")
writeLines(unlist(lapply(BAT_TEMPLATE, str_glue)), bat_conn)
close(bat_conn)
rm(bat_conn)

# Apply settings to job template and write the .job file to use for submission
job_file <- path(log_dir, str_glue("_submit_{predicted_cluster}.job"))
job_conn<-file(job_file, open="wt")
writeLines(unlist(lapply(JOB_TEMPLATE, str_glue)), job_conn)
close(job_conn)
rm(job_conn)

# ---- Submit the run and clean up temp files ----

outerr <- system2("condor_submit", args=job_file, stdout=TRUE, stderr=TRUE)
cat(outerr, sep="\n")
if (!is.null(attr(outerr, "status")) && attr(outerr, "status") != 0) {
  file_delete(bundle_path)
  stop("Submission of Condor run failed!")
}
cluster <- as.integer(str_match(tail(grep(cluster_regexp, outerr, value=TRUE), 1), cluster_regexp)[2])
if (is.na(cluster)) {
  file_delete(bundle_path)
  stop("Cannot extract cluster number from condor_submit output!")
}
if (cluster != predicted_cluster) {
  # system2("condor_rm", args=str_glue("{cluster}")) # should do this, but it does not work due to some weird Condor/R/Windows bug.
  file_delete(bundle_path)
  stop(str_glue("Submission cluster number {cluster} not equal to prediction {predicted_cluster}! You probably submitted something else via Condor while this submission was ongoing, causing the cluster number (sequence count of your submissions) to increment. As a result, log files have been named with a wrong cluster number.\n\nPlease do not submit additional Condor jobs until after a submission has completed. Note that this does not mean that you have to wait for the run to complete before submitting further runs, just wait for the submission to make it to the point where the execution points have been handed the jobs. Please try again.\n\nYou should first remove the run's jobs with: condor_rm {cluster}."))
}

# Log a listing of the bundle contents
list <- list_7z(bundle_path)
list_conn<-file(path(log_dir, str_glue("_bundle_{cluster}_contents.txt")), open="wt")
writeLines(list, con = list_conn)
close(list_conn)
rm(list, list_conn)

# Retain the bundle if so requested, then delete it from temp so that further submissions are no longer blocked
if (RETAIN_BUNDLE) {
  tryCatch(
    file_copy(bundle_path, path(log_dir, str_glue("_bundle_{cluster}.7z"))),
    error=function(cond) {
      message(cond)
      warning("Could not make a reference copy of bundle as requested via RETAIN_BUNDLE!")
    }
  )
}
file_delete(bundle_path) # Deleting the bundle unblocks this script for another submission
message(str_glue('Run "{LABEL}" with cluster number {cluster} has been submitted.'))
message(str_glue("Run log directory: {path_abs(log_dir)}"))
message("It is now possible to submit additional runs.")

# Log the cluster number if requested. If you parse the above stdout, you can parse out the cluster number.
# If you cannot capture the stdout, you can request the cluster number to be logged by specifying a log file
# path in CLUSTER_NUMBER_LOG.

if (CLUSTER_NUMBER_LOG != "") {
  readr::write_file(str_glue("{cluster}"), CLUSTER_NUMBER_LOG)
}

# ---- Handle run results ----

if (WAIT_FOR_RUN_COMPLETION) {
  # Monitor the run until it completes
  cat(str_glue('Waiting for run "{LABEL}" to complete...'), sep="\n")
  monitor(cluster)

  # Check that result files exist and are not empty, warn otherwise and delete empty files
  all_exist_and_not_empty(log_dir, "_{PREFIX}_{cluster}.{job}.err", ".err", warn=FALSE)
  if (GET_OUTPUT) {
    output_files_complete <- all_exist_and_not_empty(OUTPUT_DIR_SUBMIT, 'output_{LABEL}_{cluster}.{sprintf("%06d", job)}.{output_extension}', output_extension)
  }

  return_values <- get_return_values(path(log_dir, str_glue("{PREFIX}_{cluster}.{JOBS}.log")))
  if (any(is.na(return_values))) {
    stop(str_glue("Abnormal termination of job(s) {summarize_jobs(JOBS[is.na(return_values)])}! For details, see the {PREFIX}_{cluster}.* files in {log_dir}"))
  }
  if (any(return_values != 0)) {
    stop(str_glue("Job(s) {summarize_jobs(JOBS[return_values != 0])} returned a non-zero return value! For details, see the {PREFIX}_{cluster}.* files in {log_dir}"))
  }
  cat("All jobs are done.\n")

  # Warn when REQUEST_MEMORY or REQUEST_DISK turns out to have been set
  # too low or significantly too high.
  max_memory_use <- -1
  max_memory_job <- -1
  max_disk_use <- -1
  max_disk_job <- -1
  disk_allocated <- 0
  max_cpu_use <- -1
  max_cpu_job <- -1
  memory_use_regexp <- "^\\s+Memory \\(MB\\)\\s+:\\s+(\\d+)\\s+"
  disk_use_regexp <- "^\\s+Disk \\(KB\\)\\s+:\\s+(\\d+)\\s+(\\d+)"
  cpus_use_regexp <- "^\\s+Cpus\\s+:\\s+([[:digit:].]+)\\s+"
  for (job in JOBS) {
    job_lines <- readLines(path(log_dir, str_glue("{PREFIX}_{cluster}.{job}.log")))
    memory_use <-
      as.double(str_match(tail(
        grep(memory_use_regexp, job_lines, value = TRUE), 1
      ), memory_use_regexp)[2])
    if (!is.na(memory_use) && memory_use > max_memory_use) {
      max_memory_use <- memory_use
      max_memory_job <- job
    }
    disk_use <-
      as.double(str_match(tail(
        grep(disk_use_regexp, job_lines, value = TRUE), 1
      ), disk_use_regexp)[2:3])
    if (!any(is.na(disk_use)) && disk_use[1] > max_disk_use) {
      max_disk_use <- disk_use[1]
      disk_request <- disk_use[2]
      max_disk_job <- job
    }
    cpu_use <-
      as.double(str_match(tail(
        grep(cpus_use_regexp, job_lines, value = TRUE), 1
      ), cpus_use_regexp)[2])
    if (!is.na(cpu_use) && cpu_use > max_cpu_use) {
      max_cpu_use <- cpu_use
      max_cpu_job <- job
    }
  }
  if (max_memory_job >= 0 && max_memory_use > REQUEST_MEMORY) {
    warning(str_glue("!!!! The job ({max_memory_job}) with the highest memory use ({max_memory_use} MiB) exceeded the REQUEST_MEMORY config. !!!!"))
  }
  if (max_memory_job >= 0 && max_memory_use/REQUEST_MEMORY < 0.75 && max_memory_use > 1000) {
    warning(str_glue("REQUEST_MEMORY ({REQUEST_MEMORY} MiB) is significantly larger than the memory use ({max_memory_use} MiB) of the job ({max_memory_job}) using the most memory. Please lower REQUEST_MEMORY so that more jobs can run."))
  }
  if (max_disk_job >= 0 && max_disk_use > disk_request) {
    warning(str_glue("!!!! The job ({max_disk_job}) with the highest disk use exceeded the requested disk space by {max_disk_use-disk_request} KB. Please increase REQUEST_DISK by at least that amount. !!!!"))
  }
  if (max_disk_job >= 0 && max_disk_use/disk_allocated < 0.6 && max_disk_use > 2000000) {
    warning(str_glue("The amount of requested disk space is significantly larger ({disk_request-max_disk_use} KB more) than the disk use of the job ({max_disk_job}) using the most disk. Consider lowering REQUEST_DISK."))
  }
  if (max_cpu_use >= 0 && max_cpu_use >= REQUEST_CPUS+1) {
    warning(str_glue("The job ({max_cpu_job}) with the highest CPU thread usage ({max_cpu_use}) considerably exceeded REQUEST_CPUS ({REQUEST_CPUS}). Please increase REQUEST_CPUS to a higher integer number."))
  }

  # Make a bit of noise to notify the user of completion (works with Rscript but not from RStudio)
  alarm()
  Sys.sleep(1)
  alarm()
} else {
  cat(str_glue("You can monitor progress of the run with: condor_q {cluster}."), sep="\n")
  if (GET_OUTPUT) {
    cat(str_glue("After the run completes, you can find the output files at: {OUTPUT_DIR_SUBMIT}/{output_prefix}_{LABEL}_{cluster}.*"), sep="\n")
  }
}
