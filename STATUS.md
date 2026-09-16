# STATUS

## Sesión 2026-09-06

**Commit clonado:** `01a62c0e7d6d78063362aa9914111f4e637030c6` (2026-08-29 11:26:30 +0200)
**Repo:** https://github.com/stuffbydavid/Mine-imator.git (clon completo, historial íntegro, sin `--depth`)
**Ubicación local:** `C:\Users\mateo\OneDrive\Desktop\Claude\Mine-imator`
**DEV_DIR para build/Qt (por B16):** `C:\Dev` (todavía no usado — no se corrió build en esta sesión)

### Hecho
- Clonado el repositorio completo.
- Verificadas contra HEAD las 3 citas `archivo:línea` que ancla CLAUDE.md:
  - `CppProject/Render/GraphicsApiHandler.hpp:11` → exacta. `:41` → el contenido es correcto pero cae en línea 40 en este HEAD (desfase de 1 línea, sin relevancia).
  - `CppProject/Asset/ShaderLoadOpenGL.cpp:13-15` y `:23` → exactas.
  - `GmProject/scripts/app_update_interface/app_update_interface.gml:11-21` → exacta.
- Recontadas las métricas de §3.1: **exactas** (2.067 archivos `.gml` / 98.840 líneas, 94 shaders `.fsh`+`.vsh` / 5.733 líneas, 58 objetos, 51 sprites).
- Corregido §3 y añadida fila a §17 de `CLAUDE.md`: el commit de referencia no era nov 2023 sino 2026-08-29. Solo hubo 17 commits desde nov 2023 (migración de CppGen a C++, actualización de Qt/ffmpeg/libzip/OpenAL/OpenSSL, fixes Mac/Linux, normalización de line endings) — por eso el contenido medido no cambió pese al salto de fecha.
- Copiado `CLAUDE.md` a la raíz del repo (antes solo existía en Downloads). Esta copia es ahora la operativa.

- Verificado el hallazgo de `CppProject/Asset/Shaders/`: 12 archivos sueltos = 6 shaders exclusivos de C++ (`primitive`, `world_box`, `world_box_resize`, `world_checker`, `world_player`, `world_preview`), 106 en `Compiled/` = bytecode D3D precompilado (53 shaders × 2 etapas). Inventario real: **53 shaders, no 94**. Corregido §3.1/§5.3 y nuevo bloqueo **B17** en §8 (backend OpenGL sin caché de bytecode, a diferencia del D3D11 que sí tiene — riesgo para el objetivo de <5s de arranque en §14.3).
- **Tarea 0.2 (auditoría CppGen) — cerrada.** Informe en `research/2026-09-06-cppgen.md`. Corrí `CppGen/Win64/CppGen.exe` (binario prebuildeado) sobre el corpus real: 98.639 líneas GML → 105.545 líneas C++ (84 archivos), ~29s, exit 0, **cero warnings**. Solo resuelve 58% de los tipos de variable (dato nuevo). CppGen tiene 4 comportamientos distintos ante código no soportado (no 2). Un ejemplo del informe original del subagente (evento `Alarm_0` de `app`) resultó ser un archivo huérfano no habilitado en `app.yy`, no un bug real de CppGen — lo corregí antes de dejarlo en CLAUDE.md. Detalle en §4.3.
- **Tarea 0.8 (inventario 13 primitivas UI) — cerrada.** Informe en `research/2026-09-06-ui-inventory.md`. Hallazgo verificado y central: ninguna de las 13 `tab_control_*` maneja input — es pura geometría; la interacción real vive en `draw_*`/`sortlist_*`/`menu_*`. Corregido §6.1. También: hay hitboxes hardcodeados que no escalan con `ui_large_height`/`ui_small_height` (switch=16px, meter=20px, resize de columna en sortlist=10px, `label_height=9` en `macros.gml:152`) — corregido §6.2.

