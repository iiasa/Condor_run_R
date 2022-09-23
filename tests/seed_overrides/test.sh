#!/bin/bash
pushd "$(dirname "$0")"
set -e
Rscript ../../Condor_run_basic.R config.R
cat Condor/seed_overrides/_seed_*.job
popd
