# See https://github.com/iiasa/Condor_run_R/blob/master/configuring.md
LABEL = "transport_{Sys.Date()}"
JOBS = c(0, 5, 10, 15, 20, 25, 30, 40, 45, 50)
REQUEST_MEMORY = 1000
REQUEST_DISK = 400
GAMS_FILE_PATH = "transport.gms"
GAMS_ARGUMENTS = "gdx={OUTPUT_DIR}/{OUTPUT_FILES} //shift=%1"
BUNDLE_INCLUDE = GAMS_FILE_PATH
GAMS_VERSION = "32.2"
GET_OUTPUT = TRUE
OUTPUT_DIR = "gdx"
GDX_OUTPUT_DIR_SUBMIT = "gdx/{LABEL}"
OUTPUT_FILES = "output.gdx"
WAIT_FOR_RUN_COMPLETION = TRUE