### Abierto / a investigar
- Ningún gate abierto salvo 0.1, bloqueada por entorno (ver abajo).
- Bloqueos legales de §9 (LICENSE ausente, x264 GPL) siguen sin resolución escrita de David Andrei — `[GATE]`, no se avanzó en esto.
- Semántica exacta de `/// CppSeparate` / `/// CppOnly` (71 archivos GML lo usan) — confirmada su existencia, no su comportamiento línea por línea. Investigar antes de depender de ese mecanismo para el port.
- No se encontró todavía un caso real que dispare el path de "evento no soportado → WARNING silencioso" en CppGen (`Object.cpp:51-59`) — el candidato original resultó falso positivo.

### Estado de 0.1 (build de referencia)
- **Bloqueada por entorno**, no por el código. Falta: Visual Studio 2022/2026 con workload "Desktop development with C++" + componente "C++ CMake tools for Windows" (`WinUtils.ps1:38-41` rechaza cualquier VS que no sea versión 17/18 — solo había VS2019 instalado) y Strawberry Perl.
- Usuario está instalando VS2026 Insiders con el workload correcto (instalación manual, en curso al cierre de esta sesión).
- Instalé Strawberry Perl vía `winget` a pedido del usuario (background, resultado no confirmado aún al cierre de esta nota).
- `DEV_DIR` todavía no seteada — el usuario la va a setear a `C:\Dev` cuando avise que el toolchain está listo.

### Próximo paso
- Cuando el usuario confirme VS2022/2026 + Perl instalados: setear `DEV_DIR=C:\Dev` y correr `.\Setup.ps1` (arranca con Qt) siguiendo `BUILD.md`, registrando cada falla y su fix en `BUILD_NOTES.md`. Después, tareas 0.3 y 0.6 (bloqueadas hasta tener el build de referencia).

## Corte de sesión 2026-09-06 (PC se apaga) — y reintento

- VS2022 Community instalado y verificado (workload C++ + CMake tools). Strawberry Perl 5.42.2 instalado. `DEV_DIR=C:\Dev` seteado.
- 0.1 arrancó: `Setup.ps1` corrió OpenSSL/FFmpeg/x264/OpenAL/Libzip completos (ya copiados a `CppProject/External/Win64`), clonó y configuró Qt 5.15.19, y llegó a compilar Qt5Core/Qt5DBus/Qt5Network/Qt5Sql sin errores antes de cortarse (apagado de PC a mitad de camino, justo entrando a QtGui).
- Confirmado con el log completo (`grep -i error`, cero matches reales): el corte fue por el apagado, no un problema de build. Ver `BUILD_NOTES.md` F3/F4.
- **Reintento en curso:** borré `C:\Dev\Qt\5.15.19` (para evitar el prompt interactivo de `Build-Qt` que cuelga sesiones no interactivas) y relancé `Setup.ps1`. OpenSSL/FFmpeg/OpenAL/Libzip no se recompilan (ya extraídos/copiados); Qt se reconstruye desde cero — no hay resume incremental en el script.
- Pendiente igual que antes: 0.3, 0.4, 0.5, 0.6, 0.7, 0.9, 0.10 sin arrancar. 0.10 (gate legal) sigue siendo el más importante y no depende de nada técnico — se puede avanzar en paralelo en cualquier momento (es solo conseguir respuesta escrita de David Andrei).

## 0.1 CERRADA (2026-09-06)

Build de referencia completo: Qt 5.15.19 + las 5 libs externas + `Mine-imator.exe` compilaron sin errores. Verificado corriendo de verdad (captura de pantalla real, no solo build log): abre, muestra UI, renderiza un modelo 3D con rig. Detalle en `BUILD_NOTES.md`.

**Reevaluación del gate legal (§9.3):** se investigó a fondo a raíz de una afirmación externa del usuario ("es MIT, claramente"). Se confirmó por git history: hubo un `LICENSE` MIT (2018-2023, autor David Norgren) borrado en el commit "2.0.0" (2023). Pero se encontró algo más importante: un segundo archivo (`Installer/Windows/license.txt`, distinto al EULA de GameMaker) donde el propio David Andrei siguió afirmando por escrito "el código fuente está en GitHub bajo licencia MIT" hasta hace 2-3 semanas (borrado en `8732ee7e`, limpieza general de instaladores, no una decisión de licencia). Esto baja mucho el riesgo percibido — sigue siendo `[GATE]` pedir confirmación, pero ahora es más un trámite de cierre que una negociación incierta. Detalle completo en `CLAUDE.md` §9.3/§17.

