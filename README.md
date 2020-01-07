# Condor_run_R
R scripts to submit and analyse [HT Condor](https://research.cs.wisc.edu/htcondor/) runs

## Author
Albert Brouwer

## Introduction
This repository provides R scripts for submitting a Condor *run* (a set of jobs) to a cluster of execute hosts and analysing performance statistics. Three scripts are provided:
1. `Condor_run_basic.R`: generic submit script.
2. `Condor_run.R`: submit script with enhanced functionality for [GAMS](https://www.gams.com/) jobs.
3. `Condor_run_stats.R`: analyse and plot run performance statistics.

## Installation
The scripts are self-contained and hence can be copied to a place conviently co-located with your model/project files. Of course, you need to have [R](https://www.r-project.org/) installed to be able to run the scripts. The only non-base R packages used are from the [tidyverse](https://www.tidyverse.org/) package collection. Please ensure that you have the tidyverse installed.

For submission, you in addition need a local [HT Condor installation](https://research.cs.wisc.edu/htcondor/downloads/) and [7-Zip](https://www.7-zip.org/) (on Windows) or the `p7zip` package (on Linux) install. A recent version of both is required since some of their newer features are used.

Test that `condor_status`, `Rscript`, and `7z` can be invoked from the command line. When this does not work, add the appropriate installation directories to your `PATH` environment variable.

## Test
To check your installation, run the test in the `test_basic` subdirectory. The test can be started by running the cross-platform script `test.bat`.

The test submits a run of several small R jobs via `Condor_run_basic.R` and after completion performs analysis using `Condor_run_stats.R`. The plots can be viewed by opening the resulting `Rplots.pdf` file.

## Use
Invoke the submit scripts via Rscript, or, on Linux/MacOS, you can invoke the script directly if its execute flag is set and the script has been converted to Unix format using e.g. `dos2unix` (removing the carriage returns from the line breaks). The analysis script `Condor_run_stats.R` is best run from RStudio. The submit scripts take as command line argument the name of a file with configuration settings. 

A typical invocation command line is therefore

`Rscript Condor_run_basic.R config.R`

To set up a configuration file, copy the code block between *snippy snappy* lines from the submit script into your clipboard, and save it to a file with an `.R` extension (e.g. `config.R`). The configuration settings use R syntax, so using an `.R` extension will provide syntax highlighting if you are using a good text editor or [RStudio](https://rstudio.com/). Read the comments for each setting and customize as required.

## Function of submit scripts
1. Bundle up the job files using 7-Zip.
2. Submit the bundle once to each of the execute hosts.
   - The execute hosts are made to cache the bundle in a separate directory.
3. Submit jobs to all of the execute hosts.
   - For each job, the allocated execute host unpacks the bundle.
4. Optionally wait for the jobs to finish
5. Optionally merge GAMS GDX results files (`Condor_run.R`)

By transferring the bundle once for each execute host instead of once for each job in the run, network bandwidth requirements are minimized.

By passing the job number to the main script of the job, each job in the run can customize the calculation, e.g. by selecting one out of a collection of scenarios.

## Troubleshooting
When you cannot submit jobs, ensure that:
- You have obtained access to the Condor cluster from the cluster administrator.
- You stored the necessary credentials via `condor_store_cred` (ask your administrator).
- Issuing the command `condor_submit` tabulates the cluster status.
- Issuing the command `condor_q` results in a summary of queued jobs.
- You set the HOST_REGEXP configuration option to select the right subset of execute hosts from the cluster.

### The script does not progress
Your command prompt or terminal may be blocked because you pressed a key. Give the window focus and try hitting backspace or CTRL-Q.

### Jobs do not run but instead go on hold
Likely, some error occurred. First look at the output of the ``Condor_run[_basic].R``
script for clues. If that is not sufficient, have a look at the various log files
located at ``<CONDOR_DIR>/<EXPERIMENT>``. In order of priority:
1.  Check the ``.log`` files: is it a Condor scheduling problem?
2.  Check the ``.err`` files: standard error stream of the remote job. When not empty,
    likely some error occurred.
3.  Check the ``.out`` files: standard output of the remote job. Look for errors/warnings
    towards the end.
4.  Check the ``.lst`` files: GAMS listing file, search for error details. For GAMS jobs
    only.
5.  If all else fails, execute ``condor_q –analyze``: it might be something that
    happened after the job completed, e.g. result files not fitting because your
    disk is full.

### Jobs go on hold, but I see no log files
When no log files are produced in the ``<CONDOR_DIR>/<EXPERIMENT>`` directory,
the Condor service on your submit machine may not have access rights to write its
logging output there. This causes jobs to go on hold. Check the permissions
on the directory, or when it is on a network drive, try submitting the job from
a local disk instead.

### Jobs are idle and do not run, or only some do
The cluster may be busy. To see who else has submitted jobs, issue `condor_status -submitters`. In addition, you may have a low priority so that jobs of others are given priority, pushing your jobs to the back of the queue. To see your priority issue `condor_userprio`. Large numbers mean low priority. Your cluster administrator can set your priority.

### But why?
For further information, see the [why is the job not running?](https://htcondor.readthedocs.io/en/latest/users-manual/managing-a-job.html#why-is-the-job-not-running) section of the HTCondor manual.
