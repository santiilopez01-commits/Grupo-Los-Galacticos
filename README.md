# Los Galacticos — Programación en Finanzas (E2)

Santiago López · Pedro Leixelard · Matías Zamora · Gabriel Lathrop · Matías Rodríguez

## Cómo se ejecuta (un solo comando)

Desde la carpeta raíz del repositorio:

```
Rscript ejecutar_todo.R
```

- Usa solo los datos guardados en `datos/` (no descarga nada).
- Demora unos 6 minutos y deja tablas y figuras en `resultados/`.
- Requiere R (≥ 4.2) y el paquete `quadprog` (se instala solo si falta).

## Pregunta
¿La estimación mejorada de covarianzas (Ledoit-Wolf) y las restricciones sobre los pesos
permiten construir carteras con mejor desempeño fuera de muestra que una cartera
tradicional de mínima varianza?

## Datos
- Precios diarios ajustados 2015–2025 de Yahoo Finance (paquete `quantmod` en R).
- Composición histórica del S&P 500 (repositorio público fja05680/sp500), para
  evitar el sesgo de supervivencia: 754 empresas pasaron por el índice en el
  período y 267 ya no están.
- Tasa libre de riesgo: T-bill a 3 meses (FRED, serie TB3MS).
- Respaldo de todo lo descargado en `datos/` (ver `datos/LEEME.md`). Los scripts de
  descarga (`codigo/01_descargar_datos.R`, `codigo/01b_descargar_tasa.R`) no son
  parte del comando único: ya se ejecutaron y su resultado está en `datos/`.

## Método
- Rebalanceo mensual (último día hábil de cada mes); período fuera de muestra
  feb-2017 a dic-2025 (107 meses).
- Universo en cada fecha: acciones que eran miembros del S&P 500 en esa fecha, con
  2 años (504 días) de retornos completos.
- Covarianza estimada solo con los 504 días anteriores a cada rebalanceo:
  muestral o Ledoit-Wolf (2003, encogimiento hacia un modelo de un factor).
- Carteras: 1/N, mínima varianza (GMV) sin restricciones, GMV sin ventas cortas y
  GMV con peso máximo por acción.
- Métricas: rentabilidad, volatilidad, Sharpe (con error estándar de Lo 2002 y test de
  diferencias de Jobson-Korkie), máxima caída, rotación y Sharpe neto de costos.

## Aporte propio
Efecto de distintos límites máximos de peso por acción (10%, 5%, 2% y 1%) sobre el
desempeño, la diversificación y la rotación de las carteras, con ambos estimadores
(`resultados/tabla_limites.csv` y `resultados/fig2_limites_por_accion.png`).

## Estructura
| Carpeta / archivo | Contenido |
|---|---|
| `ejecutar_todo.R` | Comando único |
| `datos/` | Datos originales descargados (no se editan a mano) |
| `codigo/funciones.R` | Estimadores de covarianza y optimizadores |
| `codigo/02_backtest.R` | Backtest fuera de muestra |
| `codigo/03_tablas_figuras.R` | Tablas y figuras |
| `resultados/` | Todo lo que genera el código |
