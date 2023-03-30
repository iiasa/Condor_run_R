#!/bin/bash
pushd "$(dirname "$0")"
set -e
condor_submit reserve.job
echo "Warning: make sure that the job is running before trying to use the resources!"
popd
