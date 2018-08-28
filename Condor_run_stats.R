# Extract and plot stats from output files of Condor runs

# Experiment names you gave to your Condor runs
#EXPERIMENTS <- c("test1", "test2")
#EXPERIMENTS <- c("ICAO_Jet_aa_new")
#EXPERIMENTS <- c("CIRA2_reg_all")
EXPERIMENTS <- c("limpopo1_original", "limpopo1_original_b", "limpopo1_affinity", "limpopo1_affinity_b", "limpopo1_affinity_c", "limpopo1_affinity_d")
# Job $(Cluster) number string, use * or ? wildcards to match multiple cluster numbers
#CLUSTER <- "83?" 
CLUSTER <- "*"
# Name of directory under Model/Condor with output files to analyze. Set to NULL to default to the experiment name.
SUBDIRECTORY <- NULL
#SUBDIRECTORY <- "Hugo"
#SUBDIRECTORY <- "Petr"

# Map known IP4s to hostnames for readability
hostname_map <- c("147.125.99.211"="limpopo1",
                  "147.125.99.212"="limpopo2",
                  "147.125.99.213"="limpopo3",
                  "147.125.99.214"="limpopo4",
                  "147.125.99.220"="limpopo5")

# Required packages
library(tidyverse)

# Alphabetically list the .out and .log files resulting from the Condor run and check that they match up
if (basename(getwd()) != "R") stop("Directory R at the GLOBIOM root must be the working directory! When running this script using RScript from the command line, CD into the R directory first. When running this script from RStudio, make sure R is the project directory.")
out_files <- c()
log_files <- c()
experiments <- list() # expanded to a per-job list
for (experiment in EXPERIMENTS) {
  if (is.null(SUBDIRECTORY)) {
    experiment_dir<-file.path(getwd(), "..", "Model", "Condor", experiment)
  } else {
    experiment_dir<-file.path(getwd(), "..", "Model", "Condor", SUBDIRECTORY)
  }
  if (!dir.exists(experiment_dir)) stop(str_glue("Experiment directory not found! Expected location: {experiment_dir}!"))
  outs <- list.files(path=experiment_dir, pattern=str_glue("*_{experiment}_{CLUSTER}.*.out"), full.names=TRUE, recursive=FALSE)
  out_files <- c(out_files, outs)
  logs <- list.files(path=experiment_dir, pattern=str_glue("*_{experiment}_{CLUSTER}.*.log"), full.names=TRUE, recursive=FALSE)
  log_files <- c(log_files, logs)
  experiments <- c(experiments, rep(experiment, length(logs)))
}
if (length(out_files)!=length(log_files)) stop(str_glue("The number of .out ({length(out_files)}) and .log ({length(log_files)}) files should be equal!"))
if (length(out_files)==0) stop(str_glue("No output files for CLUSTER {CLUSTER} found in {experiment_dir}!"))

# Reduce the list of .out and .log file paths to extensionless root paths of these job output files and check that they are the same
for (i in seq_along(out_files))
  out_files[i] <- str_sub(out_files[i], 1, -5)
for (i in seq_along(log_files))
  log_files[i] <- str_sub(log_files[i], 1, -5)
if (!all(out_files==log_files)) stop("The .out and .log files for CLUSTER {CLUSTER} found in {experiment_dir} do not match up!")
roots <- as.list(out_files)

# Remove aborted jobs
indices_of_aborted_jobs = c()
for (i in seq_along(roots)) {
  hits <- grep("\\) \\d\\d/\\d\\d \\d\\d:\\d\\d:\\d\\d Job was aborted", readLines(str_glue("{roots[i]}.log")))
  if (length(hits) > 0) {
    indices_of_aborted_jobs <- c(i, indices_of_aborted_jobs) # need inverse order for removal
    warning(str_glue("Ignoring aborted job {roots[i]}"))
  }
}
for (i in indices_of_aborted_jobs) {
  roots[i] = NULL
  experiments[i] = NULL
}
if (length(roots) == 0) stop("No jobs left to analyze!")

