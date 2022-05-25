# Configuring a Condor cluster in support of `Condor_run_R`

This page provides information on how to set up or re-configure a Condor cluster in support of the `Condor_run_R` submit scripts. In particular the bundle caching feature requires a bit of specialized support on the execution point side.

## Setting up a bundles cache

To support receiving and caching [7-Zip](https://en.wikipedia.org/wiki/7-Zip) bundles, each execution point should provide a directory with appropriate access rights where the bundles can be cached, should periodically delete old bundles in those caches to prevent their disks from filling up, and should have a `7x` executable/binary on-path so that jobs can extract a bundle on startup.

#### Linux

Most Linux distributions provide a p7zip package that is typically not installed by default. After installation, the `7z` binary should be on-path. A refreshed Linux port of 7-Zip is in the works but at the time of this writing has not been released yet.

On Linux, the `find` command can be used to delete old bundles. For example [`find <cache directory> -mtime +1 -delete`](https://manpages.debian.org/bullseye/findutils/find.1.en.html) command that will delete all bundles with a timestamp older than one day. This can be scheduled via a [crontab entry](https://en.wikipedia.org/wiki/Cron) or a timer/service pair of SystemD unit files.

### Windows

For Windows, 7-Zip can be obtained [here](https://www.7-zip.org/). Make sure the installation directory containing `7z.exe` is added to the system PATH environment variable.

Cleanup of the bundles cache can be scheduled via the [Task Scheduler](https://docs.microsoft.com/en-us/windows/win32/taskschd/task-scheduler-start-page). For an example of a PowerShell script that deletes old files [see here](https://github.com/chrisdee/Scripts/blob/master/PowerShell/Working/files/ListOrDeleteFilesAfterNumberOfDays.ps1). An example invocation that deletes files older than two days is:
```
powershell ListOrDeleteFilesAfterNumberOfDays.ps1 -FolderPath d:\condor\bundles -FileAge 2 -LogFile d:\condor\deleteold.log
```

## POSIX Commands for Windows

The default value for [`BAT_TEMPLATE`](configuring.md##bat_template) and [`SEED_BAT_TEMPLATE`](configuring.md##seed_bat_template) use [POSIX](https://en.wikipedia.org/wiki/POSIX) commands that are normally **not** available on a Windows execution point. For example, [touch](https://linux.die.net/man/1/touch) is used to update the timestamp of the bundle to the current time when a job launches. This ensures that that a bundle will not be auto-deleted as long as jobs continue to get launched from it.

Make the needed POSIX commands available on your Windows execution points by installing any of many sets of POSIX utilities and adding them to the system `PATH` environment variable. When you have GAMS installed on an execution point, you already have an adequate set of [POSIX utilities](https://www.gams.com/latest/docs/T_POSIX.html) available in the `gbin` subdirectory of the GAMS installation: add that directory to the system `PATH`.

## Advertising capabilities

For a job to run on an execution point, certain capabilities may need to be in place. For example, a language interpreter may need to be installed. To ensure that jobs get scheduled on execution points that have the capability to run them, the user can configure [`REQUIREMENTS`](configuring.md#requirements) for a run of jobs. When these match the advertised capabilities of an execution point, the host becomes eligible.

To advertise custom capabilities of execution points, define ClassAds in their HTCondor configuration. This is done by editing the `condor_config.local` configuration file on each host. For example, to advertise that both an R and GAMS language interpreter are available and on-path, add the following lines:
```
# Have a GAMS installation on-path
GAMS = True

# Have an R installation on-path.
R = True

STARTD_ATTRS = \
  GAMS, \
  R, \
  $(STARTD_ATTRS)
```

**:point_right:Note:** any valid (but preferably descriptive) ClassId name that is not in use yet can be chosen to identify a custom capability. After configuring custom capabilities, notify the users of your cluster what capabilities are available, and how to configure requirements to select custom capabilities for their job runs.

## Configuring [templates](configuring.md#templates) for a different cluster
The [template](configuring.md#templates) default values work with the IIASA Limpopo cluster. To configure the templates for a different cluster, override [`SEED_JOB_TEMPLATE`](configuring.md#seed_job_template) and [`JOB_TEMPLATE`](configuring.md#job_template) found in both `Condor_run.R` and `Condor_run_basic.R` to generate Condor job files appropriate for the cluster. In addition, override [`SEED_BAT_TEMPLATE`](configuring.md#seed_bat_template) and [`BAT_TEMPLATE`](configuring.md##bat_template) to generate batch files or shell scripts that will run the jobs on your cluster's execution points.

As Condor administrator, you can adjust the configuration of execution points to accommodate their seeding with bundles. Though seeding jobs request minimal resources, Condor nevertheless does not schedule them when there is not at least one unoccupied CPU (the HTCondor concept of "CPU", which is basically a single hardware thread resource) or a minimum of disk, swap, and memory available on execution points. Presumably, Condor internally amends a job's stated resource requirements to make them more realistic. Unfortunately, this means that when one or more execution points are fully occupied, submitting a new run through `Condor_run_R` scripting will have the seeding jobs of hosts remain idle (queued).

The default [seed job configuration template](configuring.md#seed_job_template) has been set up to time out in that eventuality. But if that happens, only a subset of the execution points will participate in the run. And if all execution points are fully occupied, all seed jobs will time out and the submission will fail. To prevent this from happening, adjust the Condor configuration of the execution points to provide a low-resource partitionable slot to which one CPU and a *small quantity* of disk, swap, and memory are allocated. Once so reconfigured, this slot will be mostly ignored by resource-requiring jobs, and remain available for seeding jobs.

To resolve the question of what constitutes a *small quantity*, the test script in [`tests/seeding`](tests/seeding/purpose.md) can be used to fully occupy a cluster or a specific execution point (use the [`HOST_REGEXP`](configuring.md#host_regexp) config setting) and subsequently try seeding. Perform a bisection search of the execute host's seeding slot disk, swap, memory resource allocation—changing the allocation between tests—to determine the rough minimum allocation values that allow seeding jobs to be accepted. These values should be minimized so as to make it unlikely that a resource-requesting job gets scheduled in the slot. The slot also needs at least one CPU dedicated to it. Make sure that the Condor daemons on the execution point being tested pick up the configuration after you change it and before running the test again.

A basic configuration  with two partitionable slots, one for scheduling computational jobs, and a minimized slot 2 for receiving bundles might look like this:
```
SLOT_TYPE_1 = cpus=63/64, ram=63/64, swap=63/64, disk=63/64
SLOT_TYPE_2 = cpus=1/64  ram=1/4096, swap=1/4096, disk=1/4096
NUM_SLOTS_TYPE_1 = 1
NUM_SLOTS_TYPE_2 = 1
SLOT_TYPE_1_PARTITIONABLE = True
SLOT_TYPE_2_PARTITIONABLE = True
```
These lines can be included in the `condor_config.local` file of an execution point.

## Tuning Throughput

Throughput can be improved by tuning the configuration of execution points. See [this Linux performance tuning](https://wiki.archlinux.org/title/Improving_performance) or [Microsoft's Windows Server 2022 performance tuning](https://docs.microsoft.com/en-us/windows-server/administration/performance-tuning/) guide.

But even with a tuned OS you may still notice that jobs are migrated between [NUMA](https://en.wikipedia.org/wiki/Non-uniform_memory_access) nodes, or that secondary threads of CPU cores are occupied while other cores sit idle. This means that throughput can sometimes be improved further by configuring affinity/pinning to particular subsets of core threads (CPUs in Condor-speak) via the `condor_config.local` configuration of the execution point.

For affinity, configurables to look at are [`ENFORCE_CPU_AFFINITY`](https://htcondor.readthedocs.io/en/latest/admin-manual/configuration-macros.html#ENFORCE_CPU_AFFINITY) and [`SLOT<N>_CPU_AFFINITY`](https://htcondor.readthedocs.io/en/latest/admin-manual/configuration-macros.html#SLOT<N>_CPU_AFFINITY). For prioritizing how slots get filled, pertinent configuration settings include [`NEGOTIATOR_PRE_JOB_RANK`](https://htcondor.readthedocs.io/en/latest/admin-manual/configuration-macros.html#NEGOTIATOR_PRE_JOB_RANK) and [`NEGOTIATOR_POST_JOB_RANK`](https://htcondor.readthedocs.io/en/latest/admin-manual/configuration-macros.html#NEGOTIATOR_POST_JOB_RANK).

The actual tuning involves performing experiments to determine how well various execution point configurations work. Prepare a representative test workload, and submit it through `Condor_run_basic.R` or `Condor_run.R`. The [`basic` test](tests/basic/purpose.md) can also be used as a test workload. Analyze the results with `Condor_run_stat.R`: it generates a PDF report showing details of throughput as well as slot allocation. [`HOST_REGEXP`](configuring.md#host_regexp) can be used to ensure that jobs get scheduled only on the execution point being tuned.
