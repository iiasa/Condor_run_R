#!/usr/bin/env Rscript
# Submit a Condor run (a set of jobs). Expanded version for GAMS jobs. Can
# be configured to monitor progress and merge gdx output on completion.
#
# Installation: https://github.com/iiasa/Condor_run_R#installation
# Use:          https://github.com/iiasa/Condor_run_R#use
#
# Author:   Albert Brouwer
# Based on: GLOBIOM-limpopo scripts by David Leclere
# Release:  https://github.com/iiasa/Condor_run_R/releases/tag/v2022-11-03
# API version: V1

# Remove any objects from active environment so that below it will contain only the default configuration
rm(list=ls())

# ---- Configuration parameters, mandatory ----

# DO NOT EDIT HERE!
# Copy all of these to a separate configuration file and adapt their values.
# .......8><....snippy.snappy....8><.........................................
# See https://github.com/iiasa/Condor_run_R/blob/master/configuring.md
JOBS = c()
REQUEST_MEMORY = 100
GAMS_FILE_PATH = "model.gms"
GAMS_ARGUMENTS = "//job_number=%1 checkErrorLevel=1"
GAMS_VERSION = "32.1"
WAIT_FOR_RUN_COMPLETION = TRUE
# .......8><....snippy.snappy....8><.........................................
mandatory_config_names <- ls()

# ---- Configuration parameters, optional ----

# DO NOT EDIT HERE!
# Add to a separate configuration file the parameters that you need to override.
# See https://github.com/iiasa/Condor_run_R/blob/master/configuring.md
LABEL = "{Sys.Date()}"
AVAILABLE_GAMS_VERSIONS = c("24.2", "24.4", "24.9", "25.1", "29.1", "32.2")
BUNDLE_INCLUDE = c("*")
BUNDLE_INCLUDE_DIRS = c()
BUNDLE_EXCLUDE_DIRS = c(".git", ".svn", "225*")
BUNDLE_INCLUDE_FILES = c()
BUNDLE_EXCLUDE_FILES = c("**/*.~*", "**/*.log", "**/*.log~*", "**/*.lxi", "**/*.lst")
BUNDLE_ADDITIONAL_FILES = c()
BUNDLE_ONLY = FALSE
BUNDLE_DIR = NULL
RETAIN_BUNDLE = FALSE
RETAIN_SEED_ARTIFACTS = FALSE
SEED_JOB_OVERRIDES = list()
SEED_JOB_RELEASES = 0
JOB_OVERRIDES = list()
JOB_RELEASES = 3
JOB_RELEASE_DELAY = 120
HOST_REGEXP = ".*"
REQUIREMENTS = c("GAMS")
REQUEST_CPUS = 1
REQUEST_DISK = 1000000 # KiB
CONDOR_DIR = "Condor"
GAMS_CURDIR = "."
RESTART_FILE_PATH = ""
MERGE_GDX_OUTPUT = FALSE
MERGE_BIG = NULL
MERGE_ID = NULL
MERGE_EXCLUDE = NULL
REMOVE_MERGED_GDX_FILES = FALSE
GET_G00_OUTPUT = FALSE
G00_OUTPUT_DIR = ""
G00_OUTPUT_DIR_SUBMIT = NULL
G00_OUTPUT_FILE = ""
GET_GDX_OUTPUT = FALSE
GDX_OUTPUT_DIR = ""
GDX_OUTPUT_DIR_SUBMIT = NULL
GDX_OUTPUT_FILE = ""
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
  "periodic_release = (NumJobStarts <= {JOB_RELEASES}) && ((time() - EnteredCurrentStatus) > {JOB_RELEASE_DELAY})",
  "",
  "{build_requirements_expression(REQUIREMENTS, hostdoms)}",
  "request_memory = {REQUEST_MEMORY}",
  "request_cpus = {REQUEST_CPUS}", # Number of "CPUs" (hardware threads) to reserve for each job
  "request_disk = {REQUEST_DISK}",
  "",
  '+IIASAGroup = "ESM"', # Identifies you as part of the group allowed to use ESM cluster
  "run_as_owner = {ifelse(RUN_AS_OWNER, 'True', 'False')}",
  "",
  "should_transfer_files = YES",
  "when_to_transfer_output = ON_EXIT",
  'transfer_output_files = {str_sub(in_gams_curdir(GAMS_FILE_PATH), 1, -5)}.lst{ifelse(GET_G00_OUTPUT, str_glue(",{in_gams_curdir(G00_OUTPUT_DIR)}/{G00_OUTPUT_FILE}"), "")}{ifelse(GET_GDX_OUTPUT, str_glue(",{in_gams_curdir(GDX_OUTPUT_DIR)}/{GDX_OUTPUT_FILE}"), "")}',
  'transfer_output_remaps = "{str_sub(GAMS_FILE_PATH, 1, -5)}.lst={log_dir}/{PREFIX}_$(cluster).$(job).lst{ifelse(GET_G00_OUTPUT, str_glue(";{G00_OUTPUT_FILE}={G00_OUTPUT_DIR_SUBMIT}/{g00_prefix}.$(job).g00"), "")}{ifelse(GET_GDX_OUTPUT, str_glue(";{GDX_OUTPUT_FILE}={GDX_OUTPUT_DIR_SUBMIT}/{gdx_prefix}.$$([substr(strcat(string(0),string(0),string(0),string(0),string(0),string(0),string($(job))),-6)]).gdx"), "")}"',
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
  '{ifelse(in_gams_curdir(G00_OUTPUT_DIR) == "", "", str_glue("mkdir \\"{in_gams_curdir(G00_OUTPUT_DIR)}\\" 2>NUL"))}',
  '{ifelse(in_gams_curdir(GDX_OUTPUT_DIR) == "", "", str_glue("mkdir \\"{in_gams_curdir(GDX_OUTPUT_DIR)}\\" 2>NUL"))}',
  "set bundle_root=d:\\condor\\bundles",
  "if not exist %bundle_root% set bundle_root=e:\\condor\\bundles",
  "set gams_dir=c:\\GAMS\\win64\\{GAMS_VERSION}",
  "if not exist %gams_dir% set gams_dir=c:\\GAMS\\{major_gams_version}",
  "if not exist %gams_dir% (",
  "  echo ERROR: GAMS version {GAMS_VERSION} is not installed on this machine!",
  "  exit /b 1",
  ")",
  "@echo on",
  "touch %bundle_root%\\{username}\\{timestamped_bundle_name} 2>NUL", # postpone automated cleanup of bundle, can fail when another job is using the bundle but that's fine as the touch will already have happened
  '7z x %bundle_root%\\{username}\\{timestamped_bundle_name} -y -x!{CHECKPOINT_FILE} >NUL || exit /b %errorlevel%',
  "set GDXCOMPRESS=1", # causes GAMS to compress the GDX output file
  paste(
    '%gams_dir%\\gams',
    "{GAMS_FILE_PATH}",
    '-logOption=3',
    '{ifelse(GAMS_CURDIR != "", str_glue("curDir=\\"{GAMS_CURDIR}\\" "), "")}',
    '{ifelse(RESTART_FILE_PATH != "", str_glue("restart=\\"{RESTART_FILE_PATH}\\" "), "")}',
    '{ifelse(GET_G00_OUTPUT, str_glue("save=\\"", path(G00_OUTPUT_DIR, G00_OUTPUT_FILE), "\\""), "")}',
    '{str_glue(GAMS_ARGUMENTS)}',
    sep = ' '
  ),
  "set gams_errorlevel=%errorlevel%",
  "@echo off",
  "if %gams_errorlevel% neq 0 (",
  "  echo ERROR: GAMS failed with error code %gams_errorlevel% 1>&2",
  "  echo See https://www.gams.com/latest/docs/UG_GAMSReturnCodes.html#UG_GAMSReturnCodes_ListOfErrorCodes 1>&2",
  ")",
  "sleep 1", # Make it less likely that the .out file is truncated.
  "exit /b %gams_errorlevel%"
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
  "request_disk = {2*floor(file_size(bundle_path)/1024)+500}", # KiB, twice needed for move, add some for the extra files
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
  "move /Y {basename(bundle_path)} %bundle_dir%\\{timestamped_bundle_name}"
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

