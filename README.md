# Condor_run_R
R scripts to submit and analyse [HT Condor](https://research.cs.wisc.edu/htcondor/) runs

## Author
Albert Brouwer

## Introduction
This repository provides R scripts for submitting a Condor run (a set of jobs) to a cluster of execute hosts and analysing performance statistics. Three scripts are provided:
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

By transferring the bundle once for each execute host instead of once for each job in the run, a lot of network bandwidth is avoided when the job files being bundled include a lot of data.

By passing the job number to the main script of the job, each job in the run can customize the calculation, e.g. by selecting one out of a collection of scenarios.
