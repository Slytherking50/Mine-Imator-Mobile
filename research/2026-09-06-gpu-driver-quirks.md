# Investigación: bugs/rarezas conocidas de drivers GL ES por vendor (pre-Fase 2)

## Pregunta

Más allá de la existencia de extensiones (ya cubierto en 0.9), ¿hay bugs o comportamientos divergentes conocidos en los drivers OpenGL ES reales de Mali/Adreno/PowerVR/Xclipse que puedan afectar específicamente lo que este port necesita (MRT, VAOs, precisión de shaders, arrays de matrices, versión de GLSL reportada)?

**Aclaración de expectativa, antes de los hallazgos:** esto no puede ser una auditoría "completa" como 0.1-0.9 — los bugs de drivers móviles se descubren empíricamente, probando en hardware real, no leyendo documentación (una de las fuentes consultadas lo dice explícito: "driver bugs are rampant... generally not fixed, requiere workarounds por combinación de OS/dispositivo/driver"). Lo que sigue es una fotografía de lo públicamente documentado hoy, útil para saber qué vigilar, no una lista cerrada de todo lo que puede salir mal — eso solo lo cierra probar en los 3 dispositivos de referencia de §14.2, en Fase 2.

## Método

Búsqueda web dirigida a los puntos técnicos concretos que este port ya sabe que necesita (de 0.3/0.9): precisión de shaders (`mediump`/`highp`), MRT (`glDrawBuffers`), VAOs (ES 3.0), versión de GLSL reportada, arrays de matrices en shaders — no una búsqueda genérica de "bugs de GPU", para evitar traer ruido de hardware irrelevante (se descartaron explícitamente resultados sobre GPUs anteriores a ~2016-2017, dado que `minSdkVersion=29` — Android 10, 2019 — ya excluye la mayoría del hardware pre-2017 relevante en la práctica).

## Evidencia

**Precisión de shaders (`mediump`/`highp`) — comportamiento real, no solo teórico, difiere por vendor:**
- La especificación GL ES permite a cada vendor implementar `mediump`/`highp` con más precisión de la mínima requerida, o colapsar todo a 32-bit float — es decir, el mismo shader puede comportarse distinto en precisión real según el driver, por diseño de la spec, no por bug.
- **Bug concreto y específico, con repro público (`github.com/jure/precision-bug-repro`):** en Adreno 540 y 650, un `highp float` **dentro de un struct** pierde precisión a ~binary16 (media precisión) en el fragment shader, mientras que el mismo `highp float` fuera de un struct mantiene precisión IEEE-754 completa. Relevante para este proyecto porque el renderer diferido empaqueta/desempaqueta valores (profundidad, normales) con matemática de precisión ajustada — si esa lógica alguna vez pasa a vivir dentro de un struct de shader, este bug puntual podría corromper el resultado silenciosamente en dispositivos Adreno 540/650 específicamente.

**Reporte de versión de GLSL — Adreno miente en algunos casos:** drivers Adreno reportan información de versión de GLSL incorrecta incluso para ES 3.10 y 3.20. Relevante porque cualquier lógica de detección de features basada en parsear `glGetString(GL_SHADING_LANGUAGE_VERSION)` (en vez de chequear la extensión/función puntual que hace falta) podría tomar una decisión equivocada en Adreno. **Mitigación ya implícita en cómo se hizo 0.3 y 0.9:** el proyecto ya viene detectando soporte por presencia de función/extensión puntual (`GL_EXT_shader_framebuffer_fetch` vs. `GL_ARM_...`, T2 de §8.1), no por parseo de string de versión — el patrón correcto ya está establecido, solo hay que no romperlo más adelante.

**Arrays de matrices — Adreno 650 no permite indexar un array de `mat4` por una variable** (índice debe ser constante en tiempo de compilación en ese driver específico). Relevante si algún shader de Mine-imator indexa una animación por hueso/parte del cuerpo vía un array de matrices con índice dinámico — no se verificó todavía si algún shader real del proyecto hace esto (ver Incógnitas).

**MRT (`glDrawBuffers`) — sin un bug puntual documentado y confiable encontrado.** Las búsquedas dirigidas trajeron más ruido que señal acá (un resultado mezclaba "AMD Adrenalin", el driver de tarjetas de escritorio AMD, con "Qualcomm Adreno", el GPU móvil — nombres parecidos, productos de compañías distintas, sin relación — **descartado explícitamente, no se cita como hallazgo real**). No encontrar un bug documentado no es lo mismo que "no hay ninguno" — es la naturaleza de este tipo de búsqueda, ver Incógnitas.

