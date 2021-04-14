#!/usr/bin/env Rscript
# Plot and summarize performance stats extracted from log files of Condor runs
# performed with Condor_run_basic.R or Condor_run.R. For assessing job run
# times and cluster performance behaviour.
#
# Option 1: run/source this script from RStudio.
# Before running the script, set EXPERIMENTS, CLUSTER, JOB_RELATIVE_PATH,
# CONDOR_DIR, and SUBDIRECTORY as required. When run from RStudio, this script
# looks for log files in:
# <Location of this script>/<RELATIVE_PATH>/<CONDOR_DIR>/<EXPERIMENTS[]|SUBDIRECTORY>
#
# Option 2: invoke the script from the command line.
# Usage:
# > [Rscript] [<relpath>/]Condor_run_stat.R <ex1> <ex2> ...
# where <ex1>, <ex2>, and so on is an arbitrary list of experiments
# specifiers that can be either:
# - a configuration file holding an EXPERIMENT setting
# - path to an experiment directory holding run log files
# - the name of the experiment
#
# The config files are the same as those passed to the Condor_run[_basic].R
# runs to be analyzed. When run from the command line, this script looks for
# log files in:
# <Current Directory>/<CONDOR_DIR>/<EXPERIMENTS[]|SUBDIRECTORY>
#
# On Linux/MacOS you can invoke the script directly without Rscript. This
# works provided that the execute flag is set and carriage returns have been
# removed using e.g. dos2unix.
#
# Invoking this script from the command line causes plots to be output to a PDF.
#
# Author: Albert Brouwer
# Repository: https://github.com/iiasa/Condor_run_R

# ---- Initialization ----

# Job $(Cluster) number string, use * or ? wildcards to match multiple cluster numbers
CLUSTER <- "*"

# Map known IP4s to hostnames for readability
hostname_map <- c("147.125.99.211"="limpopo1",
                  "147.125.99.212"="limpopo2",
                  "147.125.99.213"="limpopo3",
                  "147.125.99.214"="limpopo4",
                  "147.125.99.220"="limpopo5",
                  "147.125.99.216"="limpopo6")

# Required packages
options(tidyverse.quiet=TRUE)
library(tidyverse)
options(tibble.width = Inf)

# ---- Handle arguments and set up plotting for RStudio or command line ----

if (Sys.getenv("RSTUDIO") == "1") {
  # Names of experiments to analyse, as set via the EXPERIMENT config setting of your runs.
  #EXPERIMENT_LOG_DIRECTORIES <- c("tests/seeding/Condor/127busylong7.8GB_part05", "tests/seeding/Condor/127busylong7.8GB_part06")
  EXPERIMENT_LOG_DIRECTORIES <- c("../../GLOBIOM/Trunk_for_Condor_testing/Condor/limpopo1")
} else {
  args <- commandArgs(trailingOnly=TRUE)
  if (length(args) == 0) {
    stop("No configuration file or experiment directory argument(s) supplied!")
  }
  # From each argument passed on the command line, collect the experiment log directory
  EXPERIMENT_LOG_DIRECTORIES <- c()
  for (arg in args) {
    if (!file.exists(arg)) {
      stop(str_glue("Argument '{arg}' is neither a configuration file nor an experiment log directory!"))
    }
    if (file.info(arg)$isdir) {
      # It is a directory, directly add it to the experiment log directories
      EXPERIMENT_LOG_DIRECTORIES <- c(EXPERIMENT_LOG_DIRECTORIES, arg)
    } else {
      # It is a file, try to source it as a configuration file
      source(arg, local=TRUE, echo=FALSE)
      if (!exists("EXPERIMENT")) {
        stop(str_glue("No EXPERIMENT defined in file '{arg}'!"))
      }
      # Construct the path to the experiment log directory from the configuration
      if (exists("CONDOR_DIR")) {
        # The experiment log directory should be under CONDOR_DIR
        eld <- file.path(CONDOR_DIR, EXPERIMENT)
        if (!file.exists(eld) || !file.info(eld)$isdir) {
          stop(str_glue("Could not locate experiment log directory at '{eld}' as configured in CONDOR_DIR and EXPERIMENT of configuration file '{arg}!'"))
        }
        EXPERIMENT_LOG_DIRECTORIES <- c(EXPERIMENT_LOG_DIRECTORIES, eld)
        rm(CONDOR_DIR, EXPERIMENT)
      } else {
        # The experiment log directory should be the default "Condor" directory
        eld <- file.path("Condor", EXPERIMENT)
        if (!file.exists(eld) || !file.info(eld)$isdir) {
          stop(str_glue("Could not locate experiment log directory at '{eld}' in the default CONDOR_DIR='Condor' directory and as configured in EXPERIMENT of configuration file '{arg}!'"))
        }
        EXPERIMENT_LOG_DIRECTORIES <- c(EXPERIMENT_LOG_DIRECTORIES, eld)
        rm(EXPERIMENT)
      }
    }
  }
  # Set PDF filename and use landscape mode for generating the PDF with plots
  pdf(paper = "a4r", width=11.7, height=8.3, file=str_c(str_c(lapply(EXPERIMENT_LOG_DIRECTORIES, basename), collapse="_"), ".pdf"))
}

