# =============================================================================
# funciones.R — Los Galacticos (FIN443, E2)
# Estimadores de covarianza y optimizadores de cartera usados en el backtest.
# =============================================================================

# -----------------------------------------------------------------------------
# Covarianza muestral (divisor T, igual que Ledoit y Wolf 2003)
# x: matriz T x N de retornos
# -----------------------------------------------------------------------------
cov_muestral <- function(x) {
  x <- sweep(x, 2, colMeans(x))
  crossprod(x) / nrow(x)
}

# -----------------------------------------------------------------------------
# Covarianza Ledoit-Wolf (2003): encogimiento hacia el modelo de un factor.
# Objetivo F: covarianzas implícitas por un modelo de mercado (mercado =
# promedio simple de las acciones), con la diagonal muestral.
# Sigma = delta * F + (1 - delta) * S, con delta óptimo estimado de los datos.
# Traducción a R del código público de los autores (covMarket.m).
# -----------------------------------------------------------------------------
cov_ledoit_wolf <- function(x) {
  t <- nrow(x); n <- ncol(x)
  x    <- sweep(x, 2, colMeans(x))
  xmkt <- rowMeans(x)

  muestra <- crossprod(cbind(x, xmkt)) / t
  covmkt  <- muestra[1:n, n + 1]
  varmkt  <- muestra[n + 1, n + 1]
  S       <- muestra[1:n, 1:n]

  F <- tcrossprod(covmkt) / varmkt          # objetivo de un factor
  diag(F) <- diag(S)

  # intensidad óptima de encogimiento
  c_  <- sum((S - F)^2)
  y   <- x^2
  p   <- sum(crossprod(y)) / t - sum(S^2)
  rdiag <- sum(y^2) / t - sum(diag(S)^2)
  z   <- x * xmkt
  v1  <- crossprod(y, z) / t - covmkt * S
  roff1 <- sum(v1 * matrix(covmkt, n, n, byrow = TRUE)) / varmkt -
           sum(diag(v1) * covmkt) / varmkt
  v3  <- crossprod(z) / t - varmkt * S
  roff3 <- sum(v3 * tcrossprod(covmkt)) / varmkt^2 -
           sum(diag(v3) * covmkt^2) / varmkt^2
  r   <- rdiag + 2 * roff1 - roff3
  k   <- (p - r) / c_
  delta <- max(0, min(1, k / t))

  list(sigma = delta * F + (1 - delta) * S, delta = delta)
}

# -----------------------------------------------------------------------------
# Cartera de mínima varianza SIN restricciones (permite ventas cortas):
# w = Sigma^-1 1 / (1' Sigma^-1 1)
# -----------------------------------------------------------------------------
gmv_libre <- function(sigma) {
  a <- solve(sigma, rep(1, ncol(sigma)))
  a / sum(a)
}

# -----------------------------------------------------------------------------
# Cartera de mínima varianza CON restricciones (programación cuadrática):
#   min w' Sigma w   s.a.  sum(w) = 1,  0 <= w <= limite
# limite = 1 significa "solo sin ventas cortas" (Frost y Savarino 1988).
# -----------------------------------------------------------------------------
gmv_restringida <- function(sigma, limite = 1) {
  n <- ncol(sigma)
  if (limite * n < 1) stop("Límite infactible: N * límite < 1")
  D <- sigma * 1e4                      # escala para estabilidad numérica
  D <- D + diag(1e-10 * mean(diag(D)), n)
  A <- cbind(rep(1, n), diag(n))
  b <- c(1, rep(0, n))
  if (limite < 1) {
    A <- cbind(A, -diag(n))
    b <- c(b, rep(-limite, n))
  }
  sol <- quadprog::solve.QP(Dmat = D, dvec = rep(0, n), Amat = A, bvec = b, meq = 1)
  w <- pmax(sol$solution, 0)            # limpia ruido numérico (~1e-17)
  w / sum(w)
}
