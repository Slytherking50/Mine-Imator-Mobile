# Registro de rendimiento (Fase 6)

Exigido por `CLAUDE.md` §14.1: ninguna optimización se acepta sin medición antes, medición después, y el dispositivo exacto. Este archivo es ese registro.

## Dispositivo de referencia actual

**Único disponible hoy** (`CLAUDE.md` §14.2, GATE resuelto parcialmente 2026-09-15: el usuario decidió medir con este dispositivo y avanzar, dejando gama media/alta pendientes de conseguir hardware):

- **Modelo:** Redmi 10C (220333QL)
- **Android:** 13 (API 33)
- **GPU:** Adreno 610
- **Clasificación real:** gama baja-media — usado como el único punto de dato disponible para los 3 tiers de §14.2 por ahora, no como sustituto real de gama media/alta

## Presupuestos objetivo (`CLAUDE.md` §14.3)

| Métrica | Objetivo | Pipeline | Estado |
|---|---|---|---|
| Viewport interactivo | 30 fps sostenidos en gama media | `render_low()` / `SHADED` (default) | Sin medir — pendiente dispositivo |
| Preview "Render" / export — tiempo por frame a 1080p | Sin definir todavía (`research/2026-09-06-b2-deferred-bandwidth.md`: ni siquiera existe la fila de presupuesto hoy) | `render_high()` / `RENDER` | Sin definir |
| Arranque | < 5 s | — | Sin medir — pendiente dispositivo |
| Memoria pico, escena típica | < 1,5 GB | — | Sin medir — pendiente dispositivo |
| Throttling térmico | sin caída > 20% tras 10 min | — | Sin medir — pendiente dispositivo |

## Punto de partida: análisis teórico ya hecho (B2, tarea 0.6)

`research/2026-09-06-b2-deferred-bandwidth.md` — modelo de bytes desde el código fuente, sin dispositivo (documentado explícitamente como tal en su momento). Conclusión: **el viewport interactivo por default (`render_low()`, lo que corre en `SHADED`) no está en riesgo** — costeado en ~250 MB/frame, ~7,5 GB/s @30fps, muy por debajo de cualquier SoC de gama media (~9-12 GB/s sostenido real). El pipeline caro (`render_high()`/`RENDER`) es otro tema, opt-in, sin objetivo de fps definido en §14.3 hoy.

Este documento reemplaza ese modelo teórico con números reales del Redmi 10C en cuanto haya conexión con el dispositivo.

## Metodología de medición (ADB, sin inyección de touch — MIUI la bloquea)

- **Arranque:** `adb shell am start -W <pkg>/<activity>` da `TotalTime` directo, sin instrumentación manual.
- **Memoria pico:** `adb shell dumpsys meminfo <pkg>` (campo `TOTAL PSS`) tomado en varios momentos: justo después de cargar assets, con una escena tipo (personaje + bloques + textura) abierta, y durante export.
- **FPS del viewport:** `adb shell dumpsys gfxinfo <pkg> framestats` mientras el usuario orbita/interactúa a mano (no puedo simular el toque) — necesita coordinación en vivo.
- **Térmico:** `adb shell dumpsys thermalservice` o lectura directa de `/sys/class/thermal/thermal_zone*/temp` antes y después de 10 minutos de uso continuo (renderizado activo, no en reposo).

## §14.4 punto 3 — Atlas de texturas, CERRADO con dato real

`GL_MAX_TEXTURE_SIZE` en el Redmi 10C (Adreno 610): **16384** (medido, `GraphicsApiHandler.cpp`, agregado 2026-09-15 — antes nunca se consultaba). El `PAGE_SIZE` fijo de `TexturePage.cpp` (4096) queda 4x por debajo, sin riesgo — no hace falta ningún cambio. El loop de fallback existente en `TexturePage.cpp` (reduce `pageSize` a la mitad si falla la asignación) protege contra falta de RAM del lado de la CPU, no contra el límite de la GPU — ahora hay un número real detrás de la suposición de que 4096 es seguro, en vez de solo confiar en la especificación mínima de OpenGL ES.