# ---- Preload the .out and .log files from the given experiment log directories ----

# Alphabetically list the .out and .log files resulting from the Condor run and check that they match up
out_paths <- c()
log_paths <- c()
experiments <- list() # expanded to a per-job list
for (eld in EXPERIMENT_LOG_DIRECTORIES) {
  experiment <- basename(eld)
  if (Sys.getenv("RSTUDIO") == "1") {
    experiment_log_dir <- file.path(dirname(rstudioapi::getActiveDocumentContext()$path), eld)
  } else {
    experiment_log_dir <- file.path(getwd(), eld)
  }
  outs <- list.files(path=experiment_log_dir, pattern=str_glue("*_{experiment}_{CLUSTER}.*.out"), full.names=TRUE, recursive=FALSE)
  out_paths <- c(out_paths, outs)
  logs <- list.files(path=experiment_log_dir, pattern=str_glue("*_{experiment}_{CLUSTER}.*.log"), full.names=TRUE, recursive=FALSE)
  log_paths <- c(log_paths, logs)
  experiments <- c(experiments, rep(experiment, length(logs)))
}
if (length(out_paths)!=length(log_paths)) stop(str_glue("The number of .out ({length(out_paths)}) and .log ({length(log_paths)}) files should be equal!"))
if (length(out_paths)==0) stop(str_glue("No output files for CLUSTER {CLUSTER} found in {experiment_log_dir}!"))

# Reduce the list of .out and .log file paths to extensionless root paths of these job output files and check that they are the same
for (i in seq_along(out_paths))
  out_paths[i] <- str_sub(out_paths[i], 1, -5)
for (i in seq_along(log_paths))
  log_paths[i] <- str_sub(log_paths[i], 1, -5)
if (!all(out_paths==log_paths)) stop("The .out and .log files for CLUSTER {CLUSTER} found in {experiment_log_dir} do not match up!")
roots <- as.list(out_paths)

# Remove aborted jobs
indices_of_aborted_jobs <- c()
for (i in seq_along(roots)) {
  hits <- grep("\\) \\d\\d/\\d\\d \\d\\d:\\d\\d:\\d\\d Job was aborted", readLines(str_glue("{roots[[i]]}.log")))
  if (length(hits) > 0) {
    indices_of_aborted_jobs <- c(i, indices_of_aborted_jobs) # need inverse order for removal
    warning(str_glue("Ignoring aborted job {roots[[i]]}"))
  }
}
for (i in indices_of_aborted_jobs) {
  roots[[i]] = NULL
  experiments[[i]] = NULL
}
if (length(roots) == 0) stop("No jobs left to analyze!")

# Pre-load the .log and .out files to speed up extraction
log_files <- list()
out_files <- list()
cat("Preloading...\n")
pb <- txtProgressBar(min=0, max=length(roots), style=3)
for (i in seq_along(roots)) {
  setTxtProgressBar(pb, i)
  log_files[[i]] <- readLines(str_glue("{roots[[i]]}.log"))
  out_files[[i]] <- readLines(str_glue("{roots[[i]]}.out"), warn=FALSE)
}
close(pb)

# ---- Extract lists of jobs data from the loaded output ----

# Extract the experiment cluster strings and job numbers
clusters <- c()
runs <- c() # {experiment}_{cluster} labels for plotting
job_numbers <- c()
for (i in seq_along(roots)) {
  mat <- str_match(roots[[i]], ".*_([0-9]+)[.]([0-9]+)$")
  clstr <- mat[2]
  prstr <- mat[3]
  if (is.na(clstr) | is.na(prstr)) stop(str_glue("Cannot extract cluster and job numbers from path {r}! Format should be *_<cluster number>.<job number>.[log|out]"))
  clusters  <- c(clusters , clstr)
  runs <- c(runs, str_glue("{experiments[i]}_{clstr}"))
  job_numbers <- c(job_numbers, as.integer(prstr))
}

# Determine the current year to help compensate for the absense of year numbers in the .log file
current_year <- as.integer(format(Sys.Date(),"%Y"))

