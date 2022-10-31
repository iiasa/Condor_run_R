args <- commandArgs(trailingOnly=TRUE)
# Matrix diagonalization
N <- 200
set.seed(1) # for reproducibility
for (i in 1:1) {
  M <- matrix(runif(N*N, -10, 10), nrow=N) # N x N matrix
  ev <- eigen(M, only.values = TRUE) # SVD is O(N^3)
}
# Return eigenvalues as output
save(ev, file="output/output.RData")
