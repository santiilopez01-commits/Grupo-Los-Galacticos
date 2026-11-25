# =============================================================================
# 03_tablas_figuras.R — Los Galacticos (FIN443, E2)
# Lee resultados/backtest.rds y genera las tablas y figuras del informe.
# =============================================================================

b    <- readRDS("resultados/backtest.rds")
ret  <- b$ret
rf   <- b$info$rf
est  <- colnames(ret)
Tm   <- nrow(ret)
COSTO <- 0.0010            # 10 pb por cada peso transado (compra o venta)

# -----------------------------------------------------------------------------
# Métricas
# -----------------------------------------------------------------------------
max_caida <- function(r) { v <- cumprod(1 + r); min(v / cummax(v) - 1) }

# Error estándar del Sharpe anualizado (Lo 2002, retornos iid)
se_sharpe_lo <- function(sr_mensual, n) sqrt(12) * sqrt((1 + 0.5 * sr_mensual^2) / n)

# Test de igualdad de Sharpe (Jobson y Korkie 1981, con la corrección de Memmel)
p_jk <- function(a, b) {
  sa <- mean(a) / sd(a); sb <- mean(b) / sd(b); rho <- cor(a, b); n <- length(a)
  theta <- (2 - 2 * rho + 0.5 * (sa^2 + sb^2 - 2 * sa * sb * rho^2)) / n
  2 * pnorm(-abs((sa - sb) / sqrt(theta)))
}

exceso <- ret - rf
rot <- b$rotacion; rot[is.na(rot)] <- 1        # primer mes: se arma la cartera completa
ret_neto <- ret - COSTO * 2 * rot              # 2 * rotación = total comprado + vendido

tabla <- data.frame(
  estrategia            = est,
  rentab_anual_pct      = 100 * (apply(1 + ret, 2, prod)^(12 / Tm) - 1),
  volatilidad_anual_pct = 100 * apply(ret, 2, sd) * sqrt(12),
  sharpe                = colMeans(exceso) / apply(exceso, 2, sd) * sqrt(12),
  stringsAsFactors = FALSE
)
sr_m <- tabla$sharpe / sqrt(12)
tabla$sharpe_ee_lo     <- se_sharpe_lo(sr_m, Tm)
tabla$sharpe_ic95_inf  <- tabla$sharpe - 1.96 * tabla$sharpe_ee_lo
tabla$sharpe_ic95_sup  <- tabla$sharpe + 1.96 * tabla$sharpe_ee_lo
tabla$p_vs_GMV_muestral <- sapply(est, function(e) p_jk(exceso[, e], exceso[, "GMV muestral"]))
tabla$p_vs_1N           <- sapply(est, function(e) p_jk(exceso[, e], exceso[, "1/N"]))
exc_neto <- ret_neto - rf
tabla$sharpe_neto_10pb  <- colMeans(exc_neto) / apply(exc_neto, 2, sd) * sqrt(12)
tabla$max_caida_pct     <- 100 * apply(ret, 2, max_caida)
tabla$rotacion_mensual_pct <- 100 * colMeans(b$rotacion, na.rm = TRUE)
tabla$n_acciones        <- colMeans(b$n_activos)
tabla$n_efectivo        <- colMeans(b$n_efectivo)
tabla$peso_max_pct      <- 100 * colMeans(b$peso_max)
tabla$posicion_corta_pct <- 100 * colMeans(b$corto)

num <- sapply(tabla, is.numeric)
tabla_out <- tabla; tabla_out[num] <- lapply(tabla[num], round, 3)
write.csv(tabla_out, "resultados/tabla_metricas.csv", row.names = FALSE)

# Aporte propio: efecto del límite máximo por acción
lim_lbl <- c("Sin límite", paste0(b$limites * 100, "%"))
fila <- function(base) c(paste(base, "sin cortos"), paste0(base, " max ", b$limites * 100, "%"))
aporte <- rbind(
  data.frame(estimador = "Muestral",     limite = lim_lbl, tabla[match(fila("GMV muestral"), est), -1]),
  data.frame(estimador = "Ledoit-Wolf",  limite = lim_lbl, tabla[match(fila("GMV Ledoit-Wolf"), est), -1])
)
aporte_out <- aporte; num <- sapply(aporte, is.numeric); aporte_out[num] <- lapply(aporte[num], round, 3)
write.csv(aporte_out, "resultados/tabla_limites.csv", row.names = FALSE)

