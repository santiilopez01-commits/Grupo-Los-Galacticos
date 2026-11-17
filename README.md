# Los Galacticos — Programación en Finanzas (E2)

## Pregunta
¿La estimación mejorada de covarianzas (Ledoit-Wolf) y las restricciones sobre los pesos
permiten construir carteras con mejor desempeño fuera de muestra que una cartera
tradicional de mínima varianza?

## Datos
- Precios diarios ajustados 2015–2025 de Yahoo Finance (paquete `quantmod` en R).
- Composición histórica del S&P 500 (repositorio público fja05680/sp500), para
  evitar el sesgo de supervivencia: 754 empresas pasaron por el índice en el
  período y 267 ya no están.
- Respaldo de todo lo descargado en `datos/` (ver `datos/LEEME.md`).

## Método
Backtest con ventana móvil: en cada rebalanceo se usa solo a las empresas que
eran miembros del índice en esa fecha y solo datos pasados. Se comparan carteras
de mínima varianza (muestral, Ledoit-Wolf y con límites máximos por acción) según
rentabilidad, volatilidad y Sharpe fuera de muestra.

## Aporte propio
Efecto de distintos límites máximos de peso por acción sobre el desempeño y la
estabilidad de las carteras.

## Cómo se ejecuta
1. `Rscript
