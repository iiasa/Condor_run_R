#!/bin/bash
pushd "$(dirname "$0")"
set -e
Rscript ../../Condor_run.R config.R
7z l Condor/**/_bundle*.7z
popd