## Toolchain de Android — instalado (2026-09-06)

- JDK 17 (Eclipse Temurin) ya estaba presente, `JAVA_HOME` seteado.
- SDK cmdline-tools descargado de `dl.google.com` (checksum SHA-256 verificado) en `C:\Android\cmdline-tools\latest\`.
- **Nota:** `sdkmanager` está deprecado en esta versión del SDK — la herramienta vigente es `android` (`C:\Android\cmdline-tools\latest\bin\android.exe`, subcomando `sdk install`).
- Instalado y verificado con evidencia directa (no solo el log del instalador):
  - `platform-tools` (`adb.exe` presente)
  - `platforms;android-34` (`android.jar` presente)
  - `build-tools;34.0.0` (`aapt.exe` presente)
  - `ndk;27.3.13750724` (`ndk-build.cmd` presente, ~2.2 GB)
- Variables de entorno seteadas (usuario, sin `/M`): `ANDROID_HOME=C:\Android`, `ANDROID_SDK_ROOT=C:\Android`, `ANDROID_NDK_HOME=C:\Android\ndk\27.3.13750724`.
- **Importante:** esto es el toolchain de compilación (SDK+NDK). Todavía NO existe una configuración de CMake/Gradle en el repo que apunte a Android — `CppProject/CMakeLists.txt` hoy solo compila para Windows (busca Qt de escritorio, ver `QT_BASE_DIR` hardcodeado). Eso es justo lo que ataca la tarea 0.3, sin arrancar.

### Próximo paso
- Redactar y que el usuario envíe el mensaje a David Andrei sobre la licencia (borrador pendiente).
- Arrancar 0.3 (resolver B1, el bloqueo crítico de `QOpenGLFunctions_3_1`/`_4_3_Core`) usando el build de referencia (0.1, ya cerrada) para comparar comportamiento antes/después.

## Qt para Android — configure logrado, build real pendiente (2026-09-06)

Tras resolver 4 fallas de toolchain encontradas una tras otra (bootstrap de qmake apuntando a una ruta MinGW de otra máquina embebida en el GCC que trae Strawberry Perl, falta de `mingw32-make.exe` en MSYS2, mezcla de rutas POSIX/Windows por el Perl propio de MSYS2 tomando precedencia, e incompatibilidad de `nmake` con el Makefile de `android-clang`), **`configure.bat` corre limpio para Qt 5.15.19 target `android-clang arm64-v8a`, exit code 0.** Detalle completo con cada causa raíz en `BUILD_NOTES.md`.

**Hallazgo importante para B1/0.3:** el resumen del configure reporta OpenGL ES 2.0 sí, pero **ES 3.0/3.1/3.2 no**. Causa confirmada en `config.log`: se usó el API level 21 de Android por default (no especifiqué `-android-ndk-platform`), y el stub `libGLESv2.so` de ese nivel de API en el NDK no exporta símbolos de ES 3.0 (`glGetStringi`, `glReadBuffer`, etc.) — no es una limitación real del NDK/dispositivo, es el nivel de API pedido. Fix: reconfigurar con `-android-ndk-platform android-24` (o el mínimo que corresponda).

**Todavía no se corrió el build real** (`mingw32-make` + `mingw32-make install`) — sería la parte larga (similar en escala al build de Qt de escritorio de 0.1, probablemente más lento porque GNU make sin `-j` corre en serie, a diferencia de `jom` que paraleliza solo).

## CERRADO — Qt 5.15.19 para Android instalado y funcionando (2026-09-06)

Con el usuario AFK, se completaron los 3 pedidos pendientes y el build real:
1. **ES 3.0 confirmado** — el fix de nivel de API no alcanzaba; la causa real era que Qt linkeaba solo contra `-lGLESv2` y este NDK (r27) separa los símbolos de ES3 en `libGLESv3.so`. Parchado `mkspecs/features/android/default_pre.prf`, reconfirmado con `OpenGL ES 3.0/3.1/3.2: yes`.
2. **Build con paralelismo** — `mingw32-make -j16` (16 núcleos).
3. **Gate G1 (minSdkVersion)** — recomendación entregada (API 29), esperando confirmación del usuario. No bloqueó nada de lo de abajo.

**Build + install completos** (con `-k` para no frenar por F10, un bug de GCC 16.2/MSYS2 en `androiddeployqt`/`androidtestrunner` que no bloquea nada de lo que necesitamos ahora). Instalado en `C:\Dev\Qt\5.15.19\install-android\`: Core, Gui, Widgets, OpenGL, Network, Sql, Xml, Concurrent, Test, PrintSupport + plugin de plataforma Android + otros plugins. Cero errores reales fuera de F10 (verificado explícitamente).

**Esto deja 0.3 lista para arrancar de verdad**: ya hay un Qt-para-Android completo contra el cual compilar el prototipo de `GraphicsApiHandler`/`Shader` migrado a `QOpenGLExtraFunctions`. Detalle completo, con cada causa raíz, en `BUILD_NOTES.md`.

### Próximo paso
- Confirmar minSdkVersion (gate abierto).
- Mandar el mensaje a David Andrei sobre la licencia (todavía no redactado).
- Arrancar 0.3: escribir el prototipo de `GraphicsApiHandler` sobre `QOpenGLExtraFunctions`, compilarlo contra `C:\Dev\Qt\5.15.19\install-android`.

## CERRADO — minSdkVersion, mensaje a David, y 0.3 (2026-09-06, mismo día, sesión larga)

- **Gate G1 (minSdkVersion) confirmado en 29**, con el argumento corregido (scoped storage existe como mecanismo de SO desde API 29; como `targetSdk` va a ser 36 sin importar el `minSdk`, fijar el piso en 29 evita mantener rutas de I/O legacy + SAF en paralelo para B4). Registrado en `CLAUDE.md` §7.1.1.
- **Borrador del mensaje a David Andrei** entregado en `LICENSE_INQUIRY_DRAFT.md` (en inglés), pendiente de que el usuario lo revise y mande.
- **Tarea 0.3 CERRADA.** Rama `fase0-0.3-graphicsapihandler-prototype`. B1 confirmado real con compilador (no solo lectura de código — encontrada y corregida una trampa metodológica: el `#include` de las clases desktop no tira error por sí solo, solo al usar el tipo). Migrado `GraphicsApiHandler.hpp` a `QOpenGLExtraFunctions`; probadas con el NDK real las 49 funciones GL que usa hoy el renderer: **48 compilan limpio, 1 (`glShaderStorageBlockBinding`, atada al batching SSBO opcional) no tiene equivalente en ningún ES.** Informe completo en `research/2026-09-06-b1-graphicsapihandler-prototype.md`. Abierto un nuevo `[GATE G1]` puntual sobre qué hacer con el batching en Android (opciones en el chat de la sesión) — no bloquea nada más, B1 en general tiene solución confirmada.

