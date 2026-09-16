# Investigación + implementación: gizmos táctiles y timeline táctil (Fase 4)

## Pregunta

Continuación de `research/2026-09-15-fase4-timeline-gizmos-inventory.md` (mismo día, sesión previa a esta). Con el inventario ya hecho, implementar las dos piezas identificadas:

1. Arreglar el picking de los gizmos de manipulación 3D (mover/rotar/escalar/target de cámara/bend) para que un tap los agarre de forma confiable.
2. Agregar los dos gestos del timeline sin equivalente táctil: zoom (`Ctrl+rueda`) y pan de vista (arrastre con botón central).

Contexto operativo: pedido explícito del usuario ("estoy sin celular ahora, haz fase cuatro completa"). Sin dispositivo Android disponible durante esta sesión — todo lo de acá está **verificado por compilación** (CppGen limpio, build nativo y APK sin errores), **no verificado en dispositivo real**. Ver "Incógnitas" al final.

## Método

1. Releído el inventario del mismo día completo antes de tocar nada.
2. Leído línea por línea (no solo grep) los 7 archivos de picking compartido identificados por el inventario: `view_control_move_axis.gml`, `view_control_move_plane.gml`, `view_control_move_pan.gml`, `view_control_scale_axis.gml`, `view_control_scale_plane.gml`, `view_control_scale_all.gml`, `view_control_rotate_axis.gml` — para confirmar el ORDEN exacto de operaciones dentro de cada función (el inventario había dejado esto como incógnita).
3. Leído también `view_shape_path.gml` completo para confirmar/corregir la afirmación del inventario de que comparte el mismo patrón riesgoso.
4. Aplicado el fix en los 7 archivos (detalle abajo).
5. Leído `view_update.gml:225-289` (implementación ya existente del pellizco/pan de cámara) para replicar el mismo patrón y las mismas funciones (`touch_count()`, `touch_pinch_delta()`, `touch_pan_dx()`, `touch_pan_dy()`).
6. Verificado que `touch_pan_dx()`/`touch_pan_dy()` tienen una implementación C++ real y conectada (`CppProject/Gml/InputFunc.cpp:79-87`), no un stub muerto — el inventario había notado que no se usaban en ningún lado de GML todavía, lo cual generaba la duda de si de verdad estaban implementadas del lado Android.
7. Leído `tab_timeline.gml:1667-1711` para agregar los dos gestos.
8. Confirmado el orden de ejecución de `tab_timeline.gml` (declaración de `mousekf` en la línea 8, cálculo real en ~574, uso en el despacho de clicks en ~1322+) para descartar que el arrastre de keyframes tenga el mismo problema que los gizmos.
9. Compilado: `cmake --build . --target CppGen` → `cmake --build .` (nativo) → `cmake --build . --target apk`, los tres sin errores. Verificado además con `grep` sobre `CppProject/Generated/` que el código Android-específico nuevo aparece tal cual en la salida generada (no es solo que CppGen no tiró error - se confirmó que el contenido real está ahí).

## Evidencia

### Corrección al inventario: `view_shape_path.gml` NO comparte el patrón riesgoso

El inventario del mismo día (sesión previa) afirmaba: *"Mismo patrón exacto en... y en `view_shape_path.gml:89` (nodos de path)"*. Releído el archivo completo: la línea 89 usa `app_mouse_box(...) && content_mouseon && view.control_mouseon_last = null` — el chequeo de posición (`app_mouse_box`) es del **frame actual** (lee `mouse_x`/`mouse_y` en vivo), y `control_mouseon_last = null` solo se usa para no robarle el click a un gizmo que sí esté en hover, no para esperar el hover del frame anterior de ESTE nodo. Es decir, arrastrar un nodo de path **ya es seguro para touch tal como está** — no se tocó este archivo. Corregido acá porque el inventario original tenía este punto mal, y CLAUDE.md §2.1 obliga a verificar contra el código, no contra un resumen previo (ni propio).

### Orden exacto confirmado en los 7 archivos de gizmo

En los 7 archivos, la estructura es idéntica: las coordenadas 2D del elemento (línea/triángulo/círculo) se calculan primero (para poder dibujar), **antes** del bloque `else if (view.control_mouseon_last = control) { if (mouse_left_pressed) {...} }` que decide si un click agarra el control. La comprobación de hover *fresca* (la que alimentará `control_mouseon_last` del próximo frame) recién se hace *después*, cerca del final de la función, junto al dibujo. Esto confirma la lectura del inventario: el click que agarra un handle depende del hover calculado un frame antes — pero como las coordenadas 2D ya están disponibles *antes* del bloque de click (fueron calculadas para el dibujo), se puede agregar un chequeo redundante ahí mismo sin reestructurar nada.

