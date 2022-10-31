@echo off
pushd %~dp0
del /Q _bundle*.7z 2>NUL
Rscript ..\..\Condor_run_basic.R --bundle-only config.R || (
    popd
    exit /b 1
)
Rscript ..\..\Condor_run_basic.R _bundle*.7z || (
    popd
    exit /b 1
)
Rscript ..\..\Condor_run_stats.R config.R
popd