### Próximo paso
- Resolver el gate puntual del batching SSBO (opción A: no portarlo a Android, ya hay fallback; opción B: portarlo a ES 3.1 vía `layout(binding=N)` fijo).
- Aplicar el mismo tratamiento de 0.3 a `Shader.hpp` (todavía sin tocar, depende de esa decisión).
- Cuando el usuario mande el mensaje a David: esperar respuesta antes de invertir mucho más tiempo (§9.3, gate legal).
- Seguir con el resto de Fase 0: 0.4 (spike GameMaker→Android), 0.5 (backend ES + shader pesado en dispositivo real), 0.6 (medir B2, ya no bloqueada), 0.7 (memoria), 0.9 (framebuffer_fetch por vendor).

---

**Nota de mantenimiento:** este archivo quedó sin actualizar entre el 2026-09-06 y el 2026-09-15 pese a la regla de §15.8 de CLAUDE.md — en ese lapso se cerraron Fase 0 completa, Fase 1, Fase 2, Fase 3, y se avanzó fuerte en Fase 4, además de una pantalla de carga Android completa. El registro real de todo eso vive en `CLAUDE.md` §17 (mantenido al día en cada sesión) y en `KNOWN_ISSUES.md` — este archivo no se reconstruyó retroactivamente por no ser parte del pedido de la sesión que escribe esta nota. Para el estado real y completo del proyecto, `CLAUDE.md` §12 (tabla de fases) es la fuente de verdad, no este archivo.

