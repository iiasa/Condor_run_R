Use `BUNDLE_*` configuration parameters to include various files in the
bundle when invoking `Condor_run_basic.R` with multiple entries in
`BUNDLE_ADDITONAL_FILES`. Then display the bundle content to verify
that they are indeed present.

Also test the --bundle-only command line argument as an override for
the BUNDLE_ONLY = FALSE default.
