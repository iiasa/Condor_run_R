# Troubleshooting

When you have an issue with getting your jobs to run or with retrieving output, please see if your problem is listed below. As a default solution, reboot your submit machine: it often helps.

- [Submit script immediately aborts with an error](#submit-script-immediately-aborts-with-an-error)
- [Cannot submit jobs](#cannot-submit-jobs)
- [The script does not progress](#the-script-does-not-progress)
- [You get `ERROR: No credential stored for` *`<user>@<domain>`* but did store your credentials](#you-get-error-no-credential-stored-for-userdomain-but-did-store-your-credentials)
- [Seeding jobs remain idle and then abort through the PeriodicRemove expression](#seeding-jobs-remain-idle-and-then-abort-through-the-periodicremove-expression)
- [Seeding jobs stay in the running state indefinitely](#seeding-jobs-stay-in-the-running-state-indefinitely)
- [Jobs do not run but instead go on hold](#jobs-do-not-run-but-instead-go-on-hold)
- [Seeding fails or jobs go on hold without producing matching `.log` files](#seeding-fails-or-jobs-go-on-hold-without-producing-matching-log-files)
- [Jobs run but at the end fail to send and write output files](#jobs-run-but-at-the-end-fail-to-send-and-write-output-files)
- [Jobs are idle and do not run, or only some do](#jobs-are-idle-and-do-not-run-or-only-some-do)
- [`Condor_run_stats.R` produces empty plots](#condor_run_statsr-produces-empty-plots)
- [Condor commands like `condor_q` fail](#condor-commands-like-condor_q-fail)
- [None of the above solves my problem](#none-of-the-above-solves-my-problem)
- [Further information](#further-information)

## Submit script immediately aborts with an error

Look carefully at the error message. If a file or directory cannot be located, a likely cause is a mismatch between the paths specified in the configuration file and the current working directory on invoking the submit script: most of the path configuration settings are relative to the current working directory. See [here](configuring.md#path-handling) for further details on path handling.

When the error message relates to a specific configuration setting, please review the documentation of that setting by locating it in the configuration documentation as described [here](configuring.md#configuring-the-condor-submit-scripts).

## Cannot submit jobs

When you cannot submit jobs, ensure that:
- You have reviewed the output of the submit script for causes and solutions.
- You have obtained access to the Condor cluster from the cluster administrator.
- You stored the necessary credentials via [`condor_store_cred add`](https://htcondor.readthedocs.io/en/latest/man-pages/condor_store_cred.html):
  * Type [`condor_store_cred add`](https://htcondor.readthedocs.io/en/latest/man-pages/condor_store_cred.html) on the command line and, when prompted, enter your login password to allow Condor to schedule jobs as you.
    + **:point_right:Note**: you will need to do this again after changing your password.
  * Type [`condor_store_cred -c add`](https://htcondor.readthedocs.io/en/latest/man-pages/condor_store_cred.html) and, when prompted, enter the condor pool password (ask your administrator).
- Issuing the command [`condor_status`](https://htcondor.readthedocs.io/en/latest/man-pages/condor_status.html) tabulates the cluster status.
- Issuing the command [`condor_q`](https://htcondor.readthedocs.io/en/latest/man-pages/condor_q.html) results in a summary of queued jobs.
- The [templates are adapted to your cluster](configuring.md#configuring-templates-for-a-different-cluster).
- You are using [up-to-date scripts](README.md#updating).

## The script does not progress

The output may be blocked. On Linux, this can happen on account of entering CTRL-S, enter CTRL-Q to unblock. On Windows, this may happen when clicking on the Command Prompt window. Give the window focus and hit backspace or enter CTRL-Q to unblock it. To get rid of this annoying behavior permanently, right-click on the Command Prompt title bar and select **Defaults**. In the dialog that appears, in the **Options** tab, deselect **QuickEdit Mode** and click **OK**. After doing so, you can left-click and drag to select text in the Command Prompt window only after first entering CTRL-M or selecting the **Edit → Mark** menu item.

## You get `ERROR: No credential stored for` *`<user>@<domain>`* but did store your credentials

Try to submit again. It might be a transient error.

If not, you may have recently changed your password and need to store your user credentials again with [`condor_store_cred add`](https://htcondor.readthedocs.io/en/latest/man-pages/condor_store_cred.html) (see above).

## Seeding jobs remain idle and then abort through the PeriodicRemove expression

A likely reason is that your cluster administrator has not given you access to the cluster yet. Ask your cluster administrator to provide access / white-list you. However, if you have successfully submitted jobs before, read on because the cause is likely different.

It may be that the entire cluster is unavailable, but that is somewhat unlikely. Also, it may be that the entire cluster is fully occupied and the execution points have not been [properly configured to always accept seeding jobs](condor.md) by the Condor administrator. Use [`condor_status -submitters`](https://htcondor.readthedocs.io/en/latest/man-pages/condor_status.html) to check availability and occupation.

Alternatively, the machine you submit from announcing itself with a wrong domain is a possible cause. It has been seen to happen that submit machines announce themselves with the `local` domain, which is not valid for remote access so that jobs cannot be collected. To check whether the submit machine has announced itself wrongly, issue the [`condor_q`](https://htcondor.readthedocs.io/en/latest/man-pages/condor_q.html) command. The output should contain the hostname and domain of your machine. If the domain is `local` the issue is likely present and can be resolved by restarting the Condor background processes on the submit machine.

The crude way to restart Condor is to reboot the submit machine. The better way is to restart the Condor service. This can be done via the Services application on Windows or via [`systemctl restart condor.service`](https://manpages.debian.org/bullseye/systemctl/systemctl.1.en.html) with root privileges on Linux.

## Seeding jobs stay in the running state indefinitely

This can occur on account of outdated state such as a stale IP address being cached by HTCondor daemons. Stop the script, invoke [`condor_restart -schedd`](https://htcondor.readthedocs.io/en/latest/man-pages/condor_restart.html), and try to submit again.

If the resubmission also stays stuck in the running state when transferring the bundle, stop the script, reboot, and then try to submit again.

## Jobs do not run but instead go on hold

Some error occurred. Errors can be transient. With the [`JOB_RELEASES`](configuring.md#job_releases) retry count set, on-hold jobs will be auto-released for a retry after [`JOB_RELEASE_DELAY`](configuring.md#job_release_delay) seconds have passed in an attempt to recover from transient errors. This process can be monitored by examining the `.log` file of a job. When jobs keep on failing and the retry count runs out, they go on hold permanently.

In that case (when you see that jobs remain in the *hold* state without being rescheduled after a few minutes), the error is probably not transient and requires some analysis. Look at the output of the `Condor_run[_basic].R` script for some initial clues. Next, issue [`condor_q -held`](https://htcondor.readthedocs.io/en/latest/man-pages/condor_q.html) to review the hold reason. If the hold reason is `Failed to initialize user log to <some path on a network drive>`, see [the next section](#jobs-go-on-hold-without-producing-matching-log-files).

Otherwise investigate further. If you can, try to run the job that failed on your local machine and see if you can reproduce the error. Local analysis tends to be much easier than figuring out what went wrong on a remote execution point. When available, run from within an integrated development environment with debug facilities. Setting the [`RETAIN_BUNDLE`](configuring.md#retain_bundle) option to `TRUE` can assist with local analysis. This will preserve a copy of the 7-Zip bundle sent to the execution points in the [log directory of the run](configuring.md#condor_dir). Unzipping that bundle will give you a replica of the file tree that the jobs were started with. The command line that starts a job can be found in the `.bat` file located in that same log directory.

If local replication and analysis is not possible, look at the various log files located at [`<CONDOR_DIR>`](configuring.md#condor_dir)`/`[`<LABEL>`](configuring.md#label). The log files to examine are, in order of priority:
1.  `.log` files: these files give per-job information on how Condor scheduled the job and transferred its inputs and outputs. When a `.log` file indicates that something went wrong with the transfer of an output file, the cause is likely *not* the transfer but rather some earlier error that made the job fail before it could produce output. Do not confuse these files with GAMS `.log` files.
2.  `.err` files: these capture the [standard error](https://en.wikipedia.org/wiki/Standard_streams#Standard_error_(stderr)) stream of each job as it runs remotely. They grow as jobs run. When not empty, likely some error occurred. For GAMS jobs, most errors are instead logged to the `.out` and `lst` files with only system-level errors producing `.err` output.
3.  `.out` files: these capture the [standard output](https://en.wikipedia.org/wiki/Standard_streams#Standard_output_(stdout)) stream of each job as it runs remotely. They grow as jobs run. Errors may be logged here too. For GAMS jobs, these files contain what is normally stored in GAMS log files (which confusingly can have the same file extension as the Condor `.log` files mentioned above) or shown in the system log of GAMS Studio. Look for high-level errors/warnings near the end.
4.  `.lst` files: these are [GAMS listing files](https://www.gams.com/latest/docs/UG_GAMSOutput.html). They are produced only for GAMS jobs. The `.lst` file is transferred when a job completes or aborts and as such are not available yet while the job is still scheduled. For GAMS, this is the place to look for detailed errors. Search for `****` backwards from the end to locate them.
5.  `_bundle_<cluster number>_contents.txt`: a listing of the contents of the bundle. Check if all files needed by your job were bundled.

Should the log files show that an error occurred on the execution point but you cannot figure out why, being able to log in to the execution point and analyse the problem there is helpful. If you have such rights, check which host the job ran on and what its working directory is by examining the start of the `.out` file. As long as the job is on hold, the working directory will remain in existence. Beware that the job might be released from its hold state for a retry while the [`JOB_RELEASES`](configuring.md#job_releases) count has not been exhausted yet.

If the above does not clarify the problem, execute [`condor_q –analyze`](https://htcondor.readthedocs.io/en/latest/man-pages/condor_q.html) and examine the output: it might be something that happened after the job completed, e.g. result files not fitting because your disk is full.

When your analysis indicates that the error might still be transient, you can release the on-hold jobs for a retry by issuing [`condor_release <cluster number of the run>`](https://htcondor.readthedocs.io/en/latest/man-pages/condor_release.html) or, if you have only one set of jobs going, [`condor_release <your user name>`](https://htcondor.readthedocs.io/en/latest/man-pages/condor_release.html).

When you are done analyzing the held jobs, use [`condor_rm`](https://htcondor.readthedocs.io/en/latest/man-pages/condor_rm.html) (with a cluster number or your user name as argument) to remove them from the queue. This will clean up their working directories on the execution point.

## Seeding fails or jobs go on hold without producing matching `.log` files

When seeding or regular jobs produce no `.log` files in a subdirectory of [`CONDOR_DIR`](configuring.md#condor_dir) there are three likely causes:

- The pool credentials are not stored or outdated. Store the pool password again using [`condor_store_cred -c add`](https://htcondor.readthedocs.io/en/latest/man-pages/condor_store_cred.html) and retry. Ask your cluster administrator for the pool password.

- [`CONDOR_DIR`](configuring.md#condor_dir) is on a network share that your user account can access but the locally running Condor daemon/service cannot. This can be resolved in several ways:
  * Move the whole project file tree containing `CONDOR_DIR` from the network share to a local disk.
  * Reconfigure [`CONDOR_DIR`](configuring.md#condor_dir) to point to a directory on a local disk (absolute paths are allowed) that Condor can access.
  * Try to reconfigure the Condor service/daemon to run from a different account or with additional rights as needed to access the network share.

- The permissions on [`CONDOR_DIR`](configuring.md#condor_dir) prevent access by the locally running Condor daemon/service. Either change the permissions on [`CONDOR_DIR`](configuring.md#condor_dir) to give Condor access or reconfigure the Condor daemon/service to run from a different account or with additional rights as needed to access the [`CONDOR_DIR`](configuring.md#condor_dir) directory.

## Seeding fails when removing a `.log` file

When you get an error such as
```
Error: [EPERM] Failed to remove 'Condor/basic_2022-12-20/_seed_limpopo1.log': operation not permitted
```
the Condor daemon does not have sufficient permissions to access the [log directory of the run](configuring.md#condor_dir). The underlying problem is that the Condor daemon that does the logging does not run under your user account and as such does not have the same permissions as you do. Give other user accounts more rights on the log directory, or recursively from one of its parent directories.

## Jobs run but at the end fail to send and write output files

There are two likely causes:

1. An [`[G00_|GDX_]OUTPUT_DIR[_SUBMIT]`](configuring.md#output_dir) configuration setting is pointing to a directory on a network share that your user account can access but the locally running Condor daemon/service cannot. Either reconfigure that configuration setting to point to a directory on a local disk (absolute paths are allowed in case of the `_SUBMIT` variants) that Condor can access or try to reconfigure the Condor service/daemon to run from a different account or with additional rights as needed to access the network share.

2. The permissions on the directory pointed to by [`[G00_|GDX_]OUTPUT_DIR[_SUBMIT]`](configuring.md#output_dir) prevent access by the locally running Condor daemon/service. Either change the permissions on that directory to give Condor access or reconfigure the Condor daemon/service to run from a different account or with additional rights as needed to gain access.

## Jobs are idle and do not run, or only some do

The cluster may be busy. To see who else has submitted jobs, issue [`condor_status -submitters`](https://htcondor.readthedocs.io/en/latest/man-pages/condor_status.html). In addition, you may have a low priority so that jobs of others are given priority, pushing your jobs to the back of the queue. To see your priority issue [`condor_userprio`](https://htcondor.readthedocs.io/en/latest/man-pages/condor_userprio.html). Large numbers mean low priority. Your cluster administrator can set your priority.

If the cluster has unused capacity, it may be that your jobs remain idle (queued and waiting to be scheduled) because they are requesting more memory or other resources than currently available. For details, see [`REQUEST_MEMORY`](configuring.md#request_memory), [`REQUEST_DISK`](configuring.md#request_disk), and [`REQUEST_CPUS`](configuring.md#request_cpus). Either wait for sufficient resources to become available, or reduce the requested resources if possible. **:warning:Beware:** use the right units for each of the request configurations!

## Condor commands like `condor_q` fail

Check your network connection. Check if your submit machine can reach machines in the pool, e.g. by issuing a `ping` command on the command line.

If there is no issue with the above, it might instead be that a outdated IP address was cached, in particular if the error looks something like:
```
> condor_q
-- Failed to fetch ads from: <123.234.145.156:9618?addrs=123.234.145.156-9618&noUDP&sock=3728_5f68_3> : pcname.orgname.local
CEDAR:6001:Failed to connect to <123.234.145.156:9618?addrs=123.234.145.156-9618&noUDP&sock=3728_5f68_3>
```

In that case, restarting Condor daemons via [`condor_restart`](https://htcondor.readthedocs.io/en/latest/man-pages/condor_restart.html) or rebooting might help.

## `Condor_run_stats.R` produces empty plots

When running `Condor_run_stats.R` and some of the resulting plots are empty, the console output probably contained something like:
```
Warning message:
Cannot extract submit time from Condor event log (e.g. ~/Condor_run_R/tests/basic/Condor/basic/job_570.0.log). Unable to determine latency between job submission and start time. Latency results and plots will be partially or fully unavailable.
```
This results from  one or more of the per-job `.log` files lacking a line identifying the source and time of submission. Examine the SchedLog entries on your submit machine at the time of the submission, e.g. via:
```
condor_fetchlog localhost SCHEDD
```
There you should find error messages that will help you resolve the problem.

## None of the above solves my problem

Reboot your machine and try to submit again. If that does not help, try to invoke `Rscript` with the `--vanilla` option.

## Further information

For further information, see the [why is the job not running?](https://htcondor.readthedocs.io/en/latest/users-manual/managing-a-job.html#why-is-the-job-not-running) section of the HTCondor manual and the [university of Liverpool Condor Troubleshooting guide](https://condor.liv.ac.uk/troubleshooting/).
