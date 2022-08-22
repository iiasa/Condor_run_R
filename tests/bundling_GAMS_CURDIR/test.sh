#!/bin/bash
pushd "$(dirname "$0")"
set -e
Rscript ../../Condor_run.R config.R
popd
