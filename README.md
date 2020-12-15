# Condor_run_R
R scripts to submit and analyse [HT Condor](https://research.cs.wisc.edu/htcondor/) runs

## Author
Albert Brouwer

___

* [Introduction](#introduction)
* [Installation](#installation)
* [Test](#test)
* [Use](#use)
* [Function of submit scripts](#function-of-submit-scripts)
* [Troubleshooting](#troubleshooting)
  + [The script does not progress](#the-script-does-not-progress)
  + [When transferring the bundle jobs keep on cycling between idle and running](#when-transferring-the-bundle-jobs-keep-on-cycling-between-idle-and-running)
  + [Jobs do not run but instead go on hold](#jobs-do-not-run-but-instead-go-on-hold)
  + [Jobs go on hold without producing matching `.log` files!](#jobs-go-on-hold-without-producing-matching-log-files)
  + [All seeding jobs remain idle and then abort through the PeriodicRemove expression](#all-seeding-jobs-remain-idle-and-then-abort-through-the-periodicremove-expression)
  + [Jobs are idle and do not run, or only some do](#jobs-are-idle-and-do-not-run-or-only-some-do)
  + [But why?](#but-why)

## Introduction
This repository provides R scripts for submitting a Condor *run* (a set of jobs) to a cluster of execute hosts and analysing performance statistics. Four scripts are provided:
1. `Condor_run_basic.R`: generic submit script.
2. `Condor_run.R`: submit script with enhanced functionality for [GAMS](https://www.gams.com/) jobs.
3. `Condor_run_stats.R`: analyse and plot run performance statistics.
4. `restart_version.R`: displays the GAMS version with which a specified restart file was saved.

## Installation
The scripts are self-contained and hence can be copied to a place conviently co-located with your model/project files. Of course, you need to have [R](https://www.r-project.org/) installed to be able to run the scripts. The only non-base R packages used are from the [tidyverse](https://www.tidyverse.org/) package collection. Please ensure that you have the tidyverse installed.

For submission, you in addition need a local [HT Condor installation](https://research.cs.wisc.edu/htcondor/downloads/) and [7-Zip](https://www.7-zip.org/) (on Windows) or the `p7zip` package (on Linux) install. A recent version of both is required since some of their newer features are used.

Test that `condor_status`, `Rscript`, and `7z` can be invoked from the command line. When this does not work, add the appropriate installation directories to your `PATH` environment variable.

## Test
To check your installation, run the test in the `test_basic` subdirectory. The test can be started by running the cross-platform script `test.bat`.

The test submits a run of several small R jobs via `Condor_run_basic.R` and after completion performs analysis using `Condor_run_stats.R`. The plots can be viewed by opening the resulting `Rplots.pdf` file.

## Use
Invoke the submit scripts via `Rscript`, or, on Linux/MacOS, you can invoke the script directly if its execute flag is set and the script has been converted to Unix format using e.g. `dos2unix` (removing the carriage returns from the line breaks). The analysis script `Condor_run_stats.R` is best run from [RStudio](https://rstudio.com/). The submit scripts take as command line argument the name of a file with configuration settings. 

A typical invocation command line is therefore

`Rscript Condor_run_basic.R config.R`

To set up a configuration file, copy the code block between *snippy snappy* lines from the submit script into your clipboard, and save it to a file with an `.R` extension (e.g. `config.R`). The configuration settings use R syntax, so using an `.R` extension will provide syntax highlighting if you are using a good text editor or RStudio. Read the comments for each setting and customize as required.

IIASA GLOBIOM developers should instead start from a ready-made configuration located in the GLOBIOM Trunk at `R/sample_config.R`.

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

**Beware:** only after completing step 3 can a further parallel submission be performed. The script notifies you thereof as follows:

`Run "test" has been submitted, it is now possible to submit additional runs while waiting for it to complete.`

The submit script enforces this by using the bundle as a lock file until step 3 completes. If you abort the script or an error occurs before then, you will need to remove the bundle to free the lock. The script will throw an explanatory error until you do.

## Job output
Each job will typically produce some kind of output. For R jobs this might be an `.RData` file, for GAMS jobs this is likely to be either a GDX or restart file. There are are many ways to produce output. In R, objects can be saved to `.RData` files with the [`save()`](https://www.rdocumentation.org/packages/base/versions/3.6.2/topics/save) function. In GAMS, GDX files of everything can be dumped at the end of execution via the [GDX](https://www.gams.com/latest/docs/UG_GamsCall.html#GAMSAOgdx) command line option, or selectively written at run time using [execute_unload](https://www.gams.com/latest/docs/UG_GDX.html#UG_GDX_WRITE_EXECUTION). Restart (`.g00`) files can be saved with the [save](https://www.gams.com/latest/docs/UG_GamsCall.html#GAMSAOsave) command line option. And so on.

The submit scripts contain default functionality that has Condor transfer job output back to the submit machine as each job completes. The relevant configuration parameters are `GET_OUTPUT`, `OUTPUT_DIR`, and `OUTPUT_FILE` for R runs using `Condor_run_basic.R`. For GAMS runs using `Condor_run.R`, the `G00_OUTPUT_DIR`, `G00_OUTPUT_FILE`, `GET_G00_OUTPUT`, `GDX_OUTPUT_DIR`, `GDX_OUTPUT_FILE` AND `GET_GDX_OUTPUT` can be used. Note that the files are renamed on receipt with unique numbers for the run and job so the output files from different runs and jobs are kept separate.

Once all jobs are done, which can be ensured by configuring `WAIT_FOR_RUN_COMPLETION=TRUE`, you may wish to combine or analyse the retrieved output as a next step. For GAMS jobs, retrieved GDX files can be automatically merged as configured by the `MERGE_GDX_OUPTUT`, `MERGE_BIG`, `MERGE_EXCLUDE` and `REMOVE_MERGED_GDX_FILES` options (`Condor_run.R`).

## Troubleshooting
When you cannot submit jobs, ensure that:
- You have reviewed the output of the submit script for causes and solutions.
- You have obtained access to the Condor cluster from the cluster administrator.
- You stored the necessary credentials via `condor_store_cred add`:
  * Type `condor_store_cred add` on the command line and, when prompted, enter your login password to allow Condor to schedule jobs as you.
    + **Note**: you will need to do this again after changing your password. 
  * Type `condor_store_cred -c add` and, when prompted, enter the condor pool password (ask your administrator).
- Issuing the command `condor_submit` tabulates the cluster status.
- Issuing the command `condor_q` results in a summary of queued jobs.
- When jobs are held, issuing `condor_q -held` shows the reason why.
- You set the HOST_REGEXP configuration option to select the right subset of execute hosts from the cluster.

### The script does not progress
The output may be blocked. On Linux, this can happen on account of entering CTRL-S, enter CTRL-Q to unblock. On Windows, this may happen when clicking on the Command Prompt window. Give the window focus and hit backspace or enter CTRL-Q to unblock it. To get rid of this annoying behavior permanently, right-click on the Command Prompt titlebar and select **Defaults**. In the dialog that appears, in the **Options** tab, deselect **QuickEdit Mode** and click **OK**.

### When transferring the bundle, jobs keep on cycling between idle and running

This behavior can occur on account of an outdated IP address being cached. Stop the script, invoke `condor_restart -schedd`, and try to submit again. If this does not work, stop the script, reboot, and try to submit again. Note that you will need to delete the bundle before starting the script again.

### Jobs do not run but instead go on hold
Likely, some error occurred. First look at the output of the ``Condor_run[_basic].R`` script for
clues. Next, issue `condor_q -held` to review the hold reason. If the hold reason  is `Failed to
initialize user log to <some path on a network drive>`, see
[the next section](#jobs-go-on-hold-without-producing-matching-log-files)

Otherwise investigate further. Look at the various log files located at ``<CONDOR_DIR>/<EXPERIMENT>``.
In order of priority:
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

### Jobs go on hold without producing matching `.log` files!
When your job produced no `.log` files in the ``<CONDOR_DIR>/<EXPERIMENT>`` directory,
store the pool password again using `condor_store_cred -c add` and retry. Ask your cluster
administrator for the pool password.

If the above does not resolve the matter, the Condor service on your submit machine may not
have the access rights to write its logging output to `<CONDOR_DIR>`. Try to set suitable
access permissions on that directory.

### All seeding jobs remain idle and then abort through the PeriodicRemove expression
It may be that the entire cluster is unavailable, but that is somewhat unlikely.
The machine you submit from announcing itself with a wrong domain is a more
probable cause. It has been seen to happen that submit machines announce
themselves with the ``local`` domain, which is not valid for remote access
so that jobs cannot be collected.

To check whether the submit machine has announced itself wrongly, issue the
``condor_q`` command. The output should contain the hostname and domain of your
machine. If the domain is ``local`` the issue is likely present and can be
resolved by restarting the Condor background processes on the submit machine.

The crude way to restart Condor is to reboot the submit machine. The better
way is to restart the Condor service. This can be done via the Services
application on Windows or via ``systemctl restart condor.service`` with
root privileges on Linux.

### Jobs are idle and do not run, or only some do
The cluster may be busy. To see who else has submitted jobs, issue `condor_status -submitters`.
In addition, you may have a low priority so that jobs of others are given priority,
pushing your jobs to the back of the queue. To see your priority issue `condor_userprio`.
Large numbers mean low priority. Your cluster administrator can set your priority.

### But why?
For further information, see the
[why is the job not running?](https://htcondor.readthedocs.io/en/latest/users-manual/managing-a-job.html#why-is-the-job-not-running)
section of the HTCondor manual.