# Extract the job submit times (with uncertain year) and strings from the .log files
submit_dtstrs <- c()
submit_times <- list()
submit_times_minus_1y <- list()
submit_time_warning <- FALSE
for (i in seq_along(roots)) {
  lines <- grep("\\) \\d\\d/\\d\\d \\d\\d:\\d\\d:\\d\\d Job submitted from host:", log_files[[i]], value=TRUE)
  if (length(lines) != 1) {
    if (!submit_time_warning) {
      warning(str_glue("Cannot extract submit time from Condor event log (e.g. {roots[[i]]}.log). Unable to determine latency between job submission and start time. Latency results and plots will be partially or fully unavailable."))
      submit_time_warning <- TRUE
    }
    submit_dtstrs <- c(submit_dtstrs, "")
    submit_times <- c(submit_times, NA)
    submit_times_minus_1y <- c(submit_times_minus_1y, NA)
  } else {
    dtstr <- str_match(lines[1], "\\) (\\d\\d/\\d\\d \\d\\d:\\d\\d:\\d\\d) Job submitted from host:")[2]
    if (is.na(dtstr)) stop(str_glue("Cannot decode submit time from {roots[[i]]}.log"))
    submit_dtstrs <- c(submit_dtstrs, dtstr)
    # Use guessed year (can fail for leap days)
    submit_times <- c(submit_times, list(strptime(str_glue("{current_year}/{dtstr}"), "%Y/%m/%d %H:%M:%S")))
    submit_times_minus_1y <- c(submit_times_minus_1y, list(strptime(str_glue("{current_year-1}/{dtstr}"), "%Y/%m/%d %H:%M:%S")))
  }
}

# Extract the job execution start times (with uncertain year) and hosts from the .log files
start_times <- list()
start_times_minus_1y <- list()
hosts <- c()
for (i in seq_along(roots)) {
  lines <- grep("\\) \\d\\d/\\d\\d \\d\\d:\\d\\d:\\d\\d Job executing on host: <\\d+\\.\\d+\\.\\d+\\.\\d+:", log_files[[i]], value=TRUE)
  if (length(lines) < 1) stop(str_glue("Cannot extract execution start time from {roots[[i]]}.log!"))
  if (length(lines) > 1) warning(str_glue("Execution started multiple times for job. Probably the initial execution host disconnected. See {roots[[i]]}.log!"))
  # Pick the last execution start time since that's on the host that can be assumed to have made it to the end.
  mat <- str_match(lines[length(lines)], "\\) (\\d\\d/\\d\\d \\d\\d:\\d\\d:\\d\\d) Job executing on host: <(\\d+\\.\\d+\\.\\d+\\.\\d+):")
  dtstr <- mat[2]
  ipstr <- mat[3]
  if (is.na(dtstr)) stop(str_glue("Cannot decode execution start time from {roots[[i]]}.log"))
  if (is.na(ipstr)) stop(str_glue("Cannot decode execution host IP from {roots[[i]]}.log"))
  # Use guessed year (can fail for leap days)
  start_times <- c(start_times, list(strptime(str_glue("{current_year}/{dtstr}"), "%Y/%m/%d %H:%M:%S")))
  start_times_minus_1y <- c(start_times_minus_1y, list(strptime(str_glue("{current_year-1}/{dtstr}"), "%Y/%m/%d %H:%M:%S")))
  if (is.na(hostname_map[ipstr])) host <- ipstr
  else host <- hostname_map[ipstr]
  hosts <- c(hosts, host)
}

# Extract the job termination times (with uncertain year) from the .log files
terminate_times <- list()
for (i in seq_along(roots)) {
  lines <- grep("\\) \\d\\d/\\d\\d \\d\\d:\\d\\d:\\d\\d Job terminated.$", log_files[[i]], value=TRUE)
  if (length(lines) != 1) stop(str_glue("Cannot extract termination time from {roots[[i]]}.log!"))
  dtstr <- str_match(lines[1], "\\) (\\d\\d/\\d\\d \\d\\d:\\d\\d:\\d\\d) Job terminated.$")[2]
  if (is.na(dtstr)) stop(str_glue("Cannot decode termination time from {roots[[i]]}.log"))
  # Use guessed year (can fail for leap days)
  terminate_times <- c(terminate_times, list(strptime(str_glue("{current_year}/{dtstr}"), "%Y/%m/%d %H:%M:%S")))
}