# Define constants
CHECKPOINT_FILE = "submit_checkpoint.RData"
API <- "Condor_run"
API_VERSION <- "v1"
USAGE <- str_c("Usage:",
               "[Rscript ]Condor_run.R [--bundle-only] <config file>|<bundle file with .7z extension>",
               "Full documentation: https://github.com/iiasa/Condor_run_R#use",
               sep="\n")

# ---- Define helper functions ----

# Check that the given binaries are on-path
check_on_path <- function(binaries) {
  where <- Sys.which(binaries)
  for (bin in binaries) {
    if (where[bin] == "") {
      stop(str_glue("Required binary/executable '{bin}' was not found! Please add its containing directory to the PATH environment variable."), call.=FALSE)
    }
  }
}

# Extract checkpoint file with 7-Zip to tempdir()
# Returns the path to the extracted checkpoint file
extract_checkpoint <- function(bundle_path) {
  check_on_path("7z")
  args_for_7z <- c(
    "e",
    str_glue('-o"{path(tempdir())}"'),
    bundle_path,
    CHECKPOINT_FILE
  )
  out <- system2("7z",
                 stdout = TRUE,
                 stderr = TRUE,
                 args = args_for_7z
  )
  if (!is.null(attr(out, "status")) && attr(out, "status") != 0) {
    message(
      "7-Zip failed to extract checkpoint file from bundle.\nThe arguments for 7z were as follows:"
    )
    message(paste(args_for_7z, collapse = '\n'))
    message("\nThe invocation of 7-Zip returned:")
    message(paste(out, collapse = '\n'))
    stop("Extraction failed!", call. = FALSE)
  }
  return(path(tempdir(), CHECKPOINT_FILE))
}

# Bundle files with 7-Zip via the given command line arguments.
# Returns a list with entries "added" and "bundle" holding the number of bytes
# added to the bundle and the byte size of the bundle file on completion.
bundle_with_7z <- function(args_for_7z) {
  check_on_path("7z")
  if (BUNDLE_ONLY) {
    message("Invoking 7-Zip via the following command line:")
    message(str_c(c("7z", args_for_7z), collapse = " "))
  }
  out <- system2("7z",
                 stdout = TRUE,
                 stderr = TRUE,
                 args = args_for_7z)
  if (!is.null(attr(out, "status")) && attr(out, "status") != 0) {
    message(
      "7-Zip failed, likely because of erroneous or too many arguments.\nThe arguments for 7z derived from the BUNDLE_* config options were as follows:"
    )
    message(paste(args_for_7z, collapse = '\n'))
    message("\nThe invocation of 7-Zip returned:")
    message(paste(out, collapse = '\n'))
    stop("Bundling failed!", call. = FALSE)
  }
  else {
    # Parse out the added number of bytes
    scan_line <- out[[str_which(out, "^Scanning the drive:") + 1]]
    cat(scan_line, sep = "\n")
    added_size <- as.double(str_match(scan_line, ", (\\d+) bytes \\(")[2])
    if (is.na(added_size))
      stop("7-Zip added size parsing failed!", call. = FALSE) # 7-Zip output format has changed?
    # Parse out the size of the bundle on completion
    size_line <- str_subset(out, "^Archive size:")
    cat(size_line, sep = "\n")
    bundle_size <- as.double(str_match(size_line, "^Archive size: (\\d+) bytes")[2])
    if (is.na(bundle_size))
      stop("7-Zip archive size parsing failed!", call. = FALSE) # 7-Zip output format has changed?
    # Return a list with the added size and bundle size
    return(list("added" = added_size, "bundle" = bundle_size))
  }
}

# List content of a 7-Zip archive
list_7z <- function(archive_path) {
  check_on_path("7z")
  out <- system2("7z", stdout=TRUE, stderr=TRUE, args=c("l", archive_path))
  if (!is.null(attr(out, "status")) && attr(out, "status") != 0) {
    stop(str_glue("Failed to list content of {archive_path}"), call.=FALSE)
  } else {
    # Clip off the header info
    out <- out[max(1, min(which(str_detect(out, "Date ")))):length(out)]
  }
  return(out)
}

# Check whether the given directory path can be excluded without
# conflicting with any of the BUNDLE_INCLUDE_* parameters.
excludable <- function(dir_path) {
  if (any(path_has_parent(BUNDLE_INCLUDE, dir_path))) return(FALSE)
  if (any(path_has_parent(BUNDLE_INCLUDE_FILES, dir_path))) return(FALSE)
  if (any(path_has_parent(BUNDLE_INCLUDE_DIRS, dir_path))) return(FALSE)
  return(TRUE)
}

# Create log directory to hold the .log/.err/.out files and other artifacts
# when not extant already.
# Returns the path to the log directory.
create_log_dir <- function() {
  tryCatch({
      if (!dir_exists(CONDOR_DIR)) dir_create(CONDOR_DIR)
      log_dir <- path(CONDOR_DIR, LABEL)
      if (!dir_exists(log_dir)) dir_create(log_dir)
      return(log_dir)
    },
    error=function(cond) {
      message("Could not create log directory!")
      message(cond)
      stop()
    }
  )
}

# Define a function to turn a path relative to GAMS_CURDIR into a path relative to the working directory when GAMS_CURDIR is set.
in_gams_curdir <- function(path) {
  if (GAMS_CURDIR == "") {
    # Needed because path_norm() with an empty path builds an absolute path
    return(path)
  }
  else {
    return(path_norm(path(GAMS_CURDIR, path)))
  }
}

