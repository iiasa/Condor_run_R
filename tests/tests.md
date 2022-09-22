This directory holds tests, each in its own subdirectory. Tests can
be run via the `test.bat` (Windows) or `test.sh` (MacOS/Linux) scripts present in every test subdirectory.

Tests listing:
- [basic](basic/purpose.md)
- [bundling](bundling/purpose.md)
- [bundling_additionals](bundling_additionals/purpose.md)
- [bundling_GAMS](bundling_GAMS/purpose.md)
- [bundling_GAMS_CURDIR](bundling_GAMS_CURDIR/purpose.md)
- [disconnect](disconnect/purpose.md)
- [noscript](noscript/purpose.md)
- [output_multiple](output_multiple/purpose.md)
- [output_empty](output_empty/purpose.md)
- [overrides](overrides/purpose.md)
- [parallel](parallel/purpose.md)
- [periodic_release](periodic_release/purpose.md)
- [seeding](seeding/purpose.md)
- [transport](transport/purpose.md)
- [year_guessing](year_guessing/purpose.md)

Note that some tests execute the `Condor_run_stats.R` script on run
completion, resulting in a PDF file that can be examined to review
run and cluster performance.
