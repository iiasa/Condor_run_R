LABEL = "transport_{Sys.Date()}" # label/name for your project/experiment, pick something short but descriptive without spaces and valid as part of a filename, can use {<config>} expansion here
PREFIX = "_gams" # prefix for per-job .err, log, .lst, and .out files
JOBS = c(0, 5, 10, 15, 20, 25, 30, 40, 45, 50) # New York demand shif
HOST_REGEXP = "^limpopo" # a regular expression to select execute hosts from the cluster
REQUEST_MEMORY = 15 # memory (MiB) to reserve for each job
REQUEST_CPUS = 1 # number of hardware threads to reserve for each job
GAMS_FILE_PATH = "transport.gms" # path to GAMS file to run for each job, relative to GAMS_CURDIR
GAMS_ARGUMENTS = "save={G00_OUTPUT_DIR}/{G00_OUTPUT_FILE} gdx={GDX_OUTPUT_DIR}/{GDX_OUTPUT_FILE} //shift=%1 PC=2 PS=0 PW=130" # additional GAMS arguments, can use {<config>} expansion here
GAMS_VERSION = "32.2" # must be installed on all execute hosts
G00_OUTPUT_DIR = "save" # relative to GAMS_CURDIR both host-side and on the submit machine, excluded from bundle
G00_OUTPUT_FILE = "transport.g00" # host-side, will be remapped with LABEL and cluster/job numbers to avoid name collisions when transferring back to the submit machine.
GET_G00_OUTPUT = TRUE
GDX_OUTPUT_DIR = "gdx" # relative to GAMS_CURDIR both host-side and on the submit machine, excluded from bundle
GDX_OUTPUT_FILE = "output.gdx" # as produced on the host-side by gdx= GAMS parameter or execute_unload, will be remapped with LABEL and cluster/job numbers to avoid name collisions when transferring back to the submit machine.
GET_GDX_OUTPUT = TRUE
WAIT_FOR_RUN_COMPLETION = TRUE
