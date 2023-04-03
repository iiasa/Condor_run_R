@echo off
pushd %~dp0
Rscript ..\..\Condor_run.R config.R || (
    popd
    exit /b 1
)
popd
