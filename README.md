![License](https://img.shields.io/github/license/iiasa/Condor_run_R)

# Condor_run_R
R scripts to submit and analyse [HT Condor](https://research.cs.wisc.edu/htcondor/) runs

## Author
Albert Brouwer

___

* [Introduction](#introduction)
* [Installation](#installation)
* [Test](#test)
* [Updating](#updating)
* [Use](#use)
* [Function of submit scripts](#function-of-submit-scripts)
* [Job output](#job-output)
* [Troubleshooting](#troubleshooting)
  + [None of the above nor below solves my problem](#none-of-the-above-nor-below-solves-my-problem)
  + [The script does not progress](#the-script-does-not-progress)
  + [You get `ERROR: No credential stored for` *`<user>@<domain>`* but did store your credentials](#you-get-error-no-credential-stored-for-userdomain-but-did-store-your-credentials)
  + [When transferring the bundle, jobs stay in the running state indefinately](#when-transferring-the-bundle-jobs-stay-in-the-running-state-indefinately)
  + [Jobs do not run but instead go on hold](#jobs-do-not-run-but-instead-go-on-hold)
  + [Jobs go on hold without producing matching `.log` files](#jobs-go-on-hold-without-producing-matching-log-files)
  + [All seeding jobs remain idle and then abort through the PeriodicRemove expression](#all-seeding-jobs-remain-idle-and-then-abort-through-the-periodicremove-expression)
  + [Jobs are idle and do not run, or only some do](#jobs-are-idle-and-do-not-run-or-only-some-do)
  + [But why?](#but-why)
* [Adapting templates to your cluster](#adapting-templates-to-your-cluster)
* [Configuring execute hosts](#configuring-execute-hosts)

## Introduction
This repository provides R scripts for submitting a Condor *run* (a set of jobs) to a cluster of execute hosts and analysing performance statistics. Four scripts are provided:
1. `Condor_run_basic.R`: generic submit script.
2. `Condor_run.R`: submit script with enhanced functionality for [GAMS](https://www.gams.com/) jobs.
3. `Condor_run_stats.R`: analyse and plot run performance statistics.
4. `restart_version.R`: displays the GAMS version with which a specified restart file was saved.

## Installation
Download the latest release [here](https://github.com/iiasa/Condor_run_R/releases) and unpack the archive. The R scripts in the root directory are self-contained and hence can be copied to a place conviently co-located with your model/project files. Of course, you need to have [R](https://www.r-project.org/) installed to be able to run the scripts. The only non-base R packages used are from the [tidyverse](https://www.tidyverse.org/) package collection. Please ensure that you have the tidyverse installed.

For submission, you in addition need a local [HT Condor installation](https://research.cs.wisc.edu/htcondor/downloads/) and [7-Zip](https://www.7-zip.org/) (on Windows) or the `p7zip` package (on Linux) install. A recent version of both is required since some of their newer features are used.

Test that `condor_status`, `Rscript`, and `7z` can be invoked from the command line. When this does not work, add the appropriate installation directories to your `PATH` environment variable. [See here](https://iiasa.github.io/GLOBIOM/R.html#setting-environment-variables) for instructions on how to do so.

## Test
This repository includes [tests](tests/tests.md). To check your setup, run the [`basic` test](tests/basic/purpose.md) via the cross-platform `test.bat` script located in the `tests/basic` subdirectory. The `basic` test submits a run of several small R jobs via `Condor_run_basic.R` and after completion performs analysis using `Condor_run_stats.R`. The plots can be viewed by opening the resulting PDF file.

## Updating
It is recommended to always update to the [latest release of the scripts](https://github.com/iiasa/Condor_run_R/releases) so that you have the latest fixes and features. Releases are typically backwards compatible and should work with your existing run configurations. Before updating, read the release notes. Automatic notification of new releases can be enabled by going to the [main repository page](https://github.com/iiasa/Condor_run_R), clicking on the Watch/Unwatch drop down menu button at the top right of the page, and check marking Custom → Releases. You need to be signed in to GitHub for this to work.

## Use
Invoke the submit script via `Rscript`, or, on Linux/MacOS, you can invoke the script directly if its execute flag is set and the script has been converted to Unix format using e.g. `dos2unix` (removing the carriage returns from the line breaks). Use the `Condor_run_basic.R` submit script for generic runs and `Condor_run.R` for GAMS runs. A typical invocation command line is therefore:

`Rscript Condor_run_basic.R config.R`

If you have made customizations to your R installation via site, profile or user environment files, it may be necessary to have `Rscript` ignore these customizations by using the `--vanilla` option, e.g.:

`Rscript --vanilla Condor_run.R config.R`

The submit scripts take as command line argument the name of a file with configuration settings. To set up a configuration file, copy the code block between *snippy snappy* lines from the chosen submit script into your clipboard, and save it to a file with an `.R` extension (e.g. `config.R`). The configuration settings use R syntax, so using an `.R` extension will provide syntax highlighting if you are using a good text editor or RStudio. Please carefully read the comments for each setting and customize as required.

Note that further optional configuration settings exist (below the  *snippy snappy* block in the submit script) that you may wish to add to your configuration file and adjust to your requirements. These concern configuration settings with default values that will work for most people. 

IIASA GLOBIOM developers should instead start from a ready-made configuration located in the GLOBIOM Trunk at `R/sample_config.R`. Note that that configuration assumes that your current working directory is at the root of the GLOBIOM working copy when you invoke via `Rscript`.

After a run completes, the analysis script `Condor_run_stats.R` can be used to obtain plots and statistics on run and cluster performance. This script can be run from [RStudio](https://rstudio.com/) or the command line via `Rscript`. When run from the command line, the plots are written to a PDF in the current working directory.

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

The submit scripts contain default functionality that has Condor transfer job output back to the submit machine as each job completes. The relevant configuration settings are `GET_OUTPUT`, `OUTPUT_DIR`, and `OUTPUT_FILE` for R runs using `Condor_run_basic.R`. For GAMS runs using `Condor_run.R`, the `G00_OUTPUT_DIR`, `G00_OUTPUT_FILE`, `GET_G00_OUTPUT`, `GDX_OUTPUT_DIR`, `GDX_OUTPUT_FILE` and `GET_GDX_OUTPUT` configs can be used. Note that the files are renamed on receipt with unique numbers for the run and job so that the output files from different runs and jobs are kept separate.

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
- The [templates are adapted to your cluster](#adapting-templates-to-your-cluster).
- You are using [up-to-date scripts](#updating).

### None of the above nor below solves my problem
Try to invoke `Rscript` with the `--vanilla` option. If that does not help, reboot your machine and try to submit again.

### The script does not progress
The output may be blocked. On Linux, this can happen on account of entering CTRL-S, enter CTRL-Q to unblock. On Windows, this may happen when clicking on the Command Prompt window. Give the window focus and hit backspace or enter CTRL-Q to unblock it. To get rid of this annoying behavior permanently, right-click on the Command Prompt titlebar and select **Defaults**. In the dialog that appears, in the **Options** tab, deselect **QuickEdit Mode** and click **OK**.

### You get `ERROR: No credential stored for` *`<user>@<domain>`* but did store your credentials
Try to submit again. It might be a transient error.

If not, you may have recently changed your password and need to store your user credentials again with `condor_store_cred add` (see above).

### When transferring the bundle, jobs stay in the running state indefinately
This can occur on account of outdated state such as a stale IP address being cached by HTCondor daemons. Stop the script, invoke `condor_restart -schedd`, and try to submit again. You will be asked to delete the bundle first.

If the resubmission also stays stuck in the running state when transferring the bundle, stop the script, reboot, and then try to submit again. If your temp directory survives reboots, you will again be asked to delete the bundle first.

### Jobs do not run but instead go on hold
Likely, some error occurred. First look at the output of the `Condor_run[_basic].R` script for clues. Next, issue `condor_q -held` to review the hold reason. If the hold reason  is `Failed to initialize user log to <some path on a network drive>`, see [the next section](#jobs-go-on-hold-without-producing-matching-log-files)

Otherwise investigate further. Look at the various log files located at `<CONDOR_DIR>/<EXPERIMENT>`. The relevant error messages are typically located at the end of the logs. The log file type to examine are, in order of priority:
1.  `.log` files: these files give per-job information on how Condor scheduled the job and transferred its inputs and outputs. When a log file indicates that something went wrong with the transfer of an output file, the cause is likely *not* the transfer but rather to some earlier error that made the job fail before it could produce output. Do not confuse these files with GAMS `.log` files.
2.  `.err` files: these capture the [standard error](https://en.wikipedia.org/wiki/Standard_streams#Standard_error_(stderr)) stream of each job as it runs remotely and expand while the job runs. When not empty, likely some error occurred. For GAMS jobs, most errors are instead logged to the `.out` and `lst` files with only system-level errors producing `.err` output.
3.  `.out` files: these capture the [standard output](https://en.wikipedia.org/wiki/Standard_streams#Standard_output_(stdout)) stream of each job as it runs remotely and expand while the job runs. Errors may be logged here. For GAMS jobs, these files contain what is normally stored in GAMS log files (which confusingly can have the same file extension as the Condor `.log` files mentioned above) or shown in the system log of GAMS Studio. Look for errors/warnings towards the end.
4.  `.lst` files: these are GAMS listing files. They are produced only for GAMS jobs. When a GAMS jobs completes, the `.lst` file is transferred to the submit machine. Therfore, the `.lst` file is They are transferred when a job completes or aborts and as such are not available yet while the job is still scheduled. For GAMS, this is typically the best place to look for detailed errors. Search for `****` near the end to locate them.
5.  If the log files do not clarify the problem, execute ``condor_q –analyze`` and examine the output: it might be something that happened after the job completed, e.g. result files not fitting because your disk is full.

### Jobs go on hold without producing matching `.log` files
When your job produced no `.log` files in the ``<CONDOR_DIR>/<EXPERIMENT>`` directory, store the pool password again using `condor_store_cred -c add` and retry. Ask your cluster administrator for the pool password.

If the above does not resolve the matter, the Condor service/daemons on your submit machine may not have the access rights to write logging output to `<CONDOR_DIR>`. Set access permissions on that directory or (grand)parent directory that give write access to the service/daemons, or move your submission files onto a disk or under a directory that is writable by others, not just your user account. 

### All seeding jobs remain idle and then abort through the PeriodicRemove expression
It may be that the entire cluster is unavailable, but that is somewhat unlikely. It may be that the entire cluster is fully occupied and the execute hosts have not been [properly configured to always accept seeding jobs](#configuring-execute-hosts) by the Condor administrator. Use `condor_status -submitters` to check availability and occuppation.

Alternatively, the machine you submit from announcing itself with a wrong domain is a possible cause. It has been seen to happen that submit machines announce themselves with the `local` domain, which is not valid for remote access so that jobs cannot be collected. To check whether the submit machine has announced itself wrongly, issue the `condor_q` command. The output should contain the hostname and domain of your machine. If the domain is `local` the issue is likely present and can be resolved by restarting the Condor background processes on the submit machine.

The crude way to restart Condor is to reboot the submit machine. The better way is to restart the Condor service. This can be done via the Services application on Windows or via ``systemctl restart condor.service`` with root privileges on Linux.

### Jobs are idle and do not run, or only some do
The cluster may be busy. To see who else has submitted jobs, issue `condor_status -submitters`. In addition, you may have a low priority so that jobs of others are given priority, pushing your jobs to the back of the queue. To see your priority issue `condor_userprio`. Large numbers mean low priority. Your cluster administrator can set your priority.

### But why?
For further information, see the [why is the job not running?](https://htcondor.readthedocs.io/en/latest/users-manual/managing-a-job.html#why-is-the-job-not-running) section of the HTCondor manual.

## Adapting templates to your cluster
The submit scripts in the [Condor_run_R repository](https://github.com/iiasa/Condor_run_R) work with the IIASA Limpopo cluster. To adjust the scripts to a different cluster, adapt the templates `seed_job_template` and `JOB_TEMPLATE` found in both `Condor_run.R` and `Condor_run_basic.R` to generate Condor job files appropriate for the cluster. Similarly, change `seed_bat_template` and `BAT_TEMPLATE` to generate batch files or shell scripts that will run the jobs on your cluster's execute hosts.

Each execute host should provide a directory where the bundles can be cached, and should periodically delete old bundles in those caches so as to prevent their disks from filling up, e.g. using a crontab entry and a `find <cache directory> -mtime +1 -delete` command that will delete all bundles with a timestamp older than one day. The `bat_template` uses [touch](https://linux.die.net/man/1/touch) to update the timestamp of the bundle to the current time. This ensures that that a bundle will not be deleted as long as jobs continue to get scheduled from it.

## Configuring execute hosts
As Condor administrator, you can adjust the configuration of execute hosts to accomodate their seeding with bundles. Though seeding jobs request no resources, Condor nevertheless does not schedule them when there is not at least one unoccupied CPU or a minimum of disk, swap, and memory available on execute hosts. Presumably, Condor internally amends a job's stated resource requirements to make them more realistic. Unfortuntely, this means that when one or more execute hosts are fully occupied, submitting a new run through `Condor_run_R` scripting will have the seeding jobs of hosts remain idle (queued).

The default seed job configuration template has been set up to time out in that eventuality. But if that happens, only a subset of the execute hosts will participate in the run. And if all execute hosts are fully occupied, all seed jobs will time out and the submission will fail. To prevent this from happening, adjust the Condor configuration of the execute hosts to provide a low-resource partitionable slot to which one CPU and a *small quantity* of disk, swap, and memory are allocated. Once so reconfigured, this slot will be mostly ignored by resource-requiring jobs, and remain available for seeding jobs.

To resolve the question of what consitutes a *small quantity*, the test script in `tests/seeding` can be used to fully occupy a cluster or a specific execute host (use the `HOST_REGEXP` config setting) and subsequently try seeding. Perform a bisection search of the excecute host's seeding slot disk, swap, memory resource allocation—changing the allocation between tests—to determine the rough minimum allocation values that allow seeding jobs to be accepted. These values should be minimized so as to make it unlikely that a resource-requesting job gets scheduled in the slot. The slot also needs at least one CPU dedicated to it. Make sure that the Condor daemons on the execute host being tested pick up the configuration after you change it and before running the test again.
