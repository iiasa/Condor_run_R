#!/usr/bin/env Rscript
# Submit a GLOBIOM Limpopo run via Condor.
#
# Usage: invoke this script via Rscript, or, on Linux/MacOS, you can
# invoke the script directly if its execute flag is set. The working
# directory must be the GLOBIOM Model subdirectory. To use non-default
# config settings, pass a relative path to a configuration file as an
# argument to this script. The format of the configuration file is
# shown in the "Default run config settings section" below.
#
# Based on: GLOBIOM-limpopo scripts by David Leclere
#
# Author: Albert Brouwer
#
# Todo:
# - Test access right on non-me-user created bundle subdirectory (through %USERNAME%)
# - Seggregate reference files in experiment_dir by cluster
#   * or have per-cluster subdirectories?
# - Seggregate cached bundles of different runs
# - Clean up cached bundles.
# - Should all the output really go into the gdx directory?
# - Check termination status of jobs, flag aborted / evicted ones (capture condor_wait -status output)
# - Make include and exclude patterns configurable
# - Handle jobs put on hold on account of error instead of waiting indefinately.
# - Get reasonable emails through notification option somehow
# - More error handling for system2 commands
# - Generate merging batch file as an alternative when not waiting for completion
# - Collect historical use using condor_stats
# - check that restart file is compatible with GAMS_VERSION
# - Do merge in process instead of alphabetical order

rm(list=ls())

# ---- Default run config settings ----

# You can replace these via a run config # file passed as a first argument
# to this script. Lines with settings like the ones just below can be used
# in the config file. No settings may be omitted from the config file.
# Use / as path separator.
EXPERIMENT = "test"
NUMBER_OF_JOBS = 5
REQUEST_MEMORY = 5000 # memory in MB to reserve for each job
REQUEST_CPUS = 1 # number of hardware threads to reserve for each job
SCENARIO_GMS_FILE = "6_scenarios_limpopo.gms"
RESTART_G00_FILE = "a4_limpopo.g00"
GAMS_VERSION = "24.4" # must be installed on all limpopo machines
GAMS_ARGUMENTS = "//nsim='%3' //ssp=SSP2 //scen_type=feedback //price_exo=0 //dem_fix=0 //irri_dem=1 //water_bio=0 //yes_output=1 cerr=5 pw 100"
ADDITIONAL_INPUT_FILES = "" # comma-separated, leave empty if none
GET_G00_OUTPUT = FALSE
GET_GDX_OUTPUT = TRUE
GDX_OUTPUT_FORMAT_DEF_GMS_FILE = "outputs_limpopo.gms"
MERGE_GDX_OUTPUT = TRUE
WAIT_FOR_RUN_COMPLETION = TRUE

# ---- Process run config settings ----

# Collect the names and types of the config settings
config_names <- ls()
config_types <- lapply(lapply(config_names, get), typeof)

# Required packages
library(stringr)

# Make sure that the working directory is the Model directory
model_dir <- getwd()
if (basename(model_dir) != 'Model') stop("Working directory should be the GLOBIOM Model subdirectory!")

# Read config file if specified via an argument, check presence and types.
args <- commandArgs(trailingOnly=TRUE)
#args = c("..\\R\\config")
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

# ---- Check status of limpopo servers ----

# Collect available limpopos
limpopos <- system2("condor_status", c("-compact", "-autoformat", "Machine", "-constraint", '"regexp(\\"^limpopo\\",machine)"'), stdout=TRUE)
if (!is.null(attr(limpopos, "status")) && attr(limpopos, "status") != 0) stop("Cannot get Condor pool status")

# Show limpopo status summary
error_code = system2("condor_status", args=c("-compact", "-constraint", '"regexp(\\"^limpopo\\",machine)"'))
if (error_code > 0) stop("Cannot show Condor pool status")
cat("\n")

# ---- Bundle the model ----

# Determine the platform file separator and the temp directory with R-default separators
temp_dir = tempdir()
fsep <- ifelse(str_detect(temp_dir, fixed("\\") ), "\\", ".Platform$file.sep") # Get the platform file separator: .Platform$file.sep is set to / on Windows
temp_dir <- str_replace_all(temp_dir, fixed(fsep), .Platform$file.sep)

# Set R-default and platform-specific paths to the submission bundle
bundle <- "globiom_bundle.7z"
bundle_path <- file.path(temp_dir, bundle)
bundle_platform_path <- str_replace_all(bundle_path, fixed(.Platform$file.sep), fsep)
if (file.exists(bundle_path)) stop(str_glue("{bundle_path} already exists! Is there another submission ongoing?"))

# Define a function to check and sanitize 7zip output
handle_7zip <- function(out) {
  if (!is.null(attr(out, "status")) && attr(out, "status") != 0) {
    cat(out, sep="\n")
    stop("7zip compression failed!")
  } 
  else {
    cat(out[grep("^Scanning the drive:", out)+1], sep="\n")
    cat(grep("^Archive size:", out, value=TRUE), sep="\n")
  }
}

