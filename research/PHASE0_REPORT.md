# Fase 0 — Informe de auditoría (2026-09-06) — **CERRADA, LAS 10 TAREAS**

Entregable de §11. Sintetiza las 10 tareas de Fase 0, con una recomendación de ruta fundada en las mediciones de esta auditoría (no en las estimaciones de v1 de `CLAUDE.md`) y una matriz de riesgos. Cada afirmación de este informe tiene su fuente citada — no repite números sin decir de dónde salen.

## 1. Resumen ejecutivo

**La Ruta B (portar `CppProject` a Qt for Android) sigue viva y es la única con evidencia medida.** Sus dos bloqueos más críticos (B1, B2) tienen solución confirmada o acotada, no solo teórica. La Ruta A (export nativo de GameMaker) se descartó sin gastar su spike — no porque se probara inviable, sino porque B ya acumuló evidencia real mientras A se hubiera quedado en la incertidumbre del día 1 (§10, §17).

**Lo que queda abierto no son bloqueos nuevos, son mediciones pendientes con un plan concreto para cerrarlas:**
- El backend ES de shaders (§5.3) es una asunción de diseño, no un hallazgo verificado — se prueba recién en Fase 1 (tarea 0.5 movida).
- El ancho de banda de indirect lighting/reflections (parte de B2) tiene un rango de 8× según el cache hit rate real de la GPU — no cerrable sin dispositivo físico.
- El presupuesto de memoria de mundos importados (0.7) **ya se cerró** con datos reales (compilando `sizeof()` contra el código real y parseando los `.schematic`/`.midata` que Mine-imator ya empaqueta) — el caso típico (terreno) es trivial (~60 MB medido), y solo una importación densa en decoración conserva incertidumbre real, más angosta que antes.
- El bloqueo legal (0.10) **ya se cerró.** David Andrei confirmó por escrito: 2.0.x es MIT, puerto móvil y distribución en Google Play autorizados, único pedido es mantener el aviso de copyright original y usar un nombre genuinamente distinto (no una variación de "Mine-imator"). Era el riesgo de mayor impacto de toda la matriz de §4 — el único capaz de matar el proyecto entero sin importar qué tan bien saliera el resto.

Con esto, **las 10 tareas de Fase 0 están cerradas** y, por la propia regla de §11, Fase 1 ya no está frenada.

**Además, ya antes de Fase 1, se auditó B5 (x264/GPL)** — el único bloqueo Alto sin auditar que quedaba en el catálogo: `AMediaCodec` (NDK) confirma que resuelve legal y térmico, pero la vía real es un módulo de encoding nuevo para Android, no una reconfiguración de FFmpeg como sugería la recomendación original. Baja de Alto a Bajo, y cambia el alcance de Fase 7 en vez de dejar un riesgo abierto.

## 2. Estado de cada tarea

