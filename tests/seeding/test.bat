@echo off
pushd %~dp0
Rscript ..\..\Condor_run_basic.R config1.R || (
    popd
    exit /b 1
)
echo Waiting for occupation to settle...
timeout 600 /nobreak
Rscript ..\..\Condor_run_basic.R config2.R || (
    popd
    exit /b 1
)
popd
