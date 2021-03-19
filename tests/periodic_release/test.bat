:<<BATCH
@echo off
pushd %~dp0
Rscript ..\..\Condor_run_basic.R config.R || (
    popd
    exit /b 1
)
Rscript ..\..\Condor_run_stats.R config.R
popd
exit /b :: end batch script processing
BATCH
# Platform-agnostic script.
# Put batch commands above and functionally-identical Linux/MacOS shell commands
# terminated by a # below. When saving this script with CR+LF end-of-line breaks,
# the trailing # makes the shell ignore the CR. Must be run with the bash shell.
pushd "$(dirname "$0")" #
set -e #
Rscript ../../Condor_run_basic.R config.R #
Rscript ../../Condor_run_stats.R config.R #
popd #
