#!/usr/bin/env Rscript
# Submit a GLOBIOM Limpopo run via Condor.
#
# Usage: invoke this script via Rscript, or, on Linux/MacOS, you can
# invoke the script directly if its execute flag is set. The working
# directory must either be the GLOBIOM R or Model subdirectory. To
# use non-default config settings, pass a relative path to a
# configuration file as an argument to this script. See below for the
# format of the configuration file.
#
# Based on: GLOBIOM-limpopo scripts by David Leclere
#
# Author: Albert Brouwer
#
# Todo:
# * Pre-submit the bundle to each limpopo
# * Merging
# * Check termination status of jobs, flag aborted / evicted ones
# * Make include and exclude patterns configurable
# * Add GAMS .lst output to .out files

rm(list=ls())

# Default run config settings. You can replace these via a run config
# file passed as a first argument to this script. Lines with settings
# like the ones just below can be used in the config file. No settings
# may be omitted from the config file. Use / as path separator.
EXPERIMENT = "test"
NUMBER_OF_JOBS = 5
REQUEST_MEMORY = 5000 # MB
REQUEST_CPUS = 1
SCENARIO_GMS_FILE = "6_scenarios_limpopo.gms"
RESTART_G00_FILE = "a4_limp.g00"
GAMS_VERSION = "24.4" # must be installed on all limpopo machines
GAMS_ARGUMENTS = "//nsim='%3' //ssp=SSP2 //scen_type=feedback //price_exo=0 //dem_fix=0 //irri_dem=1 //water_bio=0 //yes_output=1 cerr=5 pw 100"
ADDITIONAL_INPUT_FILES = "" # comma-separated, leave empty if none
GET_G00_OUTPUT = FALSE
GET_GDX_OUTPUT = TRUE
GDX_OUTPUT_FORMAT_DEF_GMS_FILE = "outputs_limpopo.gms"
MERGE_GDX_OUTPUT = TRUE

# Collect the names and types of the config settings
config_names <- ls()
config_types <- lapply(lapply(config_names, get), typeof)

# Required packages
library(stringr)

# Get the platform file separator: .Platform$file.sep is set to / on Windows
fsep <- ifelse(str_detect(tempdir(), fixed("\\") ), "\\", ".Platform$file.sep")

# Provide platform-specific and R-generic paths to the submission bundle
bundle <- "globiom_bundle.7z"
bundle_platform_path <- file.path(tempdir(), bundle, fsep=fsep)
bundle_path <- str_replace_all(bundle_platform_path, fixed("\\"), .Platform$file.sep)
# if (file.exists(bundle_path)) stop(str_glue("{bundle_path} already exists! Is there another submission ongoing?"))

# Determine the path to the Model directory from the working directory
working_dir <- getwd()
if (basename(working_dir) == 'R') {
  model_dir <- file.path(working_dir, "..", "Model")
  if (!dir.exists(model_dir)) stop(str_glue("Model directory not found! Expected location: {model_dir}!"))
} else if (basename(working_dir) == 'Model') {
  model_dir <- working_dir
} else {
  stop("Working directory should be either the GLOBIOM R of Model subdirectory!")
}

# Make sure that the Model/Condor directory exists
condor_dir = file.path(model_dir, "Condor")
if (!dir.exists(condor_dir)) stop(str_glue("GLOBIOM Model/Condor directory not found!"))

# Read config file if specified via an argument, check presence and types.
args <- c("config")
#args <- commandArgs(trailingOnly=TRUE)
if (length(args) == 0) {
  warning("No config file argument supplied, using default run settings.")
} else if (length(args) == 1) {
  rm(list=config_names)
  source(args[1], local=TRUE, echo=FALSE)
  for (i in seq_along(config_names))  {
    name <- config_names[i]
    if (!exists(name)) stop(str_glue("{name} not set in {args[1]}!"))
    type <- typeof(get(name))
    if (type != config_types[[i]]) stop(str_glue("{name} set to wrong type in {args[1]}, type should be {config_types[[i]]}"))
  }
} else {
  stop("Multiple arguments provided! Expecting at most a single config file argument.")
}

