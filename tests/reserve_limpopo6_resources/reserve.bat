@echo off
pushd %~dp0
condor_submit reserve.job || (
    echo "Error: condor_submit failed."
    popd
    exit /b 1
)
echo "Warning: make sure that the job is running before trying to use the resources!"
popd