cat("Compressing model files into submission bundle...\n")
handle_7zip(system2("7za.exe", stdout=TRUE, stderr=TRUE,
  args=c("a",
    "-mx1",
    "-bb0",
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
  )
))
cat("\n")

cat("Adding restart file to submission bundle...\n")
handle_7zip(system2("7za.exe", stdout=TRUE, stderr=TRUE,
  args=c("a",
    str_glue("{bundle_platform_path}"),
    str_glue("t{fsep}{RESTART_G00_FILE}") # t directory is excluded, make an exception
  )
))
cat("\n")

# Determine the bundle size in KiB
bundle_size <- as.integer(floor(file.info(bundle_path)$size/1024))

# ---- Seed available limpopos with the bundle ----

# Define the template for the .bat that caches the transferred bundle on the limpopo side
bat_template <- c(
  "@echo off",
  "set bundle_dir=e:\\condor\\bundles\\%USERNAME%",
  "if not exist %bundle_dir%\\ mkdir %bundle_dir% || exit /b %errorlevel%",
  "@echo on",
  "move /Y %1 %bundle_dir%"
) 

# Apply settings to bat template and write the .bat file
bat_file <- file.path(temp_dir, str_glue("_seed.bat"))
bat_conn<-file(bat_file, open="wt")
writeLines(unlist(lapply(bat_template, str_glue)), bat_conn)
close(bat_conn)

