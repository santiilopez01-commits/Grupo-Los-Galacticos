# =============================================================================
# 02_backtest.R — Los Galacticos (FIN443, E2)
# Backtest fuera de muestra de carteras de mínima varianza en el S&P 500,
# 2015-2025, con universo histórico (sin sesgo de supervivencia).
#
# Reglas:
#   - Rebalanceo mensual, al cierre del último día hábil de cada mes (t).
#   - Universo en t: acciones que eran miembros del S&P 500 en t (según la
#     composición histórica), con 504 retornos diarios completos hasta t y sin
#     precio congelado (máx. 5% de días con retorno exactamente cero).
#   - Covarianza estimada SOLO con los 504 días anteriores a t (2 años).
#   - Retorno de cada cartera: comprar en t y mantener hasta el fin del mes
#     siguiente. Si una acción deja de cotizar, su parte queda en caja (0%).
# Lo ejecuta ejecutar_todo.R (no correr por separado sin fijar la carpeta).
# =============================================================================

source("codigo/funciones.R")

VENTANA   <- 504                       # días hábiles de estimación (2 años)
LIMITES   <- c(0.10, 0.05, 0.02, 0.01) # aporte propio: peso máximo por acción
SALTO_MAX <- 0.50                      # alza diaria > 50% se trata como error de dato
GRACIA    <- 40                        # días que se aceptan precios tras salir del índice
MAX_CEROS <- 0.05                      # máx. 5% de días con retorno exactamente 0 (precio congelado)

# -----------------------------------------------------------------------------
# 1. Datos
# -----------------------------------------------------------------------------
precios <- read.csv("datos/precios_ajustados_2015_2025.csv.gz", check.names = FALSE)
fechas  <- as.Date(precios$fecha)
P       <- as.matrix(precios[, -1])

comp <- read.csv("datos/composicion_sp500_2015_2025.csv", stringsAsFactors = FALSE)
comp$fecha <- as.Date(comp$fecha)
miembros <- strsplit(comp$tickers, ",")

univ <- read.csv("datos/universo_sp500_2015_2025.csv", stringsAsFactors = FALSE)

# -----------------------------------------------------------------------------
# 2. Limpieza
#   (a) Ticker reutilizado: Yahoo asigna a empresas que salieron del índice los
#       precios de otra empresa que hoy usa el mismo ticker (ej. STI, POM, CAM).
#       Se descartan los precios posteriores a la última fecha en el índice.
#   (b) Errores de dato: alzas diarias mayores a 50% (ej. PARA, DHR) se tratan
#       como faltantes. Las caídas fuertes se mantienen (crisis reales, ej. 2020).
# -----------------------------------------------------------------------------
ultima <- setNames(as.Date(univ$ultima_fecha_en_indice), univ$ticker)
n_enmascarados <- 0
for (tk in colnames(P)) {
  fuera <- fechas > ultima[tk] + GRACIA & !is.na(P[, tk])
  n_enmascarados <- n_enmascarados + sum(fuera)
  P[fuera, tk] <- NA
}

R <- P[-1, ] / P[-nrow(P), ] - 1         # retornos diarios simples
fR <- fechas[-1]
n_saltos <- sum(R > SALTO_MAX, na.rm = TRUE)
R[!is.na(R) & R > SALTO_MAX] <- NA

# -----------------------------------------------------------------------------
# 3. Fechas de rebalanceo: último día hábil de cada mes
# -----------------------------------------------------------------------------
mes    <- format(fR, "%Y-%m")
i_fin  <- tapply(seq_along(fR), mes, max)            # índice del último día de cada mes
i_fin  <- as.integer(i_fin[order(names(i_fin))])
i_reb  <- i_fin[i_fin >= VENTANA]                    # requiere 2 años de historia
i_reb  <- i_reb[-length(i_reb)]                      # el último mes no tiene mes siguiente

miembros_en <- function(fecha) miembros[[max(which(comp$fecha <= fecha))]]

# -----------------------------------------------------------------------------
# 4. Tasa libre de riesgo (opcional): datos/tasa_libre_riesgo.csv
#    columnas fecha (primer día del mes) y tasa (% anual, T-bill 3 meses, FRED TB3MS)
# -----------------------------------------------------------------------------
rf_mensual <- function(fecha) 0
if (file.exists("datos/tasa_libre_riesgo.csv")) {
  tb <- read.csv("datos/tasa_libre_riesgo.csv")
  tb$fecha <- as.Date(tb$fecha)
  rf_mensual <- function(fecha) {           # tasa conocida en t, para el mes siguiente
    tb$tasa[max(which(tb$fecha <= fecha))] / 100 / 12
  }
  cat("Tasa libre de riesgo: datos/tasa_libre_riesgo.csv\n")
} else {
  cat("AVISO: no está datos/tasa_libre_riesgo.csv; se usa tasa libre de riesgo = 0.\n")
}

# -----------------------------------------------------------------------------
# 5. Estrategias
# -----------------------------------------------------------------------------
estrategias <- c(
  "1/N",
  "GMV muestral",
  "GMV Ledoit-Wolf",
  "GMV muestral sin cortos",
  "GMV Ledoit-Wolf sin cortos",
  paste0("GMV muestral max ", LIMITES * 100, "%"),
  paste0("GMV Ledoit-Wolf max ", LIMITES * 100, "%")
)

