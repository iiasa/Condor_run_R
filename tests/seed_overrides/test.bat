@echo off
pushd %~dp0
Rscript ..\..\Condor_run_basic.R config.R || (
    popd
    exit /b 1
)
type Condor\seed_overrides\_seed_*.job
popd