# Submit bundle to each available limpopo server
for (limpopo in limpopos) {

  hostname <- str_extract(limpopo, "^[^.]*")
  cat(str_glue("Starting transfer of bundle to {hostname}.\n"))

  # Define the Condor .job file template for bundle seeding
  job_template <- c(
    "executable = {temp_dir}/_seed.bat",
    "arguments = {bundle}",
    "universe = vanilla",
    "",
    "# -- Job log, output, and error files",
    "log = {temp_dir}/_seed_{hostname}.log",
    "output = {temp_dir}/_seed_{hostname}.out",
    "stream_output = True",
    "error = {temp_dir}/_seed_{hostname}.err",
    "stream_error = True",
    "",
    "requirements = \\",
    '  ( (Arch =="INTEL")||(Arch =="X86_64") ) && \\',
    '  ( (OpSys == "WINDOWS")||(OpSys == "WINNT61") ) && \\',
    "  ( GLOBIOM =?= True ) && \\",
    '  ( TARGET.Machine == "{limpopo}" )',
    "",
    "# -- We want to transfer even when all slots are taken",
    "request_memory = 0",
    "request_cpus = 0",
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

  err <- system2("condor_submit", args=str_glue("{job_file}"), stdout=FALSE, stderr=TRUE)
  cat(err, sep="\n")
  if (!is.null(attr(err, "status")) && attr(err, "status") != 0) {
    stop("Submission of bundle seed job failed!")
  }
}

# Wait until all limpopos are seeded with a bundle
cat("Waiting for bundle seeding to complete...\n")
for (limpopo in limpopos) {
  hostname <- str_extract(limpopo, "^[^.]*")
  log_file = file.path(temp_dir, str_glue("_seed_{hostname}.log"))
  system2("condor_wait", args=log_file, stdout=NULL)
}
cat("Seeding done: limpopo servers have received and cached the bundle.\n")
cat("\n")

# Remove the bundle locally
file.remove(bundle_path)

# ---- Prepare files for run ----

# Make sure that the Model/Condor directory exists
condor_dir = file.path(model_dir, "Condor")
if (!dir.exists(condor_dir)) stop(str_glue("GLOBIOM Model/Condor directory not found!"))

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

# Define the Condor .job file template for the run
job_template <- c(
  "executable = Condor/{EXPERIMENT}/_globiom_{EXPERIMENT}.bat",
  "arguments = {prefix} {RESTART_G00_FILE} $(Process)",
  "universe = vanilla",
  "",
  "# -- Job log, output, and error files",
  "log = Condor/{EXPERIMENT}/_globiom_{EXPERIMENT}_$(Cluster).$(Process).log",
  "output = Condor/{EXPERIMENT}/_globiom_{EXPERIMENT}_$(Cluster).$(Process).out",
  "stream_output = True",
  "error = Condor/{EXPERIMENT}/_globiom_{EXPERIMENT}_$(Cluster).$(Process).err",
  "stream_error = True",
  "",
  "requirements = \\",
  '  ( (Arch =="INTEL")||(Arch =="X86_64") ) && \\',
  '  ( (OpSys == "WINDOWS")||(OpSys == "WINNT61") ) && \\',
  "  ( GLOBIOM =?= True ) && \\",
  "  ( ( TARGET.Machine == \"{str_c(limpopos, collapse='\" ) || ( TARGET.Machine == \"')}\") )",
  "request_memory = {REQUEST_MEMORY}",
  "request_cpus = {REQUEST_CPUS}",     # Number of "CPUs" (hardware threads) to reserve for each job
  "",
  '+IIASAGroup = "ESM"', # Identifies you as part of the group allowed to use ESM cluster
  "run_as_owner = True", # Jobs will run as you, so you'll have access to H: and your own temp space
  "",
  "should_transfer_files = YES",
  "when_to_transfer_output = ON_EXIT",
  'transfer_input_files = 7za.exe, Condor/{EXPERIMENT}/{prefix}.gms{ifelse(ADDITIONAL_INPUT_FILES!="", ", ", "")}{ADDITIONAL_INPUT_FILES}',
  'transfer_output_files = {ifelse(GET_G00_OUTPUT, "t/a6_out.g00", "")}{ifelse(GET_G00_OUTPUT&&GET_GDX_OUTPUT, ", ", "")}{ifelse(GET_GDX_OUTPUT, "gdx/output.gdx", "")}',
  'transfer_output_remaps = "{ifelse(GET_G00_OUTPUT, str_glue("a6_out.g00 = t/a6_{EXPERIMENT}-$(Process).g00"), "")}{ifelse(GET_G00_OUTPUT&&GET_GDX_OUTPUT, "; ", "")}{ifelse(GET_GDX_OUTPUT, str_glue("output.gdx = gdx/output_{EXPERIMENT}_$(Cluster).$(Process).gdx"), "")}"',
  "",
  "notification = Error", # Per-job, so you'll get spammed setting it to Always or Complete. And Error does not seem to catch execution errors.
  "",
  "queue {NUMBER_OF_JOBS}"
)

# Apply settings to job template and write the .job file to use for submission
job_file <- file.path(experiment_dir, str_glue("_globiom_{EXPERIMENT}.job"))
job_conn<-file(job_file, open="wt")
writeLines(unlist(lapply(job_template, str_glue)), job_conn)
close(job_conn)

# Define the template for the .bat file that specifies what should be run on the limpopo side for each job
bat_template <- c(
  "@echo off",
  'grep "^Machine = " .machine.ad || exit /b %errorlevel%',
  "echo _CONDOR_SLOT = %_CONDOR_SLOT%",
  "mkdir gdx 2>NUL || exit /b %errorlevel%",
  "@echo on",
  "7za.exe x e:\\condor\\bundles\\{bundle} -y > NUL || exit /b %errorlevel%",
  "C:\\GAMS\\win64\\{GAMS_VERSION}\\gams.exe %1.gms -r .\\t\\%2 -s .\\t\\a6_out {GAMS_ARGUMENTS}",
  "set gams_errorlevel=%errorlevel%",
  "@echo off",
  "cat %1.lst",
  "if %gams_errorlevel% neq 0 (",
  "  echo ERROR: GAMS failed with error code %gams_errorlevel%",
  "  echo See https://www.gams.com/latest/docs/UG_GAMSReturnCodes.html#UG_GAMSReturnCodes_ListOfErrorCodes",
  ")",
  "sleep 1,", # Make it less likely that the .out file is truncated.
  "exit /b %gams_errorlevel%"
)

# Apply settings to bat template and write the .bat file
bat_file <- file.path(experiment_dir, str_glue("_globiom_{EXPERIMENT}.bat"))
bat_conn<-file(bat_file, open="wt")
writeLines(unlist(lapply(bat_template, str_glue)), bat_conn)
close(bat_conn)

# ---- Submit the run ----

outerr <- system2("condor_submit", args=str_glue("Condor{fsep}{EXPERIMENT}{fsep}_globiom_{EXPERIMENT}.job"), stdout=TRUE, stderr=TRUE)
cat(outerr, sep="\n")
if (!is.null(attr(outerr, "status")) && attr(outerr, "status") != 0) {
  stop("Submission of Condor run failed!")
}
cluster <- as.integer(str_match(outerr[-1], "cluster (\\d+)[.]$")[2])

# ---- Handle run results ----

# Wait for the run to complete
if (WAIT_FOR_RUN_COMPLETION) {
  cat("Waiting for run to complete...\n")
  for (job in 0:(NUMBER_OF_JOBS-1)) {
    log_file = file.path(experiment_dir, str_glue("_globiom_{EXPERIMENT}_{cluster}.{job}.log"))
    system2("condor_wait", args=log_file, stdout=NULL)
  }
  cat("All jobs are done.\n")
}

# Merge returned GDX files (implies GET_GDX_OUTPUT and WAIT_FOR_RUN_COMPLETION)
if (MERGE_GDX_OUTPUT) {
  cat("Merging the returned GDX files...\n")
  setwd(file.path(model_dir, "gdx"))
  system2("gdxmerge", args=str_glue("output_{EXPERIMENT}_{cluster}.*.gdx"))
  file.rename("merged.gdx", str_glue("output_{EXPERIMENT}_{cluster}_merged2.gdx"))
  setwd(model_dir)
}

cat("Done.")