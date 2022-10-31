![License](https://img.shields.io/github/license/iiasa/Condor_run_R)
[![Check Links](https://github.com/iiasa/Condor_run_R/actions/workflows/links.yml/badge.svg)](https://github.com/iiasa/Condor_run_R/actions/workflows/links.yml)

# Condor_run_R

R scripts to conveniently and quickly submit and analyse sets of [HT Condor](https://research.cs.wisc.edu/htcondor/htcondor/overview/) jobs requiring many files and/or much input data.

## Author

Albert Brouwer

___

- [Introduction](#%E2%84%B9%EF%B8%8F-introduction)
- [Installation](#installation)
- [Test](#test)
- [Updating](#updating)
- [Function of submit scripts](#function-of-submit-scripts)
- [Use](#use)
  + [Configuring](configuring.md)
- [Job output](#job-output)
- [Troubleshooting](troubleshooting.md)
- [Configuring a Condor cluster in support of `Condor_run_R`](condor.md#configuring-a-condor-cluster-in-support-of-condor_run_r)

## ℹ️ Introduction

This repository provides R scripts for submitting a *run* (a set of jobs) to an HT Condor cluster, and for analysing run performance statistics. Four scripts are provided:
1. [`Condor_run_basic.R`](https://github.com/iiasa/Condor_run_R/blob/master/Condor_run_basic.R): generic submit script suitable for any kind of job.
2. [`Condor_run.R`](https://github.com/iiasa/Condor_run_R/blob/master/Condor_run.R): submit script with enhanced functionality for [GAMS](https://www.gams.com/) jobs.
3. [`Condor_run_stats.R`](https://github.com/iiasa/Condor_run_R/blob/master/Condor_run_stats.R): analyses run statistics and produces a report such as [this one](tests/basic/basic_2022-03-07.pdf). Can be used to [tune cluster throughput](condor.md#tuning-throughput).
4. [`restart_version.R`](https://github.com/iiasa/Condor_run_R/blob/master/restart_version.R): displays the GAMS version with which a specified restart file was saved.

The advantages of using these scripts over using [`condor_submit`](https://htcondor.readthedocs.io/en/latest/man-pages/condor_submit.html) directly are:
- Manages submission of a set of related jobs in one go.
- Conveniently collect many files into a submit bundle.
  * For jobs using many source and/or data files.
- Allows (re-)submission of an existing bundle for:
  * Submission from a separate submit node.
  * Reproducible re-runs with the same set of files.
- Replicate the project file tree on your submit machine to the remote scratch directory on the machine where a job is executed: an Execution Point (EP) in HTCondor terminology.
- The submit bundle is compressed and takes less time to send to an EP.
- EPs cache the bundle so that it needs to be sent over only once per EP instead of once per job, avoiding network contention or the hassle of instead setting up a shared network-accessible filesystem.
- Jobs can be [monitored until they complete](configuring.md#wait_for_run_completion) so that it becomes easy to automate handling of run output.
- Provides for configurable retry of on-hold jobs so as to recover from transient errors.

## Installation

Download the latest release [here](https://github.com/iiasa/Condor_run_R/releases) and unpack the archive. The R scripts in the root directory are self-contained and hence can be copied to a place conveniently co-located with your model/project files. Of course, you need to have [R](https://www.r-project.org/) installed to be able to run the scripts. All packages that are required and not installed with R by default are from the [tidyverse](https://www.tidyverse.org/) package collection. Please ensure that you have the tidyverse installed.

The `Condor_run_stats.R` analysis script will produce graphical summary tables if you have the [gridExtra](https://github.com/baptiste/gridextra/) package installed, but this is not required.

For submission, you in addition need a local [HT Condor installation](https://research.cs.wisc.edu/htcondor/downloads/) and [7-Zip](https://www.7-zip.org/) (on Windows) or the `p7zip` package (on Linux) installed and on-path. A recent version of both is required since some of their newer features are used.

Test that [`condor_status`](https://htcondor.readthedocs.io/en/latest/man-pages/condor_status.html), `Rscript`, and `7z` can be invoked from the command line. When this does not work, add the appropriate installation directories to your `PATH` environment variable. [See here](https://iiasa.github.io/GLOBIOM/R.html#setting-environment-variables) for instructions on how to do so.

## Test

This repository includes [tests](tests/tests.md). To check your setup, run the [`basic` test](tests/basic/purpose.md) via the `test.bat` batch file (Windows) or `test.sh` shell script (MacOS/Linux) located in the `tests/basic` subdirectory. The `basic` test submits a run of several small R jobs via `Condor_run_basic.R` and after completion performs analysis using `Condor_run_stats.R`. The plots can be viewed by opening the resulting PDF file.

## Updating

It is recommended to always update to the latest release of the scripts so that you have the latest fixes and features. Do so by downloading the `.zip` or `.tar.gz` linked on [the releases page](https://github.com/iiasa/Condor_run_R/releases). Releases are typically backwards compatible and should work with your existing run configurations. Before updating, read the release notes shown on the releases page.

Automatic notification of new releases can be enabled by going to the [main repository page](https://github.com/iiasa/Condor_run_R), clicking on the Watch/Unwatch drop down menu button at the top right of the page, and check marking **Custom → Releases**. You need to be signed in to GitHub for this to work.

## Function of submit scripts

1. Bundle up the job files using 7-Zip.
2. Seed the execution points (EPs) with the bundle.
   - Seeding jobs transfer the bundle once for each EP.
   - The EP cache the bundle for use by your jobs.
3. Submit the jobs.
   - Jobs unpack the cached bundle when run.
5. Optionally [wait for the jobs to finish](configuring.md#wait_for_run_completion).
6. Optionally [merge GAMS GDX output files](configuring.md#merge_gdx_output) (`Condor_run.R`)

By transferring the bundle once for each EP instead of once for each job in the run, network bandwidth requirements are minimized.

When a job is run on an EP, the cached bundle is decompressed in a scratch directory. This creates the file tree that the job needs to run. By passing the job number to the main script of the job, each job in the run can customize the calculation even though it is using the same bundle as input, e.g. by using the job number to select one scenario out of a collection of scenarios.

## Use

Use the `Condor_run_basic.R` submit script for generic runs and the `Condor_run.R` submit script for GAMS runs. On Windows, invoke via `Rscript`. On MacOS/Linux that is not necessary ([shebang invokaction](https://en.wikipedia.org/wiki/Shebang_(Unix))).

To bundle and submit a run, use:

`[Rscript ][path to]Condor_run[_basic].R <configuration file>.R`

To only bundle the files and preserve the bundle, use:

`[Rscript ][path to]Condor_run[_basic].R --bundle-only <configuration file>.R`

This can also be achieved by setting [`BUNDLE_ONLY = TRUE`](configuring.md#bundle_only) in the configuration file. To learn how to set up a configuration file, see the [documentation on configuring](configuring.md).

To (re)seed a bundle and (re)submit a run from a pre-existing bundle, use:

`[Rscript ][path to]Condor_run[_basic].R <bundle file>.7z`

**:point_right:Note:** the configuration settings provided on creation of the bundle are used. These are stored in the bundle as a checkpoint file during bundling.

After a run completes, the analysis script `Condor_run_stats.R` can be used to obtain plots and statistics on run and cluster performance. This script can be run from [RStudio](https://rstudio.com/) or the command line via `Rscript`. The command line arguments specify which runs to analyse and can either be a submit configuration `.R` file or a paths to a [directory containing run log files and other artifacts](configuring.md#condor_dir).

When passing a configuration file as one of the arguments to `Condor_run_stats.R`, and the [`CONDOR_DIR`](configuring.md#condor_dir) configuration setting holds a relative path or is absent and therefore has its default relative path setting, the current working directory must be the same as was the case when invoking `Condor_run.R` or `Condor_run_basic.R` with that configuration file because otherwise the log directory cannot be located.

An example command line invocation is:

`Rscript Condor_run_stats.R Condor/2021-11-25 config.R`

This produces a PDF with plots in the current working directory. When invoking `Condor_run_stats.R` from RStudio by sourcing the script, set the first instance of LOG_DIRECTORIES to the path or paths of one or more directories containing Condor run log files to be analysed.

**:warning:Beware:** when you have made customizations to your R installation via site, profile or user environment files, this may cause anomalies that make it necessary to have `Rscript` ignore these customizations by using the `Rscript --vanilla` option on invocation.

## Job output

Each job will typically produce some kind of output. For R jobs this might be an `.RData` file. For GAMS jobs this is likely to be a GDX or a restart file. There are many ways to produce output. In R, objects can be saved to `.RData` files with the [`save()`](https://www.rdocumentation.org/packages/base/versions/3.6.2/topics/save) function. In GAMS, GDX files of everything can be dumped at the end of execution via the [GDX](https://www.gams.com/latest/docs/UG_GamsCall.html#GAMSAOgdx) command line option, or selectively written at run time using [execute_unload](https://www.gams.com/latest/docs/UG_GDX.html#UG_GDX_WRITE_EXECUTION). Restart (`.g00`) files can be saved with the [save](https://www.gams.com/latest/docs/UG_GamsCall.html#GAMSAOsave) command line option. And so on.

The submit scripts contain default functionality that has Condor transfer job output back to the submit machine as each job completes. The relevant configuration settings are [`GET_OUTPUT`](configuring.md#get_output), [`OUTPUT_DIR`](configuring.md#output_dir), and [`OUTPUT_FILE`](configuring.md#output_file) for `Condor_run_basic.R`. For GAMS runs using `Condor_run.R`, the [`G00_OUTPUT_DIR`](configuring.md#g00_output_dir), [`G00_OUTPUT_FILE`](configuring.md#g00_output_file), [`GET_G00_OUTPUT`](configuring.md#get_g00_output), [`GDX_OUTPUT_DIR`](configuring.md#gdx_output_dir), [`GDX_OUTPUT_FILE`](configuring.md#gdx_output_file) and [`GET_GDX_OUTPUT`](configuring.md#get_gdx_output) configs can be used. Note that the files are renamed on receipt with unique numbers for the run and job so that the output files from different runs and jobs are kept separate.

When you do not need to automatically process the output, you can configure [`WAIT_FOR_RUN_COMPLETION`](configuring.md#wait_for_run_completion)` = FALSE`. Condor background processes on the submit machine will track job progress and receive job output. This tacking can survive a suspend or reboot of the submit machine, but not without causing a delay in job completion: it is better to keep the submit machine connected and running.

To automatically process job output, configure [`WAIT_FOR_RUN_COMPLETION`](configuring.md#wait_for_run_completion)` = TRUE`and write a batch file or shell script that includes the [submit invocation](#use) followed by output processing steps. For GAMS jobs, retrieved GDX files can be automatically merged first as configured by the [`MERGE_GDX_OUPTUT`](configuring.md#merge_gdx_ouptut), [`MERGE_BIG`](configuring.md#merge_big), [`MERGE_EXCLUDE`](configuring.md#merge_exclude) and [`REMOVE_MERGED_GDX_FILES`](configuring.md#remove_merged_gdx_files) options (`Condor_run.R`).

## Troubleshooting

When your cannot submit or a problem occurs at a later stage, please explore the [troubleshooting documentation](troubleshooting.md) for solutions.
