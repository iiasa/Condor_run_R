#!/usr/bin/env Rscript
# Plot and summarize performance stats from output files of Condor runs
#
# Usage: run this script from RStudio by setting up an RStudio project in
# <GLOBIOM>/R. This makes <GLOBIOM>/R the working directory, as required.
# This script reads the output files of the Condor runs to analyze from either
# <GLOBIOM>/Model/Condor/<EXPERIMENTS[]>
# or
# <GLOBIOM>/Model/Condor/<SUBDIRECTORY>
#
# Beware that if you run this script from the command line via Rscript, the
# plots are output to a PDF file. 
#
# Author: Albert Brouwer
#
# Todo:
# Solver-independent extraction from "S O L V E      S U M M A R Y" sections

# Experiment names you gave to your Condor runs
#EXPERIMENTS <- c("limpopo1_affinity_half", "limpopo1_affinity_f", "limpopo1_affinity_double")
#EXPERIMENTS <- c("limpopo_nusw_5x8", "limpopo_nusw_5x16", "limpopo_nusw_5x24", "limpopo_nusw_4x32_30", "limpopo_nusw_500")
EXPERIMENTS <- c("test")
# Job $(Cluster) number string, use * or ? wildcards to match multiple cluster numbers
#CLUSTER <- "83?" 
CLUSTER <- "*"
# Name of directory under Model/Condor with output files to analyze. Set to NULL to default to the experiment name.
SUBDIRECTORY <- NULL

# Map known IP4s to hostnames for readability
hostname_map <- c("147.125.199.211"="limpopo1",
                  "147.125.199.212"="limpopo2",
                  "147.125.199.213"="limpopo3",
                  "147.125.199.214"="limpopo4",
                  "147.125.199.220"="limpopo5")

# Required packages
library(tidyverse)

# ---- Load the output files of the specified Condor run(s) ----

# Alphabetically list the .out and .log files resulting from the Condor run and check that they match up
if (basename(getwd()) != "R") stop("Directory R at the GLOBIOM root must be the working directory! When running this script using RScript from the command line, CD into the R directory first. When running this script from RStudio, make sure R is the project directory.")
out_paths <- c()
log_paths <- c()
experiments <- list() # expanded to a per-job list
for (experiment in EXPERIMENTS) {
  if (is.null(SUBDIRECTORY)) {
    experiment_dir<-file.path(getwd(), "..", "Model", "Condor", experiment)
  } else {
    experiment_dir<-file.path(getwd(), "..", "Model", "Condor", SUBDIRECTORY)
  }
  if (!dir.exists(experiment_dir)) stop(str_glue("Experiment directory not found! Expected location: {experiment_dir}!"))
  outs <- list.files(path=experiment_dir, pattern=str_glue("*_{experiment}_{CLUSTER}.*.out"), full.names=TRUE, recursive=FALSE)
  out_paths <- c(out_paths, outs)
  logs <- list.files(path=experiment_dir, pattern=str_glue("*_{experiment}_{CLUSTER}.*.log"), full.names=TRUE, recursive=FALSE)
  log_paths <- c(log_paths, logs)
  experiments <- c(experiments, rep(experiment, length(logs)))
}
if (length(out_paths)!=length(log_paths)) stop(str_glue("The number of .out ({length(out_paths)}) and .log ({length(log_paths)}) files should be equal!"))
if (length(out_paths)==0) stop(str_glue("No output files for CLUSTER {CLUSTER} found in {experiment_dir}!"))

# Reduce the list of .out and .log file paths to extensionless root paths of these job output files and check that they are the same
for (i in seq_along(out_paths))
  out_paths[i] <- str_sub(out_paths[i], 1, -5)
for (i in seq_along(log_paths))
  log_paths[i] <- str_sub(log_paths[i], 1, -5)
if (!all(out_paths==log_paths)) stop("The .out and .log files for CLUSTER {CLUSTER} found in {experiment_dir} do not match up!")
roots <- as.list(out_paths)

