# See https://github.com/iiasa/Condor_run_R/blob/master/configuring.md
LABEL = "bundling_{Sys.Date()}"
JOBS = c(0)
REQUEST_MEMORY = 100
GAMS_FILE_PATH = "model/model.gms"
GAMS_ARGUMENTS = "gdx=output"
GAMS_VERSION = "32.2"
BUNDLE_INCLUDE = "model"
BUNDLE_INCLUDE_DIRS = c("data/*.bar", "data/**/*.baz")
BUNDLE_ADDITIONAL_FILES = c("additionals/additional.file")
BUNDLE_EXCLUDE_FILES = c("data/**/exclude_me_specifically.baz")
BUNDLE_ONLY = TRUE
GET_GDX_OUTPUT = TRUE
GDX_OUTPUT_FILE = "output.gdx"
WAIT_FOR_RUN_COMPLETION = FALSE
