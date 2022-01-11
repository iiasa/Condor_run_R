![License](https://img.shields.io/github/license/iiasa/Condor_run_R)

# Condor_run_R
R scripts to conveniently and quickly submit and analyse [HT Condor](https://research.cs.wisc.edu/htcondor/htcondor/overview/) jobs requiring many files and/or much input data.

## Author
Albert Brouwer

___

- [Introduction](#introduction)
- [Installation](#installation)
- [Test](#test)
- [Updating](#updating)
- [Function of submit scripts](#function-of-submit-scripts)
- [Use](#use)
  + [Configuring](configuring.md)
- [Job output](#job-output)
- [Troubleshooting](troubleshooting.md)

## Introduction
This repository provides R scripts for submitting a *run* (a set of jobs) to a HT Condor  cluster, and for analysing run performance statistics. Four scripts are provided:
1. [`Condor_run_basic.R`](https://github.com/iiasa/Condor_run_R/blob/master/Condor_run_basic.R): generic submit script suitable for any kind of job.
2. [`Condor_run.R`](https://github.com/iiasa/Condor_run_R/blob/master/Condor_run.R): submit script with enhanced functionality for [GAMS](https://www.gams.com/) jobs.
3. [`Condor_run_stats.R`](https://github.com/iiasa/Condor_run_R/blob/master/Condor_run_stats.R): analyse and plot run performance statistics.
4. [`restart_version.R`](https://github.com/iiasa/Condor_run_R/blob/master/restart_version.R): displays the GAMS version with which a specified restart file was saved.

The advantages of using these scripts over using [`condor_submit`](https://htcondor.readthedocs.io/en/latest/man-pages/condor_submit.html) directly are:
- Conveniently collect many files into a submit bundle.
  * For jobs using many source and/or data files.
- Replicate the project file tree on your submit machine to the remote scratch directory on the machine where a job is executed (execute host).
- The submit bundle is compressed and takes less time to send to an execute host.
- Execute hosts cache the bundle so that it needs to be sent over only once per host instead of once per job, avoiding network contention or the hassle of instead setting up a shared network-accessible filesystem.
- Submit machines (e.g. laptops) can disconnect from the cluster during the run, and re-connect later to receive output.
- Can monitor jobs and wait for their completion so that it becomes easy to automate handling of run output.

## Installation
Download the latest release [here](https://github.com/iiasa/Condor_run_R/releases) and unpack the archive. The R scripts in the root directory are self-contained and hence can be copied to a place conviently co-located with your model/project files. Of course, you need to have [R](https://www.r-project.org/) installed to be able to run the scripts. All packages that are required and not installed with R by default are from the [tidyverse](https://www.tidyverse.org/) package collection. Please ensure that you have the tidyverse installed.

The `Condor_run_stats.R` analysis script will produce graphical summary tables if you have the [gridExtra](https://github.com/baptiste/gridextra/) package installed, but this is not required.

For submission, you in addition need a local [HT Condor installation](https://research.cs.wisc.edu/htcondor/downloads/) and [7-Zip](https://www.7-zip.org/) (on Windows) or the `p7zip` package (on Linux) install. A recent version of both is required since some of their newer features are used.

Test that [`condor_status`](https://htcondor.readthedocs.io/en/latest/man-pages/condor_status.html), `Rscript`, and `7z` can be invoked from the command line. When this does not work, add the appropriate installation directories to your `PATH` environment variable. [See here](https://iiasa.github.io/GLOBIOM/R.html#setting-environment-variables) for instructions on how to do so.

## Test
This repository includes [tests](tests/tests.md). To check your setup, run the [`basic` test](tests/basic/purpose.md) via the `test.bat` batch file (Windows) or `test.sh` shell script (MacOS/Linux) located in the `tests/basic` subdirectory. The `basic` test submits a run of several small R jobs via `Condor_run_basic.R` and after completion performs analysis using `Condor_run_stats.R`. The plots can be viewed by opening the resulting PDF file.

## Updating
It is recommended to always update to the [latest release of the scripts](https://github.com/iiasa/Condor_run_R/releases) so that you have the latest fixes and features. Releases are typically backwards compatible and should work with your existing run configurations. Before updating, read the release notes. Automatic notification of new releases can be enabled by going to the [main repository page](https://github.com/iiasa/Condor_run_R), clicking on the Watch/Unwatch drop down menu button at the top right of the page, and check marking Custom → Releases. You need to be signed in to GitHub for this to work.

## Function of submit scripts
1. Bundle up the job files using 7-Zip.
2. Seed the execute hosts with the bundle.
   - Seeding jobs transfer the bundle once for each execute host.
   - The execute hosts cache the bundle for use by your jobs.
3. Submit the jobs.
   - Jobs unpack the cached bundle when run.
5. Optionally wait for the jobs to finish
6. Optionally merge GAMS GDX output files (`Condor_run.R`)

By transferring the bundle once for each execute host instead of once for each job in the run, network bandwidth requirements are minimized.

When a job is run on an execute host, the cached bundle is decompressed in a scratch directory. This creates the file tree that the job needs to run. By passing the job number to the main script of the job, each job in the run can customize the calculation even though it is using the same bundle as input, e.g. by using the job number to select one scenario out of a collection of scenarios.

**Beware:** only when the jobs of the run are queued can an additional run be submitted. This is after the submit script prints the message

`It is now possible to submit additional runs.`

The submit script enforces this by using the bundle as a lock file. If you abort the script or an error occurs before the above message appears, you will need to remove the bundle to free the lock. The script will throw an explanatory error until you do.

## Use
Invoke the submit script via `Rscript`. Use the `Condor_run_basic.R` submit script for generic runs and `Condor_run.R` for GAMS runs. Both take a `.R` configuration file as only argument. An example invocation is:

`Rscript Condor_run_basic.R config.R`

If you have made customizations to your R installation via site, profile or user environment files, it may be necessary to have `Rscript` ignore these customizations by using the `--vanilla` option, e.g.:

`Rscript --vanilla Condor_run.R config.R`

To learn how to set up a configuration file, see the [documentation on configuring](configuring.md).

After a run completes, the analysis script `Condor_run_stats.R` can be used to obtain plots and statistics on run and cluster performance. This script can be run from [RStudio](https://rstudio.com/) or the command line via `Rscript`. The command line arguments specify which runs to analyse and can either be a submit configuration `.R` file or a paths to a [directory containing run log files and other artifacts](configuring.md#condor_dir).

When passing a configuration file as one of the arguments to `Condor_run_stats.R`, and the [`CONDOR_DIR`](configuring.md#condor_dir) configuration setting holds a relative path or is absent and therefore has its default relative path setting, the current working directory must be the same as was the case when invoking `Condor_run.R` or `Condor_run_basic.R` with that configuration file because otherwise the log directory cannot be located.

An example command line invocation is:

`Rscript Condor_run_stats.R Condor/2021-11-25 config.R`

This produces a PDF with plots in the current working directory. When invoking `Condor_run_stats.R` from RStudio by sourcing the script, set the first instance of LOG_DIRECTORIES to the path or paths of one or more directories containing Condor run log files to be analysed.

On Linux/MacOS, all three scripts can also be invoked directly without a leading `Rscript` on the command line ([shebang invocation](https://en.wikipedia.org/wiki/Shebang_(Unix))).

## Job output
Each job will typically produce some kind of output. For R jobs this might be an `.RData` file. For GAMS jobs this is likely to be a GDX or a restart file. There are many ways to produce output. In R, objects can be saved to `.RData` files with the [`save()`](https://www.rdocumentation.org/packages/base/versions/3.6.2/topics/save) function. In GAMS, GDX files of everything can be dumped at the end of execution via the [GDX](https://www.gams.com/latest/docs/UG_GamsCall.html#GAMSAOgdx) command line option, or selectively written at run time using [execute_unload](https://www.gams.com/latest/docs/UG_GDX.html#UG_GDX_WRITE_EXECUTION). Restart (`.g00`) files can be saved with the [save](https://www.gams.com/latest/docs/UG_GamsCall.html#GAMSAOsave) command line option. And so on.

The submit scripts contain default functionality that has Condor transfer job output back to the submit machine as each job completes. The relevant configuration settings are [`GET_OUTPUT`](configuring.md#get_output), [`OUTPUT_DIR`](configuring.md#output_dir), and [`OUTPUT_FILE`](configuring.md#output_file) for R runs using `Condor_run_basic.R`. For GAMS runs using `Condor_run.R`, the [`G00_OUTPUT_DIR`](configuring.md#g00_output_dir), [`G00_OUTPUT_FILE`](configuring.md#g00_output_file), [`GET_G00_OUTPUT`](configuring.md#get_g00_output), [`GDX_OUTPUT_DIR`](configuring.md#gdx_output_dir), [`GDX_OUTPUT_FILE`](configuring.md#gdx_output_file) and [`GET_GDX_OUTPUT`](configuring.md#get_gdx_output) configs can be used. Note that the files are renamed on receipt with unique numbers for the run and job so that the output files from different runs and jobs are kept separate.

When you do not need to automatically process the output, you can configure [`WAIT_FOR_RUN_COMPLETION`](configuring.md#wait_for_run_completion)` = FALSE` and disconnect or shut down the machine you submit from (which might be a laptop you want to take home) for the duration of the run. Without a connected submit machine, idle (queued) jobs will still be scheduled because the cached bundle suffices and no further transfer of input data from the submit machine is needed. A disconnected submit machine will receive the output data after it reconnects to the cluster, but you will need to manually trigger the processing of the output.

To automatically process job output, configure [`WAIT_FOR_RUN_COMPLETION`](configuring.md#wait_for_run_completion)` = TRUE`and write a batch file or shell script that includes the submit invocation followed by output processing steps. For GAMS jobs, retrieved GDX files can be automatically merged first as configured by the [`MERGE_GDX_OUPTUT`](configuring.md#merge_gdx_ouptut), [`MERGE_BIG`](configuring.md#merge_big), [`MERGE_EXCLUDE`](configuring.md#merge_exclude) and [`REMOVE_MERGED_GDX_FILES`](configuring.md#remove_merged_gdx_files) options (`Condor_run.R`).

## Troubleshooting
When your cannot submit or a problem occurs at a later stage, please explore the [troubleshooting documentation](troubleshooting.md) for solutions.