# Extract the experiment cluster strings and process numbers
clusters = c()
runs = c() # {experiment}_{cluster} labels for plotting
processes = c()
for (i in seq_along(roots)) {
  mat <- str_match(roots[i], ".*_([0-9]+)[.]([0-9]+)$")
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
for (root in roots) {
  lines <- grep("\\) \\d\\d/\\d\\d \\d\\d:\\d\\d:\\d\\d Job submitted from host:", readLines(str_glue("{root}.log")), value=TRUE)
  if (length(lines) != 1) stop(str_glue("Cannot extract termination time from {root}.log!"))
  dtstr <- str_match(lines[1], "\\) (\\d\\d/\\d\\d \\d\\d:\\d\\d:\\d\\d) Job submitted from host:")[2]
  if (is.na(dtstr)) stop(str_glue("Cannot decode termination time from {root}.log"))
  submit_dtstrs <- c(submit_dtstrs, dtstr)
  # Use guessed year (can fail for leap days)
  submit_times <- c(submit_times, list(strptime(str_glue("{current_year}/{dtstr}"), "%Y/%m/%d %H:%M:%S")))
  submit_times_minus_1y <- c(submit_times_minus_1y, list(strptime(str_glue("{current_year-1}/{dtstr}"), "%Y/%m/%d %H:%M:%S")))
}

# Extract the job execution start times (with uncertain year) and hosts from the .log files
start_times <- list()
start_times_minus_1y <- list()
hosts <- c()
for (root in roots) {
  lines <- grep("\\) \\d\\d/\\d\\d \\d\\d:\\d\\d:\\d\\d Job executing on host: <\\d+\\.\\d+\\.\\d+\\.\\d+:", readLines(str_glue("{root}.log")), value=TRUE)
  if (length(lines) < 1) stop(str_glue("Cannot extract execution start time from {root}.log!"))
  if (length(lines) > 1) warning(str_glue("Execution started multiple times for job. Probably the initial execution host disconnected. See {root}.log!"))
  # Pick the last execution start time since that's on the host that can be assumed to have made it to the end.
  mat <- str_match(lines[length(lines)], "\\) (\\d\\d/\\d\\d \\d\\d:\\d\\d:\\d\\d) Job executing on host: <(\\d+\\.\\d+\\.\\d+\\.\\d+):")
  dtstr = mat[2]
  ipstr = mat[3]
  if (is.na(dtstr)) stop(str_glue("Cannot decode execution start time from {root}.log"))
  if (is.na(ipstr)) stop(str_glue("Cannot decode execution host IP from {root}.log"))
  # Use guessed year (can fail for leap days)
  start_times = c(start_times, list(strptime(str_glue("{current_year}/{dtstr}"), "%Y/%m/%d %H:%M:%S")))
  start_times_minus_1y = c(start_times_minus_1y, list(strptime(str_glue("{current_year-1}/{dtstr}"), "%Y/%m/%d %H:%M:%S")))
  if (is.na(hostname_map[ipstr])) host <- ipstr
  else host <- hostname_map[ipstr]
  hosts = c(hosts, host)
}

# Extract the job terminate times (with uncertain year) from the .log files
terminate_times <- list()
for (root in roots) {
  lines <- grep("\\) \\d\\d/\\d\\d \\d\\d:\\d\\d:\\d\\d Job terminated.$", readLines(str_glue("{root}.log")), value=TRUE)
  if (length(lines) != 1) stop(str_glue("Cannot extract termination time from {root}.log!"))
  dtstr <- str_match(lines[1], "\\) (\\d\\d/\\d\\d \\d\\d:\\d\\d:\\d\\d) Job terminated.$")[2]
  if (is.na(dtstr)) stop(str_glue("Cannot decode termination time from {root}.log"))
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

# Extract the EXECUTION TIME occurrences from the .out files
execution_times <- list()
max_matches <- 0
for (root in roots) {
  seconds <- c()
  for (line in grep("^EXECUTION TIME\\s+=\\s+[0-9]+[.][0-9]+ SECONDS", readLines(str_glue("{root}.out"), warn=FALSE), value=TRUE)) {
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
for (root in roots) {
  seconds <- c()
  for (line in grep("^Cplex Time: [0-9]+[.][0-9]+sec", readLines(str_glue("{root}.out"), warn=FALSE), value=TRUE)) {
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

# Create a tibble with the collected jobs data
jobs <- tibble(experiment=experiments,
               cluster=clusters,
               run=runs,
               process=processes,
               submitted=submit_dtstrs,
               host=hosts,
               root=roots,
               `latency [s]`=latencies,
               `duration [s]`=durations)

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

# ---
# Done constructing the Condor jobs tibble, proceed with analysis.
# ---

# Plot
ggplot(jobs, aes(x=process, y=`latency [min]`, color=run)) + geom_point()
ggplot(jobs, aes(x=process, y=`duration [min]`, color=run)) + geom_point()
ggplot(jobs, aes(x=host, y=`duration [min]`, color=run)) + geom_point()
if ("EXECUTION TIME 1 [s]" %in% names(jobs)) ggplot(jobs, aes(x=process, y=`EXECUTION TIME 1 [min]`, color=run)) + geom_point()
if ("EXECUTION TIME 2 [s]" %in% names(jobs)) ggplot(jobs, aes(x=process, y=`EXECUTION TIME 2 [min]`, color=run)) + geom_point()
if ("Cplex Time 1 [s]" %in% names(jobs)) ggplot(jobs, aes(x=process, y=`Cplex Time 1 [min]`, color=run)) + geom_point()
if ("Cplex Time 1 [s]" %in% names(jobs)) ggplot(jobs, aes(x=host, y=`Cplex Time 1 [min]`, color=run)) + geom_point()

# Print summary
print(jobs %>%
        select(experiment, cluster, submitted, `duration [min]`) %>%
        group_by(cluster) %>%
        summarize(experiment=dplyr::first(experiment),
                  submitted=min(submitted),
                  `not-aborted processes`=n(),
                  `min duration [min]`=min(`duration [min]`),
                  `mean duration [min]`=mean(`duration [min]`),
                  `stdev [min]`=sd(`duration [min]`),
                  `max duration [min]`=max(`duration [min]`)) %>%
        arrange(submitted)
)