# Check and massage specific config settings
if (str_detect(EXPERIMENT, fixed(" "))) stop(str_glue("Configured EXPERIMENT name has forbidden space character(s)!"))
if (str_sub(SCENARIO_GMS_FILE, -4) != ".gms") stop(str_glue("Configured SCENARIO_GMS_FILE has no .gms extension!"))
if (str_detect(SCENARIO_GMS_FILE, fixed(" "))) stop(str_glue("Configured SCENARIO_GMS_FILE has forbidden space character(s)!"))
prefix = str_glue(str_sub(SCENARIO_GMS_FILE, 1, -5), "-", EXPERIMENT)
scenario_gms_path = file.path(model_dir, SCENARIO_GMS_FILE)
if (!(file.exists(scenario_gms_path))) stop(str_glue('Configured SCENARIO_GMS_FILE "{SCENARIO_GMS_FILE}" does not exist relative to the Model directory!'))
if (str_sub(RESTART_G00_FILE, -4) != ".g00") stop(str_glue("Configured RESTART_G00_FILE has no .g00 extension!"))
if (str_detect(RESTART_G00_FILE, fixed(" "))) stop(str_glue("Configured RESTART_G00_FILE has forbidden space character(s)!"))
restart_g00_path = file.path(model_dir, "t", RESTART_G00_FILE)
if (!(file.exists(restart_g00_path))) stop(str_glue('Configured RESTART_G00_FILE "{RESTART_G00_FILE}" does not exist relative to the Model/t directory!'))
version_match = str_match(GAMS_VERSION, "^(\\d+)[.]\\d+$")
if (is.na(version_match[1])) stop(str_glue('Invalid GAMS_VERSION "{GAMS_VERSION}"! Format must be "<major>.<minor>".'))
if (as.integer(version_match[2]) < 24) stop(str_glue('Invalid GAMS_VERSION "{GAMS_VERSION}"! Version too old for Limpopo'))
if (!str_detect(GAMS_ARGUMENTS, fixed("%3"))) stop("Configured GAMS_ARGUMENTS lack a %3 batch file argument expansion that must be used for passing the job/process number with which the scenario variant can be selected per-job.")
if (ADDITIONAL_INPUT_FILES != "") {
  for (file in str_split(ADDITIONAL_INPUT_FILES, ",")[[1]]) {
    file = str_trim(file)
    if (!(file.exists(file.path(model_dir, file)))) stop(str_glue('Misconfigured ADDITIONAL_INPUT_FILES: "{file}" does not exist relative to the Model directory!'))
  }
}
if (str_sub(GDX_OUTPUT_FORMAT_DEF_GMS_FILE, -4) != ".gms") stop(str_glue("Configured GDX_OUTPUT_FORMAT_DEF_GMS_FILE has no .gms extension!"))
if (str_detect(GDX_OUTPUT_FORMAT_DEF_GMS_FILE, fixed(" "))) stop(str_glue("Configured GDX_OUTPUT_FORMAT_DEF_GMS_FILE has forbidden space character(s)!"))
gdx_output_format_def_gms_path = file.path(model_dir, GDX_OUTPUT_FORMAT_DEF_GMS_FILE)
if (!(file.exists(gdx_output_format_def_gms_path))) stop(str_glue('Configured GDX_OUTPUT_FORMAT_DEF_GMS_FILE "{GDX_OUTPUT_FORMAT_DEF_GMS_FILE}" does not exist relative to the Model directory!'))
if (!(GET_G00_OUTPUT || GET_GDX_OUTPUT)) stop("Neither GET_G00_OUTPUT nor GET_GDX_OUTPUT are TRUE! A run without output is pointless.")
if (MERGE_GDX_OUTPUT && !GET_GDX_OUTPUT) stop("Cannot MERGE_GDX_OUTPUT without first doing GET_GDX_OUTPUT!")
if (MERGE_GDX_OUTPUT && !WAIT_FOR_RUN_COMPLETION) stop("Cannot MERGE_GDX_OUTPUT without first doing WAIT_FOR_RUN_COMPLETION!")