calcular_pesos <- function(S_m, S_lw, n) {
  w <- list()
  w[["1/N"]]                        <- rep(1 / n, n)
  w[["GMV muestral"]]               <- gmv_libre(S_m)
  w[["GMV Ledoit-Wolf"]]            <- gmv_libre(S_lw)
  w[["GMV muestral sin cortos"]]    <- gmv_restringida(S_m)
  w[["GMV Ledoit-Wolf sin cortos"]] <- gmv_restringida(S_lw)
  for (L in LIMITES) {
    w[[paste0("GMV muestral max ", L * 100, "%")]]    <- gmv_restringida(S_m, L)
    w[[paste0("GMV Ledoit-Wolf max ", L * 100, "%")]] <- gmv_restringida(S_lw, L)
  }
  w[estrategias]
}

# -----------------------------------------------------------------------------
# 6. Backtest
# -----------------------------------------------------------------------------
K <- length(i_reb)
ret      <- matrix(NA, K, length(estrategias), dimnames = list(NULL, estrategias))
rotacion <- ret; n_activos <- ret; peso_max <- ret; n_efectivo <- ret; corto <- ret
info <- data.frame(fecha_rebalanceo = fR[i_reb], mes_retorno = NA, n_universo = NA,
                   delta_lw = NA, rf = NA)
pesos_prev <- setNames(vector("list", length(estrategias)), estrategias)
n_congeladas <- 0

for (k in seq_len(K)) {
  t   <- i_reb[k]
  sig <- if (k < K) i_reb[k + 1] else i_fin[length(i_fin)]
  ventana <- (t - VENTANA + 1):t

  # universo: miembros en t con historia completa y sin precios congelados
  cand <- intersect(miembros_en(fR[t]), colnames(R))
  Xc   <- R[ventana, cand, drop = FALSE]
  ok   <- colSums(is.na(Xc)) == 0 & colMeans(Xc == 0, na.rm = TRUE) <= MAX_CEROS
  n_congeladas <- n_congeladas + sum(colSums(is.na(Xc)) == 0 & !ok)
  tk   <- cand[ok]
  X    <- R[ventana, tk]

  S_m  <- cov_muestral(X)
  lw   <- cov_ledoit_wolf(X)

  # retorno de compra y mantención del mes siguiente (faltantes = caja, 0%)
  Rm <- R[(t + 1):sig, tk, drop = FALSE]
  Rm[is.na(Rm)] <- 0
  crec <- apply(1 + Rm, 2, prod)                     # 1 + retorno del mes por acción

  W <- calcular_pesos(S_m, lw$sigma, length(tk))

  for (e in estrategias) {
    w <- setNames(W[[e]], tk)
    ret[k, e] <- sum(w * (crec - 1))

    # rotación: cambio respecto de los pesos anteriores ya "derivados" por el mercado
    if (is.null(pesos_prev[[e]])) {
      rotacion[k, e] <- NA
    } else {
      todos <- union(names(pesos_prev[[e]]), tk)
      a <- setNames(rep(0, length(todos)), todos); a[tk] <- w
      b <- setNames(rep(0, length(todos)), todos); b[names(pesos_prev[[e]])] <- pesos_prev[[e]]
      rotacion[k, e] <- 0.5 * sum(abs(a - b))
    }
    pesos_prev[[e]] <- w * crec / sum(w * crec)      # pesos al final del mes

    n_activos[k, e]  <- sum(abs(w) > 1e-6)
    peso_max[k, e]   <- max(w)
    n_efectivo[k, e] <- 1 / sum(w^2)
    corto[k, e]      <- -sum(w[w < 0])
  }

  info$mes_retorno[k] <- format(fR[sig], "%Y-%m")
  info$n_universo[k]  <- length(tk)
  info$delta_lw[k]    <- lw$delta
  info$rf[k]          <- rf_mensual(fR[t])
  cat(sprintf("[%3d/%d] %s  N=%d  delta LW=%.2f\n", k, K, fR[t], length(tk), lw$delta))
}

# -----------------------------------------------------------------------------
# 7. Guardar resultados
# -----------------------------------------------------------------------------
dir.create("resultados", showWarnings = FALSE)
write.csv(data.frame(info, ret, check.names = FALSE),
          "resultados/retornos_mensuales.csv", row.names = FALSE)
saveRDS(list(info = info, ret = ret, rotacion = rotacion, n_activos = n_activos,
             peso_max = peso_max, n_efectivo = n_efectivo, corto = corto,
             n_enmascarados = n_enmascarados, n_saltos = n_saltos,
             n_congeladas = n_congeladas,
             ventana = VENTANA, limites = LIMITES),
        "resultados/backtest.rds")
cat("\nPrecios descartados por ticker reutilizado:", n_enmascarados,
    "\nAlzas diarias > 50% tratadas como error:", n_saltos,
    "\nExclusiones por precio congelado (acción-mes):", n_congeladas, "\n")
