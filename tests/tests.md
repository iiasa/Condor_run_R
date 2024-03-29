This directory holds tests, each in its own subdirectory. Tests can
be run via the `test.bat` (Windows) or `test.sh` (MacOS/Linux) scripts present in every test subdirectory.

Tests listing:
- [basic](basic/purpose.md)
- [bundling](bundling/purpose.md)
- [bundling additionals](bundling_additionals/purpose.md)
- [bundling GAMS](bundling_GAMS/purpose.md)
- [bundling GAMS CURDIR](bundling_GAMS_CURDIR/purpose.md)
- [bundling nothing](bundling_nothing/purpose.md)
- [disconnect](disconnect/purpose.md)
- [limpopo_R_stack](limpopo_R_stack/purpose.md)
- [noscript](noscript/purpose.md)
- [output multiple](output_multiple/purpose.md)
- [output empty](output_empty/purpose.md)
- [overrides](overrides/purpose.md)
- [parallel](parallel/purpose.md)
- [periodic_release](periodic_release/purpose.md)
- [reserve_limpopo6_resources](reserve_limpopo6_resources/purpose.md)
- [seed overrides](seed_overrides/purpose.md)
- [seeding](seeding/purpose.md)
- [simple condor](simple_condor/purpose.md)
- [submit_bundle](submit_bundle/purpose.md)
- [transport](transport/purpose.md)
- [transport_output](transport_output/purpose.md)
- [year guessing](year_guessing/purpose.md)

Note that some tests execute the `Condor_run_stats.R` script on run
completion, resulting in a PDF file that can be examined to review
run and cluster performance.
