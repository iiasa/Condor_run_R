# Parallel diagonalization of matrices
M <- 100 # number of matrices to process
C <- 4 # threads

make_matrix <- function(seed) {
  set.seed(seed)
  N <- 2000 # rows/columns
  matrix(runif(N*N, -10, 10), nrow=N)
}

ev_matrix <- function(matrix) {
  eigen(matrix, only.values = TRUE)
}

library(parallel)
cl <- makeCluster(C)
matrix_list <- parLapply(cl, c(1:M), make_matrix)
ev_list <- parLapply(cl, matrix_list, ev_matrix)

# Return eigenvalues as output
save(ev_list, file="output/output.RData")
