# Fase 1 — Primera corrida real en un dispositivo Android (2026-09-08)

## Pregunta

Con el `.apk` real ya generado (`research/2026-09-08-fase1-apk-packaging.md`), ¿instala y arranca en un dispositivo Android real, y si no, por qué?

## Método

Instalar el `.apk` vía `adb` en un dispositivo físico (Xiaomi/Redmi, modelo `220333QL`, Android 13/API 33, arm64-v8a — por encima del `minSdkVersion=29`), lanzarlo, y diagnosticar cada fallo real con `logcat`, corrigiendo y reintentando, sin asumir nada sobre la causa antes de verla en el log.

## Hallazgos

### 0. La instalación en sí necesitó un permiso extra de MIUI

Primer intento de `adb install` falló con `INSTALL_FAILED_USER_RESTRICTED: Install canceled by user` — no es un problema del `.apk`, es una restricción de MIUI que requiere activar "Instalar vía USB" en Opciones de desarrollador (separado de "Depuración USB"). Una vez activado, instaló sin cambios en el `.apk`.

### 1. `libomp.so` faltante — crash inmediato al cargar la librería propia

Primer lanzamiento: todas las librerías de Qt/FFmpeg/OpenAL/zip cargaron bien, pero `libMine-imator_arm64-v8a.so` falló con `UnsatisfiedLinkError: dlopen failed: library "libomp.so" not found`. Causa raíz (confirmada, no supuesta): `CMakeLists.txt` tiene `find_package(OpenMP REQUIRED COMPONENTS CXX)` y `target_link_libraries(... OpenMP::OpenMP_CXX)` **sin ninguna exclusión para Android** — nadie lo había notado porque nunca se había llegado a correr en un dispositivo real. El NDK sí puede compilar y linkear contra OpenMP (`-fopenmp=libomp`, confirmado en `build.ninja`), pero el runtime que usa para el link (`toolchains/llvm/prebuilt/.../lib/clang/18/lib/linux/aarch64/libomp.so`, parte del toolchain, no de ninguna imagen de sistema Android) nunca se empaquetaba en el `.apk`. Arreglado igual que cada otra dependencia de runtime en este archivo: localizarlo con `file(GLOB ...)` (evitando hardcodear la versión de clang) y agregarlo a `ANDROID_EXTRA_LIBS`. No se sacó OpenMP del proyecto — sigue siendo `REQUIRED`, así que el fix respeta esa decisión existente.

### 2. `EGL_BAD_MATCH` (0x3009) — el viewport OpenGL nunca creaba contexto

Con `libomp.so` resuelto, la app abría una ventana (foco confirmado con `dumpsys window`, pantalla despierta) pero mostraba un fondo gris liso sin ningún elemento de UI — ninguna excepción visible en el logcat filtrado por `AndroidRuntime`/`FATAL`. Ampliando el filtro al tag propio de la app (`Mine-imator`, no genérico) apareció el error real:

```
W Mine-imator: QEGLPlatformContext: Failed to create context: 3009
W Mine-imator: qt.qpa.backingstore: composeAndFlush: makeCurrent() failed
W Mine-imator: QOpenGLWidget: Failed to create context
```

`3009` es hexadecimal sin prefijo `0x` (formato propio de ese mensaje de Qt) = `EGL_BAD_MATCH`. Causa raíz, en `GraphicsApiHandler.cpp` (constructor de la rama compartida Mac/Linux/Android, `#else` de `#if API_D3D11`):

```cpp
QApplication::setAttribute(Qt::AA_UseDesktopOpenGL);
...
format.setVersion(4, 3);
format.setProfile(QSurfaceFormat::CoreProfile);
```

`AA_UseDesktopOpenGL` y `CoreProfile` son conceptos exclusivos de OpenGL de escritorio — no existen en ES. `setVersion(4, 3)` se interpreta como una versión de ES 4.3, que no existe (ES llega hasta 3.2). Ningún EGLConfig del driver podía coincidir con esos atributos, así que `eglCreateContext` fallaba con `EGL_BAD_MATCH` en cada intento. Esta rama de código nunca se había ejecutado de verdad en Android hasta este momento (igual que los otros bugs de `GraphicsApiHandler.cpp` encontrados el 2026-09-06/08 — ver `CLAUDE.md` §5.1.1) — no es un bug nuevo introducido, es uno que solo se manifiesta cuando de verdad se corre en el target.

