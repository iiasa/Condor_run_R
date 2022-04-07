#!/bin/bash
pushd "$(dirname "$0")"
set -e
Rscript ../../Condor_run_basic.R config.R
echo Stop the condor service or deamons on your local machine and wait for
echo several minutes. Then restart the service or daemons and see if jobs
echo get rescheduled, log files are updated, and output is received.
popd
