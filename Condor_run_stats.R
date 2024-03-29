#!/usr/bin/env Rscript
# Plot and summarize performance stats extracted from log files of Condor runs
# performed with Condor_run_basic.R or Condor_run.R. For assessing job run
# times and cluster performance behaviour.
#
# Installation: https://github.com/iiasa/Condor_run_R#installation
# Use:          https://github.com/iiasa/Condor_run_R#use
#
# Author:  Albert Brouwer
# Release: https://github.com/iiasa/Condor_run_R/releases/tag/v2024-03-14

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
require(gridExtra, quietly=TRUE) # optional, if available produce graphical summary tables
suppressWarnings(library(tidyverse))
suppressWarnings(library(fs))

# Setup
options(tibble.width = Inf)
options(tibble.print_max = Inf)

# ---- Define helper functions ----

parse_datetime <- function(dtstr, kind, fileroot) {
  # Decode possible date-time formats
  time <- strptime(dtstr, "%Y-%m-%d %H:%M:%S")
  if (is.na(time)) {
    # Parse format without year by guessing the year is the current year.
    # The guessed year will be wrong when analyzing a run submitted in a
    # previous year. Moreover, parsing will fail (return NA) when parsing
    # a leap day from a prior year unless the current year is also a leap
    # year.
    current_time <- as.POSIXlt(Sys.time())
    time <- strptime(str_glue("{current_time$year + 1900}/{dtstr}"), "%Y/%m/%d %H:%M:%S")
    if (is.na(time)) stop(str_glue("Unsupported {kind} time format in {fileroot}.log"))

    # If the guessed year is off, the submission happened in a prior
    # year. The most likely scenario is that it is currently early in
    # the next year, and the submission was late last year. Then
    # the guessed time (with the year being one higher than it should be)
    # will be larger than the current time. Here we detect and correct
    # for this probable scenario.
    #
    # The extra day worth of seconds prevents the parsing of log files written
    # on a machine located in a different timezone from triggering the correction
    # logic.
    if (time > current_time + 24 * 60 * 60) {
      time$year <- time$year - 1
    }
  }
  return(time)
}

# ---- Handle arguments and set up plotting for RStudio or command line ----
if (interactive()) {
  # Paths to one or more directories containing log files of runs to analyse.
  LOG_DIRECTORIES <- dir_ls("tests/basic/Condor")
  if (length(LOG_DIRECTORIES) == 0) {
    stop("No LOG_DIRECTORIES provided!")
  }
} else {
  args <- commandArgs(trailingOnly=TRUE)
  if (length(args) == 0) {
    stop("No configuration file or log directory argument(s) supplied! For usage information, see: https://github.com/iiasa/Condor_run_R#use")
  }
  # From each argument passed on the command line, collect the log directory
  LOG_DIRECTORIES <- c()
  for (arg in args) {
    if (!file_exists(arg)) {
      stop(str_glue("Argument '{arg}' is neither a configuration file nor a log directory!"))
    }
    if (is_dir(arg)) {
      # It is a directory, directly add it to the log directories
      LOG_DIRECTORIES <- c(LOG_DIRECTORIES, arg)
    } else {
      # It is a file, try to source it as a configuration file
      source(arg, local=TRUE, echo=FALSE)

      # Accommodate synonym configuration options for LABEL
      if (exists("LABEL")) {
        label_from <- "LABEL"
      } else if (exists("NAME")) {
        label_from <- "NAME"
        LABEL <- NAME
      } else if (exists("PROJECT")) {
        label_from <- "PROJECT"
        LABEL <- PROJECT
      } else if (exists("EXPERIMENT")) {
        label_from <- "EXPERIMENT"
        LABEL <- EXPERIMENT
      } else {
        stop(str_glue("None of the synonyms LABEL/NAME/PROJECT/EXPERIMENT is defined in  file '{arg}'!"))
      }

      # Construct the path to the run's log directory from the configuration
      if (exists("CONDOR_DIR")) {
        # The log directory should be under CONDOR_DIR
        log_dir <- path(CONDOR_DIR, str_glue(LABEL))
        default_condor_dir = FALSE
      } else {
        # The parent log directory should be the default "Condor" directory
        log_dir <- path("Condor", str_glue(LABEL))
        default_condor_dir = TRUE
      }
      if (!file_exists(log_dir) || !is_dir(log_dir)) {
        if (str_detect(LABEL, fixed("Sys.Date(")) || str_detect(LABEL, fixed("Sys.time("))) {
          time_variable_advice <- str_glue(" {label_from} has a time-variable value '{LABEL}' so probably you started the run on an earlier date. To still analyze the run, specify its Condor log directory instead of its configuration file as an argument.")
        } else {
          time_variable_advice <- ""
        }
        stop(str_glue("Could not locate a log directory at '{log_dir}' as configured by {ifelse(default_condor_dir, '', 'CONDOR_DIR and ')}{label_from} of configuration file '{arg}!{time_variable_advice}'"))
      }

      # Add log directory path as determined from config file
      LOG_DIRECTORIES <- c(LOG_DIRECTORIES, log_dir)
    }
  }
  # Set PDF filename and use landscape mode for generating the PDF with plots
  pdf_file_name <- str_c(str_c(lapply(LOG_DIRECTORIES, basename), collapse="_"), ".pdf")
  pdf(paper = "a4r", width=11.7, height=8.3, file=pdf_file_name)
  message(str_glue("Writing tables and plots to {pdf_file_name}"))
}

