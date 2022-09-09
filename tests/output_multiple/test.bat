@echo off
pushd %~dp0
del output\result*.??? 2>NUL
Rscript ..\..\Condor_run_basic.R config.R || (
    popd
    exit /b 1
)
dir output
popd
