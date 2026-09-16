# Investigación: cobertura de `framebuffer_fetch` por vendor de GPU (tarea 0.9)

## Pregunta

¿`GL_EXT_shader_framebuffer_fetch` (o equivalente) está disponible en la cobertura suficiente de GPUs Android como para que valga la pena implementarlo como mitigación del G-buffer? Tabla por vendor (Mali/Adreno/PowerVR/Xclipse) con cuota de mercado.

**Contexto de por qué esta tarea importa menos de lo que el catálogo original de B2 sugería:** 0.6 ya estableció que `framebuffer_fetch` solo puede atacar el store/load de los targets MRT del G-buffer (~66-91 MB de un total de ~389-1.218 MB según escenario, `research/2026-09-06-b2-deferred-bandwidth.md`) — no toca SSAO, acumulación de samples, glow, subsurface scattering, ni el ray marching de indirect/reflections, que juntos son la mayoría del costo real. Esta tarea confirma si esa fracción chica es al menos viable de mitigar, no si resuelve B2 entero (no lo resuelve).

## Método

1. Se buscó el registro oficial de Khronos para `GL_EXT_shader_framebuffer_fetch` y `GL_ARM_shader_framebuffer_fetch` (dos extensiones distintas, no una sola con dos nombres) y documentación de vendor (ARM developer blog, PowerVR/Imagination docs) para confirmar soporte real, no asumido.
2. Para cuota de mercado, no existe una fuente única y pública de "% de GPUs Android por vendor" con el desglose exacto pedido (Mali/Adreno/PowerVR/Xclipse) — varias fuentes de terceros (cpu-monkey, nanoreview, statcounter) bloquearon el acceso automatizado o no tenían el dato desglosado por GPU. Se usó en cambio la cuota de mercado de **SoC** (que sí tiene una fuente primaria confiable, Counterpoint Research, actualizada a Q4 2025) y se mapeó cada fabricante de SoC a su GPU típica, verificando caso por caso qué GPU usa cada uno en sus chips actuales (no asumido por fabricante completo, ver Evidencia).
3. Se buscó específicamente la arquitectura de renderizado de Xclipse (tile-based vs. immediate-mode) porque es la única GPU de las 4 que no es un diseño mobile-first tradicional, y "soporta la extensión" no es la misma pregunta que "la extensión da el mismo beneficio de ancho de banda" en una arquitectura distinta.

## Evidencia