## Sesión 2026-09-15 — Fase 4, gizmos y timeline táctiles (sin dispositivo disponible)

**Contexto:** usuario pidió "haz fase cuatro completa" estando sin acceso al teléfono durante toda la sesión. Todo lo de abajo está **verificado solo por compilación**, no en pantalla real.

### Hecho
- Inventario completo de las 2 piezas grandes que quedaban de Fase 4 (timeline táctil, gizmos de manipulación 3D) — `research/2026-09-15-fase4-timeline-gizmos-inventory.md`.
- Implementado y compilado (CppGen + build nativo + APK, los 3 limpios):
  - Fix de picking táctil en los 7 archivos de gizmo (`view_control_move_axis/move_plane/move_pan/scale_axis/scale_plane/scale_all/rotate_axis.gml`) — chequeo aditivo gateado a Android, sin tocar el camino de escritorio.
  - Pellizco-zoom y pan de 2 dedos en el timeline (`tab_timeline.gml`).
- Detalle completo, con cada cita `archivo:línea` y las 2 correcciones al inventario original (view_shape_path.gml NO comparte el patrón riesgoso; arrastre de keyframes ya era seguro): `research/2026-09-15-fase4-gizmos-timeline-implementation.md`.
- Actualizado `CLAUDE.md` §12 (fila de Fase 4) y §17 (nueva fila), y `KNOWN_ISSUES.md` (nueva entrada KI-4, más una nota de cierre en KI-2 que ya estaba superada desde el 2026-09-12 y nunca se había marcado).

### Abierto / a investigar
- **KI-4** (`KNOWN_ISSUES.md`): todo el trabajo de esta sesión sin un solo tap real probado. Prioridad #1 la próxima vez que haya dispositivo: gizmos (los 5 tipos), después pellizco/pan del timeline.
- La aproximación del anillo de `view_control_rotate_axis.gml` (distancia-al-anillo, no exacta) — sin dato real de cuánto se nota el error.
- Bug de corrupción de texto en botones PRIMARY (ver conversación de la sesión, `task_c2b62d14` — investigación disparada en paralelo, resultado no conocido desde este archivo).

### Próximo paso
- Apenas el usuario tenga el teléfono: probar los 5 gizmos + timeline táctil (KI-4).
- Seguir con el resto de "lenguaje de gestos completo" de Fase 4 si algo más aparece necesario tras probar esto en dispositivo real.

### Segunda pasada, mismo día — 3 deudas menores cerradas
A pedido explícito del usuario ("puedes resolver eso de momento?"), resueltas las 3 cosas que habían quedado como deuda conocida en la respuesta anterior de la sesión (todavía sin dispositivo, solo compilación verificada):
1. `view_control_rotate_axis.gml` — la aproximación de distancia-al-anillo se reemplazó por un pick exacto (duplica el loop real de 64 segmentos, solo para picking, corrido temprano).
2. `view_update.gml` — la cámara ahora detecta un segundo dedo llegando DESPUÉS de que la rotación ya arrancó (antes solo detectaba "ambos juntos").
3. Trampa 2 (§6.3) caracterizada con evidencia real: `mouse_x`/`mouse_y` no quedan indefinidos entre toques, quedan congelados en la última posición — gate genérico cerrado por caracterización, no por una política nueva.

