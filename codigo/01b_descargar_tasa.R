# =============================================================================
# 01b_descargar_tasa.R — Los Galacticos (FIN443, E2)
# Descarga la tasa libre de riesgo: T-bill a 3 meses de EE.UU. (FRED, serie
# TB3MS, % anual, mensual) y la guarda como respaldo en datos/.
# Ejecutar UNA vez desde la carpeta raíz:  Rscript codigo/01b_descargar_tasa.R
# =============================================================================

if (!requireNamespace("quantmod", quietly = TRUE)) install.packages("quantmod")
library(quantmod)

tb <- getSymbols("TB3MS", src = "FRED", auto.assign = FALSE)
tb <- tb["2014-12-01/2025-12-31"]
out <- data.frame(fecha = as.character(index(tb)), tasa = as.numeric(tb))
write.csv(out, "datos/tasa_libre_riesgo.csv", row.names = FALSE)
cat("Guardado datos/tasa_libre_riesgo.csv:", nrow(out), "meses, de",
    out$fecha[1], "a", out$fecha[nrow(out)], "\n")