# ---- Preload the .out and .log files from the given log directories ----

# Alphabetically list the .out and .log files resulting from the Condor run and check that they match up
out_paths <- c()
log_paths <- c()
labels <- list() # expanded to a per-job list
for (log_dir in LOG_DIRECTORIES) {
  label <- basename(log_dir)
  if (!is_absolute_path(log_dir)) {
    if (interactive() && Sys.getenv("RSTUDIO") == "1") {
      log_dir <- path(dirname(rstudioapi::getActiveDocumentContext()$path), log_dir)
    } else {
      log_dir <- path(getwd(), log_dir)
    }
  }
  outs <- dir_ls(path=log_dir, glob=str_glue("*_{CLUSTER}.*.out"))
  out_paths <- c(out_paths, outs)
  logs <- dir_ls(path=log_dir, glob=str_glue("*_{CLUSTER}.*.log"))
  log_paths <- c(log_paths, logs)
  labels <- c(labels, rep(label, length(logs)))
}
rm(log_dir, label, outs, logs)
if (length(out_paths) == 0) stop(str_glue("No output files for CLUSTER {CLUSTER} in any of the log directories!"))
if (length(out_paths) != length(log_paths)) stop(str_glue("The number of .out ({length(out_paths)}) and .log ({length(log_paths)}) files should be equal!"))

# Reduce the list of .out and .log file paths to extensionless root paths of these job output files and check that they are the same
for (i in seq_along(out_paths))
  out_paths[i] <- str_sub(out_paths[i], 1, -5)
for (i in seq_along(log_paths))
  log_paths[i] <- str_sub(log_paths[i], 1, -5)
if (!all(out_paths==log_paths)) stop("The .out and .log files for CLUSTER {CLUSTER} found in {log_dir} do not match up!")
roots <- as.list(out_paths)

# Remove aborted jobs
indices_of_aborted_jobs <- c()
for (i in seq_along(roots)) {
  if (length(str_which(readLines(str_glue("{roots[[i]]}.log")), "\\) .* Job was aborted")) > 0) {
    indices_of_aborted_jobs <- c(i, indices_of_aborted_jobs) # need inverse order for removal
    warning(str_glue("Ignoring aborted job {roots[[i]]}"))
  }
}
for (i in indices_of_aborted_jobs) {
  roots[[i]] = NULL
  labels[[i]] = NULL
}
if (length(roots) == 0) stop("No jobs left to analyze!")
rm (indices_of_aborted_jobs)

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
rm(pb)

# ---- Extract lists of jobs data from the loaded output ----

# Extract the cluster strings and job numbers of the runs
clusters <- c()
runs <- c() # {label}_{cluster} run names for plotting
job_numbers <- c()
for (i in seq_along(roots)) {
  mat <- str_match(roots[[i]], ".*_([0-9]+)[.]([0-9]+)$")
  clstr <- mat[2]
  prstr <- mat[3]
  if (is.na(clstr) | is.na(prstr)) stop(str_glue("Cannot extract cluster and job numbers from path {r}! Format should be *_<cluster number>.<job number>.[log|out]"))
  clusters  <- c(clusters , clstr)
  runs <- c(runs, str_glue("{labels[i]}_{clstr}"))
  job_numbers <- c(job_numbers, as.integer(prstr))
}
rm(mat, clstr, prstr)