Sigue sin haber ninguna prueba en dispositivo real de nada de Fase 4. Eso sigue siendo lo único que falta para decir "completa" con evidencia, no solo por compilación.

### Tercera pasada, mismo día — primeras pruebas reales en dispositivo (ADB por WiFi)

Usuario conectó el Redmi 10C de referencia por WiFi ADB (depuración inalámbrica, emparejado por código). MIUI sigue bloqueando `adb shell input` (`INJECT_EVENTS`), así que la verificación fue: instalar, el usuario interactúa a mano, se pide feedback/capturas.

**Confirmado funcionando en dispositivo real:** gizmos, pellizco-zoom y pan de 2 dedos del timeline, panel dividido "Cámara activa" (una vez arreglado, ver abajo) — el usuario reportó "funciona todo bien" salvo los 2 puntos siguientes, que ya se corrigieron:

1. **Barra de atajos inferior mostraba hints de escritorio** (rueda de mouse, Shift+arrastre) en vez de los gestos táctiles reales — corregido en `shortcut_bar_update.gml` con 4 textos nuevos por plataforma. Causa probable de la queja "el zoom va pegado": el usuario probaba el gesto equivocado guiado por el texto viejo.
2. **Joystick virtual ausente en el panel dividido "Cámara activa"** — estaba anclado a `view_main` únicamente, tanto el dibujo (`view_draw.gml`) como la detección de toque (`view_update.gml`). Convertido a variables por-vista (`view.joystick_screen_x/y/radius`) para que cualquier panel en modo "cámara de trabajo" tenga el suyo.
3. **Joystick no aparecía con una cámara real creada** — el gate estaba en `!cam` (solo cámara de trabajo); en escritorio, `camera_control_move.gml` también mueve una cámara real seleccionada y editable (WASD/arrastre der.). Extendido el joystick (movimiento y "look" de 2do dedo) para replicar esa segunda rama, usando `tl_value_set`/`e_value.POS_*`/`ROT_*` igual que el desktop.
4. **Barra de herramientas reubicada** (`view_toolbar_draw_touch.gml`, nuevo archivo) — a pedido explícito con imagen de referencia: de tira vertical 24px sin etiqueta a barra horizontal centrada arriba del viewport, botones 40px con etiqueta de texto, mismo comportamiento/settings que escritorio. La imagen de referencia mostraba también un toggle Global/Local — identificado como feature de **Mine-imator Community Build** (no del Mine-imator base), `[GATE G2]`, el usuario decidió postergarlo a `IDEAS.md` en vez de implementarlo.

**Pausado a pedido del usuario:** el segundo celular con la interfaz "de escritorio" (chica) queda de lado por ahora — no es parte de esta pasada.

Documentado también en `UI_DEVIATIONS.md` (reubicación de la barra) e `IDEAS.md` (Global/Local, nuevo archivo).

### Cuarta pasada, mismo día — 2 bugs más del workbench + defaults de Android

Tras la barra reubicada, apareció un nuevo bug (captura del usuario): el botón "Escalar" de la barra nueva quedaba flotando sobre el popup del workbench al abrirlo, porque ambos se anclan al mismo `benchy`. Corregido en `view_toolbar_draw_touch.gml`: se apaga (`toolbar_alpha_goal = 0`) mientras `window_busy = "bench"`, en vez de solo atenuarse a .8 como hace la barra de escritorio (los clics ya estaban a salvo vía `content_mouseon`/`popup_mouseon`, esto era puramente visual).

Segundo bug reportado tras la misma prueba ("tamaño o posición rara de los paneles" del workbench, confirmado por el usuario): la lista de categorías del workbench es un ancho fijo de 192px que no se achica con la escala de Android, pero el popup completo sí (534/1.65≈324px) — la columna derecha (buscador + lista de nombres) quedaba comprimida a ~108px lógicos. `bench_draw.gml`: ancho base en Android subido de 534 a 660, dejando la columna derecha en ~184px sin tocar el ancho fijo de la lista de categorías (para no truncar etiquetas largas como "Modelo personalizado").