## Viewport interactivo (30fps) — medido con datos reales

`dumpsys gfxinfo` **no sirve para esto** — mide el compositor de vistas de Android para esta Activity, no el loop de render interno de Qt/OpenGL: mostró "Total frames rendered: 5" después de minutos de renderizado 3D continuo real. Se agregó en cambio un log propio (`AppHandler.cpp`, junto al cálculo de `gmlGlobal::fps` que el motor ya hace una vez por segundo) — mismo canal de log.txt que el resto de esta sesión.

**Medición real (usuario orbitando/interactuando ~3,5-4 minutos seguidos, Redmi 10C):**
- Fase de carga (antes de llegar al editor): 0-2 fps, esperado, no cuenta para este presupuesto
- Una vez en el editor: **predominantemente 60fps** (el techo, probablemente limitado por vsync), con caídas puntuales aisladas (18, 12, 8fps en momentos sueltos) — muy por encima del objetivo de 30fps la gran mayoría del tiempo
- **Hacia el final del tramo medido (~últimos 25s de ~4 min de uso continuo): caída sostenida a 22-39fps**, ya no son caídas puntuales sino una banda más baja mantenida — primera señal real de degradación con el tiempo, no solo ruido

**¿Es throttling térmico?** Revisado en el momento: `dumpsys thermalservice` reporta `Thermal Status: 0` (ninguno) y temperaturas de zona térmica de 37-38,6°C — moderadas, sin throttling reportado a nivel sistema. No descarta throttling específico de GPU (DVFS) que el thermal status del sistema no necesariamente captura. **Sin confirmar** — haría falta una prueba controlada de 10 minutos completos con lectura de temperatura antes/después (el presupuesto real de §14.3 es sobre 10 min, esta medición fue ~4 min) para separar "está bajando por calor" de "el usuario interactuó menos hacia el final".

## Mediciones reales

| Fecha | Métrica | Valor medido | Contra objetivo | Notas |
|---|---|---|---|---|
| 2026-09-15 | Arranque (proceso → "Particle textures: done" en log.txt, última etapa de carga de texturas core) | **~11 s** | ❌ Objetivo <5s — más del doble | `am start -W` solo mide hasta el primer frame dibujado (TotalTime: 1405ms, pantalla de carga), no hasta que la app es usable — no sirve como métrica de este presupuesto. Medido desde "Debug mode enabled" (primera línea de log) hasta "Particle textures: done" (última etapa de texturas). Instalación NO limpia (APK reinstalado sobre datos existentes) — no descarta que una instalación limpia (con el paso de copiado de datos de `data_directory_seed_android.gml`) tarde más todavía. Repetir la medición para confirmar consistencia entre corridas |
| 2026-09-15 | Memoria, pantalla de bienvenida (recién cargado, sin proyecto abierto) | TOTAL PSS 578 MB | ✅ Dentro de <1,5GB (pero no es "escena típica", el objetivo real) | `adb shell dumpsys meminfo` |
| 2026-09-15 | Memoria, proyecto "Prueba" abierto (editor real, capturado con captura de pantalla) | TOTAL PSS 583 MB | ✅ Dentro de <1,5GB, pero **no representa una "escena típica"** — la escena es el cubo por defecto, sin personaje/bloques/texturas reales de Minecraft (el proyecto no tiene ninguna versión real cargada, `KNOWN_ISSUES.md` B25/B26) | Prácticamente igual a la pantalla de bienvenida — consistente con que no hay contenido real agregado. Una medición genuinamente representativa del presupuesto necesitaría una escena con personaje+bloques+texturas reales, que hoy no es posible armar sin conseguir assets de Minecraft por fuera de la app (B26) |

## Hallazgos, sin optimizar todavía (regla §14.1: medir antes de tocar código)

**Arranque (~11s) es el primer presupuesto que no se cumple con datos reales**, no solo el modelo teórico de B2. Desglose real por etapa (mismo log.txt, timestamps exactos):

