#!/bin/bash
pushd "$(dirname "$0")"
set -e
Rscript ../../Condor_run_basic.R config1.R
echo Waiting for occupation to settle...
sleep 600
Rscript ../../Condor_run_basic.R config2.R
popd
