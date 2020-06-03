#!/usr/bin/env Rscript
# Display the GAMS version with which the specified restart file was
# generated. Helpful because you cannot use a restart file written
# with a particular GAMS versions as input for a run with an older
# GAMS version.
#
# For details see: https://www.gams.com/latest/docs/UG_SaveRestart.html
#
# Usage:
# Rscript restart_version.R <restart file>
#
# Requires the stringr package (part of the tidyverse).


library(stringr)

# Get and check argument
args <- commandArgs(trailingOnly=TRUE)
if (length(args) == 0) {
  stop("No restart file argument supplied!")
} else if (length(args) == 1) {
  restart_file = args[1]
  if (!file.exists(restart_file)) stop(str_glue('No restart file present at "{restart_file}"!'))
} else {
  stop("Multiple arguments provided! Expecting at most a single restart file argument.")
}

# Determine GAMS version used to generate restart file
conn <- file(restart_file, "rb")
byte_count <- min(4000, file.info(restart_file)$size)
invisible(seek(conn, where=-byte_count, origin="end"))
tail_bytes <- readBin(conn, what=integer(), size=1, n=byte_count)
close(conn)
tail_bytes[tail_bytes <= 0] <- 32
tail <-  rawToChar(as.raw(tail_bytes))
version_match <- str_match(tail, "\x0AWEX(\\d\\d)(\\d)-\\d\\d\\d")
if (is.na(version_match[1])) {
  stop(str_glue('Cannot determine the GAMS version that saved "{restart_file}", are you sure this is a restart file?'))
}

# Display GAMS version
cat(str_glue("GAMS version: {version_match[2]}.{version_match[3]}\n"))
