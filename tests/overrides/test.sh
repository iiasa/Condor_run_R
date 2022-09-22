#!/bin/bash
pushd "$(dirname "$0")"
set -e
Rscript ../../Condor_run_basic.R config.R
cat Condor/overrides/*.job
popd