**Qt-for-Android, primera fuente (`doc.qt.io`, notas de la propia Qt 5.15, la versión que usa este proyecto):**
- Bug de caché de glifos de texto: algunos drivers OpenGL de Android hacen que el texto se vea "scrambled" (mezclado/corrupto) — Qt ya trae un workaround activado por default (`QT_ANDROID_DISABLE_GLYPH_CACHE_WORKAROUND` para desactivarlo si hiciera falta). **Relevancia real incierta:** Mine-imator dibuja su propio sistema de UI vía GML/OpenGL directo (`draw_textfield`, etc.), no necesariamente vía el renderer de texto nativo de Qt Widgets — si el texto de la UI se dibuja con el sistema propio del proyecto (probable, dado que toda la UI es custom), este bug de Qt puede no aplicar. No se verificó cuál de los dos casos es.
- Samsung XCover 3 (primera edición, SM-G388F): crash al resumir la app desde background, atribuido por el propio equipo de Qt a "un problema de threading en el software del dispositivo" (no en Qt). Ejemplo real de que "bug de vendor específico" no siempre es una extensión faltante — puede ser un problema de ciclo de vida/threading del propio driver, categoría relevante para B3 (§8, "pérdida de contexto GL en background").

## Hallazgos

1. **Los patrones de detección de features que este proyecto ya adoptó (0.3, 0.9) son los correctos para esta clase de problema** — detectar por función/extensión puntual, no por string de versión — porque hay evidencia real de que al menos un vendor (Adreno) miente en el string de versión. No hace falta cambiar nada, solo mantener la disciplina.
2. **Hay al menos un bug de precisión con repro público que podría afectar directamente el renderer diferido** (Adreno 540/650, `highp` dentro de struct) — vale la pena evitar empaquetar cálculos de precisión crítica (profundidad, normales empaquetadas) dentro de structs de shader al escribir el backend ES de 0.5/Fase 1, como precaución barata, no como fix reactivo a un bug ya encontrado en el propio código.
3. **B3 (pérdida de contexto GL en background) tiene al menos un precedente documentado de primera mano (Qt mismo, Samsung XCover 3)** — confirma que la categoría de bloqueo no es hipotética, aunque ese caso puntual sea de un dispositivo ya viejo e irrelevante para minSdk=29.
4. **Esta clase de investigación tiene un techo de utilidad bajo sin hardware real.** A diferencia de 0.6/0.7/0.9 (donde se pudo verificar con código/datos reales del propio repo sin necesitar un dispositivo), acá la fuente de verdad son reportes de terceros sobre hardware que no está en esta máquina — el nivel de confianza es más bajo, y el ruido (como el caso "AMD Adrenalin" vs. "Qualcomm Adreno") es real y hay que filtrarlo a mano.

## Contradicciones con CLAUDE.md

Ninguna — esta investigación no encontró nada que contradiga un hallazgo ya registrado. Complementa a B14 (`for` dinámicos en drivers viejos) y B3 (pérdida de contexto) con evidencia externa de primera mano, sin cambiar su severidad.

## Incógnitas

- No se verificó si algún shader real de `GmProject/shaders/` indexa un array de `mat4` con una variable no-constante (relevante al bug de Adreno 650) — requeriría un grep dirigido sobre los 53 shaders, no se hizo en esta pasada.
- No se determinó si el texto de la UI de Mine-imator pasa por el renderer de glifos nativo de Qt (afectado por el bug documentado) o por un sistema propio vía GML/OpenGL — cambia si el workaround de Qt aplica o es irrelevante.
- No hay forma de acotar cuántos bugs de este tipo existen todavía sin descubrir en los 3 dispositivos de referencia reales que faltan elegir (§14.2, `[GATE]` todavía abierto) — este informe es un piso, no un techo.
- No se investigó específicamente PowerVR ni Xclipse en esta pasada (tiempo/señal de búsqueda insuficiente) — dado que 0.9 ya estableció que PowerVR es legado decreciente y Xclipse es <2% del mercado, se priorizó Mali/Adreno, que cubren la gran mayoría.

## Decisión propuesta

No hay ninguna acción a tomar todavía — esto es información para tener en mente al escribir el backend ES de shaders (Fase 1/0.5) y al probar en dispositivos reales (Fase 2), no un blocker. Dos cosas concretas y baratas para llevar a Fase 1: (1) al escribir el backend ES de `processCode`, evitar empaquetar valores de precisión crítica dentro de structs de shader, dado el bug documentado de Adreno 540/650; (2) mantener la disciplina ya establecida de detectar soporte por función/extensión puntual, nunca por parseo de string de versión de GLSL. El resto queda como una lista de "cosas a vigilar" para cuando haya dispositivos reales en la mano — que es, en definitiva, la única forma real de cerrar este tema.
