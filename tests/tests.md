This directory holds tests, each in its own subdirectory. Tests can
be run via the `test.bat` script present in every test subdirectory.
These scripts are cross-platform and function both when invoked from
a Linux/MacOS shell as well as as well as when run from a Windows
command prompt.

Tests listing:
- [basic](basic/purpose.md)
- [periodic_release](periodic_release/purpose.md)
- [seeding](seeding/purpose.md)

Note that some tests execute the `Condor_run_stats.R` script on run
completion, resulting in a PDF file that can be examined to review
run and cluster performance.