# Extract the job submit time (with uncertain year) and date/time string from the .log files
submit_times <- list()
submit_time_warning <- FALSE
submit_pattern <- "\\) (.*) Job submitted from host:"
for (i in seq_along(roots)) {
  lines <- str_subset(log_files[[i]], submit_pattern)
  if (length(lines) == 0) {
    if (!submit_time_warning) {
      warning(str_glue("Cannot find submit time in Condor event log (e.g. {roots[[i]]}.log). Unable to determine latency between job submission and start time. Latency results and plots will be partially or fully unavailable."))
      submit_time_warning <- TRUE
    }
    submit_times <- c(submit_times, NA)
  } else {
    # Use the last matching line, should be the only submission
    dtstr <- str_match(lines[length(lines)], submit_pattern)[2]
    if (is.na(dtstr)) stop(str_glue("Cannot decode submit time from {roots[[i]]}.log"))
    submit_times[[i]] <- parse_datetime(dtstr, "submit", roots[[i]])
  }
}
rm(submit_pattern, lines, submit_time_warning, dtstr)

# Extract the job execution start time (with uncertain year) and host from the .log files
start_times <- list()
start_pattern <- "\\) (.*) Job executing on host: <(.*).\\d+?"
hosts <- c()
for (i in seq_along(roots)) {
  lines <- str_subset(log_files[[i]], start_pattern)
  if (length(lines) < 1) stop(str_glue("Cannot extract execution start time from {roots[[i]]}.log!"))
  # Use the last execution start time since that's on the
  # host that can be assumed to have completed the job.
  mat <- str_match(lines[length(lines)], start_pattern)
  dtstr <- mat[2]
  ipstr <- mat[3]
  if (is.na(dtstr)) stop(str_glue("Cannot decode execution start time from {roots[[i]]}.log"))
  if (is.na(ipstr)) stop(str_glue("Cannot decode the IP of the execution point from {roots[[i]]}.log"))
  start_times[[i]] <- parse_datetime(dtstr, "start", roots[[i]])
  if (is.na(hostname_map[ipstr])) host <- ipstr
  else host <- hostname_map[ipstr]
  hosts <- c(hosts, host)
}
rm(start_pattern, lines, mat, dtstr, ipstr, host)

# Extract the job termination time (with uncertain year) from the .log files
termination_times <- list()
termination_pattern <- "\\) (.*) Job terminated.$"
for (i in seq_along(roots)) {
  lines <- str_subset(log_files[[i]], termination_pattern)
  if (length(lines) == 0) stop(str_glue("Cannot extract termination time from {roots[[i]]}.log!"))
  dtstr <- str_match(lines[length(lines)], termination_pattern)[2]
  if (is.na(dtstr)) stop(str_glue("Cannot decode termination time from {roots[[i]]}.log"))
  termination_times[[i]] <- parse_datetime(dtstr, "termination", roots[[i]])
}
rm(termination_pattern, lines, dtstr)

# Extract the CPUs (threads) usage from the .log files
cpus_usages <- list()
cpus_usage_regexp <- "^\\s+Cpus\\s+:\\s+([[:digit:].]+)\\s+"
for (i in seq_along(roots)) {
  lines <- str_subset(log_files[[i]], cpus_usage_regexp)
  if (length(lines) == 0) stop(str_glue("Cannot extract CPUs usage from {roots[[i]]}.log!"))
  # Use the last match which should correspond to the job start that ran to completion.
  cpus_usage <- as.double(str_match(lines[length(lines)], cpus_usage_regexp)[2])
  if (is.na(cpus_usage)) stop(str_glue("Cannot decode CPUs usage from {roots[[i]]}.log"))
  cpus_usages[[i]] <- cpus_usage
}
rm(cpus_usage_regexp, lines, cpus_usage)