Arreglado con un guard `#ifdef Q_OS_ANDROID`: en Android, `format.setRenderableType(QSurfaceFormat::OpenGLES); format.setVersion(3, 0);` (sin perfil — no aplica a ES), sin `AA_UseDesktopOpenGL`. ES 3.0 es la base segura que necesita `QOpenGLExtraFunctions` (el reemplazo de 0.3 para las clases GL versionadas de escritorio) y está disponible universalmente en `minSdk 29`; el batching por SSBO (que pediría ES 3.1) ya es Opción A — no se porta a Android ([GATE G1], `CLAUDE.md` §5.1.1).

Verificado tras el fix: el log muestra información real del driver Adreno (`AdrenoGLES-0: Driver Path: /vendor/lib64/egl/libGLESv2_adreno.so`, versión de compilador de shaders, etc.) — confirma que el contexto ES esta vez sí se creó contra el GPU real del dispositivo (Adreno, Qualcomm), sin ningún "Failed to create context" en el log.

### 3. Datafiles ausentes — confirmado como el hueco ya anticipado, con evidencia visual

Sin `libomp`/EGL rotos, la app llegó lo bastante lejos como para mostrar su **propio diálogo de error** (`ErrorDialog.cpp`, renderizado correctamente vía QWidget — primera confirmación de que el sistema de widgets de Qt funciona de punta a punta en este dispositivo):

> "The file /data/data/org.internal.testbuild/files/Data/legacy.midata could not be found."

Esto confirma exactamente el hueco ya anotado en `PHASE1_PLAN.md` (datafiles no empaquetados para Android) — pero ahora con evidencia directa de dónde los busca la app (`getFilesDir()/Data/...`, el directorio privado interno de la app) en vez de solo sospecharlo.

**Prueba rápida, no la solución definitiva:** se empujó la carpeta `Data/` (28MB, la misma que usa el build de escritorio) al dispositivo con `adb push` + `adb shell run-as org.internal.testbuild cp -r ...` (posible porque es un build debuggable). Tras reiniciar la app, el diálogo de error desapareció y no volvió a aparecer ningún error de archivo faltante en el log — confirma que el mecanismo de carga de datos en sí funciona bien una vez que los archivos están en el lugar esperado; el problema real es puramente de empaquetado/distribución, no de lógica de carga.

## Estado tras los tres fixes, y un cuarto hallazgo confirmado con evidencia real

Con la pantalla en negro, se le pidió al usuario tocarla directamente (la inyección de eventos de `adb shell input tap` está bloqueada por la política de seguridad de MIUI en este dispositivo — `SecurityException: ... requires INJECT_EVENTS permission` — incluso desde shell). El toque reveló un diálogo real de la propia app: **"Some shaders failed to compile. Check that your graphics drivers are up-to-date and restart Mine-imator."** — texto que viene literal de `GmProject/scripts/shader_startup/shader_startup.gml:106`, la lógica original de GameMaker (transpileada por CppGen), que compila las 49 shaders del proyecto y aborta con `game_end()` (por eso el proceso termina limpio, no con una excepción — no era un crash, era un apagado intencional) si cualquiera falla.

`Printer::Line` (el logger propio de Mine-imator) no escribe a logcat en este build (`std::cout` bajo `DEBUG_MODE` se pierde — Android no redirige el stdout de una librería nativa cargada dentro de un proceso Java a logcat) sino a un archivo real: `QDir::homePath() + "/Mine-imator/log.txt"`, que en Android resuelve a `/data/data/org.internal.testbuild/files/Mine-imator/log.txt` — accesible con `adb shell run-as` por ser un build debuggable. Ese archivo tiene el detalle exacto que logcat no mostraba:

