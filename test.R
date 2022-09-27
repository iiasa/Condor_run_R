failure <- function() {
        blather <- function() {
          cat("Blathering bla bla...\n")
        }
	on.exit(message("Exiting!!!!!!!!!!!!!"))
	blather()
	stop("Throwing an error!")
}
failure()