# Resumen de datos
resumen <- c(
  sprintf("Período fuera de muestra: %s a %s (%d meses)",
          b$info$mes_retorno[1], b$info$mes_retorno[Tm], Tm),
  sprintf("Ventana de estimación: %d días hábiles", b$ventana),
  sprintf("Acciones en el universo por mes: mínimo %d, promedio %.0f, máximo %d",
          min(b$info$n_universo), mean(b$info$n_universo), max(b$info$n_universo)),
  sprintf("Intensidad de encogimiento Ledoit-Wolf: promedio %.2f (rango %.2f a %.2f)",
          mean(b$info$delta_lw), min(b$info$delta_lw), max(b$info$delta_lw)),
  sprintf("Tasa libre de riesgo promedio: %.2f%% anual", 100 * 12 * mean(rf)),
  sprintf("Precios descartados por ticker reutilizado: %d", b$n_enmascarados),
  sprintf("Alzas diarias > 50%% tratadas como error de dato: %d", b$n_saltos),
  sprintf("Exclusiones por precio congelado (acción-mes): %d", b$n_congeladas)
)
writeLines(resumen, "resultados/resumen_datos.txt")

# -----------------------------------------------------------------------------
# Figuras
# -----------------------------------------------------------------------------
fechas_m <- as.Date(paste0(b$info$mes_retorno, "-01"))
sel <- c("1/N", "GMV muestral", "GMV Ledoit-Wolf", "GMV Ledoit-Wolf sin cortos",
         "GMV Ledoit-Wolf max 2%")
col <- c("grey40", "#D55E00", "#0072B2", "#009E73", "#CC79A7")

png("resultados/fig1_valor_acumulado.png", width = 1600, height = 1000, res = 160)
v <- apply(1 + ret[, sel], 2, cumprod)
par(mar = c(4, 4.5, 3, 1))
matplot(fechas_m, v, type = "l", lty = 1, lwd = 2, col = col, log = "y",
        xaxt = "n", xlab = "", ylab = "Valor de US$1 invertido (escala log)",
        main = "Valor acumulado fuera de muestra, 2017-2025")
axis.Date(1, fechas_m, format = "%Y")
abline(h = 1, col = "grey80")
legend("topleft", sel, col = col, lwd = 2, bty = "n", cex = 0.9)
dev.off()

png("resultados/fig2_limites_por_accion.png", width = 1800, height = 650, res = 160)
par(mfrow = c(1, 3), mar = c(4, 4.5, 3, 1))
x <- seq_along(lim_lbl)
for (m in list(c("volatilidad_anual_pct", "Volatilidad anual (%)"),
               c("sharpe", "Ratio de Sharpe"),
               c("rotacion_mensual_pct", "Rotación mensual (%)"))) {
  a <- aporte[aporte$estimador == "Muestral", m[1]]
  l <- aporte[aporte$estimador == "Ledoit-Wolf", m[1]]
  plot(x, a, type = "b", pch = 19, lwd = 2, col = "#D55E00", ylim = range(a, l),
       xaxt = "n", xlab = "Peso máximo por acción", ylab = m[2], main = m[2])
  lines(x, l, type = "b", pch = 17, lwd = 2, col = "#0072B2")
  axis(1, x, lim_lbl)
  if (m[1] == "volatilidad_anual_pct")
    legend("topleft", c("Muestral", "Ledoit-Wolf"), col = c("#D55E00", "#0072B2"),
           pch = c(19, 17), lwd = 2, bty = "n")
}
dev.off()

png("resultados/fig3_encogimiento_y_universo.png", width = 1600, height = 700, res = 160)
par(mfrow = c(1, 2), mar = c(4, 4.5, 3, 1))
plot(b$info$fecha_rebalanceo, b$info$delta_lw, type = "l", lwd = 2, col = "#0072B2",
     xlab = "", ylab = "delta", main = "Intensidad de encogimiento Ledoit-Wolf")
plot(b$info$fecha_rebalanceo, b$info$n_universo, type = "l", lwd = 2, col = "grey30",
     xlab = "", ylab = "N acciones", main = "Tamaño del universo invertible")
dev.off()

cat("\n===== RESULTADOS =====\n")
print(tabla_out[, c("estrategia", "rentab_anual_pct", "volatilidad_anual_pct", "sharpe",
                    "rotacion_mensual_pct", "n_acciones")], row.names = FALSE)
cat("\nTablas y figuras guardadas en resultados/\n")
