#!/bin/bash
pushd "$(dirname "$0")" >/dev/null
set -e
Rscript ../../Condor_run_stats.R logs
echo ---
echo Check the plots with time axes for oddities.
echo ---
popd >/dev/null
