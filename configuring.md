# Configuring the Condor submit scripts

Configuration is done via a separate configuration file. This page documents the configuration parameters that can be included. Some parameters are mandatory, most are optional. The path to the configuration file to use is [passed as argument to the `Condor_run_basic.R` and `Condor_run.R` submit scripts](https://github.com/iiasa/Condor_run_R#use). To quickly find the documentation of a particular parameter, click on the drop down menu button located just to the top left of this paragraph when displayed on GitHub: it is a smallish button that looks like three stacked horizontal lines with leading bullets. In the menu, type the partial name of a parameter to filter the entries and select an entry to navigate to its documentation. [See here](https://github.blog/changelog/2021-04-13-table-of-contents-support-in-markdown-files/) for a demo of this feature.

To set up an initial configuration file, copy (do *not* cut) the code block with mandatory configuration parameters located between the *snippy snappy* comments from the chosen submit script (see [`Condor_run_basic.R`](https://github.com/iiasa/Condor_run_R/blob/master/Condor_run_basic.R#L19) and [`Condor_run.R`](https://github.com/iiasa/Condor_run_R/blob/master/Condor_run.R#L19)) and paste it into a new file with an `.R` extension (e.g. `config.R`). The configuration settings use R syntax, so using an `.R` extension for the configuration file name will provide syntax highlighting when using a good text editor or RStudio.

After completing the above, you have the mandatory configuration parameters in your configuration flie. Their values will need to be adapted. Please see the documentation of these parameters to learn what they do. You may also wish to add some of the optional configuration parameters. Their defaults are located below the last *snippy snappy* comment. These concern configuration settings with default values that will work for most people.

Your configuration may need adaptation to the particulars of your Condor cluster. For example, [`REQUIREMENTS`](#requirements) filters execution points based on their capabilities as advertised via their the Condor configuration of each execution point. Also, you may need to [adapt templates](#templates). For general information on Condor cluster configuration in support of the `Condor_run_R` submit scripts, see [this page](condor.md). For details on the specific configuration of your Condor cluster, ask your cluster administrator.

IIASA GLOBIOM developers can start from a ready-made configuration located in the GLOBIOM Trunk at `R/sample_config.R` which is adapted to the Limpopo cluster. Note that that configuration assumes that your current working directory is at the root of the GLOBIOM working copy when you invoke via `Rscript`. For more information, see the GLOBIOM wiki [here](https://github.com/iiasa/GLOBIOM/wiki/Running-scenarios-in-parallel-on-Limpopo#configuration).

## Path handling

Since the submit script and configuration file may not be located in the the chosen current working directory, you may need to prefix them with a path on invocation:

`Rscript [<path to>]Condor_run_basic.R [<path to>]my_configuration.R`

Several configuration parameters specify paths to files or directories. **Use only `/`** as directory separator in path values. Paths are relative to the current working directory unless otherwise indicated in the description of the configuration parameter. Things are easiest to configure when you use the root of the file tree of your project as current working directory when submitting. This root will typically be the directory where you cloned/checked-out the repository holding your project files.

This approach allows you to test jobs on your submit machine, and then easily use the submit script to bundle up your project's file tree via 7-Zip for transfer to and execution on the cluster. The `BUNDLE_*` parameters detailed below control which files are added to the bundle. In addition, parameters specifying the location of input and output files—when so indicated in their documentation—can cause files to be included or excluded from the bundle. For some examples of how to set this up, see [the tests](tests/tests.md). To verify what was bundled, check the `_bundle_<cluster number>_contents.txt` listing file that is written to the [log directory of the run](configuring.md#condor_dir) on submission.

## Mandatory configuration parameters

### JOBS

Specify the job numbers of the jobs to submit. Job numbers start at 0. For example, configuring `c(0:3,7,10)` will start jobs 0 to 3, 8 and 10.

Typically, the script that is run when your jobs are started accepts the job number as an argument so that it knows which variant of the calculation to run. For example, a script that runs a model scenario might map the job number to a particular scenario so that submitting with `JOBS = c(0:9)` will run the first ten scenarios in parallel on the cluster.

### REQUEST_MEMORY

An estimate of the amount of memory (in MiB) required per job. Condor will stop scheduling jobs on an execution point (EP) when the sum of their memory requests exceeds the memory allocated to the execution slot of on the execution point. Overestimating your memory request may therefore allow fewer jobs to run than there actually could. Underestimating it puts the EP at risk of running out of memory, which can endanger other jobs as well. It is therefore important to configure a good estimate.

You can find a job's actual, requested, and allocated memory use in a small table at the end of its `.log` file located in the [log directory of the run](#condor_dir) after tge job completes. When you use [`WAIT_FOR_RUN_COMPLETION`](#wait_for_run_completion)` = TRUE`, the submit script will analyse the `.log` files of the jobs for you at the end of the run, and produce a warning when the `REQUEST_MEMORY` estimate is too low or significantly too high.

**:point_right:Note:** your jobs will get scheduled only in "slots" of EPs that have sufficient memory to satisfy your request. To see what memory resources your cluster has available issue [`condor_status -avail`](https://htcondor.readthedocs.io/en/latest/man-pages/condor_status.html). 

### WAIT_FOR_RUN_COMPLETION

If `TRUE`, wait for the run to complete while displaying progress monitoring information and, on completion, check the presence of output files, prune empty log files, and analyze resource usage. When submitting a GAMS job through `Condor_run.R`, also perform a merge of the GDX ouput when [`MERGE_GDX_OUTPUT`](#merge_gdx_output)`= TRUE`.

Also useful for custom-scripted processing of output, with processing steps placed subsequent to the [submission invocation](https://github.com/iiasa/Condor_run_R/#use).

## `Condor_run_basic.R`-specific mandatory configuration parameters

### LAUNCHER

Interpreter/language-runtime with which to launch the [`SCRIPT`](#script) or, when [`SCRIPT`](#script) is empty, the executable/binary to run.

### ARGUMENTS

Arguments to the script or, when [`SCRIPT`](#script) is empty, the [`LAUNCHER`](#launcher). When submitting multiple jobs, this must include `%1` which expands to the job number.

## `Condor_run.R`-specific mandatory configuration parameters

### GAMS_VERSION

GAMS version to run the job with. Must be installed on all selected execution points.

Available GAMS versions are configured by [`AVAILABLE_GAMS_VERSIONS`](#available_gams_versions).

### GAMS_FILE_PATH

Path to GAMS file to run for each job, relative to [`GAMS_CURDIR`](#gams_curdir).

### GAMS_ARGUMENTS

Additional GAMS arguments. You can use `{}` expansion to include other config settings, or expressions based on them, as arguments. Should include `%1` which expands to the job number.

## Optional configuration parameters

The below configuration parameters are optional. Add the ones you need to your configuration file (see above).

### CONDOR_DIR

Default value: `"Condor"`

Parent directory to hold the log directory of the run. The log directory is named via [`LABEL`](#label). Condor and job log files and other run artifacts are stored in the log directory. Excluded from the bundle. Can also be an absolute path. Created when it does not exist, and so too is the log directory.

### LABEL

Default value: `"{Sys.Date()}"`

Synonyms: NAME, EXPERIMENT, PROJECT

Label/name of your project/experiment that is conducted by performing the run. This label will be used to name the [log directory of the run](#condor_dir). This directory is created when it does not exist. The LABEL should therefore be short and contain only characters that are valid directory names. You can use `{}` expansions as part of the label.

### PREFIX

Default value: `"job"`

Prefix for the file names of the per-job `.err`, `.log`, `.lst` and `.out` log files written to the [log directory of the run](#condor_dir).

### CLUSTER_NUMBER_LOG

Default value: `""`

Path of log file for capturing cluster number. No such file is written when set to an empty string.

### BUNDLE_INCLUDE

Default value: `c("*")`

Paths or wildcard patterns specifying the files to include in the bundle. When a path points to a directory, or a wildcard matches a directory, the files contained in that directory will be included recursively.

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

Paths and wildcards specifying additional files to add to the bundle. When a path points to a directory, or a wildcard matches a directory, the files contained in that directory will be added recursively. Each entry is processed via a separate invocation of 7-Zip so that there are no limits on the number of entries.

**:point_right:Note:** the configuration options that exclude files from the bundle, such as `BUNDLE_EXCLUDE_DIRS`, do not affect the bundling of additional files.

### BUNDLE_ONLY

Default value: `FALSE`

Set to `TRUE` to perform only the bundling without subsequent submission. The 7-Zip invocation command lines will be echoed to the console for reference. On completion of bundling, the submit script will quit with explanatory messages stating where the bundle and a listing of its contents are stored. These have a timestamp included in their name so as to prevent them from overwriting existing bundle and listing files.

**:point_right:Note:** see also [`BUNDLE_DIR`](#bundle_dir)

### BUNDLE_DIR

Default value: `NULL`

The directory where to store the bundle when setting `BUNDLE_ONLY = TRUE` or passing the `--bundle-only` command line parameter. Can be an absolute or relative path to an existing directory. When left set to its `NULL` default value, the bundle is stored in the [log directory of the run](#condor_dir).

### RETAIN_BUNDLE

Default value: `FALSE`

Set to `TRUE` retain the bundle the bundle in the [log directory of the run](#condor_dir) after seeding completes. The bundle will be uniquely named by including the cluster sequence number of the run so that you can easily associate it with the other run artifacts preserved in the log directory. A message displaying the path of the retained bundle will shown.

Retaining the bundle enables you to later re-submit the very same run by passing the bundle on the command line. It also allows you to locally analyze execution-point-side issues with jobs by extracting the bundle and trying to run a job locally.

**:point_right:Note:** when submitting an existing bundle, using `--bundle-only` on the command line, or setting `BUNDLE_ONLY = TRUE`, `RETAIN_BUNDLE = TRUE` does nothing since the bundle is already being stored somewhere.

### RETAIN_SEED_ARTIFACTS

Default value: `FALSE`

Retain the `.bat`, `.err`, `.job`, `.out`, and `.log` files involved in the seeding in the [log directory of the run](#condor_dir) when set to `TRUE`. This can be useful for troubleshooting the seeding procedure.

### SEED_JOB_OVERRIDES

Default value: `list()`

Override lines in the `.job` files generated from [`SEED_JOB_TEMPLATE`](#seed_job_template). These [submit description files](https://htcondor.readthedocs.io/en/latest/man-pages/condor_submit.html#submit-description-file-commands) contain commands that you may wish to override while stopping short of overriding the full template. To do so, the list can be filled with one or more key/value pairs, where each key should exactly match the start of the to-be-replaced line in the submit descriptions, and the value provides a template for the replacement line that is first subjected to `{}` expansion.

**:point_right:Note:** the submit descriptions are derived from the `SEED_JOB_TEMPLATE` via `{}` expansion. Keys in the list are matched to the start of so-expanded lines, not to the unexpanded lines present in the template.

### SEED_JOB_RELEASES

Default value: `0`

Number of times to auto-release (retry) held bundle-seeding jobs before giving up. Not retrying—by using the 0 default value—is fine when you have plenty of execution points (EPs) in the cluster: execution points that could not receive the bundle are assumed to be unavailable and will be excluded from the subsequent job submission stage. The execution points that could receive the bundle will still process your jobs.

When the cluster has only one or a couple of EPs, or there are intermittent failures on account of networking issues, it may be worthwhile to retry a few times. This can make the seeding process take longer.

### JOB_OVERRIDES

Default value: `list()`

Override lines in the `.job` file generated from [`JOB_TEMPLATE`](#job_template). This [submit description file](https://htcondor.readthedocs.io/en/latest/man-pages/condor_submit.html#submit-description-file-commands) contains commands that you may wish to override while stopping short of overriding the full template. To do so, the list can be filled with one or more key/value pairs, where each key should exactly match the start of the to-be-replaced line in the submit description, and the value provides a template for the replacement line that is first subjected to `{}` expansion.

**:point_right:Note:** the submit description is derived from the `JOB_TEMPLATE` via `{}` expansion. Keys in the list are matched to the start of so-expanded lines, not to the unexpanded lines present in the template.

### JOB_RELEASES

Default value: `3`

Number of times to auto-release (retry) held (failed) jobs before giving up. This allows your jobs to recover from transient errors such as a network outage or an execution point running out of memory. When the re-tries have run out, your jobs will remain in the held state. Then the error is likely not transient and requires some analysis as described [here](troubleshooting.md#jobs-do-not-run-but-instead-go-on-hold).

### JOB_RELEASE_DELAY

Default value: `120`

Number of seconds to wait after a job has entered the *hold* state before auto-releasing it for a retry. The maximum number of retries is set via [`JOB_RELEASES`](#job_releases). When common causes of transient failure on your cluster take long to resolve, set this value to an estimate of the problem half life so as to not exhaust the retries too soon.

### REQUIREMENTS

Default value: `c()` for `Condor_run_basic.R`.

Default value: `c("GAMS")` for `Condor_run.R`.

Requirement expressions that select the execution points (EPs) to submit to based on their capabilities. The expressions must all evaluated to True for an EP to be selected. For convenience, bare ClassId identifiers are accepted and converted to valid `<identifier> =?= True` expressions.

Requirements expressions `'OpSys ==  "LINUX"'` and `'Arch == "X86_64"'` respectively select EPs that run the Linux operating system and have a 64-bit AMD/Intel processor architecture. Using `'OpSys ==  "WINDOWS"'` you can select Windows EPs. **Such OS and architecture selection is normally not necessary** because by default, when omitting such requirements, EPs are required to have the same `OpSys` and `Arch` as the machine you submit from, which is likely the desired behavior. However, if your code can run on both Linux and Windows—for example because it is Python code, and a Python interpreter is available on all EPs—add ```'OpSys == "LINUX" || OpSys == "WINDOWS"'``` as a requirement.

For more information on requirement expressions, see the documentation of
the `requirements` command of the [submit description file](https://htcondor.readthedocs.io/en/latest/man-pages/condor_submit.html#submit-description-file-commands).

**:point_right:Note:** custom [`ClassAds`] may have been defined on the EPs that allow you select their capabilities on a more fine-grained level via requirement expressions. For example a `ClassAdd` that advertises the availability of a particular version of a language interpreter. Ask your cluster administrator.

### HOST_REGEXP

Default value: `.*`

A [regular expression](https://www.w3schools.com/java/java_regex.asp) to select a subset of execution points from the cluster by hostname. Jobs will be scheduled only on the machines thus selected. The default value selects all available EPs.

### REQUEST_CPUS

Default value: `1`

Number of hardware threads to reserve for each job. The default value is good for jobs that are single-threaded, or mostly so. When your job involves significant multiprocessing, set this value to an estimate of the average number of in-use threads. A small table at the end of the `.log` file of a job located in the [log directory of the run](#condor_dir) will record the average hardware thread usage when the job completes.
  
The "CPUS" naming is Condor speak for hardware threads. In normal parlance, a CPU can contain multiple processing cores, with each core potentially able to run multiple hardware threads, typically two per core. It is those hardware threads—each able to support and independent parallel execution context—that this setting and the statistic in the `.log` file refers to.

**:point_right:Note:** your jobs will get scheduled only in "slots" of EPs that have sufficient "CPUS" to satisfy your request. To see how many "CPUS" your cluster has available issue [`condor_status -avail -state`](https://htcondor.readthedocs.io/en/latest/man-pages/condor_status.html). 

### REQUEST_DISK

Default value: `1000000`

An estimate of the amount of execution-point-side disk space required per job for storing intermediate and output data. Specify the value in [KiB](https://en.wikipedia.org/wiki/Byte#Multiple-byte_units) units. The submit script will add to this value the uncompressed size of the bundle to yield a disk request reflecting the overall storage requirement of the job. This sum is used to allocate disk space for a job when it is started on an EP.
  
You can find a job's actual, requested (with added uncompressed bundle size), and allocated disk space in a small table at the end of its `.log` file located in the [log directory of the run](#condor_dir) after the job completes. When you use [`WAIT_FOR_RUN_COMPLETION`](#wait_for_run_completion)` = TRUE`, the submit script will analyse the `.log` files of the jobs for you at the end of the run, and produce a warning when the `REQUEST_DISK` estimate is too low or significantly too high.

**:point_right:Note:** your jobs will get scheduled only in "slots" of EPs that have sufficient disk to satisfy your request. To see what disk resources your cluster has available issue [`condor_status -avail -server`](https://htcondor.readthedocs.io/en/latest/man-pages/condor_status.html). 
  
### RUN_AS_OWNER

Default value: `TRUE`

If `TRUE`, jobs will run as you and have access to your account-specific environment. If `FALSE`, jobs will run under a functional user account.

### NOTIFICATION

Default value: `"Never"`

Specify when to send notification emails. Alternatives are:
- `"Complete"`, when a job completes.
- `"Error"`, when a job errors or goes on hold.
- `"Always"`, when a job completes or reaches checkpoint.

**:warning:Beware:** when your run has many jobs, selecting anything other than `"Never"` will be very spammy.

### EMAIL_ADDRESS

Default value: `NULL`

Set with your email if you don't receive notifications. Typically not needed as Condor by default tries to infer your email from your username.

### NICE_USER

Default value: `FALSE`

Be nice, give jobs of other users priority by setting this to `TRUE`.

### CLUSTER_NUMBER_LOG

Default value: `""`

Path of log file for capturing cluster number. No such file is written when set to an empty string.

This feature provides a simple way of communicating the cluster number to post-processing scripting. Such scripting will need to know the cluster number in order to access the output files belonging to the run: output files are uniquely named by including the cluster number in their file name.

### CLEAR_LINES

Default value: `TRUE`

Clear status monitoring lines so as to show only the last status, set to FALSE when this does not work. This might be the case when the output goes into the chunk output of an RMarkdown notebook in RStudio while [this RStudio issue](https://github.com/rstudio/rstudio/issues/8040) is not yet resolved in the RStudio version that you are using.

## `Condor_run_basic.R`-specific optional configuration parameters

### SCRIPT
Default value: `""`  

The script to launch with [`LAUNCHER`](#launcher). When empty (the default) the job is not defined by a script but rather by the executable/binary specified in the [`LAUNCHER`](#launcher) setting.

### GET_OUTPUT

Default value: `TRUE`

### OUTPUT_DIR

Default value: `"output"`

Directory for output files. Relative to the current working directory on the execution point and also on the submit machine when [`OUTPUT_DIR_SUBMIT`](#output_dir_submit) is not set. In that case, the directory is excluded form the bundle.

When `OUTPUT_DIR` does not exist on the EP, the default [`BAT_TEMPLATE`](#bat_template) of `Condor_run_basic.R` will create it.

### OUTPUT_DIR_SUBMIT

Default value: `NULL`

Directory on the submit machine into where job output files are transferred. Can also be an absolute path. Excluded from bundle. When set to `NULL`, [`OUTPUT_DIR`](#output_dir) will be used instead.

### OUTPUT_FILES

Default value: `c("output.RData")`

Synonym: OUTPUT_FILE

Name(s) of the output file(s) as produced by a job on the execution point. Will be renamed with the cluster number (submission sequence number) and job number to avoid name collisions when transferred back to the submit machine.

**:point_right:Note:** to automatically process output files renamed with the cluster number, it is helpful to have an easy means of obtaining the cluster number. The [`CLUSTER_NUMBER_LOG`](#cluster_number_log) option serves this purpose.

## `Condor_run.R`-specific optional configuration parameters

### GET_G00_OUTPUT

Default value: `FALSE`

### G00_OUTPUT_DIR

Default value: `""`

When set (changed from its `""` default), this configures the directory for storing work/save output files. Relative to [`GAMS_CURDIR`](#gams_curdir) on the execution point (EP) and also on the submit machine side when [`G00_OUTPUT_DIR_SUBMIT`](#g00_output_dir_submit) is not set. In that case, the directory is excluded from the bundle.

When set and when `G00_OUTPUT_DIR` does not exist on the EP the default [`BAT_TEMPLATE`](#bat_template) of `Condor_run.R` will create it.

### G00_OUTPUT_DIR_SUBMIT

Default value: `NULL`

Directory on the submit machine into where `.g00` job work/save files are transferred. Can also be an absolute path. Excluded from bundle. When set to `NULL`, [`G00_OUTPUT_DIR`](#g00_output_dir) will be used instead.

### G00_OUTPUT_FILE

Default value: `""`

Name of work/save file produced by a job on the execution point the [`save=` GAMS parameter](https://www.gams.com/latest/docs/UG_GamsCall.html#GAMSAOsave). Will be renamed with the cluster number (submission sequence number) and job number to avoid name collisions when transferred to the submit machine.

**:point_right:Note:** to automatically process G00 output files renamed with the cluster number, it is helpful to have an easy means of obtaining the cluster number. The [`CLUSTER_NUMBER_LOG`](#cluster_number_log) option serves this purpose.

### GET_GDX_OUTPUT

Default value: `FALSE`

### GDX_OUTPUT_DIR

Default value: `""`

When set (changed from its `""` default), this sets the directory for storing GDX output files. Relative to [`GAMS_CURDIR`](#gams_curdir) on the execution point also on the submit machine when [`GDX_OUTPUT_DIR_SUBMIT`](#gdx_output_dir_submit) is not set. In that case, the directory is excluded from the bundle.

When set and when `GDX_OUTPUT_DIR` does not exist on the EP the default [`BAT_TEMPLATE`](#bat_template) of `Condor_run.R` will create it.

### GDX_OUTPUT_DIR_SUBMIT

Default value: `NULL`

Directory on the submit machine into where GDX job output files are transferred. Can also be an absolute path. Excluded from bundle. When set to `NULL`, [`GDX_OUTPUT_DIR`](#gdx_output_dir) will be used instead.

### GDX_OUTPUT_FILE

Default value: `""`

Name of the GDX output file produced by a job on the execution point the [`gdx=` GAMS parameter](https://www.gams.com/latest/docs/UG_GamsCall.html#GAMSAOgdx) or an [`execute_unload` statement](https://www.gams.com/latest/docs/UG_GDX.html#UG_GDX_WRITE_EXECUTION_EXECUTE_UNLOAD). Will be renamed with the cluster number (submission sequence number) and job number to avoid name collisions when transferred to the submit machine.

**:point_right:Note:** to automatically process GDX output files renamed with the cluster number, it is helpful to have an easy means of obtaining the cluster number. The [`CLUSTER_NUMBER_LOG`](#cluster_number_log) option serves this purpose.

### AVAILABLE_GAMS_VERSIONS

Default value: `c("24.2", "24.4", "24.9", "25.1", "29.1", "32.2")`

GAMS versions installed on execution points advertising the `GAMS`` requirement.

### GAMS_CURDIR

Default value: `"."`

Working directory for GAMS and its arguments relative to the current working directory. The value `"."` defaults to the current working directory.

### RESTART_FILE_PATH

Default value: `""`

Path relative to [`GAMS_CURDIR`](#gams_curdir) pointing to the [work/restart file](https://www.gams.com/latest/docs/UG_SaveRestart.html) to launch GAMS with on the execution point. If set, the restart file is added to the bundle via a separate 7-Zip invocation.

**:point_right:Note:** the configuration options that exclude files from the bundle, such as `BUNDLE_EXCLUDE_DIRS`, do not affect the bundling of the restart file.

**:warning:Beware:** the restart file will not work if the GAMS version on the EP (see [GAMS_VERSION](#gams_version)) is older than the GAMS version used to generated it. The `Condor_run.R` submit script will throw an explanatory error in that case to prevent the run's jobs from later going on hold for this somewhat obscure reason.

If you are unsure which GAMS version a restart file was generated with, you can determine that by using the [`restart_version.R`](https://github.com/iiasa/Condor_run_R/blob/master/restart_version.R) script.

### MERGE_GDX_OUTPUT

Default value: `FALSE`

If `TRUE`, use [GDXMERGE](https://www.gams.com/latest/docs/T_GDXMERGE.html) on the GDX output files when all jobs in the run are done. Requires that the GDXMERGE executable (located in the GAMS system directory) is on-path and that [`WAIT_FOR_RUN_COMPLETION`](#wait_for_run_completion)` = TRUE`.

**:warning:Beware:** GDXMERGE is limited. It sometimes gives "Symbol is too large" errors, and neither the `big=` (via the [`MERGE_BIG`](#merge_big) configuration setting below) nor running GDXMERGE on a large-memory machine can avoid that. Moreover, no non-zero return code results in case of such errors, so silent failures are possible. This may or may not have improved in more recent versions of GDXMERGE.

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

## Templates

The template parameters configure Condor `.job` files and job launch scripts (that run on the execute-point side). These files are generated from the templates on submitting a run. The template strings can use `{}` expansion to include other configuration parameters and run-time state in the generated files.

**:point_right:Note:** Templates are cluster-specific. Your cluster administrator can provide templates adapted to your cluster. To do so, cluster administrators can follow the guidance on [configuring templates for a different cluster](condor.md#configuring-templates-for-a-different-cluster).

**:warning:Caution:** When [updating to a new release](README.md#updating) additional functionality may be present in the default template values, in particular there where `{}` expansions are used. When overriding templates, it is therefore important to keep an eye on the [release notes](https://github.com/iiasa/Condor_run_R/releases) to see if template default values were changed: you may need to update your templates, for example by applying your template customizations to the new defaults.

### JOB_TEMPLATE

Default value: see [`Condor_run_basic.R`](https://github.com/iiasa/Condor_run_R/blob/master/Condor_run_basic.R#L72) or [`Condor_run.R`](https://github.com/iiasa/Condor_run_R/blob/master/Condor_run.R#L84).

Template of the Condor `.job` file to submit the run with. The [submit description file](https://htcondor.readthedocs.io/en/latest/man-pages/condor_submit.html#submit-description-file-commands) produced with this template through `{}` expansion is preserved in the [log directory of the run](#condor_dir).

**:point_right:Note:** since keeping a custom template up-to-date with new releases is a maintenance burden, consider using [`JOB_OVERRIDES`](#job_overrides) instead. That will suffice when you need to customize only one or a few lines in the submit description.

### BAT_TEMPLATE

Default value: see [`Condor_run_basic.R`](https://github.com/iiasa/Condor_run_R/blob/master/Condor_run_basic.R#L106) or [`Condor_run.R`](https://github.com/iiasa/Condor_run_R/blob/master/Condor_run.R#L118).

Template for the `.bat` file that launches jobs on the execution point (EP). The default uses POSIX commands which are not normally available on Windows EPs and require a POSIX command distribution to be installed and put on-path. GAMS installations have such commands in the `gbin` subdirectory. The `.bat` file produced with this template is preserved in the [log directory of the run](#condor_dir).

### SEED_JOB_TEMPLATE

Default value: see [`Condor_run_basic.R`](https://github.com/iiasa/Condor_run_R/blob/master/Condor_run_basic.R#L130) or [`Condor_run.R`](https://github.com/iiasa/Condor_run_R/blob/master/Condor_run.R#L160).

Template of the Condor `.job` file to submit the bundle seed jobs with. The [submit description files](https://htcondor.readthedocs.io/en/latest/man-pages/condor_submit.html#submit-description-file-commands) produced with this template through `{}` expansion are preserved in the [log directory of the run](#condor_dir) when seeding fails.

**:point_right:Note:** since keeping a custom template up-to-date with new releases is a maintenance burden, consider using [`SEED_JOB_OVERRIDES`](#seed_job_overrides) instead. That will suffice when you need to customize only one or a few lines in the submit description.

### SEED_BAT_TEMPLATE

Default value: see [`Condor_run_basic.R`](https://github.com/iiasa/Condor_run_R/blob/master/Condor_run_basic.R#L155) or [`Condor_run.R`](https://github.com/iiasa/Condor_run_R/blob/master/Condor_run.R#L185).

Template for the `.bat` file that caches the bundle on the execution point for a seeding job. The default uses POSIX commands which are not normally available on Windows EPs and require a POSIX command distribution to be installed and put on-path. GAMS installations have such commands in the `gbin` subdirectory. The `.bat` file produced with this template is preserved in the [log directory of the run](#condor_dir) when seeding fails.
