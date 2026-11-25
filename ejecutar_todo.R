# =============================================================================
# ejecutar_todo.R — Los Galacticos (FIN443, E2)
# COMANDO ÚNICO. Desde la carpeta raíz del repositorio:
#
#     Rscript ejecutar_todo.R
#
# Usa solo los datos guardados en datos/ (no descarga nada de internet).
# Demora unos 6 minutos. Deja tablas y figuras en resultados/.
# =============================================================================

set.seed(443)   # el backtest es determinístico; la semilla se fija por norma del curso

if (!requireNamespace("quadprog", quietly = TRUE)) {
  install.packages("quadprog", repos = "https://cloud.r-project.org")
}

source("codigo/02_backtest.R")
source("codigo/03_tablas_figuras.R")

writeLines(capture.output(sessionInfo()), "resultados/sesion_R.txt")
