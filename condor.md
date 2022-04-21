# Configuring a Condor cluster in support of `Condor_run_R`
This page, currently in draft form, collects information on how to set up or re-configure a Condor cluster in support of the `Condor_run_R` submit scripts. In particular the bundle caching feature requires a bit of specialized support on the execute host side.

## Setting up a bundles cache

To support receiving and caching bundles, each execute host should provide a directory with appropriate access rights where the bundles can be cached, and should periodically delete old bundles in those caches so as to prevent their disks from filling up.
### Windows

On Windows, you can schedule cache cleanup via the [Task Scheduler](https://docs.microsoft.com/en-us/windows/win32/taskschd/task-scheduler-start-page). For an example of a PowerShell script that deletes old files [see here](https://github.com/chrisdee/Scripts/blob/master/PowerShell/Working/files/ListOrDeleteFilesAfterNumberOfDays.ps1). An example invocation that deletes files older than two days is:
```
powershell ListOrDeleteFilesAfterNumberOfDays.ps1 -FolderPath d:\condor\bundles -FileAge 2 -LogFile d:\condor\deleteold.log
```

#### Linux

On Linux, the `find` command can be used. For example [`find <cache directory> -mtime +1 -delete`](https://manpages.debian.org/bullseye/findutils/find.1.en.html) command that will delete all bundles with a timestamp older than one day. This can be scheduled via a [crontab entry](https://en.wikipedia.org/wiki/Cron) or a timer/service pair of SystemD unit files.

## Advertising capabilities

For a job to run on an execute host, certain capabilities may need to be in place. For examle, a language interpreter may need to be installed. To ensure that jobs get scheduled on execute hosts that have the capability to run them, the user can configure [`REQUIREMENTS`](configuring.md#requirements) for a run of jobs. When these match the advertised capabilities of an execute host, the host becomes eligable.

To advertise custom capabilities of execute hosts, ydefine ClassAds in their HTCondor configuration. This is done by editing the `condor_config.local` configuration file on each host. For example, to advertise that both an R and GAMS language interpreter are available and on-path, add the following lines:
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

After configuring custom capabilities, notify the users of your cluster what capabilities are available, and how to configure requirements to select that capability for their job runs.

## Configuring [templates](configuring.md#templates) for a different cluster

The [template](configuring.md#templates) default values work with the IIASA Limpopo cluster. To configure the templates for a different cluster, override [`SEED_JOB_TEMPLATE`](configuring.md#seed_job_template) and [`JOB_TEMPLATE`](configuring.md#job_template) found in both `Condor_run.R` and `Condor_run_basic.R` to generate Condor job files appropriate for the cluster. In addition, override [`SEED_BAT_TEMPLATE`](configuring.md#seed_bat_template) and [`BAT_TEMPLATE`](configuring.md##bat_template) to generate batch files or shell scripts that will run the jobs on your cluster's execute hosts.

As Condor administrator, you can adjust the configuration of execute hosts to accommodate their seeding with bundles. Though seeding jobs request minimal resources, Condor nevertheless does not schedule them when there is not at least one unoccupied CPU (the HTCondor concept of "CPU", which is basically a single hardware thread resource) or a minimum of disk, swap, and memory available on execute hosts. Presumably, Condor internally amends a job's stated resource requirements to make them more realistic. Unfortuntely, this means that when one or more execute hosts are fully occupied, submitting a new run through `Condor_run_R` scripting will have the seeding jobs of hosts remain idle (queued).

The default [seed job configuration template](configuring.md#seed_job_template) has been set up to time out in that eventuality. But if that happens, only a subset of the execute hosts will participate in the run. And if all execute hosts are fully occupied, all seed jobs will time out and the submission will fail. To prevent this from happening, adjust the Condor configuration of the execute hosts to provide a low-resource partitionable slot to which one CPU and a *small quantity* of disk, swap, and memory are allocated. Once so reconfigured, this slot will be mostly ignored by resource-requiring jobs, and remain available for seeding jobs.

To resolve the question of what consitutes a *small quantity*, the test script in `tests/seeding` can be used to fully occupy a cluster or a specific execute host (use the `HOST_REGEXP` config setting) and subsequently try seeding. Perform a bisection search of the excecute host's seeding slot disk, swap, memory resource allocation—changing the allocation between tests—to determine the rough minimum allocation values that allow seeding jobs to be accepted. These values should be minimized so as to make it unlikely that a resource-requesting job gets scheduled in the slot. The slot also needs at least one CPU dedicated to it. Make sure that the Condor daemons on the execute host being tested pick up the configuration after you change it and before running the test again.

## POSIX commands for Windows execute hosts

The default values for [`BAT_TEMPLATE`](configuring.md##bat_template) and [`SEED_BAT_TEMPLATE`](configuring.md##seed_bat_template) use [POSIX](https://en.wikipedia.org/wiki/POSIX) commands that are by default not available on Windows. For example batch/shell script that launches a job should contains a [touch](https://linux.die.net/man/1/touch) to update the timestamp of the bundle to the current time. This ensures that that a bundle will not be deleted as long as jobs continue to get scheduled from it. This batch/shell script is generated from the [`BAT_TEMPLATE`](configuring.md##bat_template) whose default value includes an invocation of `touch`.

Make the needed POSIX commands available on your Windows execute hosts by installing any of many sets of POSIX utilities and adding them to the system `PATH` environment variable. When you have GAMS installed on an execute host, you already have an adequete set of [POSIX utilities](https://www.gams.com/latest/docs/T_POSIX.html) available in the `gbin` subdirectory of the GAMS installation: add that directory to the system `PATH`.