Dos pedidos más del usuario, ambos ya implementados y verificados:
- **Modo avanzado activado por defecto en Android** (`settings_startup.gml`) — solo afecta una instalación limpia, `settings_load.gml` respeta cualquier valor guardado después.
- **Splashes de carga recortados de 26 a 14** (`Data/LoadRenders/renders.json`) — el usuario todavía no mandó sus propios renders; se dejó el espacio (14 entradas) usando 14 de las 26 existentes como placeholder, para reemplazar sin tocar la cuenta cuando lleguen los archivos nuevos.

**Todo lo anterior confirmado por el usuario en el mismo Redmi 10C** ("funciona todo") — con esto, Fase 4 queda cerrada (`CLAUDE.md` §12, `KNOWN_ISSUES.md` KI-4).

## Sesión 2026-09-16 — B22 (HTTPS/OpenSSL), auto-update de punta a punta, primer commit/push del repo, y hallazgo crítico B36

**Contexto:** sesión larga, varios pedidos del usuario en cadena. Cierra con el usuario AFK y una instrucción explícita de seguir avanzando en cosas que no requirieran de él ni de su teléfono.

### Hecho

**B22 (HTTPS) — RESUELTO y verificado en dispositivo real.** Recompilado OpenSSL 3.0.21 para Android arm64 (fix de detección de NDK en `15-android.conf`, problema de rutas cortas 8.3/backslash) y Qt 5.15.19 reconfigurado con `-openssl-linked`. Verificado con tráfico HTTPS real contra `api.github.com` y `mineimator.com` en el Redmi 10C.

**Windows Smart App Control** bloqueaba binarios recién compilados (`moc`/`uic`/`rcc`/`qmake`) — resuelto reusando las herramientas de host de escritorio ya confiables (idénticas, mismo Qt), y además se dejó `signtool.exe` + certificado autofirmado configurado como solución durable a pedido explícito del usuario.

**UX / botón Atrás de Android:** mapeado `Qt::Key_Back` a `vk_escape` (no existía — Android hoy cerraba la app directo, sin pasar por ningún popup). Agregados botones de cerrar/cancelar reales donde antes solo había "Mantené Escape" (ej. exportación) — a pedido explícito del usuario, reemplazando la dependencia de teclado físico.

**B33 (nuevo):** `Shader::BeginUse()` puede fallar en silencio — se agregó chequeo de retorno + log en los 3 sitios que importan (loop de render principal, `RenderFunc.cpp`, blit final de `GLWidget.cpp`). Mitigación, causa raíz sin confirmar.

**Fase 6 (diagnóstico, sin optimizar — a pedido explícito):** instrumentado el arranque completo con `log()` real (no `debug()`, que está gateado por `dev_mode`). Resultado real medido: ~1934ms total, `app_startup_lists` (828ms) y `app_startup_fonts` (514ms) los mayores contribuyentes. Causas raíz identificadas y documentadas en `PERF_LOG.md` (oversampling de `new_transition_texture_map`, rango de glifos 32-1024 en 11 `font_add()`) — **ninguna optimizada**, el usuario eligió quedarse solo con el diagnóstico.

**KI-1:** re-aplicado a pedido de investigar B31 (texto borroso reportado en el celular de un amigo, no el dispositivo de referencia), causó una regresión real y visible (popups/pantalla de carga recortados y reescalados, confirmado por 2 capturas del usuario) — revertido el mismo día. Motivo: varios parches de escala Android posteriores al revert original de 2026-09-09 se afinaron asumiendo la ausencia de este fix.

**CppGen "crasheaba" (B34) — RESUELTO.** Investigación larga (WinDbg instalado y usado por primera vez en este proyecto) terminó en que no era un bug: `CppGen.exe` tiene que correrse con working directory = su propia carpeta (`CppGen/Win64/`), no la raíz del repo — invocarlo desde la raíz rompe el cálculo de rutas y termina en `std::terminate()` sin ningún mensaje útil, antes de su propio manejo de error.