# ---- Check arguments and bundle when passed ----

# Sanity check arguments
args <- commandArgs(trailingOnly=TRUE)
bundle_only <- FALSE
file_arg <- args[[1]]
if (length(args) == 0) {
  stop(str_c("No arguments!", USAGE, sep="\n"))
} else if (length(args) > 2) {
  stop(str_c("Too many arguments!", USAGE, sep="\n"))
} else if (length(args) == 2) {
  if (args[[1]] != "--bundle-only") {
    stop(str_c("Invalid arguments!", USAGE, sep="\n"))
  } else {
    bundle_only <- TRUE
  }
  file_arg <- args[[2]]
}
rm(args)
if (bundle_only && tools::file_ext(file_arg) == "7z") {
  stop(str_c("The --bundle-only argument does not apply when you already have a bundle!", USAGE, sep="\n"))
}

# When passed a bundle, extract and load checkpoint and skip to submission
if (tools::file_ext(file_arg) == "7z") {
  api <- API
  api_version <- API_VERSION
  rm(API, API_VERSION)
  checkpoint_path <- extract_checkpoint(file_arg)
  tryCatch({
      load(
        file = checkpoint_path,
        envir = .GlobalEnv,
        verbose = FALSE
      )
    },
    error=function(cond) {
      message("Could not load checkpoint!")
      message(cond)
      stop()
    }
  )
  rm(checkpoint_path)

  # Override bundle_path loaded from checkpoint
  bundle_path <- file_arg
  rm(file_arg)

  # Perform API checks
  if (!exists("API")) stop("No API in checkpoint!")
  if (!exists("API_VERSION")) stop("No API_VERSION in checkpoint!")
  if (API != api) {
    message("The bundle cannot be submitted with this script.")
    message("Try using Condor_run_basic.R instead.")
    stop(str_glue("Incompatible API '{API}': expecting '{api}',!"))
  }
  if (API != api) {
    message("The bundle cannot be submitted with this script.")
    message("The API version requested by the bundle is too old or new.")
    stop(str_glue("Incompatible API_VERSION '{API_VERSION}': this script supports API_VERSION '{api_version}'!"))
  }
  rm(api, api_version)

  log_dir <- create_log_dir()
} else {
  # ---- Check configuration file and settings ----

  # Check that the specified file argument exists
  if (!(file_exists(file_arg))) stop(str_glue('Invalid command line argument: specified configuration file "{file_arg}" does not exist!'))

  # Remove mandatory config defaults from the global scope
  rm(list=config_names[config_names %in% mandatory_config_names])
  rm(mandatory_config_names)

  # Source the config file, should add mandatory config settings to the global scope
  source(file_arg, local=TRUE, echo=FALSE)

  # Check that all config settings exist and have no weird value type
  for (i in seq_along(config_names))  {
    name <- config_names[i]
    if (!exists(name)) stop(str_glue("Mandatory config setting {name} is not set in config file {file_arg}!"))
    type <- typeof(get(name))
    if (type != config_types[[i]] &&
        config_types[[i]] != "integer" && # R has no stable numerical type
        config_types[[i]] != "double" && # R has no stable numerical type
        type != "NULL" && # allow for NULL
        config_types[[i]] != "NULL" # allow for default vector being empty
    ) stop(str_glue("{name} set to wrong type in {file_arg}, type should be {config_types[[i]]}"))
  }
  rm(type, name, i, config_types, config_names)

  # Override BUNDLE_ONLY when --bundle-only was provided as a command line argument
  if (bundle_only) {
    BUNDLE_ONLY <- TRUE
  }
  rm(bundle_only)

  # Copy configuration file to temp directory to minimize the risk of it being edited in the mean time
  tmp_config_path <- path(tempdir(), str_glue("config.R"))
  tryCatch(
    file_copy(file_arg, tmp_config_path, overwrite=TRUE),
    error=function(cond) {
      message(str_glue("Cannot make a copy of configuration file {file_arg}!"))
      message(cond)
      stop()
    }
  )
  rm(file_arg)

  # Synonyms ensure backwards compatibility with old config namings and
  # allow a name choice that best fits the configuration value.
  # Copy any synonyms to their canonical configs. This overrides the
  # default value.

  if (exists("NAME")) {
    LABEL <- NAME
    rm(NAME)
  }
  if (exists("EXPERIMENT")) {
    LABEL <- EXPERIMENT
    rm(EXPERIMENT)
  }
  if (exists("PROJECT")) {
    LABEL <- PROJECT
    rm(PROJECT)
  }

  # Check and massage specific config settings
  if (GAMS_CURDIR != "" && !dir_exists(GAMS_CURDIR)) stop(str_glue("No {GAMS_CURDIR} directory as configured in GAMS_CURDIR found relative to working directory {getwd()}!"))
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
  if (str_sub(GAMS_FILE_PATH, -4) != ".gms") stop(str_glue("Configured GAMS_FILE_PATH has no .gms extension!"))
  if (!(file_exists(in_gams_curdir(GAMS_FILE_PATH)))) stop(str_glue('Configured GAMS_FILE_PATH "{GAMS_FILE_PATH}" does not exist relative to GAMS_CURDIR!'))
  if (str_detect(GAMS_FILE_PATH, '[<>|:?*" \\t\\\\]')) stop(str_glue("Configured GAMS_FILE_PATH has forbidden character(s)! Use / as path separator."))
    if (RESTART_FILE_PATH != "") {
    if (!(file_exists(in_gams_curdir(RESTART_FILE_PATH)))) stop(str_glue('Configured RESTART_FILE_PATH "{RESTART_FILE_PATH}" does not exist relative to GAMS_CURDIR!'))
    if (str_detect(RESTART_FILE_PATH, "^/") || str_detect(RESTART_FILE_PATH, "^.:")) stop(str_glue("Configured RESTART_FILE_PATH must be located under the working directory for proper bundling: absolute paths not allowed!"))
    if (str_detect(RESTART_FILE_PATH, fixed("../"))) stop(str_glue("Configured RESTART_FILE_PATH must be located under the working directory for proper bundling: you may not go up to parent directories using ../"))
    if (str_detect(RESTART_FILE_PATH, '[<>|:?*" \\t\\\\]')) stop(str_glue("Configured RESTART_FILE_PATH has forbidden character(s)! Use / as path separator."))
  }

  version_match <- str_match(GAMS_VERSION, "^(\\d+)[.](\\d+)$")
  if (any(is.na(version_match))) stop(str_glue('Invalid GAMS_VERSION "{GAMS_VERSION}"! Format must be "<major>.<minor>".'))
  if (!(GAMS_VERSION %in% AVAILABLE_GAMS_VERSIONS)) stop(str_glue('Invalid GAMS_VERSION "{GAMS_VERSION}"! The GAMS-capable execution points have only these GAMS versions installed: {str_c(AVAILABLE_GAMS_VERSIONS, collapse=" ")}'))
  dotless_gams_version <- str_glue(version_match[2], version_match[3])
  major_gams_version <- version_match[2]
  rm(version_match)

  if (length(JOBS) < 1 && !str_detect(GAMS_ARGUMENTS, fixed("%1"))) stop("Configured GAMS_ARGUMENTS lack a %1 batch file argument expansion of the job number with which the job-specific (e.g. scenario) can be selected.")
  if (str_detect(CONDOR_DIR, '[<>|?*" \\t\\\\]')) stop(str_glue("Configured CONDOR_DIR has forbidden character(s)! Use / as path separator."))
  if (!is.null(BUNDLE_DIR)) {
    if (BUNDLE_DIR == "") stop("Configured BUNDLE_DIR may not be an empty path!")
    if (!(file_exists(BUNDLE_DIR))) stop(str_glue('Configure BUNDLE_DIR "{BUNDLE_DIR}" does not exist!'))
  }

  # Check and massage GAMS output config settings
  if (!(GET_G00_OUTPUT || GET_GDX_OUTPUT)) stop("Neither GET_G00_OUTPUT nor GET_GDX_OUTPUT are TRUE! A run without output is pointless.")
  if (GET_G00_OUTPUT) {
    if (is.null(G00_OUTPUT_DIR_SUBMIT)) {
      # Use G00_OUTPUT_DIR on the submit machine side as well.
      if (!(file_exists(in_gams_curdir(G00_OUTPUT_DIR)))) stop(str_glue('Configured G00_OUTPUT_DIR "{G00_OUTPUT_DIR}" does not exist relative to GAMS_CURDIR!'))
      G00_OUTPUT_DIR_SUBMIT <- in_gams_curdir(G00_OUTPUT_DIR)
    } else {
      # Use a separate G00_OUTPUT_DIR_SUBMIT configuration on the submit machine side
      if (str_detect(G00_OUTPUT_DIR_SUBMIT, '[<>|?*" \\t\\\\]')) stop(str_glue("Configured G00_OUTPUT_DIR_SUBMIT has forbidden character(s)! Use / as path separator."))
      if (!(file_exists(G00_OUTPUT_DIR_SUBMIT))) stop(str_glue('Configured G00_OUTPUT_DIR_SUBMIT "{G00_OUTPUT_DIR_SUBMIT}" does not exist!'))
    }
    if (str_detect(G00_OUTPUT_DIR, "^/") || str_detect(G00_OUTPUT_DIR, "^.:")) stop(str_glue("Configured G00_OUTPUT_DIR must be located under the working directory: absolute paths not allowed!"))
    if (str_detect(G00_OUTPUT_DIR, fixed("../"))) stop(str_glue("Configured G00_OUTPUT_DIR must be located under the working directory: you may not go up to parent directories using ../"))
    if (str_detect(G00_OUTPUT_DIR, '[<>|:?*" \\t\\\\]')) stop(str_glue("Configured G00_OUTPUT_DIR has forbidden character(s)! Use / as path separator."))
    if (str_sub(G00_OUTPUT_FILE, -4) != ".g00") stop(str_glue("Configured G00_OUTPUT_FILE has no .g00 extension!"))
    if (str_length(G00_OUTPUT_FILE) <= 4) stop(str_glue("Configured G00_OUTPUT_FILE needs more than an extension!"))
    if (str_detect(G00_OUTPUT_FILE, '[<>|:?*" \\t/\\\\]')) stop(str_glue("Configured G00_OUTPUT_FILE has forbidden character(s)!"))
  }
  if (GET_GDX_OUTPUT) {
    if (is.null(GDX_OUTPUT_DIR_SUBMIT)) {
      # Use GDX_OUTPUT_DIR on the submit machine side as well.
      if (!(file_exists(in_gams_curdir(GDX_OUTPUT_DIR)))) stop(str_glue('Configured GDX_OUTPUT_DIR "{GDX_OUTPUT_DIR}" does not exist relative to GAMS_CURDIR!'))
      GDX_OUTPUT_DIR_SUBMIT <- in_gams_curdir(GDX_OUTPUT_DIR)
    } else {
      # Use a separate GDX_OUTPUT_DIR_SUBMIT configuration on the submit machine side.
      if (str_detect(GDX_OUTPUT_DIR_SUBMIT, '[<>|?*" \\t\\\\]')) stop(str_glue("Configured GDX_OUTPUT_DIR_SUBMIT has forbidden character(s)! Use / as path separator."))
      if (!(file_exists(GDX_OUTPUT_DIR_SUBMIT))) stop(str_glue('Configured GDX_OUTPUT_DIR_SUBMIT "{GDX_OUTPUT_DIR_SUBMIT}" does not exist!'))
    }
    if (str_detect(GDX_OUTPUT_DIR, "^/") || str_detect(GDX_OUTPUT_DIR, "^.:")) stop(str_glue("Configured GDX_OUTPUT_DIR must be located under the working directory: absolute paths not allowed!"))
    if (str_detect(GDX_OUTPUT_DIR, fixed("../"))) stop(str_glue("Configured GDX_OUTPUT_DIR must be located under the working directory: you may not go up to parent directories using ../"))
    if (str_detect(GDX_OUTPUT_DIR, '[<>|:?*" \\t\\\\]')) stop(str_glue("Configured GDX_OUTPUT_DIR has forbidden character(s)! Use / as path separator."))
    if (str_sub(GDX_OUTPUT_FILE, -4) != ".gdx") stop(str_glue("Configured GDX_OUTPUT_FILE has no .gdx extension!"))
    if (str_length(GDX_OUTPUT_FILE) <= 4) stop(str_glue("Configured GDX_OUTPUT_FILE must contain more than only an extension!"))
    if (str_detect(GDX_OUTPUT_FILE, '[<>|:?*" \\t/\\\\]')) stop(str_glue("Configured GDX_OUTPUT_FILE has forbidden character(s)!"))
  }

  if (MERGE_GDX_OUTPUT && !GET_GDX_OUTPUT) stop("Cannot MERGE_GDX_OUTPUT without first doing GET_GDX_OUTPUT!")
  if (MERGE_GDX_OUTPUT && !WAIT_FOR_RUN_COMPLETION) stop("Cannot MERGE_GDX_OUTPUT without waiting for run completion! When MERGE_GDX_OUTPUT is TRUE, WAIT_FOR_RUN_COMPLETION may not be FALSE.")
  if (REMOVE_MERGED_GDX_FILES && !MERGE_GDX_OUTPUT) stop("Cannot REMOVE_MERGED_GDX_FILES without first doing MERGE_GDX_OUTPUT!")
  if (MERGE_GDX_OUTPUT) check_on_path("gdxmerge")

  # Though not utilized unless GET_G00_OUTPUT or GET_GDX_OUTPUT are TRUE, the below variables are
  # used in conditional string expansion via str_glue() such that the non-use is enacted only
  # only after the expansion already happened. Hence we need to assign some dummy values here when
  # when no assignment happened above.
  if (is.null(G00_OUTPUT_DIR_SUBMIT)) G00_OUTPUT_DIR_SUBMIT <- ""
  if (is.null(GDX_OUTPUT_DIR_SUBMIT)) GDX_OUTPUT_DIR_SUBMIT <- ""

  # Determine GAMS version used to generate RESTART_FILE_PATH, verify that it is <= GAMS_VERSION
  if (RESTART_FILE_PATH != "") {
    conn <- file(in_gams_curdir(RESTART_FILE_PATH), "rb")
    byte_count <- min(4000, file_size(in_gams_curdir(RESTART_FILE_PATH)))
    invisible(seek(conn, where=-byte_count, origin="end"))
    tail_bytes <- readBin(conn, what=integer(), size=1, n=byte_count)
    close(conn)
    tail_bytes[tail_bytes <= 0] <- 32
    tail <-  rawToChar(as.raw(tail_bytes))
    restart_version <- str_match(tail, "\x0AWEX(\\d\\d\\d)-\\d\\d\\d")[2]
    if (is.na(restart_version)) {
      warning(str_glue("Cannot determine GAMS version that saved {in_gams_curdir{(RESTART_FILE_PATH)}"))
    } else {
      if (dotless_gams_version < restart_version) {
        stop("The configured host-side GAMS_VERSION is older than the GAMS version that saved the configured restart file (RESTART_FILE_PATH). GAMS will fail!")
      }
    }
  }
  rm(dotless_gams_version)

  # ---- Bundle the files needed to run the jobs ----

  # Timestamp file names at millisecond resolution. This serves keep
  # multiple artifact files stored in the same directory separate.
  timestamp <- str_replace_all(format(Sys.time(),"%y%m%d%H%M%OS3"), "[.]", "")
  timestamped_bundle_name <- str_glue('_bundle_{timestamp}.7z')
  timestamped_bundle_list_name <- str_glue("_bundle_{timestamp}_contents.txt")
  timestamped_config_name <- str_glue("_config_{timestamp}.R")
  rm(timestamp)

  log_dir <- create_log_dir()
  tmp_bundle_path <- path(tempdir(), timestamped_bundle_name)

  # Include/exclude files in/from bundle
  args_for_7z <- unlist(lapply(c(
    "a",
    unlist(lapply(BUNDLE_INCLUDE_DIRS,  function(p) return(str_glue("-ir!", p)))),
    unlist(lapply(BUNDLE_INCLUDE_FILES, function(p) return(str_glue("-i!",  p)))),
    unlist(lapply(BUNDLE_EXCLUDE_DIRS,  function(p) return(str_glue("-xr!", p)))),
    unlist(lapply(BUNDLE_EXCLUDE_FILES, function(p) return(str_glue("-x!",  p)))),
    ifelse(excludable(CONDOR_DIR), "-xr!{CONDOR_DIR}", ""),
    ifelse(excludable(G00_OUTPUT_DIR_SUBMIT), "-xr!{G00_OUTPUT_DIR_SUBMIT}", ""),
    ifelse(excludable(GDX_OUTPUT_DIR_SUBMIT), "-xr!{GDX_OUTPUT_DIR_SUBMIT}", ""),
    tmp_bundle_path,
    "{BUNDLE_INCLUDE}"
  ), str_glue))
  cat("Compressing files into bundle...\n")
  size <- bundle_with_7z(args_for_7z)
  added_size <- size$added
  rm(args_for_7z, size, BUNDLE_INCLUDE, BUNDLE_INCLUDE_DIRS, BUNDLE_INCLUDE_FILES, BUNDLE_EXCLUDE_DIRS, BUNDLE_EXCLUDE_FILES)
  cat("\n")

  # Add additional files to bundle via separate invocations on 7-Zip
  if (length(BUNDLE_ADDITIONAL_FILES) != 0) {
    cat("Bundling additional files...\n")
    for (af in BUNDLE_ADDITIONAL_FILES) {
      size <- bundle_with_7z(c(
        "a",
        tmp_bundle_path,
        af
      ))
      added_size <- added_size + size$added
    }
    rm(af, size)
    cat("\n")
  }
  rm(BUNDLE_ADDITIONAL_FILES)

  # Add any GAMS restart file to the bundle
  if (RESTART_FILE_PATH != "") {
    # Bundle separately so that base directory can be added to BUNDLE_EXCLUDE_DIRS
    cat("Bundling restart file...\n")
    size <- bundle_with_7z(c(
      "a",
      tmp_bundle_path,
      in_gams_curdir(RESTART_FILE_PATH)
    ))
    added_size <- added_size + size$added
    rm(size)
    cat("\n")
  }

  # Checkpoint environment minus functions into the bundle
  tryCatch({
    checkpoint_conn <- file(path(tempdir(), CHECKPOINT_FILE), open="wb")
    save(
      list = ls()[lapply(lapply(ls(), get), typeof) != "closure"],
      file = checkpoint_conn,
      envir = .GlobalEnv
    )
    close(checkpoint_conn)
    rm(checkpoint_conn)
    },
    error=function(cond) {
      message("Could not checkpoint environment!")
      message(cond)
      stop()
    }
  )
  size <- bundle_with_7z(c(
    "a",
    tmp_bundle_path,
    path(tempdir(), CHECKPOINT_FILE)
  ))
  added_size <- added_size + size$added
  rm(size, bundle_with_7z)

  # Add uncompressed bundle size to the disk request in KiB
  REQUEST_DISK <- REQUEST_DISK + ceiling(added_size / 1024)
  rm(added_size)

  # List the bundle contents to tempdir()
  tmp_bundle_list_path <- path(tempdir(), timestamped_bundle_list_name)
  tryCatch({
      list_conn <- file(tmp_bundle_list_path, open="wt")
      lines <- list_7z(tmp_bundle_path)
      if (length(str_which(lines, "[.][gG]0[0123]$")) > 1)
        warning(
          "Multiple restart files were bundled! Probably you need only one restart file. You can exclude directories and files from the bundle with BUNDLE_EXCLUDE_DIRS and BUNDLE_EXCLUDE_FILES.",
          call. = FALSE,
          immediate. = TRUE
        )
      writeLines(lines, con = list_conn)
      close(list_conn)
      rm(lines, list_conn)
    },
    error=function(cond) {
      message("Could not list the bundle content!")
      message(cond)
      stop()
    }
  )

  if (BUNDLE_ONLY) {
    # Store the bundle in the log directory by default or BUNDLE_DIR when set.
    tryCatch({
        bundle_store_path <- path(ifelse(is.null(BUNDLE_DIR), log_dir, BUNDLE_DIR), timestamped_bundle_name)
        file_move(tmp_bundle_path, bundle_store_path)
        message(str_glue("Storing the bundle at {bundle_store_path}"))
        rm(bundle_store_path, tmp_bundle_path)
      },
      error=function(cond) {
        message("Could not store bundle!")
        message(cond)
        stop()
      }
    )
    # Store the bundle contents list in the log directory.
    tryCatch({
        bundle_list_store_path <- path(log_dir, timestamped_bundle_list_name)
        file_move(tmp_bundle_list_path, bundle_list_store_path)
        rm(bundle_list_store_path, tmp_bundle_list_path)
      },
      error=function(cond) {
        message("Could not store bundle contents list file!")
        message(cond)
        stop()
      }
    )
    # Store the configuration file in the log directory.
    tryCatch({
        config_store_path <- path(log_dir, timestamped_config_name)
        file_move(tmp_config_path, config_store_path)
        rm(config_store_path, tmp_config_path)
      },
      error=function(cond) {
        message("Could not store configuration file!")
        message(cond)
        stop()
      }
    )
    q(save = "no")
  } else {
    # Point the to-be-submitted bundle
    bundle_path <- tmp_bundle_path
  }
}

