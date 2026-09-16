# Patches sobre código upstream

Registro exigido por `CLAUDE.md` §15.3: todo cambio sobre código original de Mine-imator (no exclusivo de la adaptación a Android), con el motivo, para poder rebasear si aparece un fork vivo.

## `camera_control_rotate.gml` / `camera_control_move.gml` — guard Android sobre `display_mouse_set()` (2026-09-09, Fase 2, instrumental)

**Estado: aplicado, es un parche instrumental — NO es la solución de input táctil de Fase 4.** Ver `KNOWN_ISSUES.md` B10 para el diagnóstico completo y por qué esto no cierra esa entrada.

Ambas funciones son upstream (mouse-look de escritorio, sin relación previa con Android). El patrón `display_mouse_get_x/y()` + `display_mouse_set(lockx, locky)` cada frame (recentrar el cursor del SO para permitir arrastre infinito) no tiene equivalente en touch — Android reporta la posición real del dedo sin importar qué fuerce el código, produciendo saltos erráticos confirmados en dispositivo real. Se agregó una rama `platform_get() == e_platform.ANDROID` que usa `mouse_dx`/`mouse_dy` (delta crudo entre frames, ya calculado en `app_update_mouse.gml`) en vez de la diferencia contra el punto recentrado, sin llamar a `display_mouse_set()`. Cero cambio de comportamiento fuera de Android (la rama existente para el resto de plataformas queda intacta).

Acompaña esto: `enums.gml` (`e_platform.ANDROID` reagregado) y `UtilFunc.cpp` `platform_get()` (rama `Q_OS_ANDROID` reagregada) — ambos habían sido revertidos en una ronda anterior de la misma sesión (2026-09-09) y se reintrodujeron solo para poder hacer este chequeo de plataforma.

## `AppHandler.cpp:343` — `GFX->surface->BeginUse(win->size())` → `BeginUse(win->size() / scale)` (2026-09-09)

**Estado: revertido a pedido del usuario junto con el resto de los cambios de ese día (ver `KNOWN_ISSUES.md` KI-1) — el código descrito abajo NO está aplicado en este momento.** Se deja el registro igual porque el diagnóstico y la decisión de arquitectura (gate G1) siguen vigentes para cuando se retome.

**No es un fix del port a Android — es un fix upstream.** El bug es preexistente en Mine-imator 2.0.x, en la feature de escritorio "Interface Scale" (Configuración > Interfaz, 100%/200%/300%, `action_setting_interface_scale`), y nunca se había manifestado porque casi ningún usuario de escritorio cambia ese setting de su valor por defecto (100%, `scale=1`, en cuyo caso el bug es matemáticamente un no-op).

**El bug:** la superficie interna de render se armaba al tamaño REAL de la ventana (`win->size()`), pero `window_get_width()/height()` (lo que usa el GML para todo el layout) devuelven `win->size() / App->scale`. Cuando `App->scale != 1`, la superficie queda más grande de lo que el GML piensa que es, y todo lo dibujado con coordenadas GML termina ocupando solo una fracción de la superficie real — antes de que esa superficie se vuelva a escalar por `App->scale` una segunda vez al componerla en pantalla (`GLWidget.cpp`, `draw_surface_ext(..., App->scale, App->scale, ...)`).

**Verificado como bug de escritorio, no de Android** (gate G1, ver `research/` y `KNOWN_ISSUES.md` KI-1): reproducido en el build de Windows (`build-release/Mine-imator.exe`) forzando `"scale": 2, "scale_auto": false` en `settings.midata` — mismo desajuste exacto, mismos números, cero código específico de Android involucrado. Capturas: la ventana de carga se resuelve a `1480×900` reales (740×450 × scale=2, porque `AppWindow::UpdateSize()` en escritorio sí multiplica por `scale`) pero `window_get_width/height()` seguía devolviendo `740×450` — un desajuste de exactamente 2x, el mismo patrón medido en el dispositivo Android real (Xiaomi/Redmi/POCO, 220333QL, densidad 2.0).

**El fix:** `GFX->surface->BeginUse(win->size() / scale)` — la superficie se arma al tamaño LÓGICO (el mismo que ya usa `window_get_width()/height()`), no al tamaño físico real. Verificado no-op en escritorio con `scale=1` (740×450 sin cambios) y verificado que corrige el desajuste con `scale=2` (surface ahora 740×450, coincide con `window_get_width/height`) — en ambas plataformas.

