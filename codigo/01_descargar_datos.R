# =============================================================================
# 01_descargar_datos.R  —  Los Galacticos (FIN443, E2)
# Descarga precios diarios ajustados 2015-2025 de TODAS las acciones que
# pertenecieron al S&P 500 en el período (no solo las actuales), para evitar
# el sesgo de supervivencia. Guarda un respaldo en datos/.
#
# Ejecutar UNA vez desde la carpeta raíz del repositorio:
#   Rscript codigo/01_descargar_datos.R
# El resto del análisis lee los CSV de datos/, no internet.
# =============================================================================

if (!requireNamespace("quantmod", quietly = TRUE)) install.packages("quantmod")
library(quantmod)

inicio <- as.Date("2015-01-01")
fin    <- as.Date("2025-12-31")

# Universo histórico: 754 tickers que estuvieron en el índice entre 2015 y 2025
universo <- read.csv("datos/universo_sp500_2015_2025.csv", stringsAsFactors = FALSE)
tickers  <- universo$ticker

# Yahoo usa guion en vez de punto (BRK.B -> BRK-B, BF.B -> BF-B)
a_yahoo <- function(t) gsub(".", "-", t, fixed = TRUE)

precios  <- list()
registro <- data.frame(ticker = tickers, descargado = "NO", n_obs = 0L,
                       primera_fecha = NA_character_, ultima_fecha = NA_character_,
                       stringsAsFactors = FALSE)

for (i in seq_along(tickers)) {
  t <- tickers[i]
  cat(sprintf("[%d/%d] %s\n", i, length(tickers), t))
  x <- tryCatch(
    getSymbols(a_yahoo(t), src = "yahoo", from = inicio, to = fin + 1,
               auto.assign = FALSE, warnings = FALSE),
    error = function(e) NULL)
  if (!is.null(x) && nrow(x) > 0) {
    ajustado <- Ad(x)
    colnames(ajustado) <- t
    precios[[t]] <- ajustado
    registro$descargado[i]    <- "SI"
    registro$n_obs[i]         <- nrow(ajustado)
    registro$primera_fecha[i] <- as.character(min(index(ajustado)))
    registro$ultima_fecha[i]  <- as.character(max(index(ajustado)))
  }
  Sys.sleep(0.3)  # no saturar a Yahoo
}

# Formato ancho: una fila por fecha, una columna por ticker (NA = no cotizaba)
precios <- do.call(merge, precios)
tabla   <- data.frame(fecha = as.character(index(precios)),
                      round(coredata(precios), 4), check.names = FALSE)

# Se guarda comprimido (.csv.gz) para respetar el límite de 25 MB de GitHub web.
# Se lee con: read.csv("datos/precios_ajustados_2015_2025.csv.gz", check.names = FALSE)
dir.create("datos", showWarnings = FALSE)
con <- gzfile("datos/precios_ajustados_2015_2025.csv.gz", "w")
write.csv(tabla, con, row.names = FALSE, na = "")
close(con)
registro$en_indice_hoy <- universo$en_indice_hoy
registro$fecha_descarga <- as.character(Sys.Date())
write.csv(registro, "datos/registro_descarga.csv", row.names = FALSE)

# Resumen para el informe (limitación por sesgo de supervivencia)
cat("\n===== RESUMEN =====\n")
cat("Tickers en el universo histórico:", nrow(registro), "\n")
cat("Descargados:", sum(registro$descargado == "SI"), "\n")
cat("Sin datos en Yahoo:", sum(registro$descargado == "NO"), "\n")
cat("  de ellos, empresas que ya salieron del índice:",
    sum(registro$descargado == "NO" & registro$en_indice_hoy == "NO"), "\n")
