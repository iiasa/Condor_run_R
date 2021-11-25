# Configuring the Condor submit scripts

To set up a configuration file, copy the code block between *snippy snappy* lines from the chosen submit script (either `Condor_run_basic.R` or `Condor_run.R`) into your clipboard, and save it to a file with an `.R` extension (e.g. `config.R`). The configuration settings use R syntax, so using an `.R` extension will provide syntax highlighting if you are using a good text editor or RStudio. Please carefully read the comments for each setting and customize as required.

Note that further optional configuration settings exist (below the *snippy snappy* block in the submit script) that you may wish to add to your configuration file and adjust to your requirements. These concern configuration settings with default values that will work for most people.

IIASA GLOBIOM developers should instead start from a ready-made configuration located in the GLOBIOM Trunk at `R/sample_config.R`. Note that that configuration assumes that your current working directory is at the root of the GLOBIOM working copy when you invoke via `Rscript`. For more information, see the GLOBIOM wiki [here](https://github.com/iiasa/GLOBIOM/wiki/Running-scenarios-in-parallel-on-Limpopo#configuration).

In path values, use '/' as directory separator. Paths are relative to the current working directory unless otherwise indicated.

## Mandatory configuration parameters

### JOBS
Specify the job numbers of the jobs to submit. Jobs numbers start at 0. For example configuring `c(0:3,7,10)` will start jobs 0, 1, 2, 3, 7, and 10.

Typically, the script that is run when your jobs are started accepts the job number as an argument so that it knows which variant of the calculation to run. For example, a script that runs a model scenario might map the job number to a particular scenario so that submitting with `JOS = c(0:9)` will run the first ten scenarios in parallel on the cluster.

## HOST_REGEXP
A regular expression to select execute hosts from the cluster by hostname.

### REQUEST_MEMORY
Amount of memory (MiB) to reserve for each job.

### REQUEST_CPUS
Number of hardware threads to reserve for each job.

### WAIT_FOR_RUN_COMPLETION
Wait for the run to complete while displaying montiring information.

## Mandatory for `Condor_run.R` only

### GAMS_FILE_PATH
Path to GAMS file to run for each job, relative to `GAMS_CURDIR`.

### GAMS_ARGUMENTS
Additional GAMS arguments, can use {<config>} expansion here. `%1` expands the job number.

### GAMS_VERSION
GAMS version to run the job with. Must be installed on all selected execute hosts.

## Optional configuration parameters
The below configuration parameters are optional. Add the ones you need to your configuration file (see above).

### LABEL
Default value: `"{Sys.Date()}"`

Synonyms: NAME, EXPERIMENT, PROJECT

The run to be submitted can be given a short descriptive label. This label will be used to rename output files such that they do not overwrite output files from other runs. It is also used to create a subdirectory of CONDOR_DIR where run managment artifacts such a log files are placed. The LABEL should therefore be short and contain only characters that are valid in file names. You can use `{}` expansions as part of the label.

Note that a unique sequence number (the Condor "cluster" number) will also be used to (re)name the output files and artifacts so that name collisions are also avoided when using the same label for multiple runs.

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

Retain the bundle in the run's `CONDOR_DIR` subdirectory when `TRUE`. Can be useful for locally analyzing host-side issues with jobs.

### CONDOR_DIR
Default value: `"Condor"`

Directory where for each run, Condor log files and other run artifacts are stored in a subdirectory. Excluded from bundle. Can also be an absolute path. Created when it does not exist.

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

Clear status monitoring lines so as to show only the last status, set to FALSE when this does not work, e.g. when the output goes into the chunk output of an RMarkdown notebook.

### PREFIX
Default value: `"job"`

Prefix for per-job `.err`, `.log`, `.lst` and `.out` artifact file names stored in a subdirectory of `CONDOR_DIR`.

### JOB_TEMPLATE
Default value: see `Condor_run.R` or `Condor_run_basic.R`.

Template of the Condor `.job` file to submit the run with. A copy of the `.job` file produced with this template is stored together with the artifacts of the run.

### BAT_TEMPLATE
Default value: see `Condor_run.R` or `Condor_run_basic.R`.

Template for the `.bat` file that specifies what should be run on the execute host side for each job. This default uses POSIX commands which are not normally available on Windows execute hosts and require a POSIX command distribution to be installed and put on-path. GAMS installations have such commands in the `gbin` subdirectory.

## Optional configuration parameters specific to `Condor_run_basic.R`

### OUTPUT_DIR
Default value: `"output"`

Directory for output files. Relative to the current working directory both on the execute host side and also on the submit machine if `OUTPUT_DIR_SUBMIT` is not set. In that case, the directory is excluded form the bundle.

### OUTPUT_DIR_SUBMIT
Default value: `NULL`

Directory on the submit machine into where job output files are transferred. Can also be an absolute path. Excluded from bundle. When set to `NULL`, `OUTPUT_DIR` will be used instead.

### OUTPUT_FILE
Default value: `"output.RData"`

Name of output file as produced by a job on the execute host side. Will be renamed with `LABEL` and cluster/job numbers to avoid name collisions when transferred back to the submit machine.

## Optional configuration parameters specific to `Condor_run.R`

### EXECUTE_HOST_GAMS_VERSIONS
Default value: `c("24.2", "24.4", "24.9", "25.1", "29.1", "32.2")`

GAMS versions installed on execute hosts.

### GAMS_CURDIR
Default value: `""`

Working directory for GAMS and its arguments relative to the current working directory. The value `""` defaults to the current working directory.

### RESTART_FILE_PATH
Default value: `""`

Path relative to `GAMS_CURDIR` pointing to the work/restart file to launch GAMS with on the execute host side. Included in bundle if set.

### MERGE_GDX_OUTPUT
Default value: `FALSE`

Use [GDXMERGE](https://www.gams.com/latest/docs/T_GDXMERGE.html) if `TRUE` when the run completes. Requires that `WAIT_FOR_RUN_COMPLETION = TRUE`.

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

### GET_G00_OUTPUT
Default value: `FALSE`

### G00_OUTPUT_DIR
Default value: `""`

Directory for work/save files. Relative to `GAMS_CURDIR` both execute host side and also on the submit machine if `G00_OUTPUT_DIR_SUBMIT` is not set. In that case, the directory is excluded from the bundle.

### G00_OUTPUT_DIR_SUBMIT
Default value: `NULL`

Directory on the submit machine into where `.g00` job work/save files are transferred. Can also be an absolute path. Excluded from bundle. When set to `NULL`, `G00_OUTPUT_DIR` will be used instead.

### G00_OUTPUT_FILE
Default value: `""`

Name of work/save file produced by a job on the execute host side via the [`save=` GAMS parameter]](https://www.gams.com/latest/docs/UG_GamsCall.html#GAMSAOsave). Will be renamed with `LABEL` and cluster/job numbers to avoid name collisions when transferred to the submit machine.

### GET_GDX_OUTPUT
Default value: `FALSE`

### GDX_OUTPUT_DIR
Default value: `""`

Directory for GDX output files. Relative to `GAMS_CURDIR` both on the execute host side and also on the submit machine if `GDX_OUTPUT_DIR_SUBMIT` is not set. In that case, the directory is excluded form the bundle.

### GDX_OUTPUT_DIR_SUBMIT
Default value: `NULL`

Directory on the submit machine into where GDX job output files are transferred. Can also be an absolute path. Excluded from bundle. When set to `NULL`, `GDX_OUTPUT_DIR` will be used instead.

### GDX_OUTPUT_FILE
Default value: `""`

Name of the GDX output file produced by a job on the execute host side via the [`gdx=` GAMS parameter](https://www.gams.com/latest/docs/UG_GamsCall.html#GAMSAOgdx) or an [`execute_unload` statement](https://www.gams.com/latest/docs/UG_GDX.html#UG_GDX_WRITE_EXECUTION_EXECUTE_UNLOAD). Will be renamed with `LABEL` and cluster/job numbers to avoid name collisions when transferred to the submit machine.
