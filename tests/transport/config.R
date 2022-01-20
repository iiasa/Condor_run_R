# See https://github.com/iiasa/Condor_run_R/blob/master/configuring.md
LABEL = "transport_{Sys.Date()}"
JOBS = c(0, 5, 10, 15, 20, 25, 30, 40, 45, 50)
HOST_REGEXP = "^limpopo"
REQUEST_MEMORY = 1000
GAMS_FILE_PATH = "transport.gms"
GAMS_ARGUMENTS = "gdx={GDX_OUTPUT_DIR}/{GDX_OUTPUT_FILE} //shift=%1"
GAMS_VERSION = "32.2"
G00_OUTPUT_DIR = "work"
G00_OUTPUT_FILE = "work.g00"
GET_G00_OUTPUT = TRUE
GDX_OUTPUT_DIR = "gdx"
GDX_OUTPUT_FILE = "output.gdx"
GET_GDX_OUTPUT = TRUE
WAIT_FOR_RUN_COMPLETION = TRUE
