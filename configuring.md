# Configuring  the Condor submit scripts
This page lists the configuration parameters that can be included in the configuration file that is [passed as argument to the `Condor_run_basic.R` and `Condor_run.R` submit scripts](https://github.com/iiasa/Condor_run_R#use). To quickly find the documentation of a particular parameter, click on the headings selection and filter drop down menu button located just to the top left of this text when displayed on GitHub. This smallish button looks like three stacked horizontal lines with leading bullets.

To set up an initial configuration file, copy (do *not* cut) the code block with mandatory configuration parameters located between the *snippy snappy* comments from the chosen submit script (see [`Condor_run_basic.R`](https://github.com/iiasa/Condor_run_R/blob/master/Condor_run_basic.R#L19) and [`Condor_run.R`](https://github.com/iiasa/Condor_run_R/blob/master/Condor_run.R#L19)) and paste it into a new file with an `.R` extension (e.g. `config.R`). The configuration settings use R syntax, so using an `.R` extension will provide syntax highlighting if you are using a good text editor or RStudio. Please carefully read the comments for each setting and customize as required.

You may also wish to add some of the optional configuration settings. Their defaults are located below the last *snippy snappy* comment. These concern configuration settings with default values that will work for most people.

IIASA GLOBIOM developers should instead start from a ready-made configuration located in the GLOBIOM Trunk at `R/sample_config.R`. Note that that configuration assumes that your current working directory is at the root of the GLOBIOM working copy when you invoke via `Rscript`. For more information, see the GLOBIOM wiki [here](https://github.com/iiasa/GLOBIOM/wiki/Running-scenarios-in-parallel-on-Limpopo#configuration).

When you want to use the submit scripts with a different Condor cluster, please read the section on [configuring templates for a different cluster](#configuring-templates-for-a-different-cluster)

## Path handling
Several configuration parameters specify paths to files or directories. **Use only `/`** as directory separator in path values. Paths are relative to the current working directory unless otherwise indicated in the description of the configuration parameter. Things are easiest to configure when you use the root of the file tree of your project as current working directory when submitting. This root will typically be the directory where you cloned/checked-out the repository holding your project files.

This approach allows you to test jobs on your submit machine, and then easily use the submit script to bundle up your project's file tree via 7-Zip for transfer to and execution on the cluster. The `BUNDLE_*` parameters detailed below control which files are added to the bundle. For some examples of how to set this up, see [the tests](tests/tests.md)

## Mandatory configuration parameters

### JOBS
Specify the job numbers of the jobs to submit. Jobs numbers start at 0. For example configuring `c(0:3,7,10)` will start jobs 0, 1, 2, 3, 7, and 10.

Typically, the script that is run when your jobs are started accepts the job number as an argument so that it knows which variant of the calculation to run. For example, a script that runs a model scenario might map the job number to a particular scenario so that submitting with `JOBS = c(0:9)` will run the first ten scenarios in parallel on the cluster.

## HOST_REGEXP
A regular expression to select execute hosts from the cluster by hostname.

### REQUEST_MEMORY
An estimate of the amount of memory (in MiB) required per job. Condor will stop scheduling jobs on an execute host when the sum of their memory requests exceeds the memory allocated to the execution slot of on the host. Overestimating your memory request may therefore allow fewer jobs to run than there actually could. Underestimating it puts the execute host at risk of running out of memory, which can endanger other jobs as well.

It is therefore important to configure a good estimate. When you use [`WAIT_FOR_RUN_COMPLETION`](#wait_for_run_completion)` = TRUE`, the submit script will analyse the `.log` files of the jobs after they complete and produce a warning when the `REQUEST_MEMORY` estimate is significantly wrong. Use this warning to imrpove the estimate.

### REQUEST_CPUS
Number of hardware threads to reserve for each job. Set this to at least 1. If you know that your job involves considerable multiprocessing, set this value to an estimate of the average number of in-use threads.

### WAIT_FOR_RUN_COMPLETION
If `TRUE`, wait for the run to complete while displaying montiring information.

## `Condor_run_basic.R`-specific mandatory configuration parameters

### LAUNCHER
Interpreter with which to launch the script.

### SCRIPT
Script that comprises your job.

### ARGUMENTS
Arguments to the script. Should include `%1` which expands to the job number.

## `Condor_run.R`-specific mandatory configuration parameters

### GAMS_VERSION
GAMS version to run the job with. Must be installed on all selected execute hosts.

Available GAMS versions are configured by  [`EXECUTE_HOST_GAMS_VERSIONS`](#execute_host_gams_versions).

### GAMS_FILE_PATH
Path to GAMS file to run for each job, relative to [`GAMS_CURDIR`](#gams_curdir).

### GAMS_ARGUMENTS
Additional GAMS arguments, can use {<config>} expansion here. Should include `%1` which expands to the job number.

## Optional configuration parameters
The below configuration parameters are optional. Add the ones you need to your configuration file (see above).

### CONDOR_DIR
Default value: `"Condor"`

Parent directory to hold the log directory of the run. The log directory is named via [`LABEL`](#label). Condor and job log files and other run artifacts are stored in the log directory. Excluded from the bundle. Can also be an absolute path. Created when it does not exist, and so too is the log directory.

### LABEL
Default value: `"{Sys.Date()}"`

Synonyms: NAME, EXPERIMENT, PROJECT

Label/name of your project/experiment that is conducted by performing the run. This label will be used to rename output files such that they do not overwrite output files from other runs. It is also used to name the [log directory of the run](#condor_dir). This directory is created when it does not exist. The LABEL should therefore be short and contain only characters that are valid in file/directory names. You can use `{}` expansions as part of the label.

Note that in addition a unique sequence number (the Condor "cluster" number) will be used to (re)name the output files, log files, and other run artifacts so that name collisions are avoided when using the same label for multiple runs. It is therefore handy to have an easy means to obtain the cluster number when in need of performing automated processing of output files after run completion. The [`CLUSTER_NUMBER_LOG`](#cluster_number_log) option serves this purpose.

### PREFIX
Default value: `"job"`

Prefix for the file names of the per-job `.err`, `.log`, `.lst` and `.out` log files written to the [log directory of the run](#condor_dir).

### CLUSTER_NUMBER_LOG
Default value: `""`

Path of log file for capturing cluster number. No such file is written when set to an empty string.

### BUNDLE_INCLUDE
Default value: `"*"`

What to include in the bundle relative to the current working directory. Recursive. Supports wildcards.

### BUNDLE_INCLUDE_DIRS
Default value: `c()`

Further directories to include recursively at the root of the bundle. Supports wildcards.

### BUNDLE_EXCLUDE_DIRS
Default value: `c(".git", ".svn")` for `Condor_run_basic.R`.

Default value: `c(".git", ".svn", "225*")` for `Condor_run.R`.

Exclude directories recursively. Supports wildcards.

### BUNDLE_INCLUDE_FILES
Default value: `c()`

Further files to include in the bundle. Supports wildcards.

### BUNDLE_EXCLUDE_FILES
Default value: `c("**/*.log")` for `Condor_run_basic.R`.

Default value: `c("**/*.~*", "**/*.log", "**/*.log~*", "**/*.lxi", "**/*.lst")` for `Condor_run.R`.

Files to exclude from the bundle. Supports wildcards.

### BUNDLE_ADDITIONAL_FILES
Default value: `c()`

Files to add to root of bundle during an additional invocation of 7-Zip. Can also use an absolute path for these.

### RETAIN_BUNDLE
Default value: `FALSE`

Retain the bundle in the run's [`CONDOR_DIR`](#condor_dir) subdirectory when `TRUE`. Can be useful for locally analyzing host-side issues with jobs.

### SEED_JOB_RELEASES
Default value: `0`

Number of times to auto-release (retry) held seed jobs before giving up.

### JOB_RELEASES
Default value: `3`

Number of times to auto-release (retry) held jobs before giving up.

### RUN_AS_OWNER
Default value: `TRUE`

If `TRUE`, jobs will run as you and have access to your account-specific environment. If `FALSE`, jobs will run under a functional user account.

### NOTIFICATION
Default value: `"Never"`

Specify when to send notification emails. Alternatives are:
- `"Complete"`, when a job completes.
- `"Error"`, when a job errors or goes on hold.
- `"Always"`, when a job completes or reaches checkpoint.

**Beware:** when your run has many jobs, selecting anything other than `"Never"` will be very spammy.

### EMAIL_ADDRESS
Default value: `NULL`

Set with your email if you don't receive notifications. Typically not needed as Condor by default tries to infer your emmail from your username.

### NICE_USER
Default value: `FALSE`

Be nice, give jobs of other users priority by setting this to `TRUE`.

### CLUSTER_NUMBER_LOG
Default value: `""`

Path of log file for capturing cluster number. No such file is written when set to an empty string.

### CLEAR_LINES
Default value: `TRUE`

Clear status monitoring lines so as to show only the last status, set to FALSE when this does not work. This might be the case when the output goes into the chunk output of an RMarkdown notebook in RStudio while [this RStudio issue](https://github.com/rstudio/rstudio/issues/8040) is not yet resolved in the RStudio version that you are using.

## `Condor_run_basic.R`-specific optional configuration parameters

### OUTPUT_DIR
Default value: `"output"`

Directory for output files. Relative to the current working directory on the execute host side and also on the submit machine when [`OUTPUT_DIR_SUBMIT`](#output_dir_submit) is not set. In that case, the directory is excluded form the bundle.

When `OUTPUT_DIR` does not exist on the execute host side, the default [`BAT_TEMPLATE`](#bat_template) of `Condor_run_basic.R` will create it.

### OUTPUT_DIR_SUBMIT
Default value: `NULL`

Directory on the submit machine into where job output files are transferred. Can also be an absolute path. Excluded from bundle. When set to `NULL`, [`OUTPUT_DIR`](#output_dir) will be used instead.

### OUTPUT_FILE
Default value: `"output.RData"`

Name of output file as produced by a job on the execute host side. Will be renamed with [`LABEL`](#label) and cluster/job numbers to avoid name collisions when transferred back to the submit machine.

## `Condor_run.R`-specific optional configuration parameters

### GET_G00_OUTPUT
Default value: `FALSE`

### G00_OUTPUT_DIR
Default value: `""`

When set (changed from its `""` default), this configures the directory for storing work/save output files. Relative to [`GAMS_CURDIR`](#gams_curdir) on the execute host and also on the submit machine side when [`G00_OUTPUT_DIR_SUBMIT`](#g00_output_dir_submit) is not set. In that case, the directory is excluded from the bundle.

When set and when `G00_OUTPUT_DIR` does not exist on the execute host side, the default [`BAT_TEMPLATE`](#bat_template) of `Condor_run.R` will create it.

### G00_OUTPUT_DIR_SUBMIT
Default value: `NULL`

Directory on the submit machine into where `.g00` job work/save files are transferred. Can also be an absolute path. Excluded from bundle. When set to `NULL`, [`G00_OUTPUT_DIR`](#g00_output_dir) will be used instead.

### G00_OUTPUT_FILE
Default value: `""`

Name of work/save file produced by a job on the execute host side via the [`save=` GAMS parameter](https://www.gams.com/latest/docs/UG_GamsCall.html#GAMSAOsave). Will be renamed with [`LABEL`](#label) and cluster/job numbers to avoid name collisions when transferred to the submit machine.

### GET_GDX_OUTPUT
Default value: `FALSE`

### GDX_OUTPUT_DIR
Default value: `""`

When set (changed from its `""` default), this sets the directory for storing GDX output files. Relative to [`GAMS_CURDIR`](#gams_curdir) on the execute host side and also on the submit machine side when [`GDX_OUTPUT_DIR_SUBMIT`](#gdx_output_dir_submit) is not set. In that case, the directory is excluded form the bundle.

When set and when `GDX_OUTPUT_DIR` does not exist on the execute host side, the default [`BAT_TEMPLATE`](#bat_template) of `Condor_run.R` will create it.

### GDX_OUTPUT_DIR_SUBMIT
Default value: `NULL`

Directory on the submit machine into where GDX job output files are transferred. Can also be an absolute path. Excluded from bundle. When set to `NULL`, [`GDX_OUTPUT_DIR`](#gdx_output_dir) will be used instead.

### GDX_OUTPUT_FILE
Default value: `""`

Name of the GDX output file produced by a job on the execute host side via the [`gdx=` GAMS parameter](https://www.gams.com/latest/docs/UG_GamsCall.html#GAMSAOgdx) or an [`execute_unload` statement](https://www.gams.com/latest/docs/UG_GDX.html#UG_GDX_WRITE_EXECUTION_EXECUTE_UNLOAD). Will be renamed with [`LABEL`](#label) and cluster/job numbers to avoid name collisions when transferred to the submit machine.

### EXECUTE_HOST_GAMS_VERSIONS
Default value: `c("24.2", "24.4", "24.9", "25.1", "29.1", "32.2")`

GAMS versions installed on execute hosts.

### GAMS_CURDIR
Default value: `""`

Working directory for GAMS and its arguments relative to the current working directory. The value `""` defaults to the current working directory.

### RESTART_FILE_PATH
Default value: `""`

Path relative to [`GAMS_CURDIR`](#gams_curdir) pointing to the work/restart file to launch GAMS with on the execute host side. Included in bundle if set.

### MERGE_GDX_OUTPUT
Default value: `FALSE`

If `TRUE`, use [GDXMERGE](https://www.gams.com/latest/docs/T_GDXMERGE.html) on the GDX output files when all jobs in the run are done. Requires that the GDXMERGE executable (located in the GAMS system directory) is on-path and that [`WAIT_FOR_RUN_COMPLETION`](#wait_for_run_completion)` = TRUE`.

**Beware:** GDXMERGE is limited. It sometimes gives "Symbol is too large" errors, and neither the `big=` (via the [`MERGE_BIG`](#merge_big) configuration setting below) nor running GDXMERGE on a large-memory machine can avoid that. Moreover, no non-zero return code results in case of such errors, so silent failures are possible. This may or may not have improved in more recent versions of GDXMERGE.

### MERGE_BIG
Default value: `NULL`

Symbol size cutoff beyond which GDXMERGE writes symbols one-by-one to avoid running out of memory (see https://www.gams.com/latest/docs/T_GDXMERGE.html).

### MERGE_ID
Default value: `NULL`

Comma-separated list of symbols to include in the merge. String-valued. The `NULL` default includes all symbols.

### MERGE_EXCLUDE
Default value: `NULL`

Comma-separated list of symbols to exclude from the merge. String-valued. The `NULL` default excludes no symbols.

### REMOVE_MERGED_GDX_FILES
Default value: `FALSE`

When `TRUE`, remove per-job GDX output files after having been merged.

## Configuring templates for a different cluster
The template parameters allow you to configure how Condor `.job` files and job launch scripts (that run on the execute-host side) are generated. The template strings can use `{}` expansion. The default values work with the IIASA Limpopo cluster. To configure the templates for a different cluster, override [`SEED_JOB_TEMPLATE`](#seed_job_template) and [`JOB_TEMPLATE`](#job_template) found in both `Condor_run.R` and `Condor_run_basic.R` to generate Condor job files appropriate for the cluster. In addition, override [`SEED_BAT_TEMPLATE`](#seed_bat_template) and [`BAT_TEMPLATE`](#bat_template) to generate batch files or shell scripts that will run the jobs on your cluster's execute hosts.

Each execute host should provide a directory where the bundles can be cached, and should periodically delete old bundles in those caches so as to prevent their disks from filling up, e.g. using a crontab entry and a [`find <cache directory> -mtime +1 -delete`](https://manpages.debian.org/bullseye/findutils/find.1.en.html) command that will delete all bundles with a timestamp older than one day. The `bat_template` uses [touch](https://linux.die.net/man/1/touch) to update the timestamp of the bundle to the current time. This ensures that that a bundle will not be deleted as long as jobs continue to get scheduled from it.

As Condor administrator, you can adjust the configuration of execute hosts to accommodate their seeding with bundles. Though seeding jobs request minimal resources, Condor nevertheless does not schedule them when there is not at least one unoccupied CPU or a minimum of disk, swap, and memory available on execute hosts. Presumably, Condor internally amends a job's stated resource requirements to make them more realistic. Unfortuntely, this means that when one or more execute hosts are fully occupied, submitting a new run through `Condor_run_R` scripting will have the seeding jobs of hosts remain idle (queued).

The default seed job configuration template has been set up to time out in that eventuality. But if that happens, only a subset of the execute hosts will participate in the run. And if all execute hosts are fully occupied, all seed jobs will time out and the submission will fail. To prevent this from happening, adjust the Condor configuration of the execute hosts to provide a low-resource partitionable slot to which one CPU and a *small quantity* of disk, swap, and memory are allocated. Once so reconfigured, this slot will be mostly ignored by resource-requiring jobs, and remain available for seeding jobs.

To resolve the question of what consitutes a *small quantity*, the test script in `tests/seeding` can be used to fully occupy a cluster or a specific execute host (use the `HOST_REGEXP` config setting) and subsequently try seeding. Perform a bisection search of the excecute host's seeding slot disk, swap, memory resource allocation—changing the allocation between tests—to determine the rough minimum allocation values that allow seeding jobs to be accepted. These values should be minimized so as to make it unlikely that a resource-requesting job gets scheduled in the slot. The slot also needs at least one CPU dedicated to it. Make sure that the Condor daemons on the execute host being tested pick up the configuration after you change it and before running the test again.

### JOB_TEMPLATE
Default value: see  [`Condor_run_basic.R`](https://github.com/iiasa/Condor_run_R/blob/master/Condor_run_basic.R#L63) or [`Condor_run.R`](https://github.com/iiasa/Condor_run_R/blob/master/Condor_run.R#L75).

Template of the Condor `.job` file to submit the run with. The `.job` file produced with this template is preserved in the [log directory of the run](#condor_dir).

### BAT_TEMPLATE
Default value: see [`Condor_run_basic.R`](https://github.com/iiasa/Condor_run_R/blob/master/Condor_run_basic.R#L101) or [`Condor_run.R`](https://github.com/iiasa/Condor_run_R/blob/master/Condor_run.R#L113).

Template for the `.bat` file that launches jobs on the execute host side. The default uses POSIX commands which are not normally available on Windows execute hosts and require a POSIX command distribution to be installed and put on-path. GAMS installations have such commands in the `gbin` subdirectory. The `.bat` file produced with this template is preserved in the [log directory of the run](#condor_dir).

### SEED_JOB_TEMPLATE
Default value: see  [`Condor_run_basic.R`](https://github.com/iiasa/Condor_run_R/blob/master/Condor_run_basic.R#L125) or [`Condor_run.R`](https://github.com/iiasa/Condor_run_R/blob/master/Condor_run.R#L149).

Template of the Condor `.job` file to submit the bundle seed jobs with. The `.job` file produced with this template is preserved in the [log directory of the run](#condor_dir) when seeding fails.

### SEED_BAT_TEMPLATE
Default value: see [`Condor_run_basic.R`](https://github.com/iiasa/Condor_run_R/blob/master/Condor_run_basic.R#L156) or [`Condor_run.R`](https://github.com/iiasa/Condor_run_R/blob/master/Condor_run.R#L180).

Template for the `.bat` file that caches the bundle on the execute host side for a seeding job. The default uses POSIX commands which are not normally available on Windows execute hosts and require a POSIX command distribution to be installed and put on-path. GAMS installations have such commands in the `gbin` subdirectory. The `.bat` file produced with this template is preserved in the [log directory of the run](#condor_dir) when seeding fails.