# Calculate the execution start latencies in seconds (difference between submit and execution start times)
latencies <- c()
for (i in seq_along(roots)) {
  if (is.na(submit_times[[i]])) {
    latencies <- c(latencies, NA)
  } else {
    if (start_times[[i]] >= submit_times[[i]]) {
      latency <- difftime(start_times[[i]], submit_times[[i]], units="secs")
    } else {
      # Submission must have happened in the prior year relative to execution start
      latency <- difftime(start_times[[i]], submit_times_minus_1y[[i]], units="secs")
    }
    latencies <- c(latencies, latency)
  }
}

# Calculate the execution duration in seconds (difference between execution start and termination times)
durations <- c()
for (i in seq_along(roots)) {
  if (terminate_times[[i]] >= start_times[[i]]) {
    duration <- difftime(terminate_times[[i]], start_times[[i]], units="secs")
  } else {
    # Execution start must have happened in the prior year relative to execution termination
    duration <- difftime(terminate_times[[i]], start_times_minus_1y[[i]], units="secs")
  }
  durations <- c(durations, duration)
}

# Determine the number of running jobs in each cluster
running_at_start <- c()
running_at_stop <- c()
for (i in seq_along(roots)) {
  if (is.na(latencies[[i]]) || is.na(durations[[i]])) {
    running_at_start <- c(running_at_start, NA)
    running_at_stop <- c(running_at_stop, NA)
  } else {
    running_at_start <- c(running_at_start, sum(clusters[[i]] == clusters & latencies[[i]] >= latencies & latencies[[i]] < latencies + durations, na.rm=TRUE))
    running_at_stop <- c(running_at_stop, sum(clusters[[i]] == clusters & latencies[[i]] + durations[[i]] >= latencies & latencies[[i]] + durations[[i]] < latencies + durations, na.rm=TRUE))
  }
}

# If available, obtain the hostname from the .out files instead
# To make it available, execute the following command in the batch file of your jobs:
# grep "^Machine = " .machine.ad
for (i in seq_along(roots)) {
  machine_line <- grep('^Machine = ".*"', out_files[[i]], value=TRUE)
  host <- str_match(machine_line, '^Machine = "([^.]+)[.].*"')[2]
  if (!is.na(host)) hosts[i] = host
}

# If available, obtain the Condor slot name from the .out file
# To make it available, execute the following command in the batch file of your jobs:
# echo _CONDOR_SLOT = %_CONDOR_SLOT%
slots <- list()
for (i in seq_along(roots)) {
  slot_line <- grep("^_CONDOR_SLOT ?= ?.*$", out_files[[i]], value=TRUE)
  # try to match dynamic slot format and clip off dynamic slot number
  slot <- str_match(slot_line, "^_CONDOR_SLOT ?= ?(.*)_\\d+$")[2]
  if (is.na(slot)) {
    # try to match regular slot format
    slot <- str_match(slot_line, "^_CONDOR_SLOT ?= ?(.*)$")[2]
  }
  slots[[i]] = slot # NA if no match
}

# Extract the total CPLEX time from the .out files
total_CPLEX_times <- c()
for (i in seq_along(roots)) {
  s <- NaN
  for (line in grep("^Cplex Time: [0-9]+[.][0-9]+sec", out_files[[i]], value=TRUE)) {
    if (is.nan(s)) s<- 0
    s <- s + as.double(str_match(line, "^Cplex Time: ([0-9]+[.][0-9]+)sec")[2])
  }
  total_CPLEX_times <- c(total_CPLEX_times, s)
}

# Extraction complete, loaded .log and .out files are no longer needed
rm(log_files)
rm(out_files)

# ---- Collect the jobs data in a tibble / data frame -----

# Create a tibble with the collected jobs data
jobs <- tibble(experiment=unlist(experiments),
               cluster=clusters,
               run=runs,
               job=job_numbers,
               submitted=submit_dtstrs,
               host=hosts,
               slot=unlist(slots),
               root=roots,
               `latency [s]`=latencies,
               `duration [s]`=durations,
               running_at_start=running_at_start,
               running_at_stop=running_at_stop,
               `total CPLEX time [s]`=total_CPLEX_times)

# Add a combined host_slot column
jobs <- add_column(jobs, host_slot=paste(jobs$host, jobs$slot))

# Before every column with [s] units, add derived columns with [min] and [h] units
for (name in names(jobs)) {
  if (str_sub(name, -3, -1) == "[s]") {
    name_head <- str_sub(name, 1, -4)
    jobs <- add_column(jobs, !!(str_glue("{name_head}[h]")) := jobs[[name]]/3600, .before=name)
    jobs <- add_column(jobs, !!(str_glue("{name_head}[min]")) := jobs[[name]]/60, .before=name)
  }
}

# ---- Analyse jobs data ----

