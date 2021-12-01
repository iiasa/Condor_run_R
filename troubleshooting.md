# Troubleshooting
When you have an issue with getting your jobs to run or with retrieving output, please see if your problem is listed below. As a default solution, reboot your submit machine: it often helps.

- [Cannot submit jobs](#cannot-submit-jobs)
- [The script does not progress](#the-script-does-not-progress)
- [You get `ERROR: No credential stored for` *`<user>@<domain>`* but did store your credentials](#you-get-error-no-credential-stored-for-userdomain-but-did-store-your-credentials)
- [When transferring the bundle, jobs stay in the running state indefinitely](#when-transferring-the-bundle-jobs-stay-in-the-running-state-indefinitely)
- [Jobs do not run but instead go on hold](#jobs-do-not-run-but-instead-go-on-hold)
- [Jobs go on hold without producing matching `.log` files](#jobs-go-on-hold-without-producing-matching-log-files)
- [Jobs run but at the end fail to send and write output files](#jobs-run-but-at-the-end-fail-to-send-and-write-output-files)
- [All seeding jobs remain idle and then abort through the PeriodicRemove expression](#all-seeding-jobs-remain-idle-and-then-abort-through-the-periodicremove-expression)
- [Jobs are idle and do not run, or only some do](#jobs-are-idle-and-do-not-run-or-only-some-do)
- [None of the above solves my problem](#none-of-the-above-solves-my-problem)
- [Further information](#further-information)

## Cannot submit jobs
When you cannot submit jobs, ensure that:
- You have reviewed the output of the submit script for causes and solutions.
- You have obtained access to the Condor cluster from the cluster administrator.
- You stored the necessary credentials via [`condor_store_cred add`](https://htcondor.readthedocs.io/en/latest/man-pages/condor_store_cred.html):
  * Type [`condor_store_cred add`](https://htcondor.readthedocs.io/en/latest/man-pages/condor_store_cred.html) on the command line and, when prompted, enter your login password to allow Condor to schedule jobs as you.
    + **Note**: you will need to do this again after changing your password.
  * Type [`condor_store_cred -c add`](https://htcondor.readthedocs.io/en/latest/man-pages/condor_store_cred.html) and, when prompted, enter the condor pool password (ask your administrator).
- Issuing the command [`condor_status`](https://htcondor.readthedocs.io/en/latest/man-pages/condor_status.html) tabulates the cluster status.
- Issuing the command [`condor_q`](https://htcondor.readthedocs.io/en/latest/man-pages/condor_q.html) results in a summary of queued jobs.
- The [templates are adapted to your cluster](README.md#adapting-templates-to-your-cluster).
- You are using [up-to-date scripts](README.md#updating).

## The script does not progress
The output may be blocked. On Linux, this can happen on account of entering CTRL-S, enter CTRL-Q to unblock. On Windows, this may happen when clicking on the Command Prompt window. Give the window focus and hit backspace or enter CTRL-Q to unblock it. To get rid of this annoying behavior permanently, right-click on the Command Prompt titlebar and select **Defaults**. In the dialog that appears, in the **Options** tab, deselect **QuickEdit Mode** and click **OK**.

## You get `ERROR: No credential stored for` *`<user>@<domain>`* but did store your credentials
Try to submit again. It might be a transient error.

If not, you may have recently changed your password and need to store your user credentials again with [`condor_store_cred add`](https://htcondor.readthedocs.io/en/latest/man-pages/condor_store_cred.html) (see above).

## When transferring the bundle, jobs stay in the running state indefinitely
This can occur on account of outdated state such as a stale IP address being cached by HTCondor daemons. Stop the script, invoke [`condor_restart -schedd`](https://htcondor.readthedocs.io/en/latest/man-pages/condor_restart.html), and try to submit again. You will be asked to delete the bundle first.

If the resubmission also stays stuck in the running state when transferring the bundle, stop the script, reboot, and then try to submit again. If your temp directory survives reboots, you will again be asked to delete the bundle first.

## Jobs do not run but instead go on hold
Likely, some error occurred. First look at the output of the `Condor_run[_basic].R` script for clues. Next, issue [`condor_q -held`](https://htcondor.readthedocs.io/en/latest/man-pages/condor_q.html) to review the hold reason. If the hold reason  is `Failed to initialize user log to <some path on a network drive>`, see [the next section](#jobs-go-on-hold-without-producing-matching-log-files)

Otherwise investigate further. Look at the various log files located at [`<CONDOR_DIR>`](configuring.md#condor_dir)`/`[`<LABEL>`](configuring.md#label). The log files to examine are, in order of priority and by filename extension:
1.  `.log` files: these files give per-job information on how Condor scheduled the job and transferred its inputs and outputs. When a log file indicates that something went wrong with the transfer of an output file, the cause is likely *not* the transfer but rather to some earlier error that made the job fail before it could produce output. Do not confuse these files with GAMS `.log` files.
2.  `.err` files: these capture the [standard error](https://en.wikipedia.org/wiki/Standard_streams#Standard_error_(stderr)) stream of each job as it runs remotely. They grow as jobs run. When not empty, likely some error occurred. For GAMS jobs, most errors are instead logged to the `.out` and `lst` files with only system-level errors producing `.err` output.
3.  `.out` files: these capture the [standard output](https://en.wikipedia.org/wiki/Standard_streams#Standard_output_(stdout)) stream of each job as it runs remotely. They grow as jobs run. Errors may be logged here too. For GAMS jobs, these files contain what is normally stored in GAMS log files (which confusingly can have the same file extension as the Condor `.log` files mentioned above) or shown in the system log of GAMS Studio. Look for high-level errors/warnings near the end.
4.  `.lst` files: these are [GAMS listing files](https://www.gams.com/latest/docs/UG_GAMSOutput.html). They are produced only for GAMS jobs. The `.lst` file is transferred when a job completes or aborts and as such are not available yet while the job is still scheduled. For GAMS, this is the place to look for detailed errors. Search for `****` backwards from the end to locate them.

Should the log files show that an error occurred on the execute host but you cannot figure out why, being able to log in to the execute host and analyse the problem there is helpful. If you have such rights, check which host the job ran on and what its working directory is by examining the start of the `.out` file. As long as the job is on hold, the working directory will remain in existence. Beware that the job might be released from its hold state for a retry while the [`JOB_RELEASES`](configuring.md#job_releases) count has not been exhausted yet.

When you do not have the rights to log in to execute hosts to analyze held jobs in-situ, setting the [`RETAIN_BUNDLE`](configuring.md#retain_bundle) option to `TRUE` can assist. This will preserve a copy of the 7-Zip bundle sent to the execute hosts in the [log directory of the run](configuring.md#condor_dir). Unzip that bundle and try to run the job locally to see if you can reproduce the problem. The command line that invokes the job can be found in the `.bat` file located in that same log directory.

If the above does not clarify the problem, execute [`condor_q –analyze`](https://htcondor.readthedocs.io/en/latest/man-pages/condor_q.html) and examine the output: it might be something that happened after the job completed, e.g. result files not fitting because your disk is full.

When you are done analyzing the held jobs, use [`condor_rm`](https://htcondor.readthedocs.io/en/latest/man-pages/condor_rm.html) to remove them. This will clean up their working directories on the execute host.

## Jobs go on hold without producing matching `.log` files
When your job produced no `.log` files in a subdirectory of [`CONDOR_DIR`](configuring.md#condor_dir) there are three likely causes:

1. The pool credentials are not stored or outdated. Store the pool password again using [`condor_store_cred -c add`](https://htcondor.readthedocs.io/en/latest/man-pages/condor_store_cred.html) and retry. Ask your cluster administrator for the pool password.

2. [`CONDOR_DIR`](configuring.md#condor_dir) is on a network share that your user account can access but the locally running Condor daemon/service cannot. Either reconfigure [`CONDOR_DIR`](configuring.md#condor_dir) to point to a directory on a local disk (absolute paths are allowed) that Condor can access or try to reconfigure the Condor service/daemon to run from a different account or with additional rights as needed to access the network share.

3. The permissions on [`CONDOR_DIR`](configuring.md#condor_dir) prevent access by the locally running Condor daemon/service. Either change the permissions on [`CONDOR_DIR`](configuring.md#condor_dir) to give Condor access or reconfigure the Condor daemon/service to run from a different account or with additional rights as needed to access the [`CONDOR_DIR`](configuring.md#condor_dir) directory.

## Jobs run but at the end fail to send and write output files
There are two likely causes:

1. An [`[G00_|GDX_]OUTPUT_DIR[_SUBMIT]`](configuring.md#output_dir) configuration setting is pointing to a directory on a network share that your user account can access but the locally running Condor daemon/service cannot. Either reconfigure that configuration setting to point to a directory on a local disk (absolute paths are allowed in case of the `_SUBMIT` variants) that Condor can access or try to reconfigure the Condor service/daemon to run from a different account or with additional rights as needed to access the network share.

2. The permissions on the directory pointed to by [`[G00_|GDX_]OUTPUT_DIR[_SUBMIT]`](configuring.md#output_dir) prevent access by the locally running Condor daemon/service. Either change the permissions on that directory to give Condor access or reconfigure the Condor daemon/service to run from a different account or with additional rights as needed to gain access.

## All seeding jobs remain idle and then abort through the PeriodicRemove expression
It may be that the entire cluster is unavailable, but that is somewhat unlikely. It may be that the entire cluster is fully occupied and the execute hosts have not been [properly configured to always accept seeding jobs](README.md#configuring-execute-hosts) by the Condor administrator. Use [`condor_status -submitters`](https://htcondor.readthedocs.io/en/latest/man-pages/condor_status.html) to check availability and occuppation.

Alternatively, the machine you submit from announcing itself with a wrong domain is a possible cause. It has been seen to happen that submit machines announce themselves with the `local` domain, which is not valid for remote access so that jobs cannot be collected. To check whether the submit machine has announced itself wrongly, issue the [`condor_q`](https://htcondor.readthedocs.io/en/latest/man-pages/condor_q.html) command. The output should contain the hostname and domain of your machine. If the domain is `local` the issue is likely present and can be resolved by restarting the Condor background processes on the submit machine.

The crude way to restart Condor is to reboot the submit machine. The better way is to restart the Condor service. This can be done via the Services application on Windows or via [`systemctl restart condor.service`](https://manpages.debian.org/bullseye/systemctl/systemctl.1.en.html) with root privileges on Linux.

## Jobs are idle and do not run, or only some do
The cluster may be busy. To see who else has submitted jobs, issue [`condor_status -submitters`](https://htcondor.readthedocs.io/en/latest/man-pages/condor_status.html). In addition, you may have a low priority so that jobs of others are given priority, pushing your jobs to the back of the queue. To see your priority issue [`condor_userprio`](https://htcondor.readthedocs.io/en/latest/man-pages/condor_userprio.html). Large numbers mean low priority. Your cluster administrator can set your priority.

## None of the above solves my problem
Reboot your machine and try to submit again. If that does not help, try to invoke `Rscript` with the `--vanilla` option.

## Further information
For further information, see the [why is the job not running?](https://htcondor.readthedocs.io/en/latest/users-manual/managing-a-job.html#why-is-the-job-not-running) section of the HTCondor manual and the [university of Liverpool Condor Troubleshooting guide](https://condor.liv.ac.uk/troubleshooting/).