# Remove aborted jobs
indices_of_aborted_jobs = c()
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
pb <- txtProgressBar(min = 0, max = length(roots), style = 3)
for (i in seq_along(roots)) {
  setTxtProgressBar(pb, i)
  log_files[[i]] <- readLines(str_glue("{roots[[i]]}.log"))
  out_files[[i]] <- readLines(str_glue("{roots[[i]]}.out"), warn=FALSE)
}
close(pb)

# ---- Extract lists of jobs data from the loaded output ----

# Extract the experiment cluster strings and process numbers
clusters = c()
runs = c() # {experiment}_{cluster} labels for plotting
processes = c()
for (i in seq_along(roots)) {
  mat <- str_match(roots[[i]], ".*_([0-9]+)[.]([0-9]+)$")
  clstr <- mat[2]
  prstr <- mat[3]
  if (is.na(clstr) | is.na(prstr)) stop(str_glue("Cannot extract cluster and process numbers from path {r}! Format should be *_<cluster number>.<process number>.[log|out]"))
  clusters  <- c(clusters , clstr)
  runs <- c(runs, str_glue("{experiments[i]}_{clstr}"))
  processes <- c(processes, as.integer(prstr))
}

# Determine the current year to help compensate for the absense of year numbers in the .log file
current_year <- as.integer(format(Sys.Date(),"%Y"))

# Extract the job submit times (with uncertain year) and strings from the .log files
submit_dtstrs <- c()
submit_times <- list()
submit_times_minus_1y <- list()
for (i in seq_along(roots)) {
  
  lines <- grep("\\) \\d\\d/\\d\\d \\d\\d:\\d\\d:\\d\\d Job submitted from host:", log_files[[i]], value=TRUE)
  if (length(lines) != 1) stop(str_glue("Cannot extract termination time from {roots[[i]]}.log!"))
  dtstr <- str_match(lines[1], "\\) (\\d\\d/\\d\\d \\d\\d:\\d\\d:\\d\\d) Job submitted from host:")[2]
  if (is.na(dtstr)) stop(str_glue("Cannot decode termination time from {roots[[i]]}.log"))
  submit_dtstrs <- c(submit_dtstrs, dtstr)
  # Use guessed year (can fail for leap days)
  submit_times <- c(submit_times, list(strptime(str_glue("{current_year}/{dtstr}"), "%Y/%m/%d %H:%M:%S")))
  submit_times_minus_1y <- c(submit_times_minus_1y, list(strptime(str_glue("{current_year-1}/{dtstr}"), "%Y/%m/%d %H:%M:%S")))
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
  dtstr = mat[2]
  ipstr = mat[3]
  if (is.na(dtstr)) stop(str_glue("Cannot decode execution start time from {roots[[i]]}.log"))
  if (is.na(ipstr)) stop(str_glue("Cannot decode execution host IP from {roots[[i]]}.log"))
  # Use guessed year (can fail for leap days)
  start_times = c(start_times, list(strptime(str_glue("{current_year}/{dtstr}"), "%Y/%m/%d %H:%M:%S")))
  start_times_minus_1y = c(start_times_minus_1y, list(strptime(str_glue("{current_year-1}/{dtstr}"), "%Y/%m/%d %H:%M:%S")))
  if (is.na(hostname_map[ipstr])) host <- ipstr
  else host <- hostname_map[ipstr]
  hosts = c(hosts, host)
}

# Extract the job terminate times (with uncertain year) from the .log files
terminate_times <- list()
for (i in seq_along(roots)) {
  lines <- grep("\\) \\d\\d/\\d\\d \\d\\d:\\d\\d:\\d\\d Job terminated.$", log_files[[i]], value=TRUE)
  if (length(lines) != 1) stop(str_glue("Cannot extract termination time from {roots[[i]]}.log!"))
  dtstr <- str_match(lines[1], "\\) (\\d\\d/\\d\\d \\d\\d:\\d\\d:\\d\\d) Job terminated.$")[2]
  if (is.na(dtstr)) stop(str_glue("Cannot decode termination time from {roots[[i]]}.log"))
  # Use guessed year (can fail for leap days)
  terminate_times = c(terminate_times, list(strptime(str_glue("{current_year}/{dtstr}"), "%Y/%m/%d %H:%M:%S")))
}