**Por qué se decidió acá y no en Android-specific code:** gate G1 (`CLAUDE.md`, decisión 2026-09-09) evaluó 3 opciones para el modelo de escalado completo (necesario para Fase 3 táctil) y confirmó que `App->scale` es el mecanismo de densidad ya existente y compartido por escritorio y Android — corregirlo en el punto compartido, no con un `#ifdef Q_OS_ANDROID`, es correcto porque el bug en sí no es específico de una plataforma.

## `CppProject/Asset/Shaders/{world_checker.fsh, world_preview.vsh, world_box.vsh}` — mezcla `int`/`float` inválida en GLSL ES (2026-09-09, Fase 2)

**Estado: aplicado y verificado en dispositivo real.** Fix upstream — desktop GLSL (`#version 150`) convierte `int`↔`float` implícitamente en `+`, `/`, `>=`; GLSL ES 3.00 no. Mismo patrón que el bug de inicializadores globales no-const ya documentado en `research/2026-09-08-fase1-first-device-run.md` (hallazgo 6) — código de estos 3 shaders (exclusivos de C++, sin contraparte en `GmProject`, usados por el importador/constructor de mundos) nunca antes se había compilado contra un compilador ES real, porque no forman parte de la lista de 49 shaders que `shader_startup.gml` compila al arrancar — se cargan on-demand.

Cambios: `world_checker.fsh` (`12` → `12.0`), `world_preview.vsh` (`CHUNK_HEIGHT_MIN` a `-64.0`; `/ PREVIEW_TEXTURE_SIZE` → `/ float(PREVIEW_TEXTURE_SIZE)`, el define se queda como `int` porque también se usa en un `%`), `world_box.vsh` (`>= 1` → `>= 1.0`, ×3). Detalle completo con los errores exactos del compilador: `KNOWN_ISSUES.md` KI-3.

## `CppProject/Asset/ShaderLoadOpenGL.cpp` — sin calificador de precisión GLSL ES en ningún shader (2026-09-09, Fase 2)

**Estado: fix aplicado, compilación verificada en ambas plataformas — NO verificado en dispositivo real todavía** (el celular perdió la conexión ADB inalámbrica durante esta investigación).

**El hallazgo:** GLSL ES 3.00 (spec §4.5.3) no tiene precisión default para `float`/`int` en shaders de FRAGMENTO — es obligatorio un `precision` explícito o el compilador debe rechazar el shader. Ninguno de los 53 shaders del proyecto (ni los de `GmProject`, dialecto GameMaker, ni los 6 de `CppProject/Asset/Shaders/`) tiene jamás un calificador de precisión — el dialecto GLSL de escritorio en el que están escritos no tiene ese concepto. Que compilen en el único dispositivo probado (Adreno 610) solo prueba que ESE driver es permisivo, no que todos lo sean — confirmado leyendo el código fuente real de Qt (`qopenglshaderprogram.cpp:469-481,636-652`): el mecanismo de portabilidad de Qt (`#define highp/mediump/lowp` vacíos) solo aplica a OpenGL de escritorio, nunca inyecta un `precision` default para ES.

**El fix:** `defines += "precision highp float;\nprecision highp int;\n";` agregado al bloque `#ifdef Q_OS_ANDROID` que ya arma los defines por plataforma — `highp` iguala el comportamiento implícito de GLSL de escritorio (float de precisión completa siempre), sin costo si el driver ya asumía eso (caso Adreno) y es lo único que evita un rechazo total de compilación en un driver más estricto (Mali/PowerVR más viejos, candidatos a los otros 2 dispositivos de referencia de `CLAUDE.md` §14.2). No toca `sampler2D` — ES 3.00 sí define un default (`lowp`) para tipos sampler en fragmento, ese caso no tenía el problema.

**Verificado en dispositivo real (2026-09-09, tras reconectar):** instalado en el Adreno 610 real — los 47 shaders de `shader_startup.gml` más los 3 on-demand (`world_checker`/`world_preview`/`world_box`) compilan limpio, cero errores nuevos en el log. Confirma la predicción: el driver ya asumía `highp` de hecho, así que hacerlo explícito no cambió nada observable — el fix es puramente preventivo para un driver más estricto (Mali/PowerVR), sin costo en el dispositivo actual.