**Primer commit y push del proyecto a control de versiones.** Hasta ahora este repo nunca tuvo git propio. Se agregó identidad local (`Slytherking50` / email noreply de GitHub, `--local`, nunca `--global`), un commit cubriendo ~172 archivos (excluyendo backups, capturas sueltas, y explícitamente `GmProject/datafiles/Data/Minecraft/{Game Base.zip,.midata,current_state.png}` por la sospecha legal ya abierta), y push a un remoto nuevo `mobile` (`github.com/Slytherking50/Mine-Imator-Mobile`, antes completamente vacío) — `origin` sigue apuntando al fork de David Andrei, sin tocar.

**Auto-update, primer test real de punta a punta:**
- v0.0.2: falló la instalación ("no se pudo abrir el instalador") — B35: `file_paths.xml` declaraba `path="updates/"` en vez de `path="Mine-imator/updates/"` (no coincidía con lo que devuelve `user_directory_get()`). Corregido en v0.0.3.
- v0.0.3: el usuario probó actualizar y "mismo error" — pero el fix era correcto; el problema era metodológico: la app vieja (v0.0.1) instalada seguía siendo la que ejecutaba el install, nunca se había reemplazado. `adb install -r` directo de v0.0.3, y publicada v0.0.4 para tener un ciclo de auto-update genuinamente probable.
- Confirmar el resultado de v0.0.4 queda pendiente — necesita el teléfono, bloqueado con el usuario AFK.

**B36 — CRÍTICO, encontrado y confirmado trabajando de forma autónoma (usuario AFK):** investigando el pendiente legal de "Game Base" (señalado a mitad de sesión, pospuesto ese momento a pedido del usuario en favor de un bug visual), se encontró que `Data/Minecraft/Game Base.zip` — el único archivo de esa carpeta que el build de Android empaqueta, por diseño, precisamente porque debía ser 100% generado sin assets de Mojang (B25) — tiene su contenido reescrito desde el 2026-09-12 con el paquete real de texturas de Minecraft 1.20.2 (6.186/6.188 archivos idénticos byte a byte). **Confirmado además, descargando y desensamblando los 3 `.apk` ya publicados** (`gh release download`, solo lectura): `v0.0.2`, `v0.0.3` y `v0.0.4` — las 3 releases públicas de este mismo repo — distribuyen ese contenido ahora mismo. No hay ningún commit ni entrada de sesión del 2026-09-12 que explique cómo pasó; el candidato más probable es un archivo suelto encontrado en la misma carpeta (`Reparado.zip`, contenido idéntico, creado el día anterior). **No se tomó ninguna acción de remediación** — despublicar/reemplazar releases públicas es un `[GATE]` legal y una acción visible para terceros, ninguna de las dos se ejecuta sin confirmación explícita. Detalle completo, con todos los timestamps y hashes: `KNOWN_ISSUES.md` B36, `CLAUDE.md` §8/§17.

### Abierto / a investigar
- **B36 es la máxima prioridad apenas el usuario vuelva** — ver recomendación completa en `KNOWN_ISSUES.md` B36 (despublicar/reemplazar las 3 releases, restaurar el placeholder legítimo, republicar limpio).
- Confirmar v0.0.4 con el dispositivo real (auto-update de punta a punta, ver arriba).
- B30 (crash de skin) — mitigación aplicada, causa raíz sin confirmar, falta el log del celular del amigo.
- B31 (texto borroso en el celular del amigo) — sigue sin resolver, el intento de fix (KI-1) fue revertido por regresión.
- Prueba térmica de 10 min (§14.3) — necesita el teléfono.
- Posición exacta del nuevo botón de cancelar exportación — sin verificar en dispositivo real.

### Próximo paso
- Presentar B36 al usuario apenas esté disponible — es lo primero que necesita decidir.
- Con su ok, ejecutar la remediación (despublicar releases, restaurar placeholder, republicar) y recién ahí retomar la verificación de auto-update v0.0.4.