**Extensiones, no una sola:**
- `GL_EXT_shader_framebuffer_fetch` (Khronos, extensión #122 ES / #520 GL, coherencia completa garantizada entre reads/writes del framebuffer).
- `GL_ARM_shader_framebuffer_fetch` (extensión separada, específica de ARM, soportada desde ES 2.0, un solo buffer de lectura, con un path de MSAA más eficiente que la versión EXT según la propia blog de ARM).
- Esto importa para la implementación: un shader portable tiene que chequear **los dos nombres de extensión**, no uno solo — un driver Mali puede exponer únicamente el ARM-específico según versión, y asumir que solo existe el EXT genérico dejaría a Mali afuera aunque sí lo soporte. Es el mismo tipo de trampa que T1 en §8.1 (una verificación que se queda corta y concluye mal) — la agrego ahí también.

**Por vendor:**

| Vendor | Arquitectura | Extensión confirmada | Fuente |
|---|---|---|---|
| **Adreno** (Qualcomm) | Tile-based | `GL_EXT_shader_framebuffer_fetch`, confirmado en modelos probados (Adreno 305/320/330 con 100% de soporte reportado) | Reportes de vendor/Khronos |
| **PowerVR** (Imagination) | Tile-based deferred — es la arquitectura de origen de esta extensión (memoria de tile con lectura de píxel nativa) | `GL_EXT_shader_framebuffer_fetch`, listado en la documentación oficial de extensiones soportadas de PowerVR | docs.imgtec.com / PowerVR Supported Extensions (OpenGL ES/EGL) |
| **Mali** (ARM) | Tile-based | Ambas extensiones — `GL_ARM_shader_framebuffer_fetch` (propia, desde ES 2.0) y `GL_EXT_shader_framebuffer_fetch` (genérica, documentada explícitamente para arquitecturas tile-based Mali/Immortalis en la blog de desarrolladores de ARM) | Khronos registry + ARM Developer Community blog |
| **Xclipse** (Samsung, GPU AMD RDNA 2/3) | **Immediate-mode**, no tile-based — confirmado como una ruptura deliberada respecto al resto de GPUs móviles (Mali/Adreno/PowerVR son todas tile-based) | No se encontró confirmación de la extensión en documentación pública. Aunque la expusiera, el mecanismo que hace barato a `framebuffer_fetch` (el tile sigue en memoria on-chip entre pasadas del mismo tile) no aplica igual a un diseño immediate-mode | Reportes técnicos sobre Exynos 2200/2400 (Xclipse 920/940) |

**Cuota de mercado — SoC (Counterpoint Research, Q4 2025, shipments globales), no GPU directamente:**

| Fabricante | Cuota (todo el mercado, incl. Apple) | Cuota re-normalizada solo Android (excluyendo Apple 23%) |
|---|---|---|
| MediaTek | 30% | ~39% |
| Qualcomm | 22% | ~29% |
| UNISOC | 15% | ~19% |
| Samsung (Exynos) | 6% | ~8% |
| HiSilicon (Kirin) | 3% | ~4% |
| Apple (excluido, no es Android) | 23% | — |

**Mapeo SoC → GPU, verificado por fabricante, no asumido:**
- MediaTek → Mali en toda la línea Dimensity/Helio actual.
- Qualcomm → Adreno siempre (GPU propia).
- UNISOC → **mayoritariamente Mali** en los chips actuales (Tiger T612/T606/T770 confirmados con Mali-G57), PowerVR quedó relegado a modelos viejos/de entrada (T310, 2019) — no es un 50/50 como se podría asumir de "usa las dos", es Mali en la gran mayoría del volumen actual.
- Samsung Exynos → Mali en la mayoría de la línea (gama media), **Xclipse solo en los SoC flagship más recientes** (Exynos 2200/2400, variantes regionales de Galaxy S22/S24 — no todos los mercados, Qualcomm cubre el resto incluso en flagships Samsung).
- HiSilicon → Mali.

## Hallazgos

### 1. Cobertura combinada Mali+Adreno+PowerVR (todas confirmadas con soporte real) es la gran mayoría del volumen Android

Con el mapeo de arriba: Mali termina cubriendo aproximadamente MediaTek (39%) + la mayoría de UNISOC (19%) + la mayoría de Samsung (8%) + HiSilicon (4%) ≈ **~65-70% de los shipments Android**. Adreno cubre el ~29% de Qualcomm. Sumados, **Mali+Adreno solos ya son ~95%+ del volumen**, y ambos confirmaron soporte real de la extensión. PowerVR es hoy una fracción chica y decreciente (legado, no volumen actual). **Esto no es una cifra de "cuota de mercado de GPU" medida directamente — es derivada de cuota de SoC más el GPU típico de cada fabricante, y se presenta así de explícito para no hacerla pasar por más precisa de lo que es.**

### 2. Xclipse es el verdadero outlier, y es una fracción mínima del mercado — pero la tendencia importa más que el número de hoy

Menos del ~2% del volumen Android total (una porción de un Samsung que ya es ~8%, y Xclipse solo cubre parte de la línea flagship de Samsung, no toda). Su arquitectura immediate-mode significa que aunque existiera soporte de la extensión, **no está garantizado que entregue el mismo ahorro de ancho de banda** que en las 3 arquitecturas tile-based — el mecanismo de fondo (tile en memoria on-chip entre pasadas) no es el mismo. Dado el tamaño de su cuota, no cambia la decisión de si vale la pena implementar la mitigación.

**Pero que Samsung haya elegido específicamente moverse a immediate-mode con RDNA en su línea flagship (Exynos 2200/2400) sugiere una tendencia de gama alta, no una rareza de un solo fabricante.** AMD no diseña GPUs tile-based — si otros fabricantes de SoC premium siguieran a Samsung en licenciar arquitecturas de escritorio adaptadas (en vez de las IP mobile-first de ARM/Imagination/Qualcomm), la cuota de TBDR en el segmento alto podría erosionarse con el tiempo, aunque hoy siga siendo la norma abrumadora. Esto no cambia la decisión de implementar `framebuffer_fetch` ahora (cobertura alta hoy, costo de implementación bajo, ninguna razón para no hacerlo) — sí es una razón para no apostar *más* inversión en optimizaciones que dependan estructuralmente de TBDR (más allá de esta) como si TBDR fuera una propiedad permanente del hardware móvil de gama alta. Es una señal a vigilar en 14.2 (dispositivos de referencia) cuando se elija el dispositivo de "gama alta", no una conclusión a la que actuar todavía.

### 3. La implementación necesita chequear dos strings de extensión, no uno

`GL_EXT_shader_framebuffer_fetch` y `GL_ARM_shader_framebuffer_fetch` son extensiones separadas. Un chequeo que solo busque la primera puede reportar "no soportado" en un Mali que sí lo soporta bajo el nombre ARM-específico — mismo patrón que la trampa T1 de §8.1 (un chequeo que se queda corto concluye mal). Documentado ahí también.

## Contradicciones con CLAUDE.md

- §11, criterio de éxito de 0.9 pedía "tabla Mali/Adreno/PowerVR/Xclipse con cuota de mercado" asumiendo implícitamente que existe una fuente directa de cuota de mercado por GPU. No existe públicamente con ese desglose exacto — se usó cuota de SoC + mapeo a GPU, documentado como estimación derivada, no medición directa.
- §8, B2 (fila de mitigación) mencionaba `framebuffer_fetch` sin la advertencia de que cubre una fracción chica del total (ya corregido en la revisión de 0.6, pero esta tarea lo confirma desde el ángulo de cobertura de hardware, no de bandwidth).

## Incógnitas

- No se pudo verificar con una fuente primaria (Qualcomm/ARM/Samsung) un número de "cuota de mercado de GPU" directo — todo lo de arriba es derivado de cuota de SoC, que es una aproximación razonable pero no la métrica pedida literalmente.
- No se encontró confirmación pública de si Xclipse expone algún string de framebuffer fetch — "no se encontró" no es lo mismo que "no existe"; requeriría acceso a un dispositivo Exynos 2200/2400 real y `glGetString(GL_EXTENSIONS)`.
- No se verificó versión mínima de driver por generación de Mali (Utgard/Midgard/Bifrost/Valhall) para cada una de las dos extensiones — la tabla de arriba confirma que Mali soporta al menos una de las dos en general, no en qué generación exacta aparece cada una.
- Cuota de SoC (shipments nuevos) no es lo mismo que base instalada (dispositivos en uso hoy) — un proyecto con minSdk=29 (§7.1.1) va a tener una base instalada con más peso hacia dispositivos de 2-5 años, no shipments del último trimestre. No se ajustó por esto.

## Decisión propuesta

`framebuffer_fetch` es viable de implementar: Mali y Adreno (~95%+ del volumen Android, con el mapeo de arriba) confirman soporte real, y PowerVR (legado, decreciente) también. Xclipse es la única duda real, pero es una fracción tan chica del mercado (<2%) que no cambia la decisión — en el peor caso, esos dispositivos simplemente no reciben la mitigación y siguen pagando el costo completo del G-buffer, sin bloquear al resto.

Dicho esto, y esto es lo que hay que llevarse de 0.9 más que la tabla de cobertura: **la mitigación en sí ataca una fracción chica del problema real que encontró 0.6** (~66-91 MB de banda del G-buffer, no los ~1,2 GB del pipeline completo ni los 5,5 GB con indirect/reflections). Vale la pena implementarla porque la cobertura de hardware es alta y el costo de implementación es bajo, pero no hay que esperar que mueva la aguja de "B2 crítica vs. manejable" — eso ya lo decidieron el preset móvil y los formatos optimizados en 0.6, no esto.