| # | Tarea | Estado | Resultado |
|---|---|---|---|
| 0.1 | Compilar Mine-imator 2.0.2 sin modificar | **Parcial** — solo Windows | Compiló, abrió, cargó un proyecto y renderizó un frame real (captura verificada). **Linux no se intentó en esta sesión** — el criterio de éxito original pedía los dos SO. `BUILD_NOTES.md` |
| 0.2 | Auditar CppGen | Cerrada, incluido el pendiente de diff-check | 4 preguntas de §4.3 respondidas con corrida real de `CppGen.exe` sobre el corpus completo (0 warnings, exit 0, 58% de tipos de variable resueltos). Diff-check contra `Generated/` corrido después (cero deriva, caso `Accessor.cpp:641` confirmado rama muerta) — y encontró que una corrección anterior sobre el caso `Alarm_0` estaba mal, ya corregida de nuevo. `research/2026-09-06-cppgen.md` |
| 0.3 | Resolver B1 | Cerrada | `QOpenGLExtraFunctions` cubre 48/49 llamadas GL reales, verificado por compilador contra Qt-Android real. 1 excepción (`glShaderStorageBlockBinding`, SSBO) resuelta por `[GATE G1]`: no portar batching a Android. `research/2026-09-06-b1-graphicsapihandler-prototype.md` |
| ~~0.4~~ | ~~Spike Ruta A~~ | **Eliminada del proyecto** | Decisión, no medición — ver §1 y §10/§17 de `CLAUDE.md` |
| 0.5 | Backend ES + shader más pesado en dispositivo real | **Movida a Fase 1** | Necesita un `CppProject` corriendo en Android, que no existe antes de esa fase. §5.3 queda marcada como asunción no verificada hasta entonces |
| 0.6 | Medir B2 — ancho de banda del pipeline diferido | Cerrada, con incertidumbre residual acotada | El viewport interactivo default (`render_low`/`SHADED`) no corre el pipeline caro y no está en riesgo — objetivo de §14.3 no amenazado. El pipeline caro (`render_high`, preview opt-in + export) sin indirect/reflections entra en presupuesto con preset móvil + RGBA16F (~11,7 GB/s @30fps). Indirect/reflections quedan con un rango de 4-33 GB/s según cache hit rate, no cerrable sin dispositivo. `research/2026-09-06-b2-deferred-bandwidth.md` |
| 0.7 | Presupuesto de memoria, mundo real importado | Cerrada, con datos reales (no estimados) | `WorldVertex` compacto confirmado. `sizeof(obj_timeline)` real compilado = 8.560B. Fracciones reales medidas sobre los `.schematic`/`.midata` empaquetados: preset "Grande" = **~60 MB medido** para terreno (caso típico), ~374 MB-1,63 GB razonado solo para importación densa en decoración (sin muestra real de ese caso). `research/2026-09-06-memory-budget.md` |
| 0.8 | Inventario de las 13 primitivas de UI | Cerrada | `research/2026-09-06-ui-inventory.md` — 13 `tab_control_*` son geometría pura; la interacción real vive en la familia paralela `draw_*`/`sortlist_*`/`menu_*` |
| 0.9 | Cobertura de `framebuffer_fetch` por vendor | Cerrada | Mali+Adreno (~95%+ del volumen Android vía cuota de SoC mapeada a GPU) confirman soporte real. Xclipse (AMD RDNA, immediate-mode, <2%) es la única duda y no cambia la decisión de implementar — mitiga solo una fracción chica de B2 de todos modos (el G-buffer, no indirect/reflections). `research/2026-09-06-framebuffer-fetch-coverage.md` |
| 0.10 | `[GATE]` Bloqueos legales | **Cerrada** | David Andrei confirmó por mail: MIT vigente, puerto móvil + Google Play autorizados, nombre debe ser genuinamente distinto. `CLAUDE.md` §9.3 |

**minSdkVersion = 29, `[GATE G1 — CERRADO]`** (§7.1.1): decidido con cobertura + el argumento de scoped storage obligatorio desde esa API, evitando mantener dos rutas de I/O (B4).

## 3. Bloqueos críticos — dónde quedó cada uno