# Extract the disk usage and request (KB) from the .log files
disk_usages <- list()
disk_requests <- list()
disk_regexp <- "^\\s+Disk \\(KB\\)\\s+:\\s+(\\d+)\\s+(\\d+)"
for (i in seq_along(roots)) {
  lines <- str_subset(log_files[[i]], disk_regexp)
  if (length(lines) == 0) stop(str_glue("Cannot extract disk usage from {roots[[i]]}.log!"))
  # Use the last match which should correspond to the job start that ran to completion.
  disk_match <-str_match(lines[length(lines)], disk_regexp)
  disk_usage <- as.double(disk_match[2])
  disk_request <- as.double(disk_match[3])
  if (is.na(disk_usage)) stop(str_glue("Cannot decode disk usage from {roots[[i]]}.log"))
  if (is.na(disk_request)) stop(str_glue("Cannot decode disk request from {roots[[i]]}.log"))
  disk_usages[[i]] <- disk_usage
  disk_requests[[i]] <- disk_request
}
rm(disk_regexp, lines, disk_match, disk_usage, disk_request)

# Extract the memory usage (MB) from the .log files
memory_usages <- list()
memory_usage_regexp <- "^\\s+Memory \\(MB\\)\\s+:\\s+(\\d+)\\s+"
for (i in seq_along(roots)) {
  lines <- str_subset(log_files[[i]], memory_usage_regexp)
  if (length(lines) == 0) stop(str_glue("Cannot extract memory usage from {roots[[i]]}.log!"))
  # Use the last match which should correspond to the job start that ran to completion.
  memory_usage <- as.double(str_match(lines[length(lines)], memory_usage_regexp)[2])
  if (is.na(memory_usage)) stop(str_glue("Cannot decode memory usage from {roots[[i]]}.log"))
  memory_usages[[i]] <- memory_usage
}
rm(memory_usage_regexp, lines, memory_usage)

# Calculate the execution start latencies in seconds (difference between submit and execution start times)
latencies <- c()
for (i in seq_along(roots)) {
  latencies <- c(latencies,  difftime(start_times[[i]], submit_times[[i]], units="secs"))
}

