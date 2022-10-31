#!/bin/bash
pushd "$(dirname "$0")"
set -e
rm -f _bundle*.7z
Rscript ../../Condor_run_basic.R --bundle-only config.R
Rscript ../../Condor_run_basic.R _bundle*.7z
Rscript ../../Condor_run_stats.R config.R
popd
