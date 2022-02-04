#!/bin/bash
pushd "$(dirname "$0")"
set -e
Rscript ../../Condor_run_basic.R config.R
Rscript ../../Condor_run_stats.R config.R
popd