# Calculate the execution duration in seconds (difference between execution start and termination times)
durations <- c()
for (i in seq_along(roots)) {
  durations <- c(durations, difftime(termination_times[[i]], start_times[[i]], units="secs"))
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
machine_pattern = '^Machine = "([^.]+)[.].*"'
for (i in seq_along(roots)) {
  lines <- str_subset(out_files[[i]], machine_pattern)
  if (lines > 0) {
    # Should be only one match at the very start of the .out
    host <- str_match(lines[[1]], machine_pattern)[2]
    if (!is.na(host)) {
      # replace existing entry
      hosts[i] = host
    }
  }
}
rm(lines, host)

# If available, obtain the Condor slot name from the .out file
# To make it available, execute the following command in the batch file of your jobs:
# echo _CONDOR_SLOT = %_CONDOR_SLOT%
# on Windows, or, on Linux
# echo _CONDOR_SLOT = $_CONDOR_SLOT
slots <- list()
for (i in seq_along(roots)) {
  slot <- NA
  lines <- str_subset(out_files[[i]], "^_CONDOR_SLOT ?= ?.*$")
  if (length(lines) > 0) {
    # try to match dynamic slot format and clip off dynamic slot number
    slot <- str_match(lines[[1]], "^_CONDOR_SLOT ?= ?(.*)_\\d+$")[2]
    if (is.na(slot)) {
      # try to match regular slot format, NA if no match
      slot <- str_match(lines[[1]], "^_CONDOR_SLOT ?= ?(.*)$")[2]
    }
  }
  slots[[i]] <- ifelse(is.na(slot), "NA", slot)
}
rm(lines, slot)

# Extract the total CPLEX time from the .out files
total_CPLEX_times <- c()
for (i in seq_along(roots)) {
  s <- NaN
  for (line in str_subset(out_files[[i]], "^Cplex Time: [0-9]+[.][0-9]+sec")) {
    if (is.nan(s)) s<- 0
    s <- s + as.double(str_match(line, "^Cplex Time: ([0-9]+[.][0-9]+)sec")[2])
  }
  total_CPLEX_times <- c(total_CPLEX_times, s)
}
rm(s, line)

# Extraction complete, loaded .log and .out files are no longer needed
rm(log_files)
rm(out_files)

# ---- Collect the jobs data in a tibble / data frame -----

# Create a tibble with the collected jobs data
jobs <- tibble(label=unlist(labels),
               cluster=clusters,
               run=runs,
               job=job_numbers,
               submitted=submit_times,
               host=hosts,
               slot=unlist(slots),
               root=roots,
               `latency [s]`=latencies,
               `duration [s]`=durations,
               running_at_start=running_at_start,
               running_at_stop=running_at_stop,
               `total CPLEX time [s]`=total_CPLEX_times,
               `CPUs usage`=unlist(cpus_usages),
               `disk usage [KB]`=unlist(disk_usages),
               `disk request [KB]`=unlist(disk_requests),
               `memory usage [MB]`=unlist(memory_usages))

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

# Summarize run times
jobs %>%
  select(label, cluster, submitted, `latency [min]`, `duration [min]`, `latency [h]`, `duration [h]`, `running_at_start`) %>%
  group_by(cluster) %>%
  summarize(label=dplyr::first(label),
            submitted=Reduce(min, submitted),
            `jobs`=n(),
            `max running`=max(`running_at_start`),
            `mean [min]`=mean(`duration [min]`),
            `stderr [min]`=sd(`duration [min]`)/sqrt(jobs),
            `stdev [min]`=sd(`duration [min]`),
            `min [min]`=min(`duration [min]`),
            `max [min]`=max(`duration [min]`),
            `overall [min]`=max(`latency [min]` + `duration [min]`),
            `throughput [jobs/h]`=n()/max(`latency [h]` + `duration [h]`),
            .groups="keep") %>%
  arrange(cluster) -> summary

# Summarize and group by cluster and host
jobs %>%
  select(label, cluster, host, submitted, `duration [min]`) %>%
  group_by(cluster,host) %>%
  summarize(label=dplyr::first(label),
            submitted=Reduce(min, submitted),
            `jobs`=n(),
            `mean [min]`=mean(`duration [min]`),
            `stderr [min]`=sd(`duration [min]`)/sqrt(jobs),
            `stdev [min]`=sd(`duration [min]`),
            `min [min]`=min(`duration [min]`),
            `max [min]`=max(`duration [min]`),
            .groups="keep") %>%
  arrange(host, cluster) -> summary_grouped

# Summarize resource use
jobs %>%
  select(label, cluster,`CPUs usage`, `disk usage [KB]`, `disk request [KB]`, `memory usage [MB]`) %>%
  group_by(cluster) %>%
  summarize(label=dplyr::first(label),
            `mean CPUs`=mean(`CPUs usage`),
            `mean disk usage-request [KB]`=mean(`disk usage [KB]` - `disk request [KB]`),
            `min [KB]`=min(`disk usage [KB]` - `disk request [KB]`),
            `max [KB]`=max(`disk usage [KB]` - `disk request [KB]`),
            `mean memory usage [MB]`=mean(`memory usage [MB]`),
            `min [MB]`=min(`memory usage [MB]`),
            `max [MB]`=max(`memory usage [MB]`),
            .groups="keep") %>%
  arrange(cluster) -> resource_summary

# Tabulate summaries
if (exists("grid.table")) {
  # produce graphical tables
  grid.table(summary, theme=ttheme_default(base_size = 6.0))
  print(ggplot() + theme_void())
  grid.table(summary_grouped, theme=ttheme_default(base_size = 8.3))
  print(ggplot() + theme_void())
  grid.table(resource_summary, theme=ttheme_default(base_size = 7.0))
} else {
  # produce tables formatted as text
  print(summary)
  print(summary_grouped)
  print(resource_summary)
}

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

# Summary plots
print(ggplot(summary, aes(x=jobs/5, y=`mean [min]`, color=str_glue("{label}_{cluster}"))) + geom_errorbar(aes(ymin=`mean [min]`-`stdev [min]`, ymax=`mean [min]`+`stdev [min]`), width=1) + geom_point(size=3) + xlab("jobs/limpopo") + ylab("mean job time [min]") + scale_color_discrete(name = "run") + ggtitle("contention") + theme_grey(base_size=20))
print(ggplot(summary, aes(x=jobs, y=`throughput [jobs/h]`, color=str_glue("{label}_{cluster}"))) + geom_point(size=3) + scale_x_continuous(trans='log10') + xlab("jobs/run") + ylab("jobs/h") + scale_color_discrete(name = "run") + ggtitle("throughput") + theme_grey(base_size=20))
