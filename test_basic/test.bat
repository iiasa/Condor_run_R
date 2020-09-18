:<<BATCH
@echo off
pushd %~dp0
Rscript ..\Condor_run_basic.R config.R
Rscript ..\Condor_run_stats.R
popd
exit /b :: end batch script processing
BATCH
# Platform-agnostic script.
# Put batch commands above and functionally-identical Linux/MacOS shell
# commands terminated by a # below. Save this script with CR+LF end-of-line
# breaks. The trailing # makes the shell ignore the CR.
# Must be run with the bash shell.
pushd "$(dirname "$0")" #
Rscript ../Condor_run_basic.R config.R #
Rscript ../Condor_run_stats.R #
popd #
