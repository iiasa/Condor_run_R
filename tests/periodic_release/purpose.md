Test that the `periodic_release` clause in the job file works as intended and
configured via the default `JOB_RELEASES` setting. The intent is to
automatically release held jobs for a re-run up to the configured
`JOB_RELEASES` number of times. This will make jobs automatically recover
from transient failures, but not keep on re-trying indefinitely if there is
an intrinsic problem.

The run of jobs is submitted via `Condor_run_basic.R`. Simple R jobs are
submitted. These either randomly fail with a low probability, or sleep for
some seconds and return a bit of data. The test script passes when after a
few releases, the failed/held jobs will succeed as well.

A job might get really unlucky and randomly fail `1+JOB_RELEASES` times.
This unlikely circumstance manifests by the test not completing and a job
remaining in the held state. If this happens, abort the test script,  issue
`condor_rm <user>`, and re-run the test.
