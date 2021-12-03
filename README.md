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
- [Use](#use)
  + [Configuring](configuring.md)
- [Troubleshooting](troubleshooting.md)
- [Function of submit scripts](#function-of-submit-scripts)
- [Job output](#job-output)
- [Adapting templates to your cluster](#adapting-templates-to-your-cluster)
- [Configuring execute hosts](#configuring-execute-hosts)

## Introduction
This repository provides R scripts for submitting a *run* (a set of jobs) to a HT Condor  cluster, and for analysing run performance statistics. Four scripts are provided:
1. `Condor_run_basic.R`: generic submit script suitable for any kind of job.
2. `Condor_run.R`: submit script with enhanced functionality for [GAMS](https://www.gams.com/) jobs.
3. `Condor_run_stats.R`: analyse and plot run performance statistics.
4. `restart_version.R`: displays the GAMS version with which a specified restart file was saved.

The advantages of using these scripts over using the [`condor_submit`](https://htcondor.readthedocs.io/en/latest/man-pages/condor_submit.html) directly are:
- Conveniently collect many files into a submit bundle.
- The submit bundle is compressed and takes less time to send to an execute host.
- Execute hosts can cache the bundle so that it needs to be sent over only once per host instead of once per job, avoiding network contention.
- Can monitor jobs and wait for their completion so that it becomes easy to automate handling of run output.

## Installation
Download the latest release [here](https://github.com/iiasa/Condor_run_R/releases) and unpack the archive. The R scripts in the root directory are self-contained and hence can be copied to a place conviently co-located with your model/project files. Of course, you need to have [R](https://www.r-project.org/) installed to be able to run the scripts. All packages that are required and not installed with R by default are from the [tidyverse](https://www.tidyverse.org/) package collection. Please ensure that you have the tidyverse installed.

For submission, you in addition need a local [HT Condor installation](https://research.cs.wisc.edu/htcondor/downloads/) and [7-Zip](https://www.7-zip.org/) (on Windows) or the `p7zip` package (on Linux) install. A recent version of both is required since some of their newer features are used.

Test that [`condor_status`](https://htcondor.readthedocs.io/en/latest/man-pages/condor_status.html), `Rscript`, and `7z` can be invoked from the command line. When this does not work, add the appropriate installation directories to your `PATH` environment variable. [See here](https://iiasa.github.io/GLOBIOM/R.html#setting-environment-variables) for instructions on how to do so.

## Test
This repository includes [tests](tests/tests.md). To check your setup, run the [`basic` test](tests/basic/purpose.md) via the cross-platform `test.bat` script located in the `tests/basic` subdirectory. The `basic` test submits a run of several small R jobs via `Condor_run_basic.R` and after completion performs analysis using `Condor_run_stats.R`. The plots can be viewed by opening the resulting PDF file.

## Updating
It is recommended to always update to the [latest release of the scripts](https://github.com/iiasa/Condor_run_R/releases) so that you have the latest fixes and features. Releases are typically backwards compatible and should work with your existing run configurations. Before updating, read the release notes. Automatic notification of new releases can be enabled by going to the [main repository page](https://github.com/iiasa/Condor_run_R), clicking on the Watch/Unwatch drop down menu button at the top right of the page, and check marking Custom → Releases. You need to be signed in to GitHub for this to work.

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

## Troubleshooting
When your cannot submit or a problem occurs at a later stage, please explore the [troubleshooting documentation](troubleshooting.md) for solutions.

## Function of submit scripts
1. Bundle up the job files using 7-Zip.
2. Submit the bundle once to each of the execute hosts.
   - The execute hosts are made to cache the bundle in a separate directory.
3. Submit the jobs.
4. Optionally wait for the jobs to finish
5. Optionally merge GAMS GDX results files (`Condor_run.R`)

By transferring the bundle once for each execute host instead of once for each job in the run, network bandwidth requirements are minimized and the submit machine (which might be a laptop) can be disconnected from the cluster or shut down on completion of submission. Without a connected submit machine, idle (queued) jobs will still be scheduled because the cached bundle suffices and no further transfer of input data from the submit machine is needed. A disconnected submit machine will receive the output data after it reconnects to the cluster.

By passing the job number to the main script of the job, each job in the run can customize the calculation even though it is given the same bundle as input, e.g. by selecting one out of a collection of scenarios.

**Beware:** only after the jobs are submitted can a further parallel submission be performed. The script notifies you thereof as follows:

`Run "test" has been submitted, it is now possible to submit additional runs while waiting for it to complete.`

The submit script enforces this by using the bundle as a lock file until step 3 completes. If you abort the script or an error occurs before then, you will need to remove the bundle to free the lock. The script will throw an explanatory error until you do.

## Job output
Each job will typically produce some kind of output. For R jobs this might be an `.RData` file. For GAMS jobs this is likely to be a GDX or a restart file. There are many ways to produce output. In R, objects can be saved to `.RData` files with the [`save()`](https://www.rdocumentation.org/packages/base/versions/3.6.2/topics/save) function. In GAMS, GDX files of everything can be dumped at the end of execution via the [GDX](https://www.gams.com/latest/docs/UG_GamsCall.html#GAMSAOgdx) command line option, or selectively written at run time using [execute_unload](https://www.gams.com/latest/docs/UG_GDX.html#UG_GDX_WRITE_EXECUTION). Restart (`.g00`) files can be saved with the [save](https://www.gams.com/latest/docs/UG_GamsCall.html#GAMSAOsave) command line option. And so on.

The submit scripts contain default functionality that has Condor transfer job output back to the submit machine as each job completes. The relevant configuration settings are [`GET_OUTPUT`](configuring.md#get_output), [`OUTPUT_DIR`](configuring.md#output_dir), and [`OUTPUT_FILE`](configuring.md#output_file) for R runs using `Condor_run_basic.R`. For GAMS runs using `Condor_run.R`, the [`G00_OUTPUT_DIR`](configuring.md#g00_output_dir), [`G00_OUTPUT_FILE`](configuring.md#g00_output_file), [`GET_G00_OUTPUT`](configuring.md#get_g00_output), [`GDX_OUTPUT_DIR`](configuring.md#gdx_output_dir), [`GDX_OUTPUT_FILE`](configuring.md#gdx_output_file) and [`GET_GDX_OUTPUT`](configuring.md#get_gdx_output) configs can be used. Note that the files are renamed on receipt with unique numbers for the run and job so that the output files from different runs and jobs are kept separate.

Once all jobs are done, which can be ensured by configuring [`WAIT_FOR_RUN_COMPLETION`](configuring.md#wait_for_run_completion)` = TRUE`, you may wish to combine or analyse the retrieved output as a next step. For GAMS jobs, retrieved GDX files can be automatically merged as configured by the [`MERGE_GDX_OUPTUT`](configuring.md#merge_gdx_ouptut), [`MERGE_BIG`](configuring.md#merge_big), [`MERGE_EXCLUDE`](configuring.md#merge_exclude) and [`REMOVE_MERGED_GDX_FILES`](configuring.md#remove_merged_gdx_files) options (`Condor_run.R`).


## Adapting templates to your cluster
The submit scripts in the [Condor_run_R repository](https://github.com/iiasa/Condor_run_R) work with the IIASA Limpopo cluster. To adjust the scripts to a different cluster, adapt the templates `seed_job_template` and [`JOB_TEMPLATE`](configuring.md#job_template) found in both `Condor_run.R` and `Condor_run_basic.R` to generate Condor job files appropriate for the cluster. Similarly, change `seed_bat_template` and [`BAT_TEMPLATE`](configuring.md#bat_template) to generate batch files or shell scripts that will run the jobs on your cluster's execute hosts.

Each execute host should provide a directory where the bundles can be cached, and should periodically delete old bundles in those caches so as to prevent their disks from filling up, e.g. using a crontab entry and a [`find <cache directory> -mtime +1 -delete`](https://manpages.debian.org/bullseye/findutils/find.1.en.html) command that will delete all bundles with a timestamp older than one day. The `bat_template` uses [touch](https://linux.die.net/man/1/touch) to update the timestamp of the bundle to the current time. This ensures that that a bundle will not be deleted as long as jobs continue to get scheduled from it.

## Configuring execute hosts
As Condor administrator, you can adjust the configuration of execute hosts to accomodate their seeding with bundles. Though seeding jobs request no resources, Condor nevertheless does not schedule them when there is not at least one unoccupied CPU or a minimum of disk, swap, and memory available on execute hosts. Presumably, Condor internally amends a job's stated resource requirements to make them more realistic. Unfortuntely, this means that when one or more execute hosts are fully occupied, submitting a new run through `Condor_run_R` scripting will have the seeding jobs of hosts remain idle (queued).

The default seed job configuration template has been set up to time out in that eventuality. But if that happens, only a subset of the execute hosts will participate in the run. And if all execute hosts are fully occupied, all seed jobs will time out and the submission will fail. To prevent this from happening, adjust the Condor configuration of the execute hosts to provide a low-resource partitionable slot to which one CPU and a *small quantity* of disk, swap, and memory are allocated. Once so reconfigured, this slot will be mostly ignored by resource-requiring jobs, and remain available for seeding jobs.

To resolve the question of what consitutes a *small quantity*, the test script in `tests/seeding` can be used to fully occupy a cluster or a specific execute host (use the `HOST_REGEXP` config setting) and subsequently try seeding. Perform a bisection search of the excecute host's seeding slot disk, swap, memory resource allocation—changing the allocation between tests—to determine the rough minimum allocation values that allow seeding jobs to be accepted. These values should be minimized so as to make it unlikely that a resource-requesting job gets scheduled in the slot. The slot also needs at least one CPU dedicated to it. Make sure that the Condor daemons on the execute host being tested pick up the configuration after you change it and before running the test again.