# Ensure that the experiment directory to hold the results exists
experiment_dir <- file.path(condor_dir, EXPERIMENT)
if (!dir.exists(experiment_dir)) dir.create(experiment_dir)

# Copy the configuration to the experiment directory for reference
config_file <- file.path(experiment_dir, str_glue("_config_{EXPERIMENT}.txt"))
if (length(args) > 0) {
  if (!file.copy(args[1], config_file, overwrite=TRUE)) {
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

# Copy the scenario GAMS script to the experiment directory
if (!file.copy(file.path(model_dir, SCENARIO_GMS_FILE), file.path(experiment_dir, str_glue("{prefix}.gms")), overwrite=TRUE)) {
  stop(str_glue("Cannot copy the configured SCENARIO_GMS_FILE file to {experiment_dir}")) 
}

# Define the Condor .job file template
job_template <- c(
  "# -- Job executable filename: what is to be done",
  "Executable = Condor/{EXPERIMENT}/_globiom_{EXPERIMENT}.bat",
  "# -- Arguments to be passed to the executable",
  "#    Here: the sequential process number, from 0 to the number of 'queued' executions (N in 'Queue N' instruction at the bottom of this file)",
  "#          In this case, _start. bat automatically :",
  "#          - identifies the number of scenarios, modifies above-mentioned 'N' value in present script",
  "#          - generate scenario specific 6_scenarios_[0..N-1] files with the correct scenario",
  "#          Then each queued execution of _globiom.bat uses current process number passed as argument to:",
  "#          - switch between scenario specific 6_ files",
  "#          - index scenario specific output gdx files",
  "Arguments = {prefix} {RESTART_G00_FILE} $(Process)",
  "",
  "# -- Basic 'Universe' of Condor",
  "#  not requiring special Condor libraries",
  "#  but restricted in possibilities (no parallel processing, checkpointing, etc...)",
  "Universe = vanilla",
  "",
  "# -- Naming of Condor output, log and error output files",
  "output = Condor/{EXPERIMENT}/_globiom_{EXPERIMENT}_$(Cluster).$(Process).out",
  "log = Condor/{EXPERIMENT}/_globiom_{EXPERIMENT}_$(Cluster).$(Process).log",
  "error = Condor/{EXPERIMENT}/_globiom_{EXPERIMENT}_$(Cluster).$(Process).err",
  "# -- Allow above mentioned output files to be updated live as the job is running on limpopo",
  "stream_input = True",
  "stream_output = True",
  "stream_error = True",
  "",
  "# -- Machine requirements for your job. Here:",
  "#    any of these architectures AND",
  "#    any of these OSs AND",
  "#    a specific tag that only limpopo has (you'll never go out of limpopo with this line)",
  "Requirements = \\",
  '  ( (Arch =="INTEL")||(Arch =="X86_64") ) && \\',
  '  ( (OpSys == "WINDOWS")||(OpSys == "WINNT61") ) && \\',
  "  ( GLOBIOM =?= True )",
  '#  && ( ( TARGET.Machine == "limpopo1.iiasa.ac.at" ) || ( TARGET.Machine == "limpopo2.iiasa.ac.at" ) )',
  "#    minimum number of CPUs and minimum memory",
  "request_memory = {REQUEST_MEMORY}",
  "request_cpus = {REQUEST_CPUS}",
  "",
  "# -- Identifies you as part of the group allowed to use ESM cluster",
  '+IIASAGroup = "ESM"',
  "",
  "",
  "# -- Manage rights in the temp folder you'll be running into",
  "run_as_owner = True",
  "# -- Indicate whether/when/what files should be copied to/from the temporary folder",
  "should_transfer_files = YES",
  "when_to_transfer_output = ON_EXIT",
  'transfer_input_files = {bundle_path}, 7za.exe, Condor/{EXPERIMENT}/{prefix}.gms{ifelse(ADDITIONAL_INPUT_FILES!="", ", ", "")}{ADDITIONAL_INPUT_FILES}',
  'transfer_output_files = {ifelse(GET_G00_OUTPUT, "t/a6_out.g00", "")}{ifelse(GET_G00_OUTPUT&&GET_GDX_OUTPUT, ", ", "")}{ifelse(GET_GDX_OUTPUT, "gdx/output.gdx", "")}',
  'transfer_output_remaps = "{ifelse(GET_G00_OUTPUT, str_glue("a6_out.g00 = t/a6_{EXPERIMENT}-$(Process).g00"), "")}{ifelse(GET_G00_OUTPUT&&GET_GDX_OUTPUT, "; ", "")}{ifelse(GET_GDX_OUTPUT, str_glue("output.gdx = gdx/output_{EXPERIMENT}-$(Process).gdx"), "")}"',
  "",
  "# -- Send an email when:",
  "# Always, Complete, Error, Never",
  "Notification = Error",
  "",
  "# -- Submit N jobs",
  "Queue {NUMBER_OF_JOBS}"
)

# Apply settings to job template and write the .job file to use for submission
job_file <- file.path(experiment_dir, str_glue("_globiom_{EXPERIMENT}.job"))
job_conn<-file(job_file, open="wt")
writeLines(unlist(lapply(job_template, str_glue)), job_conn)
close(job_conn)

# Define the template for the .bat file that specifies what should be run on the limpopo side for each job
bat_template <- c(
  'grep "^Machine = " .machine.ad',
  "echo _CONDOR_SLOT=%_CONDOR_SLOT%",
  "7za.exe x {bundle} -y > NUL",
  "mkdir gdx 2>NUL",
  "C:\\GAMS\\win64\\{GAMS_VERSION}\\gams.exe %1.gms -r .\\t\\%2 -s .\\t\\a6_out {GAMS_ARGUMENTS}"
)

# Apply settings to bat template and write the .bat file
bat_file <- file.path(experiment_dir, str_glue("_globiom_{EXPERIMENT}.bat"))
bat_conn<-file(bat_file, open="wt")
writeLines(unlist(lapply(bat_template, str_glue)), bat_conn)
close(bat_conn)

# Set working directory to the model directory and bundle the model
setwd(model_dir)
status <- system2("7za.exe", args=c("a",
  "-mx=1",
  "-x!*.exe",
  "-x!*.zip",
  str_glue("-x!{SCENARIO_GMS_FILE}"),
  "-x!*.~*",
  "-x!test*.gdx",
  "-xr!225*",
  "-x!*.lst",
  "-x!*.log",
  "-x!*.lxi",
  "-xr!Condor",
  "-xr!Demand",
  "-xr!gdx",
  "-xr!graphs",
  "-xr!output",
  "-xr!t",
  "-xr!trade",
  "-xr!SIMBIOM",
  "-ir!finaldata",
  str_glue("{bundle_platform_path}"),
  "*"
))
if (status != 0) stop("zipping model failed!")
status <- system2("7za.exe", args=c("a",
  str_glue("{bundle_platform_path}"),
  str_glue("t{fsep}{RESTART_G00_FILE}") # t directory is excluded, make an exception
))
if (status != 0) stop("zipping model failed!")

# Submit the run
outerr <- system2("condor_submit", args=str_glue("Condor{fsep}{EXPERIMENT}{fsep}_globiom_{EXPERIMENT}.job"), stdout=TRUE, stderr=TRUE)
cat(outerr, sep="\n")
if (!is.null(attr(outerr, "status")) && attr(outerr, "status") != 0) {
  stop("submission of Condor run failed!")
}
cluster <- as.integer(str_match(outerr[-1], "cluster (\\d+)[.]$")[2])

# Restore the working directory
setwd(working_dir)

# Wait for the run to complete
if (WAIT_FOR_RUN_COMPLETION) {
  cat("Waiting for run to complete...\n")
  for (job in 0:(NUMBER_OF_JOBS-1)) {
    log_file = file.path(experiment_dir, str_glue("_globiom_{EXPERIMENT}_{cluster}.{job}.log"))
    log_platform_file <- str_replace_all(log_file, fixed(.Platform$file.sep), fsep)
    system2("condor_wait", args=log_platform_file, stdout=NULL)
  }
  cat("Done.\n")
}

# Remove the bundle
file.remove(bundle_path)