- `GL_RENDERER: Adreno (TM) 610`, `GL_VENDOR: Qualcomm`, `OpenGL version: 3.2` — confirma que el fix de `QSurfaceFormat` (punto 2, arriba) efectivamente negoció un contexto ES real contra el GPU real.
- **Las 49 shaders (`.vsh`) reportan `not found`** en la carga: `Shader: C:/Users/mateo/OneDrive/Desktop/Claude/Mine-imator/CppProject/Asset/Shaders/*.vsh not found in Load:178`. Causa raíz, confirmada leyendo `CMakeLists.txt:76,467-468`: `GM_SHADERS_DIR`/`ASSETS_DIR` son **rutas absolutas del host de build de Windows**, horneadas como `#define` en tiempo de compilación — no es un bug nuevo, es exactamente el hueco que ya estaba anotado sin resolver en un comentario del propio `CMakeLists.txt` (líneas 644-649, de la sesión anterior) desde antes de correr nada en un dispositivo real. Esta corrida lo confirma con evidencia concreta en vez de dejarlo como sospecha.
- De las 49, 48 igual "compilan" (probablemente desde algún fallback/ruta alternativa cuando el archivo fuente no aparece — no investigado en detalle) pero **`shader_high_glint` específicamente falla** (`shader_high_glint compiled: no`), disparando el `break` del ciclo y el diálogo de error. Por qué esta shader en particular falla y las otras 48 no, con todas apuntando al mismo mecanismo roto de rutas, queda como incógnita abierta.

## Estado final de esta sesión

La app corre de punta a punta — instala, arranca, crea contexto ES real contra el Adreno del dispositivo, carga datos (una vez empujados manualmente), compila 48 de 49 shaders — y se detiene de forma controlada (no crashea) exactamente donde el propio proyecto ya sabía que faltaba trabajo: las rutas de assets basadas en el filesystem del host de build. Es la validación más completa de la arquitectura de todo el port hasta ahora.

## Contradicciones

Ninguna con hallazgos previos. El hallazgo de OpenMP es nuevo (no estaba en la lista original de "qué falta" de Fase 1 punto 1). El de EGL confirma exactamente el tipo de bug que 0.5/B3 esperaban encontrar, solo que en la etapa más básica posible (creación de contexto, antes de cualquier shader). El de las rutas de shaders **confirma con evidencia real** algo que ya estaba escrito como sospecha sin verificar en `CMakeLists.txt` desde la sesión anterior — no es un hallazgo que contradiga nada, es uno que cierra una incógnita que ya estaba planteada.

## Incógnitas que quedan

- Resuelto: la pantalla negra **no** era "UI de escritorio sin adaptar" — era la app deteniéndose sola (`game_end()`) tras fallar `shader_high_glint`, con la ventana ya cerrándose antes de dibujar la UI de escritorio. No se llegó a ver si la UI en sí reacciona al tacto, porque la app se cierra antes de llegar ahí.
- Por qué `shader_high_glint` específicamente falla y las otras 48 shaders "compilan" pese a que las 49 reportan el mismo `.vsh not found` — no investigado. Podría ser un fallback/cache que coincide por casualidad con 48 de las 49, o alguna diferencia real en el shader que la hace más sensible al problema de fondo.
- El mecanismo real para que `GM_SHADERS_DIR`/`ASSETS_DIR` (y por extensión los datafiles del punto 3) resuelvan a algo real en Android — assets de Android vía `AssetManager`, o plegarlos al `.qrc` existente — sigue sin diseñarse. Ambos `adb push` manuales de esta sesión (Data/, y lo que haría falta para Shaders/) son solo diagnóstico, no una solución.
- No se probó rotar el dispositivo, ni comportamiento en background/foreground, ni ningún otro ciclo de vida de Android — la app nunca llegó a un estado estable el tiempo suficiente para eso.

## Actualización — cierre real de Fase 1 (misma sesión, continuación)

Con el hueco de rutas de shaders identificado, aparecieron tres problemas más, cada uno encontrado y arreglado con el mismo ciclo (rebuild → reinstalar → leer `log.txt` real → diagnosticar → arreglar → repetir):

### 5. `DEBUG_MODE` usaba rutas de host incluso para los shaders ya embebidos como recurso Qt