Citas exactas (línea del bloque de click / líneas donde ya están disponibles las coordenadas 2D que reutiliza el fix):

- `view_control_move_axis.gml:57` (click) / `:21-29` (`start2D`/`end2D` ya calculados)
- `view_control_move_plane.gml:90` / `:29-52` (`corner12D..corner42D`)
- `view_control_move_pan.gml:32` / `:8-11` (`pos2D`/`radius2D`)
- `view_control_scale_axis.gml:64` / `:32-36` (`start2D`/`end2D`)
- `view_control_scale_plane.gml:90` / `:29-52` (`corner12D`/`22D`/`42D`)
- `view_control_scale_all.gml:27` / `:9-16` (`coord`/`radius2D`)
- `view_control_rotate_axis.gml:55` / caso distinto, ver abajo

### Caso especial: `view_control_rotate_axis.gml`

A diferencia de los otros 6, el anillo de rotación se dibuja como 64 segmentos de línea calculados **dentro de un loop** que corre **después** del bloque de click (líneas 111-154, loop; línea 55, click) — no hay una forma barata de reusar coordenadas ya calculadas, porque no existen todavía en ese punto de la función. Se optó por una **aproximación**: antes del bloque de click se agrega un único punto extra proyectado (`point3D_mul_matrix(point3D(len, 0, 0), mat)`, la misma fórmula que el loop real usa en su primera iteración) para estimar el radio 2D del anillo, y el fallback de Android chequea distancia-al-anillo (`abs(distancia_al_centro - radio_estimado) < ancho/2`) en vez de la comprobación segmento-por-segmento exacta que hace el loop real.

**Esto es una aproximación, no un duplicado exacto** — documentado así en el propio comentario del código. No replica la distorsión de perspectiva por ángulo de cada segmento individual, ni la oclusión "detrás de la esfera" que el loop real aplica vía `control_test_point` (línea 130-141). En el peor caso, un tap agarra la rotación con un offset menor al visual esperado, o a través de la mitad oculta del anillo — no bloquea nada ni causa un crash, pero no es pixel-perfect. Alternativa descartada: duplicar el loop completo de 64 segmentos antes del click, mucho más código por un beneficio marginal (el caso borde de la oclusión es poco frecuente).

### `touch_pan_dx()`/`touch_pan_dy()` — confirmadas implementadas, no stubs muertos

`GmProject/scripts/util_cpp/util_cpp.gml:74-87` — los cuerpos GML son el fallback de escritorio (`return 0`), marcados `/// CppSeparate` (cuerpo real en C++, patrón ya documentado en `CLAUDE.md` §4.2). `CppProject/Gml/InputFunc.cpp:79-87` confirma la implementación real: `AppWin->touchPanDx / App->scale` — alimentada por `AppWindow::event()` desde `QTouchEvent` real (mismo mecanismo que `touch_pinch_delta()`, ya usado y confirmado funcionando en el pellizco de cámara, aunque ese camino específico de pan por deltas nunca se había usado en ningún GML hasta este cambio — la cámara usa `mouse_dx`/`mouse_dy` sintetizados en su lugar, ver abajo).

### Por qué la cámara y el timeline usan mecanismos de pan distintos

El pan de dos dedos de la cámara (`view_update.gml:261-289`) detecta 2 dedos para **cambiar de modo** (de "rotar" a "panear"), pero el movimiento en sí sigue leyendo `mouse_dx`/`mouse_dy` sintetizados por Qt, porque ya existe un estado (`window_busy = "viewpancamera"`) al que se entra desde un click inicial de un dedo. El timeline no tiene ese click inicial — el pan de dos dedos tiene que funcionar apenas el segundo dedo toca, sin pasar primero por un estado de "un dedo". Por eso el timeline usa `touch_pan_dx()`/`touch_pan_dy()` directamente (deltas dedicados de los 2 dedos) en vez de la posición sintetizada de un solo mouse virtual.

### Arrastre de keyframes — confirmado ya seguro para touch, sin cambios

