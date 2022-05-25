Test that the cluster's execution points accept bundle seed jobs even when
otherwise occupied. The test first submits a run of jobs that occupy all
resource-requiring slots. Then an additional run is submitted whose bundle
seed jobs should run successfully in spite of the otherwise full occupation.

This test verifies that the execution points have been configured as described
[here](../../README.md#configuring-execute-hosts).

Note that the per-execute-host seed jobs as submitted by `Condor_run.R` and
`Condor_run_basic` are not blocking but time out if they do not succeed after
a configurable number of releases. The execution points that thereby did not
receive the seed bundle are prevented from participating in the subsequent
submission. This is visible in the logging output. Excluded execution points
might not be properly configured for always accepting seed jobs and should be
examined.