`Shader::Load()` solo usa la ruta de recurso Qt (`:Shaders/...`, ya embebida en `index.qrc` para todas las plataformas) cuando `DEBUG_MODE=0` (Release). Nuestro build era Debug, así que tomaba la rama que arma rutas con `GM_SHADERS_DIR`/`ASSETS_DIR` (host de Windows) en vez de usar el recurso ya disponible. Arreglado: `#if DEBUG_MODE && !defined(Q_OS_ANDROID)` — Android usa siempre el recurso embebido, sin importar el tipo de build (el hot-reload de shaders en vivo que `DEBUG_MODE` habilita no tiene sentido en un dispositivo de todos modos).

### 6. GLSL ES prohíbe inicializadores globales no-constantes

Con los shaders ya encontrados, aparecieron 49 errores `ERROR: Invalid #version` — causa real: `Shader::glslVersion` arranca en `"150 core"` (string de escritorio) y solo se actualiza si los tests de detección GL 4.0/4.3 compilan, pero esos tests usan sintaxis de escritorio (`#version 430`/`#version 400`) que nunca puede compilar contra ES — así que en Android `glslVersion` se queda pegado en `"150 core"` para siempre. Arreglado poniendo `glslVersion = "300 es"` directo para Android, sin pasar por la detección de escritorio.

Con eso resuelto, apareció un error distinto: `'_aTangent' : Only consts can be used in a global initializer` — GLSL ES prohíbe que el inicializador de una variable global referencie un atributo no-constante (desktop GLSL sí lo permite), y el código de desempaquetado de vértices (`ShaderLoadOpenGL.cpp`, formato `VERTEX_BUFFER`) declaraba `vec3 in_Normal = <expresión con _aNormal>;` como global. Primer intento de fix (declarar como variable local dentro de `main()`) rompió shaders que llaman funciones auxiliares (`getWind()`, etc.) definidas *antes* de `main()`, que referencian `in_Normal`/`in_Wave` como globales — "undeclared identifier" en esas funciones. Fix correcto: declarar las variables como globales *sin* inicializador (legal en ES) y asignarles el valor real como primera instrucción dentro de `main()` (una asignación no es un "inicializador global").

### 7. Orden de inicialización: un shader se carga antes de que `Shader::Init()` fije la versión

Con las 49 shaders de `shader_startup.gml` compilando, quedó un último error silencioso (no dispara el diálogo porque no es parte de esa lista): `primitive` (uno de los 6 shaders exclusivos de C++) seguía fallando con `Invalid #version`. Causa: `AppHandler.cpp` construye `PrimitiveRenderer` (que carga `primitive` de inmediato) *antes* de llamar a `Shader::Init()` — así que `primitive` compila con el valor **default estático** de `glslVersion`, no con el que `Init()` calcula. En desktop nunca fue un problema porque el default (`"150 core"`) ya es una versión de escritorio válida. Arreglado moviendo el valor correcto ("300 es") al inicializador estático mismo, para que sea correcto desde el arranque sin depender del orden de inicialización.

## Resultado final verificado

Con los 7 bugs arreglados (instalación MIUI, OpenMP, EGL, rutas de shaders, DEBUG_MODE vs. recurso Qt, inicializadores globales ES, orden de `Init()`), **Mine-imator arranca y dibuja su interfaz y escena 3D completas en un dispositivo Android real** (Xiaomi/Redmi, Adreno 610): menú de escritorio completo (File/Edit/Render/View/Help), barra de herramientas, panel de propiedades del proyecto, controles de timeline, y el viewport 3D mostrando la escena default de un proyecto nuevo (bloque de pasto flotante, cielo, nubes, terreno) — todo renderizado vía el contexto OpenGL ES 3.0 real. Esto supera ampliamente el criterio original de Fase 1 ("arranca y dibuja un triángulo").

**Fase 1 — CERRADA.**

## Decisión

Los 7 bugs reales encontrados en esta sesión de pruebas en dispositivo están todos arreglados y verificados. Fase 1 cumple y supera su criterio de cierre. Sigue: Fase 2 (adaptación de la UI de escritorio a un layout táctil — el desajuste de proporciones entre los paneles fijos y la pantalla del teléfono, visible en la captura final, es exactamente ese trabajo, no un bug), y separado de eso, la decisión pendiente del usuario sobre el nombre final de la app antes de cualquier publicación real.