| Bloqueo | Severidad al empezar Fase 0 | Severidad ahora | Qué cambió |
|---|---|---|---|
| B1 (`QOpenGLFunctions_3_1`/`_4_3_Core`) | Crítica | **Resuelta** | 0.3 — migración a `QOpenGLExtraFunctions` verificada por compilador |
| B2 (ancho de banda del renderer) | Crítica | **Media** | 0.6 — el objetivo interactivo real no está en riesgo; el pipeline caro entra en presupuesto sin indirect/reflections; esas dos features siguen sin acotar del todo |
| B11 (memoria, mundos importados) | Media | **Baja** | 0.7 — medido con datos reales, no estimado: el caso típico (terreno) es trivial (~60 MB), el riesgo queda acotado a importaciones densas en decoración sin muestra real para cerrar del todo |
| B4 (SAF vs. rutas de archivo) | Alta | Sin cambios — no auditada en Fase 0 | Confirmado como parte del argumento de minSdk=29 (§7.1.1), no investigado en profundidad todavía |
| B5 (x264 GPL) | Alta | **Baja — AUDITADO (pre-Fase 1)** | `AMediaCodec` (NDK) confirma que resuelve legal y térmico, pero es un módulo de encoding nuevo, no un flag de FFmpeg — cambia el alcance de Fase 7, no la viabilidad. `research/2026-09-06-b5-x264-mediacodec.md` |
| B6 (Qt LGPL) | Alta | Sin cambios | No auditado en Fase 0 — relevante sobre todo para iOS, no bloqueante en Android (linkeo dinámico) |
| B7/§9.3 (licencia de Mine-imator) | Alta | **Resuelta** | 0.10 — David Andrei confirmó MIT, puerto móvil y distribución autorizados por escrito |
| B8-B10, B12-B17 | Diversas | Sin cambios | No auditadas en Fase 0 — catalogadas, no investigadas |

## 4. Matriz de riesgos (probabilidad × impacto)

Escala: probabilidad y impacto en Bajo/Medio/Alto. "Riesgo" es la combinación, no un producto numérico — se prioriza por lectura, no por fórmula.

| Riesgo | Probabilidad | Impacto | Riesgo neto | Por qué |
|---|---|---|---|---|
| David Andrei no responde o responde negativamente (0.10) — **RESUELTO** | — | — | **Cerrado** | Confirmó MIT, puerto móvil y distribución en Google Play por escrito. Era el único riesgo Alto de toda la matriz — ya no está |
| El backend ES de `processCode` (§5.3) no generaliza igual de bien que el desktop | Media | Alto (rehace la estimación de 53 shaders) | **Medio-Alto** | Es una asunción no verificada, no un hallazgo — se prueba en Fase 1 (0.5 movida), no antes |
| Indirect lighting/reflections no llegan a un costo aceptable ni degradados | Media | Medio (son features opcionales, hay fallback) | **Medio** | Rango de 4-33 GB/s sin cerrar; pero incluso en el peor caso, el fallback es "no ofrecerlas en Android", no perder el proyecto |
| Preset de importación "Grande" causa OOM en dispositivos de 4 GB | Baja (el caso típico —terreno— mide ~60 MB; solo importaciones muy densas en decoración se acercan a un rango de riesgo, sin muestra real para confirmarlo del todo) | Alto si ocurre (crash sin aviso) | **Bajo** | Cerrado con datos reales en 0.7 — de Medio-Alto a Bajo en esta misma sesión |
| 0.1 nunca se verificó en Linux | Baja probabilidad de bloqueo real (Qt/CMake ya funcionan en Windows) | Bajo-Medio (afecta solo desarrollo cruzado, no el producto Android) | **Bajo** | Android no depende de que el build de Linux funcione; es deuda de auditoría, no un riesgo de producto |
| B5 (x264/GPL) — auditado, resuelto en diseño, pendiente de implementar | Alta (es requisito funcional) | Medio (ya no es "sin salida" — es trabajo de ingeniería presupuestado, no un riesgo abierto) | **Bajo** | Auditado pre-Fase 1: `AMediaCodec` (NDK) es la vía real, confirmada estable y sin conflicto con minSdk=29. El trabajo (módulo de encoding nuevo, decisión Surface/ByteBuffer, recompilar FFmpeg sin GPL y dinámico) queda presupuestado en Fase 7, no es un bloqueo |
| Xclipse/tendencia a immediate-mode erosiona TBDR en gama alta a futuro | Baja hoy, incierta a 2-3 años | Bajo hoy (afecta <2% del mercado) | **Bajo, vigilar** | No cambia ninguna decisión de esta fase — sí condiciona cuánta inversión futura tiene sentido en optimizaciones TBDR-específicas |
| B3, B4, B6, B8-B10, B12-B17 sin auditar en profundidad | Desconocida | Desconocida | **Sin evaluar** | Están catalogados (§8) pero Fase 0 no los tocó — quedan para auditoría dentro de las fases correspondientes (I/O, UI táctil, etc.), no bloquean el inicio de Fase 1 |

