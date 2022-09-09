#!/bin/bash
pushd "$(dirname "$0")"
set -e
rm -f output/result*.???
Rscript ../../Condor_run_basic.R config.R
ls output
popd