# Plot, print() needed for sourcing because of https://yihui.name/en/2017/06/top-level-r-expressions/

print(ggplot()
      + geom_point(data=jobs, aes(x=`latency [min]`, y=running_at_start, color=run))
      + geom_point(data=jobs, aes(x=`latency [min]` + `duration [min]`, y=running_at_stop, color=run))
      + xlab("time after submission [min]")
      + ylab("running jobs")
      + theme_grey(base_size = 20)
)

if (any(!is.na(jobs["latency [min]"]))) {
  print(ggplot(jobs, aes(x=job, y=`latency [min]`, color=run))
        + geom_point(alpha=1/2)
        + geom_point(aes(y=`latency [min]`+`duration [min]`), alpha=1/2)
        + geom_segment(aes(xend=job, yend=`latency [min]`+`duration [min]`), alpha=1/5)
        + ylab("job start-stop time after submission [min]")
        + theme_grey(base_size=20)
  )
  print(ggplot(jobs, aes(x=job, y=`latency [min]`, color=slot))
        + geom_point(alpha=1)
        + geom_point(aes(y=`latency [min]`+`duration [min]`), alpha=1)
        + geom_segment(aes(xend=job, yend=`latency [min]`+`duration [min]`), alpha=1)
        + ylab("job start-stop time after submission [min]")
  )
}
print(ggplot(jobs, aes(x=job, y=host_slot, color=slot))
      + geom_point(size=3)
      + ylab("host slot")
      + ggtitle("slot allocation")
      + theme_grey(base_size=20)
)
print(ggplot(jobs, aes(x=`latency [min]`, y=host_slot, color=slot))
      + geom_jitter()
      + xlab("start time after submission [min]")
      + ylab("host slot") + ggtitle("slot allocation")
      + theme_grey(base_size=20)
)
print(ggplot(jobs, aes(x=job, y=`duration [min]`, color=run))
      + geom_smooth(formula = y ~ x, method="lm", se=FALSE)
      + geom_point()
)
print(ggplot(jobs, aes(x=host, y=`duration [min]`, color=run))
      + geom_point()
)

if (any(!is.nan(unlist(jobs["total CPLEX time [min]"])))) {
  print(ggplot(jobs, aes(x=job, y=`total CPLEX time [min]`, color=run))
        + geom_point()
  )
}

# Summarize
jobs %>%
select(experiment, cluster, submitted, `latency [min]`, `duration [min]`, `latency [h]`, `duration [h]`, `running_at_start`) %>%
group_by(cluster) %>%
summarize(experiment=dplyr::first(experiment),
          submitted=min(submitted),
          `jobs`=n(),
          `max running`=max(`running_at_start`),
          `mean [min]`=mean(`duration [min]`),
          `stderr [min]`=sd(`duration [min]`)/sqrt(jobs),
          `stdev [min]`=sd(`duration [min]`),
          `min [min]`=min(`duration [min]`),
          `max [min]`=max(`duration [min]`),
          `overall [min]`=max(`latency [min]` + `duration [min]`),
          `throughput [jobs/h]`=n()/max(`latency [h]` + `duration [h]`)) %>%
arrange(cluster) -> summary
print(summary)
print(ggplot(summary, aes(x=jobs/5, y=`mean [min]`, color=str_glue("{experiment}_{cluster}"))) + geom_errorbar(aes(ymin=`mean [min]`-`stdev [min]`, ymax=`mean [min]`+`stdev [min]`), width=1) + geom_point(size=3) + xlab("jobs/limpopo") + ylab("mean job time [min]") + scale_color_discrete(name = "run") + ggtitle("contention") + theme_grey(base_size=20))
print(ggplot(summary, aes(x=jobs, y=`throughput [jobs/h]`, color=str_glue("{experiment}_{cluster}"))) + geom_point(size=3) + scale_x_continuous(trans='log10') + xlab("jobs/run") + ylab("jobs/h") + scale_color_discrete(name = "run") + ggtitle("throughput") + theme_grey(base_size=20))

options(tibble.print_max = Inf)

# Print summary grouped by job cluster and host
print(jobs %>%
      select(experiment, cluster, host, submitted, `duration [min]`) %>%
      group_by(cluster,host) %>%
      summarize(experiment=dplyr::first(experiment),
                submitted=min(submitted),
                `jobs`=n(),
                `mean [min]`=mean(`duration [min]`),
                `stderr [min]`=sd(`duration [min]`)/sqrt(jobs),
                `stdev [min]`=sd(`duration [min]`),
                `min [min]`=min(`duration [min]`),
                `max [min]`=max(`duration [min]`)) %>%
      arrange(host, cluster)
)
