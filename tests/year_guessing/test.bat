@echo off
pushd %~dp0
Rscript ..\..\Condor_run_stats.R logs || (
    popd
    exit /b 1
)
echo ---
echo Check the plots with time axes for oddities.
echo ---
popd