| Tramo | Duración | Qué es |
|---|---|---|
| "Debug mode enabled" → "Model textures: load" | **~6 s** | Todo lo que pasa ANTES de que arranque la carga de texturas — el tramo más grande de los 11s, más que toda la carga de texturas junta |
| "Model textures: load" → "done" | ~2 s | Carga de modelos |
| "Block textures" (diffuse+animadas+previews+profundidades) | ~2 s | Carga de bloques |
| "Item textures" | ~1 s | Carga de ítems |
| "Particle textures" | <1 s | Carga de partículas |
| **Carga de texturas total** | **~5 s** | Ya está prácticamente en el presupuesto por sí sola |

**Actualización — B17 investigado y DESCARTADO como causa principal.** Se agregó instrumentación real (`Shader::Load()`, `Shader.cpp`, timer por shader, Android-only) y se midió: los 47 shaders logueados suman **~1,68 s de compilación real total** — lejos de explicar los ~6s. Desglose real de esta corrida:

| Tramo | Duración | Qué es |
|---|---|---|
| "Debug mode enabled" → primer shader compilado | ~1 s | Inicialización de ventana/contexto GL, `Shader::Init()` (detección de versión GLSL) |
| Compilación de los 47 shaders | ~2 s (suma real 1,68s + overhead) | Confirmado con timer real, no estimado — **B17 no es la causa principal** |
| Último shader compilado → "Model textures: load" | **~3 s** | **Sin explicar todavía — nuevo sospechoso principal**, no estaba visible antes de agregar el timing por shader |

**Próximo paso, más preciso ahora.** Se descartó el desarchivado como causa: "Archive already unzipped, re-using" aparece exactamente junto con "Model textures: load" (ambos son casi el mismo instante) — el chequeo de si ya está desarchivado es rápido, no el cuello de botella. Los ~3s reales están ANTES de esa línea, entre el último shader compilado y el chequeo de desarchivado.

`minecraft_assets_load.gml:13` tiene un `if (current_step < 5) break` — la función corre una vez por frame y las primeras 5 llamadas no hacen nada (pausa deliberada, probablemente para el fade-in de la pantalla de carga). **Hipótesis más fuerte ahora:** si cada uno de esos 5 frames tarda mucho más de lo normal durante el arranque en frío del contexto GL/driver (un fenómeno conocido en GPUs móviles — los primeros frames después de crear el contexto suelen ser bastante más lentos que en régimen estable), 5 frames lentos podrían sumar los ~3s completos sin que haya ningún trabajo pesado real ahí — sería tiempo de espera de animación, no de cómputo. Sin confirmar todavía: requeriría loguear el tiempo de cada uno de esos 5 frames específicamente, no solo las etapas con nombre.

**Hipótesis de los 5 frames lentos: DESCARTADA con datos reales.** Instrumentado (`minecraft_assets_load.gml`, `current_step`/`current_time` por frame): los 5 frames de espera tardaron en total **~280ms** (deltas de 223/19/19/18ms — completamente normales, ~50+ fps). No es ahí.

**Ubicación real del hueco, por lectura de código (`app_startup.gml`):** entre `shader_startup()` (ya medido: ~2s reales) y `minecraft_assets_startup()` corren **13 funciones de setup más**, ninguna medida todavía: `legacy_startup`, `app_startup_lists`, `app_startup_collapse`, `app_startup_micro_animations`, `app_startup_window`, `app_startup_themes`, `app_startup_fonts`, `app_startup_interface_lists`, `app_startup_keybinds`, `app_startup_recent`, `toasts_startup`, `json_startup`, `settings_startup`, `project_startup`, `render_startup`, `camera_startup`. El ~1,5s restante del hueco de 6s está en algún lado de esta lista — probablemente repartido entre varias, no una sola. `app_startup_fonts()` es la sospechosa más plausible individualmente (cargar/rasterizar fuentes es un costo típico real), pero sin medir todavía.

**RESUELTO (2026-09-16) — medición real con timers en las 16 funciones, Redmi 10C:**

