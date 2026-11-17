# datos/ — Fuente y respaldo

Estos archivos son los originales descargados. **No se editan a mano.**

## 1. Composición histórica del S&P 500
- **Fuente:** repositorio público `fja05680/sp500` en GitHub
  (https://github.com/fja05680/sp500), archivo
  `S&P 500 Historical Components & Changes (Updated).csv`
  (versión del 07-09-2026). Descargado el 16-11-2026.
- `composicion_sp500_2015_2025.csv`: lista de miembros del índice en cada fecha
  de cambio, desde el 24-12-2014 (composición vigente al 01-01-2015) hasta el 22-12-2025.
- `universo_sp500_2015_2025.csv`: los **754 tickers** que pertenecieron al índice en
  algún momento entre 2015 y 2025, con su primera y última fecha en el índice.
  `en_indice_hoy` indica si seguía en el índice en el último dato disponible (18-08-2026).
  **267 de los 754 ya no están en el índice**: usar solo la composición actual
  dejaría fuera a todas ellas (sesgo de supervivencia).

## 2. Precios diarios ajustados
- **Fuente:** Yahoo Finance, descargados con el paquete `quantmod` de R
  (script `codigo/01_descargar_datos.R`). Período 01-01-2015 a 31-12-2025.
- `precios_ajustados_2015_2025.csv`: fecha, ticker, precio ajustado
  (por dividendos y splits).
- `registro_descarga.csv`: para cada ticker, si se obtuvo o no, número de
  observaciones, rango de fechas y fecha de descarga.

## Cómo se usa para evitar el sesgo de supervivencia
En cada fecha de rebalanceo *t*, el universo invertible son solo las acciones que
eran miembros del índice en *t* según `composicion_sp500_2015_2025.csv`, y la
covarianza se estima solo con datos anteriores a *t*.

## Limitación
Yahoo Finance no tiene precios para parte de las empresas que salieron del índice
(quiebras, fusiones, cambios de ticker). Esas acciones quedan fuera del análisis y
se informa cuántas son (ver `registro_descarga.csv`) como limitación en el informe.