# Calculate the execution latencies in seconds (difference between submit and execute times)
latencies <- c()
for (i in seq_along(roots)) {
  if (start_times[[i]] >= submit_times[[i]]) {
    latency <- difftime(start_times[[i]], submit_times[[i]], units="secs")
  } else {
    # Submission must have happened in the prior year relative to execution start
    latency <- difftime(start_times[[i]], submit_times_minus_1y[[i]], units="secs")
  }
  latencies <- c(latencies, latency)
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

# If available, obtain the hostname from the .out files instead
# To make it available, execute the following command in the batch file of your jobs:
# grep "^Machine = " .machine.ad
for (i in seq_along(roots)) {
  machine_line = grep('^Machine = ".*"', out_files[[i]], value=TRUE)
  host = str_match(machine_line, '^Machine = "([^.]+)[.].*"')[2]
  if (!is.na(host)) hosts[i] = host
}

# If available, obtain the Condor partitionable slot name from the .out file
# To make it available, execute the following command in the batch file of your jobs:
# echo _CONDOR_SLOT = %_CONDOR_SLOT%
slots <- list()
for (i in seq_along(roots)) {
  slot_line = grep("^_CONDOR_SLOT ?= ?.*$", out_files[[i]], value=TRUE)
  slot = str_match(slot_line, "^_CONDOR_SLOT ?= ?(.*)_\\d+$")[2] # clip off the dynamic slot number
  if (is.na(slot)) {
    slots[[i]] = NA
  } else {
    slots[[i]] = slot
  }
}

# Extract the EXECUTION TIME occurrences from the .out files
execution_times <- list()
max_matches <- 0
for (i in seq_along(roots)) {
  seconds <- c()
  for (line in grep("^EXECUTION TIME\\s+=\\s+[0-9]+[.][0-9]+ SECONDS", out_files[[i]], value=TRUE)) {
    seconds <- c(seconds, as.double(str_match(line, "^EXECUTION TIME\\s+=\\s+([0-9]+[.][0-9]+) SECONDS")[2]))
  }
  max_matches = max(max_matches, length(seconds))
  execution_times <- c(execution_times, list(seconds))
}
# Set any missing occurrences (early abort of job presumably) to NA
if (max_matches > 0) {
  for (i in seq_along(execution_times)) {
    for (j in 1:max_matches) {
      if (length(execution_times[[i]]) < j) execution_times[[i]][j] = NA
    }
  }
}
if (max_matches > 0) {
  execution_times <- transpose(execution_times)
} else {
  execution_times <- list()
}

# Extract the Cplex Time occurrences from the .out files
cplex_times <- list()
max_matches <- 0
for (i in seq_along(roots)) {
  seconds <- c()
  for (line in grep("^Cplex Time: [0-9]+[.][0-9]+sec", out_files[[i]], value=TRUE)) {
    seconds <- c(seconds, as.double(str_match(line, "^Cplex Time: ([0-9]+[.][0-9]+)sec")[2]))
  }
  max_matches = max(max_matches, length(seconds))
  cplex_times <- c(cplex_times, list(seconds))
}
# Set any missing occurrences (early abort of job presumably) to NA
if (max_matches > 0) {
  for (i in seq_along(cplex_times)) {
    for (j in 1:max_matches) {
      if (length(cplex_times[[i]]) < j) cplex_times[[i]][j] = NA
    }
  }
}
if (max_matches > 0) {
  cplex_times <- transpose(cplex_times)
} else {
  cplex_times <- list()
}

# Extraction complete, loaded .log and .out files are no longer needed
rm(log_files)
rm(out_files)

# ---- Collect the jobs data in a tibble / data frame -----

# Create a tibble with the collected jobs data
jobs <- tibble(experiment=unlist(experiments),
               cluster=clusters,
               run=runs,
               process=processes,
               submitted=submit_dtstrs,
               host=hosts,
               slot=unlist(slots),
               root=roots,
               `latency [s]`=latencies,
               `duration [s]`=durations)

# Add a combined host_slot column
jobs = add_column(jobs, host_slot=paste(jobs$host, jobs$slot))

# Add the extracted EXECUTION TIMEs to the jobs data
for (i in seq_along(execution_times)) {
  jobs = add_column(jobs, !!(str_glue("EXECUTION TIME {i} [s]")) := unlist(execution_times[[i]]))
}

# Add the extracted Cplex Times to the jobs data
for (i in seq_along(cplex_times)) {
  jobs = add_column(jobs, !!(str_glue("Cplex Time {i} [s]")) := unlist(cplex_times[[i]]))
}

# Before every column with [s] units, add derived columns with [min] and [h] units 
for (name in names(jobs)) {
  if (str_sub(name, -3, -1) == "[s]") {
    name_head = str_sub(name, 1, -4)
    jobs = add_column(jobs, !!(str_glue("{name_head}[h]")) := jobs[[name]]/3600, .before=name)
    jobs = add_column(jobs, !!(str_glue("{name_head}[min]")) := jobs[[name]]/60, .before=name)
  }
}

# ---- Analyse jobs data ----

# Plot
ggplot(jobs, aes(x=process, y=host_slot, color=run)) + geom_point() + ggtitle("slot allocation")
ggplot(jobs, aes(x=process, y=`latency [min]`, color=run)) + geom_point(alpha=1/2) + geom_point(aes(y=`latency [min]`+`duration [min]`), alpha=1/2) + geom_segment(aes(xend=process, yend=`latency [min]`+`duration [min]`), alpha=1/5) + ylab("job start-stop time after submission [min]")
ggplot(jobs, aes(x=process, y=`latency [min]`, color=slot)) + geom_point(alpha=1) + geom_point(aes(y=`latency [min]`+`duration [min]`), alpha=1) + geom_segment(aes(xend=process, yend=`latency [min]`+`duration [min]`), alpha=1) + ylab("job start-stop time after submission [min]")
ggplot(jobs, aes(x=process, y=`duration [min]`, color=run)) + geom_smooth(method="lm", se=FALSE) + geom_point()
ggplot(jobs, aes(x=host, y=`duration [min]`, color=run)) + geom_point()
if ("EXECUTION TIME 1 [s]" %in% names(jobs)) ggplot(jobs, aes(x=process, y=`EXECUTION TIME 1 [min]`, color=run)) + geom_smooth(method="lm", se=FALSE)  + geom_point()
if ("EXECUTION TIME 2 [s]" %in% names(jobs)) ggplot(jobs, aes(x=process, y=`EXECUTION TIME 2 [min]`, color=run)) + geom_smooth(method="lm", se=FALSE)  + geom_point()
if ("Cplex Time 1 [s]" %in% names(jobs)) ggplot(jobs, aes(x=process, y=`Cplex Time 1 [min]`, color=run)) + geom_smooth(method="lm", se=FALSE) + geom_point()
if ("Cplex Time 1 [s]" %in% names(jobs)) ggplot(jobs, aes(x=host, y=`Cplex Time 1 [min]`, color=run)) + geom_point()

# Print summary
print(jobs %>%
      select(experiment, cluster, submitted, `duration [min]`, `latency [h]`, `duration [h]`) %>%
      group_by(cluster) %>%
      summarize(experiment=dplyr::first(experiment),
                submitted=min(submitted),
                `processes`=n(),
                `mean [min]`=mean(`duration [min]`),
                `stdev [min]`=sd(`duration [min]`),
                `min [min]`=min(`duration [min]`),
                `max [min]`=max(`duration [min]`),
                `throughput [jobs/h]`=n()/max(`latency [h]`+`duration [h]`)) %>%
      arrange(cluster)
)

options(tibble.print_max = Inf)

# Print summary grouped by job cluster and host
print(jobs %>%
      select(experiment, cluster, host, submitted, `duration [min]`) %>%
      group_by(cluster,host) %>%
      summarize(experiment=dplyr::first(experiment),
                submitted=min(submitted),
                `processes`=n(),
                `mean [min]`=mean(`duration [min]`),
                `stdev [min]`=sd(`duration [min]`),
                `min [min]`=min(`duration [min]`),
                `max [min]`=max(`duration [min]`)) %>%
      arrange(host, cluster)
)