`tab_timeline.gml:8` declara `mousekf` como local de la función; el cálculo real (`tab_timeline.gml:574,583-584`, per el inventario del mismo día) corre bien antes del despacho de clicks que lo usa (~`tab_timeline.gml:1322-1377`), dentro del mismo paso top-a-abajo de la función en el mismo frame. A diferencia de los gizmos (que dependen de un valor escrito en el frame ANTERIOR), acá el valor se calcula y se consume en el mismo frame — mismo patrón seguro que `view_shape_path.gml`. No se tocó nada de esto.

## Hallazgos

**Gizmos (7 archivos, ver arriba):** agregado un chequeo adicional, solo para Android (`platform_get() == e_platform.ANDROID`), que reutiliza las coordenadas 2D ya calculadas para el dibujo de ese mismo frame, en vez de depender de `control_mouseon_last` (frame anterior). Aditivo puro — el camino de escritorio (`control_mouseon_last`) queda exactamente igual, el nuevo chequeo solo se evalúa como una condición `||` extra. `view_control_camera.gml` y `view_control_bend.gml` no se tocaron porque, según el inventario, llaman directamente a `view_control_move_axis`/`view_control_rotate_axis` — el fix ahí los cubre heredado.

**Timeline:** agregados 2 bloques nuevos en `tab_timeline.gml`, ambos gateados `platform_get() == e_platform.ANDROID`:
- Zoom: reutiliza `touch_pinch_delta()` (ya usado por la cámara) alimentando la misma fórmula `timeline_zoom_goal` que ya usaba el `Ctrl+rueda`, de forma continua en vez de por tick.
- Pan: nuevo, primer uso real de `touch_pan_dx()`/`touch_pan_dy()` en todo el proyecto, aplicando la misma actualización de `hor_scroll`/`ver_scroll` que ya hacía el pan por botón central.

## Contradicciones con CLAUDE.md

1. El inventario del mismo día (`research/2026-09-15-fase4-timeline-gizmos-inventory.md`) afirmaba que `view_shape_path.gml:89` comparte el patrón riesgoso de los gizmos — **es falso**, corregido arriba. El propio inventario ya había marcado esto como parte de una lista de greps dirigidos, no como una lectura completa línea por línea del archivo — la lectura completa (este documento) lo corrige.
2. `CLAUDE.md` §12, fila de Fase 4, sigue sin actualizar con este trabajo (el inventario ya había notado esto como pendiente). Corregido en esta misma sesión, ver `CLAUDE.md` directamente.

## Incógnitas

**La más importante, ya señalada por el inventario y todavía sin resolver por falta de dispositivo:** no se confirmó en un teléfono real si el fallback de Android en los gizmos efectivamente soluciona el problema — depende de que `mouse_x`/`mouse_y` (crudos) ya reflejen la posición del tap en el mismo frame que `mouse_left_pressed` se vuelve verdadero, lo cual es una asunción razonable (el evento de press trae su propia posición) pero no una que se haya visto confirmada contra la síntesis real de Qt en este proyecto. **Es la primera cosa a probar cuando el usuario tenga el teléfono de nuevo**: tocar y arrastrar cada uno de los 5 tipos de gizmo (mover, rotar, escalar, pan de cámara vía target, bend) y confirmar que el primer tap agarra el control esperado, no uno vecino ni ninguno.

Otras, heredadas del inventario y todavía abiertas:
- Sensibilidad de `touch_pinch_delta()`/`touch_pan_dx/dy()` sin calibrar contra un dispositivo real (mismo estado que el pellizco de cámara, nunca afinado tampoco).
- La aproximación del anillo de rotación (ver arriba) - cuánto se nota el error en la práctica, sin dato real.
- Si el pan de 2 dedos del timeline y el swipe-to-scroll de `scrollbar_draw.gml` (Fase 3) interfieren entre sí cuando ambos gestos podrían aplicar a la vez (2 dedos sobre la franja de scroll específicamente) - no se investigó la posible superposición de zonas de hit-test.

## Decisión propuesta

No aplica gate — es implementación dentro del alcance ya aprobado explícitamente por el usuario ("haz fase cuatro completa"), sobre una arquitectura de input ya establecida (mismo patrón aditivo `platform_get() == e_platform.ANDROID` usado en cámara/teclado/tema, sin tocar el camino de escritorio en ningún archivo). Verificado por compilación (CppGen, build nativo, APK, los tres limpios) — pendiente de verificación en dispositivo real apenas el usuario lo tenga de vuelta, per CLAUDE.md §2.3 ("no marcar una tarea como hecha sin evidencia... build log, screenshot, medición o test que pasa" - acá hay build log, falta el test real).
