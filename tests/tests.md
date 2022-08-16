This directory holds tests, each in its own subdirectory. Tests can
be run via the `test.bat` (Windows) or `test.sh` (MacOS/Linux) scripts present in every test subdirectory.

Tests listing:
- [basic](basic/purpose.md)
- [bundling](bundling/purpose.md)
- [disconnect](disconnect/purpose.md)
- [noscript](noscript/purpose.md)
- [parallel](parallel/purpose.md)
- [periodic_release](periodic_release/purpose.md)
- [seeding](seeding/purpose.md)
- [transport](transport/purpose.md)
- [year_guessing](year_guessing/purpose.md)

Note that some tests execute the `Condor_run_stats.R` script on run
completion, resulting in a PDF file that can be examined to review
run and cluster performance.