## 5. Recomendación de ruta

**Seguir con la Ruta B.** No es una recomendación por descarte de las demás (C y D nunca se evaluaron, no están descartadas — ver §10) sino porque B es la única que acumuló evidencia real esta fase: sus dos bloqueos catalogados como críticos al arrancar (B1, B2) bajaron a resuelto/medio con medición real, no con optimismo. La ruta no está "aprobada sin condiciones" — tiene dos condiciones abiertas que Fase 1 tiene que resolver temprano, no al final:

1. **Validar §5.3 con la tarea 0.5** (backend ES + `shader_high_light_point` real) apenas exista un build de Android mínimo. Si el backend ES no generaliza tan bien como el desktop, la estimación de "un archivo, no 53 shaders" se cae, y eso cambia el costo del proyecto de forma material — es la asunción de mayor apalancamiento de todo el análisis de shaders.
2. El preset de importación "Grande" ya no necesita restricción para el caso típico (terreno, ~60 MB medido) — 0.7 se cerró con datos reales dentro de esta misma fase. Queda una guarda barata opcional (avisar/degradar si `sch_timeline_amount` supera un umbral) para el único escenario sin cerrar del todo: importaciones muy densas en decoración.

## 6. Qué falta antes de Fase 1

**Nada bloqueante.** El único gate real (0.10) ya cerró — Fase 1 puede arrancar por regla propia de §11. Plan detallado en `research/PHASE1_PLAN.md` (preparado antes de la respuesta de David Andrei, ya sin el freno que tenía al escribirse).

- **0.1 en Linux** sigue deferido por decisión explícita (2026-09-06), no por omisión — esta máquina no tiene WSL, instalarlo pide reiniciar Windows, y el riesgo asociado es Bajo (§4). No bloquea Fase 1.
- **El nombre del proyecto (§9.5)** sigue siendo una decisión del usuario, ahora con una restricción confirmada por David Andrei (no puede ser una variación de "Mine-imator") — vale la pena resolverla temprano en Fase 1, porque toca el manifest/paquete de Android (`research/PHASE1_PLAN.md`, punto 5).

## 7. Fuentes

- `research/2026-09-06-cppgen.md` (0.2)
- `research/2026-09-06-b1-graphicsapihandler-prototype.md` (0.3, incluye cierre de `[GATE G1]` sobre SSBO)
- `research/2026-09-06-b2-deferred-bandwidth.md` (0.6, con historial de 3 revisiones dentro de la misma tarea)
- `research/2026-09-06-memory-budget.md` (0.7)
- `research/2026-09-06-ui-inventory.md` (0.8)
- `research/2026-09-06-framebuffer-fetch-coverage.md` (0.9)
- `research/2026-09-06-b5-x264-mediacodec.md` (auditoría B5, pre-Fase 1)
- `research/2026-09-06-gpu-driver-quirks.md` (bugs de driver conocidos por vendor, pre-Fase 2 — sin blockers nuevos)
- `BUILD_NOTES.md` (0.1, F1-F10 y checkpoint de Qt-Android)
- `LICENSE_INQUIRY_DRAFT.md` (0.10, borrador enviado) + respuesta de David Andrei, 2026-09-06, registrada en `CLAUDE.md` §9.3
- `research/PHASE1_PLAN.md` (plan de Fase 1, ya sin freno de gate)
- `CLAUDE.md` §7.1.1 (minSdk=29), §8 (catálogo de bloqueos), §8.1 (trampas de verificación T1/T2), §10 (rutas técnicas), §14.3 (presupuestos, viewport vs. preview/export), §17 (registro de correcciones — historial completo de cada revisión, no solo el resultado final)