| Función | ms medidos |
|---|---|
| `legacy_startup` | 64 |
| **`app_startup_lists`** | **828** |
| `app_startup_collapse` | 1 |
| `app_startup_micro_animations` | 0 |
| `app_startup_window` | 0 |
| `app_startup_themes` | 1 |
| **`app_startup_fonts`** | **514** |
| `app_startup_interface_lists` | 0 |
| `app_startup_keybinds` | 3 |
| `app_startup_recent` | 11 |
| `toasts_startup` | 290 |
| `json_startup` | 0 |
| `settings_startup` | 218 |
| `project_startup` | 0 |
| `render_startup` | 4 |
| `camera_startup` | 0 |
| **Total** | **~1934 ms** |

Coincide casi exacto con el hueco de ~1,5-2s que se venía persiguiendo. Cuatro funciones concentran el 97% del tiempo: **`app_startup_lists` (828ms, 43%)**, **`app_startup_fonts` (514ms, 27%, confirma la sospecha ya anotada)**, `toasts_startup` (290ms, 15%) y `settings_startup` (218ms, 11%) — el resto (12 funciones) suma menos de 100ms combinado.

**Instrumentación:** `GmProject/scripts/app_startup/app_startup.gml`, `log()` (no gateado por `dev_mode`) alrededor de cada llamada, solo Android (`platform_get() == e_platform.ANDROID`). Queda en el código fuente — no se sacó, porque es barata (2 `if` + 1 `log()` por función) y útil para volver a medir después de optimizar cualquiera de las 4 candidatas.

**Causa raíz de las 2 candidatas principales, por lectura de código (2026-09-16) — ninguna optimización aplicada todavía, a pedido explícito del usuario ("ninguna por ahora, solo quería el diagnóstico"):**

- **`app_startup_lists` (828ms):** el costo real está en `new_transition_texture_map(36, 36, 6, true)` y `new_transition_texture_map(24, 24, 3, false)` (`GmProject/scripts/app_startup_lists/app_startup_lists.gml:380-381`, entre los logs "Make transitions"/"Transitions OK" ya existentes). Esa función (`new_transition_texture_map.gml`) genera **66 texturas** (33 tipos de transición × 2 tamaños), y para cada una dibuja hasta `quality = w * aa = 36 * 4 = 144` segmentos de línea (calculando bezier/ease por segmento) en una superficie a 4x, más un cambio de render target y una conversión a textura por transición — para un resultado final de apenas 36×36 o 24×24 píxeles. Sobremuestreo real: 144 segmentos para un ícono de 36px es mucho más de lo que el ojo puede distinguir. **Optimización identificada, no aplicada:** bajar `quality` a algo como 32-48 segmentos — barato de probar, fácil de revertir si se nota, no tocado todavía.

- **`app_startup_fonts` (514ms):** las 11 llamadas a `font_add()` (`GmProject/scripts/app_startup_fonts/app_startup_fonts.gml`) usan el mismo rango de glyphs (32-1024, ~992 glyphs) para las 11 fuentes — cada una rasteriza ese rango completo vía FreeType al arrancar. **Optimización identificada, no aplicada por riesgo:** el rango real necesario es probablemente mucho menor (latín básico + acentos de español), pero reducirlo a ciegas es riesgoso — ya pasó una vez que un tamaño de fuente insuficiente hizo que "." y "-" se rindieran invisibles en `8bit_arcade_in.ttf` (comentario en el mismo archivo, línea 26-35) — habría que auditar qué caracteres se usan realmente antes de tocar el rango.

**Estado:** diagnóstico cerrado para ambas, ninguna optimización aplicada. Retomar cuando el usuario decida priorizar el arranque — el camino de menor riesgo es `new_transition_texture_map`'s `quality`.

**Nota de proceso, no de rendimiento:** esta medición se retrasó porque `CppGen.exe` parecía estar crasheando (`KNOWN_ISSUES.md` B34) — resultó ser un error de invocación propio (directorio de trabajo incorrecto), no un bug real. Repetir la medición 2-3 veces más sigue pendiente, para separar "siempre tarda esto" de variación de esta corrida puntual.