# ---- Define submission helper functions ----

# Delete a file if it exists
delete_if_exists <- function(dir_path, file_name) {
  file_path <- path(dir_path, file_name)
  if (file_exists(file_path)) file_delete(file_path)
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
  rm(i)
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
  # Clear text displayed on current line and reset cursor to start of line
  # provided that CLEAR_LINES has been configured to be TRUE. Otherwise,
  # issue a line feed to move on to the start of the next line.
  clear_line <- function() {
    if (CLEAR_LINES)
      cat("\r                                                                     \r")
    else
      cat("\n")
  }

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
    match <- str_match(str_subset(outerr, regexp), regexp)
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

# Get the return values of job log files, or NA when a job did not terminate normally or the log file is absent.
get_return_values <- function(log_file_paths) {
  return_values <- rep(NA, length(log_file_paths))
  return_value_regexp <- "\\(1\\) Normal termination \\(return value (\\d+)\\)"
  for (i in seq_along(log_file_paths)) {
    tryCatch({
        loglines <- suppressWarnings(readLines(log_file_paths[[i]]))
        return_value <- as.integer(str_match(tail(str_subset(loglines, return_value_regexp), 1), return_value_regexp)[2])
        return_values[[i]] <- return_value
      },
      error=function(cond) {
        # NA already set for entry
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

# Tests for all JOBS whether output files exist and are not empty.
# Empty files are deleted.
#
# dir: directory containing the files.
# output_file_name_template: str_glue() template, can use job variable as well as variables defined in the calling context.
# warn: if TRUE, generate warnings when output files are absent or empty.
# Warnings are generated when files are absent or empty.
#
# The boolean return value is TRUE when all files exist and are not empty.
all_exist_and_not_empty <- function(dir, output_file_name_template, warn=TRUE) {
  absentees <- c()
  empties <- c()
  for (job in JOBS) {
    paths <- path(dir, str_glue(output_file_name_template))
    absent <- !file_exists(paths)
    absentees <- c(absentees, any(absent))
    empty <- !absent & (file_size(paths) == 0)
    empties <- c(empties, any(empty))
    file_delete(paths[empty])
  }
  if (warn && any(absentees)) {
    warning(str_glue("Some output files were not returned for job(s) {summarize_jobs(JOBS[absentees])}!"), call.=FALSE)
  }
  if (warn && any(empties)) {
    warning(str_glue("Empty output files resulting from job(s) {summarize_jobs(JOBS[empties])}! These empty files were deleted."), call.=FALSE)
  }
  return(!(any(absentees) || any(empties)))
}

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
rm(selected_by)

# ---- Seed available execution points with the bundle ----

# Lock submission or wait for submission lock to disappear.
# Use a lock file in the parent temporary directory available to all R sessions.
# This prevents parallel submissions from causing unpredicatable increments to
# the cluster sequence number.
lock_file <- path(dirname(tempdir()), "Condor_run_R_submission.lock")
while(file_exists(lock_file)) {
  message(str_glue("Submission lock file {lock_file} exists, another submission must be ongoing."))
  message("Waiting for the submission lock file to disappear...")
  Sys.sleep(30)
}
file_create(lock_file)

# Use a finalizer to ensure deletion of the lock file on exit or gc()
lock <- new.env()
invisible(reg.finalizer(lock, function(lock) {
  file_delete(lock_file)
}, onexit=TRUE))

# Get username in a way that works on MacOS, Linux, and Windows.
#
# The username does not affect how jobs run. It is only used to
# divide the execution-point-side bundle cache directory into
# per-user subdirectories where bundles are placed. This makes
# troubleshooting on the EP side a bit easier.
username <- Sys.getenv("USERNAME")
if (username == "") username <- Sys.getenv("USER")
if (username == "") stop("Cannot determine the username!")

# Apply settings to  template and write batch file / shell script that launches jobs on the execution point
seed_bat <- path(tempdir(), str_glue("_seed.bat"))
bat_conn<-file(seed_bat, open="wt")
writeLines(unlist(lapply(SEED_BAT_TEMPLATE, str_glue)), bat_conn)
close(bat_conn)
rm(bat_conn)

# Try to seed each available execution point with the bundle by submitting seed jobs.
# Caching and automated bundle cleanup is assumed to be active on execute points, see ticket:
# https://mis.iiasa.ac.at/portal/page/portal/IIASA/Content/TicketS/Ticket?defpar=1%26pWFLType=24%26pItemKey=103034818402942720
cluster_regexp <- "submitted to cluster (\\d+)[.]$"
clusters <- c()
hostnames <- c()
for (hostdom in hostdoms) {

  hostname <- str_extract(hostdom, "^[^.]*")
  hostnames <- c(hostnames, hostname)
  cat(str_glue("Starting transfer of bundle to {hostname}."), sep="\n")

  # Apply settings to seed job template and write the .job file to use for submission
  seed_job_file <- path(log_dir, str_glue("_seed_{hostname}.job"))
  seed_job_conn<-file(seed_job_file, open="wt")
  seed_job_lines <- unlist(lapply(SEED_JOB_TEMPLATE, str_glue))
  for (s in names(SEED_JOB_OVERRIDES)) {
    ov <- str_starts(seed_job_lines, s)
    if (!any(ov)) {
      stop(str_glue("Could not apply SEED_JOB_OVERRIDES! No line in job template starting with '{s}'."))
    }
    seed_job_lines[ov] <- str_glue(SEED_JOB_OVERRIDES[[s]])
    rm(ov)
  }
  writeLines(seed_job_lines, seed_job_conn)
  close(seed_job_conn)
  rm(seed_job_conn, seed_job_lines, s)

  # Try to submit the seed job to the current execute point
  tries_left <- 2
  while (tries_left > 0) {
    tries_left <- tries_left - 1

    # Delete any job output left over from an aborted prior run or previous try
    delete_if_exists(log_dir, str_glue("_seed_{hostname}.log"))
    delete_if_exists(log_dir, str_glue("_seed_{hostname}.out"))
    delete_if_exists(log_dir, str_glue("_seed_{hostname}.err"))

    outerr <- suppressWarnings(system2("condor_submit", args=seed_job_file, stdout=TRUE, stderr=TRUE))
    if (!is.null(attr(outerr, "status")) && attr(outerr, "status") != 0) {
      message(str_glue("Invoking condor_submit for transfer of bundle to execute point '{hostname}' failed:"))
      message(str_glue("{outerr}"))
      if (tries_left > 0) {
        message("Retrying...")
        # Wait a bit to give transient error conditions time to disappear
        Sys.sleep(10)
      } else {
        message(str_glue("No retries left, giving up on execute point '{hostname}'."))
      }
    } else {
      # Seed job submitted, extract the cluster number
      tries_left <- 0
      cluster <- as.integer(str_match(tail(str_subset(outerr, cluster_regexp), 1), cluster_regexp)[2])
      if (is.na(cluster)) {
        stop("Cannot extract cluster number from condor_submit output!")
      }
      clusters <- c(clusters, cluster)
      rm(cluster)
    }
  }
  rm(hostname, tries_left, seed_job_file)
}

# Stop when none of the condor_submit invocations returned a cluster number
if (length(clusters) == 0) {
  stop("No seed jobs could be submitted!")
}

# Predict the cluster number for the actual run from the highest extracted cluster number
predicted_cluster <- max(clusters) + 1

# Wait until seed jobs complete
cat("Waiting for bundle seeding to complete...\n")
monitor(clusters)
rm(clusters)

# Check if any seed jobs produced .log files
if (!any(file_exists(path(log_dir, str_glue("_seed_{hostnames}.log"))))) {
  message("None of the seed jobs produced a .log file!")
  stop(str_glue("Aborting, see https://github.com/iiasa/Condor_run_R/blob/master/troubleshooting.md#seeding-fails-or-jobs-go-on-hold-without-producing-matching-log-files for possible solutions."))
}

# Determine which seed jobs failed
return_values <- get_return_values(path(log_dir, str_glue("_seed_{hostnames}.log")))
err_file_sizes <-  file_size(path(log_dir, str_glue("_seed_{hostnames}.err")))
err_file_sizes[is.na(err_file_sizes)] <- 0 # consider absent .err files to be zero-length
failed_seeds <- is.na(return_values) | return_values != 0 | err_file_sizes != 0
rm(return_values, err_file_sizes)

# Check whether seed jobs failed
if (all(failed_seeds)) {
  stop(str_glue("All seed jobs failed! For details, see the _seed_* files in {log_dir}. The likely cause is explained here: https://github.com/iiasa/Condor_run_R/blob/master/troubleshooting.md#all-seeding-jobs-remain-idle-and-then-abort-through-the-periodicremove-expression"))
}
if (any(failed_seeds)) {
  if (length(failed_seeds[failed_seeds == TRUE]) == 1) {
    warning(str_glue("A seed job failed, will refrain from scheduling jobs on the affected execution point {hostnames[failed_seeds]}."))
  } else {
    warning(str_glue("Seed jobs failed, will refrain from scheduling jobs on the affected execution points {str_c(hostnames[failed_seeds], collapse=', ')}."))
  }
  hostdoms <- hostdoms[!failed_seeds]
  hostnames <- hostnames[!failed_seeds]
}
rm(failed_seeds)

# Delete seeding artifacts of normally terminated seed jobs unless everything is to be retained
if (RETAIN_SEED_ARTIFACTS) {
  file_move(dir_ls(tempdir(), regexp="_seed_.*[.]job"), log_dir)
  file_move(seed_bat, log_dir)
} else {
  file_delete(seed_bat)
  for (hostname in hostnames) {
    delete_if_exists(log_dir, str_glue("_seed_{hostname}.job"))
    delete_if_exists(log_dir, str_glue("_seed_{hostname}.log"))
    delete_if_exists(log_dir, str_glue("_seed_{hostname}.out"))
    delete_if_exists(log_dir, str_glue("_seed_{hostname}.err"))
  }
  rm(hostname)
}
rm(seed_bat)

# Report that seeding is done
if (length(hostnames) == 1) {
  cat(str_glue("Seeding done: execution point {hostnames} has received and cached the bundle.\n"))
} else {
  cat(str_glue("Seeding done: execution points {str_c(hostnames, collapse=', ')} have received and cached the bundle.\n"))
}
cat("\n")
rm(hostnames)

# ---- Retain artifacts in log directory ----

# When the bundle is located in tempdir(), retain it if so requested,
# renaming it with the submission sequence cluster numbers.
# Otherwise delete it early: though tempdir() will be deleted when the session
# ends, but freeing potentially significant resources early can help.
if (exists("tmp_bundle_path") && file_exists(tmp_bundle_path)) {
  if (RETAIN_BUNDLE) {
    tryCatch({
        bundle_log_path <- path(log_dir, str_glue("_bundle_{predicted_cluster}.7z"))
        file_move(tmp_bundle_path, bundle_log_path)
        message(str_glue("Retaining the bundle at {bundle_log_path}"))
        rm(bundle_log_path)
      },
      error=function(cond) {
        message("Could not retain bundle!")
        message(cond)
        stop()
      }
    )
  } else {
    file_delete(tmp_bundle_path)
  }
  rm(tmp_bundle_path)
}

# When the bundle contents list is located in tempdir(), store it in the log directory,
# renaming it with the submission sequence cluster number.
if (exists("tmp_bundle_list_path") && file_exists(tmp_bundle_list_path)) {
  tryCatch({
      file_move(tmp_bundle_list_path, path(log_dir, str_glue("_bundle_{predicted_cluster}_contents.txt")))
    },
    error=function(cond) {
      message("Could not store bundle contents list file!")
      message(cond)
      stop()
    }
  )
  rm(tmp_bundle_list_path)
}

# When the configuration file is located in tempdir(), store it in the log directory,
# renaming it with the submission sequence cluster number.
if (exists("tmp_config_path") && file_exists(tmp_config_path)) {
  tryCatch({
      config_log_path <- path(log_dir, str_glue("_config_{predicted_cluster}.R"))
      file_move(tmp_config_path, config_log_path)
    },
    error=function(cond) {
      message(str_glue("Could not store the configuration file!"))
      message(cond)
      stop()
    }
  )
  rm(tmp_config_path)
}

# ---- Prepare files for run ----

# Apply settings to BAT_TEMPLATE and write the batch file / shell script to launch jobs with
bat_path <- path(log_dir, str_glue("_launch_{predicted_cluster}.bat"))
bat_conn<-file(bat_path, open="wt")
writeLines(unlist(lapply(BAT_TEMPLATE, str_glue)), bat_conn)
close(bat_conn)
rm(bat_conn)

# Generate G00 and GDX output file remapping prefixes for keeping output files of different runs separate.
# Separating the output files of different jobs within a run is handled in the job template.
g00_prefix <- ifelse(GET_G00_OUTPUT, str_glue("{tools::file_path_sans_ext(G00_OUTPUT_FILE)}_{predicted_cluster}"), "")
gdx_prefix <- ifelse(GET_GDX_OUTPUT, str_glue("{tools::file_path_sans_ext(GDX_OUTPUT_FILE)}_{predicted_cluster}"), "")

# Apply settings to job template and write the .job file to use for submission
job_file <- path(log_dir, str_glue("_submit_{predicted_cluster}.job"))
job_conn<-file(job_file, open="wt")
job_lines <- unlist(lapply(JOB_TEMPLATE, str_glue))
for (s in names(JOB_OVERRIDES)) {
  ov <- str_starts(job_lines, s)
  if (!any(ov)) {
    stop(str_glue("Could not apply JOB_OVERRIDES! No line in job template starting with '{s}'."))
  }
  job_lines[ov] <- str_glue(JOB_OVERRIDES[[s]])
  rm(ov)
}
writeLines(job_lines, job_conn)
close(job_conn)
rm(job_conn, job_lines, s)

# ---- Submit the run and clean up temp files ----

outerr <- system2("condor_submit", args=job_file, stdout=TRUE, stderr=TRUE)
cat(outerr, sep="\n")
if (!is.null(attr(outerr, "status")) && attr(outerr, "status") != 0) {
  stop("Submission of Condor run failed!")
}
cluster <- as.integer(str_match(tail(str_subset(outerr, cluster_regexp), 1), cluster_regexp)[2])
if (is.na(cluster)) {
  stop("Cannot extract cluster number from condor_submit output!")
}
if (cluster != predicted_cluster) {
  # system2("condor_rm", args=str_glue("{cluster}")) # should do this, but it does not work due to some weird Condor/R/Windows bug.
  stop(str_glue("Submission cluster number {cluster} not equal to prediction {predicted_cluster}! You probably submitted something else via Condor while this submission was ongoing, causing the cluster number (sequence count of your submissions) to increment. As a result, log files have been named with a wrong cluster number.\n\nPlease do not submit additional Condor jobs until after a submission has completed. Note that this does not mean that you have to wait for the run to complete before submitting further runs, just wait for the submission to make it to the point where the execution points have been handed the jobs. Please try again.\n\nYou should first remove the run's jobs with: condor_rm {cluster}."))
}

# Submission successful, delete the submission lock file by triggering its deletion finalizer
rm(lock)
invisible(gc())
rm(lock_file)

# Report successful submission to the user
message(str_glue('Run "{LABEL}" with cluster number {cluster} has been submitted.'))
message(str_glue("Run log directory: {path_abs(log_dir)}"))

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
  all_exist_and_not_empty(log_dir, "_{PREFIX}_{cluster}.{job}.err", warn=FALSE)
  all_exist_and_not_empty(log_dir, "{PREFIX}_{cluster}.{job}.lst")
  if (GET_G00_OUTPUT) {
    g00s_complete <- all_exist_and_not_empty(G00_OUTPUT_DIR_SUBMIT, "{g00_prefix}.{job}.g00")
  }
  if (GET_GDX_OUTPUT) {
    gdxs_complete <- all_exist_and_not_empty(GDX_OUTPUT_DIR_SUBMIT, '{gdx_prefix}.{sprintf("%06d", job)}.gdx')
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
        str_subset(job_lines, memory_use_regexp), 1
      ), memory_use_regexp)[2])
    if (!is.na(memory_use) && memory_use > max_memory_use) {
      max_memory_use <- memory_use
      max_memory_job <- job
    }
    disk_use <-
      as.double(str_match(tail(
        str_subset(job_lines, disk_use_regexp), 1
      ), disk_use_regexp)[2:3])
    if (!any(is.na(disk_use)) && disk_use[1] > max_disk_use) {
      max_disk_use <- disk_use[1]
      disk_request <- disk_use[2]
      max_disk_job <- job
    }
    cpu_use <-
      as.double(str_match(tail(
        str_subset(job_lines, cpus_use_regexp), 1
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

  # Merge returned GDX files (implies GET_GDX_OUTPUT and WAIT_FOR_RUN_COMPLETION)
  if (MERGE_GDX_OUTPUT) {
    if (!gdxs_complete) {
      warning("MERGE_GDX_OUTPUT was set but not honored: no complete set of GDX files was returned.")
    } else {
      cat("Merging the returned GDX files...\n")
      prior_wd <- getwd()
      setwd(GDX_OUTPUT_DIR_SUBMIT)
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
      merge_args <- c(merge_args, str_glue("{gdx_prefix}.*.gdx"))
      merge_args <- c(merge_args, str_glue("output={gdx_prefix}_merged.gdx"))
      # Invoke GDX merge
      error_code <- system2("gdxmerge", args=merge_args)
      setwd(prior_wd)
      if (error_code > 0) stop("Merging failed!")
      # Delete merged GDX files if so requested
      if (REMOVE_MERGED_GDX_FILES) {
        for (job in JOBS) {
          file_delete(path(GDX_OUTPUT_DIR_SUBMIT, str_glue('{gdx_prefix}.{sprintf("%06d", job)}.gdx')))
        }
      }
    }
  }
  # Make a bit of noise to notify the user of completion (works with Rscript but not from RStudio)
  alarm()
  Sys.sleep(1)
  alarm()
} else {
  cat(str_glue("You can monitor progress of the run with: condor_q {cluster}."), sep="\n")
  if (GET_G00_OUTPUT) {
    cat(str_glue("After the run completes, you can find the G00 results at: {G00_OUTPUT_DIR_SUBMIT}/{g00_prefix}.*.g00"), sep="\n")
  }
  if (GET_GDX_OUTPUT) {
    cat(str_glue("After the run completes, you can find the GDX results at: {GDX_OUTPUT_DIR_SUBMIT}/{gdx_prefix}.*.gdx"), sep="\n")
  }
}
