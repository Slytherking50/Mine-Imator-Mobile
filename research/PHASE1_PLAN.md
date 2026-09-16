# Fase 1 — Plan de ejecución (preparado 2026-09-06)

**[FASE 1 — CERRADA] (2026-09-08).** Verificado en un dispositivo Android real (Xiaomi/Redmi, Adreno 610): Mine-imator arranca y dibuja su interfaz de escritorio completa y una escena 3D real (proyecto nuevo por defecto — bloque de pasto, cielo, nubes, terreno), renderizada vía OpenGL ES 3.0 real contra el GPU del dispositivo. Supera el criterio original ("arranca y dibuja un triángulo"). Siete bugs reales encontrados y arreglados en el camino — detalle completo en `research/2026-09-08-fase1-first-device-run.md`. Sigue: Fase 2 (adaptación de la UI a táctil) y la decisión pendiente del usuario sobre el nombre final antes de publicar.

**Actualización (2026-09-06, mismo día):** este plan se escribió mientras 0.10 seguía abierto, con la ejecución explícitamente frenada por §11 hasta que David Andrei respondiera. Ya respondió — confirmó MIT, puerto móvil y distribución en Google Play, con la única condición de mantener el aviso de copyright y usar un nombre genuinamente distinto (`CLAUDE.md` §9.3). **El freno de §11 ya no aplica — Fase 1 puede arrancar.** El plan de abajo queda sin cambios de contenido, solo cambia su estado: de "preparación bloqueada" a "listo para ejecutar".

## Objetivo (§12)

**APK que arranca y dibuja un triángulo. Sin features.** Incluye la tarea 0.5 (backend ES de `processCode` + `shader_high_light_point` en dispositivo real), movida acá desde Fase 0 porque necesita un `CppProject` corriendo en Android para poder correrse.

## Aclaración de alcance — hallazgo de esta sesión, no supuesto

**"Sin features" no significa un binario reducido.** `CppProject/CMakeLists.txt` es un único `add_executable` con **todo** el árbol de `CppProject` globbeado (`file(GLOB_RECURSE PROJECT_SOURCES ... "*.cpp" "*.hpp")`, línea 282-285) — no existe (ni existe una forma barata de crear) un target que compile un subconjunto de la app. Armar uno sería, en sí mismo, un proyecto de reestructuración del build no presupuestado.

**Consecuencia:** Fase 1 implica que el Mine-imator real completo compile y linkee para Android — las 98.840 líneas derivadas de GML, los 58 objetos, todo. "Sin features" quiere decir que no hace falta que la UI táctil, el import de mundos, ni el export de video *funcionen* todavía (eso es Fase 3/5/7) — pero el código tiene que compilar y el binario tiene que arrancar y renderizar. Esto es más trabajo de lo que "dibujar un triángulo" sugiere a primera lectura, y vale la pena decirlo así de explícito para no subestimar la tarea.

## Qué ya existe (de Fase 0, verificado, no repetir)

| Pieza | Estado | Fuente |
|---|---|---|
| Qt 5.15.19 compilado para Android (arm64-v8a) | Verificado, instalado en `C:\Dev\Qt\5.15.19\install-android` | `BUILD_NOTES.md` |
| NDK r27 + toolchain (clang, GNU make) | Verificado, funcional | `BUILD_NOTES.md` |
| `GraphicsApiHandler.hpp` migrado a `QOpenGLExtraFunctions` | Hecho y verificado por compilador (48/49 funciones GL), en la rama `fase0-0.3-graphicsapihandler-prototype`, **sin mergear** | `research/2026-09-06-b1-graphicsapihandler-prototype.md` |
| Tratamiento de `Shader.hpp`/`Shader.cpp`/`ShaderLoadOpenGL.cpp` | **Diseñado, no aplicado** — guard `#ifndef Q_OS_ANDROID` para `QOpenGLFunctions_4_3_Core`/`gl43Core`, mover `glGetProgramResourceIndex` a `GFX->` (ya cubierto por `QOpenGLExtraFunctions`) | `CLAUDE.md` §5.1.1 |
| `minSdkVersion` = 29 | `[GATE G1 — CERRADO]` | `CLAUDE.md` §7.1.1 |
| `[GATE G1]` sobre SSBO/batching | CERRADO, Opción A (no portar batching a Android) | `CLAUDE.md` §5.1.1 |
| B5/x264 — qué hace falta para el build de FFmpeg-Android | Auditado: sacar `--enable-gpl`/`--enable-libx264`, compilar dinámico. Encoding real (`AMediaCodec`) es trabajo de Fase 7, no de Fase 1 | `research/2026-09-06-b5-x264-mediacodec.md` |
| Inventario de funciones GL por versión ES | Completo, 49 funciones clasificadas | `research/2026-09-06-b1-graphicsapihandler-prototype.md` |

## Qué falta, en orden de dependencia

### 1. Librerías externas para Android (`CppProject/External/Android/`) — **HECHO Y VALIDADO CON BUILD REAL (2026-09-08)**

Las 5 librerías están compiladas, copiadas a `CppProject/External/Android/` y wireadas en `CMakeLists.txt`:

- **zlib**: no hizo falta compilar nada — el NDK trae un zlib de sistema completo sin prefijo. Se sacó `QtZlib` (Z_PREFIX de Qt) del include path para Android; `GZIP.cpp`/`NBT.cpp` y el FreeType de Qt ahora resuelven contra el mismo zlib plano del sistema.
- **libpng**: compilado desde la fuente que Qt empaqueta (`qt5/qtbase/src/3rdparty/libpng`, sin CMake propio — se escribió uno standalone) — lo necesita el FreeType de Qt para bitmaps de color en fuentes (confirmado por `llvm-nm -u` antes de compilar nada). `libqtlibpng.a`.
- **OpenAL-soft**: compilado con backend `OpenSL` nativo (detectado automáticamente por CMake). `libopenal.so`.
- **libzip**: compilado sin bzip2/lzma/zstd/openssl (Mine-imator solo usa zip plano, confirmado por grep). `libzip.so`.
- **FFmpeg, sin x264/GPL**: config de `Setup.ps1:380-405` adaptada (sin `--enable-gpl`/`--enable-libx264`, `--enable-shared --disable-static`, toolchain NDK). Requirió instalar MSYS2 (`C:/Dev/msys64`, mismo mecanismo que ya usa `Setup.ps1` para desktop) porque el `make` nativo del NDK no traduce rutas POSIX ni puede ejecutar los wrappers de compilador (son scripts bash). `configure` confirmó `License: LGPL version 2.1 or later` — verifica por herramienta que sacar x264/gpl deja el build limpio. 5 `.so` (avcodec/avformat/avutil/swresample/swscale), cada uno con símbolos reales verificados.
- **x264**: no se compila para Android, como estaba decidido.

FreeType sigue sin hacer falta compilarlo — prebuilt de Qt, ya wireado.

**Hallazgo nuevo de esta pasada:** `libavutil/avconfig.h` (header generado por `configure`, no parte de la fuente de FFmpeg) es específico de arquitectura — la copia versionada en `External/Sources/` (generada para Windows/x86_64) tiene `AV_HAVE_FAST_UNALIGNED=1`, la real de Android/aarch64 tiene `0`. Sería un bug silencioso si se hubiera compartido sin más. Arreglado con un include path específico de Android que gana por orden de búsqueda. Detalle completo, con cada paso y cada problema encontrado, en `research/2026-09-08-fase1-external-libraries-android.md`.

**Verificado con el build más importante posible:** con las 5 librerías en su lugar, `cmake --build .` completo sobre todo `CppProject` para Android — 160 archivos, 0 errores, **link exitoso**. `libMine-imator_arm64-v8a.so` real, 72.6 MB, sin ninguna mención de símbolo indefinido en el log. Primera vez que el proyecto completo no solo compila sino que **linkea** para Android.

### 2. `CppProject/CMakeLists.txt` — rama Android — **HECHO Y VALIDADO (2026-09-08)**

No solo escrito — compilado de verdad. Se armó `CppProject/Android/` (manifest, `build.gradle` con AGP 8.7.0/`mavenCentral()` en vez de las versiones desactualizadas de la plantilla de Qt, wrapper de Gradle) como `QT_ANDROID_PACKAGE_SOURCE_DIR`, y la rama `elseif(ANDROID)` del CMakeLists (target como `add_library(SHARED)`, `QT_INSTALL_DIR`/`ANDROID_MIN_SDK_VERSION`/`ANDROID_TARGET_SDK_VERSION` correctos, exclusión de x264). Se corrió un `cmake configure` + `cmake --build` real contra el NDK, **7 iteraciones**, cada una arreglando un problema real encontrado por el compilador/linker, verificando después de cada fix que Windows siguiera compilando limpio. Resultado: **el 100% de `CppProject` compila para Android arm64-v8a** — quedan solo símbolos de linkeo por las librerías del punto 1, que todavía no existen. Detalle completo, con cada bug encontrado y su fix, en `research/2026-09-08-fase1-android-cmake-first-build.md`.

**Hueco nuevo, encontrado y no resuelto:** la copia de datafiles (`Data/`, `Particles/`, `Schematics/`) y el `install()` de CMake se excluyeron para Android (`if(NOT ANDROID)`) sin reemplazo — `androiddeployqt` empaqueta distinto (assets de Android o `.qrc`), no se investigó cuál. `ASSETS_DIR`/`GM_SHADERS_DIR` son rutas absolutas del host de build, sin sentido en un dispositivo — tampoco resuelto.

CppGen sigue corriendo en el host (Windows), no en el target — confirmado funcionando así en la compilación real (`CPPGEN_EXE` apunta a `CppGen/Win64/CppGen.exe` sin importar la plataforma de `CppProject`, consistente con 0.2: la salida de CppGen es agnóstica de plataforma).

### 3. Aplicar el tratamiento de `Shader.hpp`/`Shader.cpp`/`ShaderLoadOpenGL.cpp` — **HECHO (2026-09-06, rama `fase1-shader-android-guard`)**

Guard `#ifndef Q_OS_ANDROID` aplicado en `Shader.hpp:9,222`, `Shader.cpp:65,103-113,253`; `glGetProgramResourceIndex` movido de `gl43Core->` a `GFX->` en `ShaderLoadOpenGL.cpp:262`. Verificado con compilador real en los dos lados: desktop (`Mine-imator.exe` recompilado, MSVC Debug, 0 warnings/0 errores) y Android (test aislado con la misma estructura, compilado con `clang++` del NDK contra Qt-Android real, confirma además que `Q_OS_ANDROID` se auto-define desde los headers de Qt al targetear `aarch64-linux-android24`, sin que el proyecto tenga que definirlo a mano). Sin commitear todavía.

### 4. Barrido de APIs Windows-only/desktop-only fuera de lo que 0.3 cubrió — **CERRADO CON COMPILACIÓN REAL (2026-09-08), no solo grep**

La pasada de grep original (2026-09-06) encontró 3 grupos (abajo, sin cambios) pero avisaba que un grep no podía cerrar esto del todo. Se cerró de verdad: una compilación real de **todo** `CppProject` para Android (punto 2, ya hecho) encontró 5 bugs de compilación reales que ningún patrón de texto hubiera detectado, porque no son "APIs Windows-only" — son diferencias de API entre clases de Qt y entre GL desktop/ES (`qopenglext.h`/`GLclampd`, `GL_TEXTURE_LOD_BIAS`, `isInitialized()`, `initializeOpenGLFunctions()` sin bool, `QThread::create` no disponible en esta build de Qt). Los 5 ya están arreglados y verificados — **el 100% del código compila para Android**. Detalle completo en `research/2026-09-08-fase1-android-cmake-first-build.md`.

Hallazgo transversal: 2 de los 5 bugs (`isInitialized()`, `initializeOpenGLFunctions()`) **no son específicos de Android** — son bugs latentes en la rama OpenGL compartida (Mac/Linux/Android) que 0.3 nunca compiló de verdad (solo un test aislado) y que Windows nunca ejercita (toma la rama D3D11). Quedaban ahí desde la migración de 0.3, invisibles hasta esta compilación.

Del grep original, sin cambios:
- **`QFileDialog` (`Gml/FileFunc.cpp:208,233`, open y save)** — ubicación concreta del ya catalogado B4 (SAF vs. rutas).
- **`QDesktopWidget::logicalDpiX()`/`devicePixelRatio()` (B18, §8)** — sigue sin confirmar contra un dispositivo real.
- **Drag-and-drop de archivos del SO (`AppWindow.cpp`)** — compila, queda muerto en Android, hueco de Fase 5.
- `QClipboard`/`QStandardPaths` — portables, sin riesgo.

**Nuevo hueco encontrado en esta pasada, sin resolver:** cómo llegan los datafiles (`Data/`, `Particles/`, `Schematics/`, shaders) al dispositivo — el mecanismo de copia/`install()` de escritorio no aplica a Android y no tiene reemplazo todavía (`androiddeployqt` empaqueta distinto). Ver `research/2026-09-08-fase1-android-cmake-first-build.md`, Incógnitas.

### 5. Manifest, ícono, nombre de paquete

0.10 ya cerró (§9.3): David Andrei confirmó MIT y autorizó el puerto móvil, pero fue explícito con una condición — el nombre **no puede ser una variación reconocible de "Mine-imator"** (dio el ejemplo puntual de "Mine-imator Mobile" como lo que no quiere). Elegir el nombre real sigue siendo una decisión del usuario, no técnica, pero ya no depende de nadie más — vale la pena resolverla temprano en Fase 1, porque el `applicationId`/paquete de Android es más caro de cambiar después de la primera publicación que antes.

## Riesgos e incógnitas de este plan

- **Actualizado (2026-09-08, cuarta pasada — cierre):** Fase 1 verificada de punta a punta en un dispositivo real. Los siete bugs encontrados en el camino (instalación bloqueada por MIUI, OpenMP sin empaquetar, EGL pidiendo OpenGL de escritorio, rutas de shaders absolutas del host, `DEBUG_MODE` ignorando el recurso Qt ya embebido, inicializadores globales no válidos en GLSL ES, orden de inicialización de `Shader::Init()`) están todos arreglados y verificados — ver `research/2026-09-08-fase1-first-device-run.md`. El resultado final: la UI de escritorio completa y una escena 3D real se dibujan correctamente en el Adreno 610 del dispositivo de prueba.
- FFmpeg se cross-compiló con el NDK con éxito, pero con `--disable-asm` (sin optimizaciones ARM NEON) — no evaluado si hace falta revisar esto por rendimiento.
- La UI de escritorio se ve, pero con las proporciones de sus paneles fijos desajustadas para la pantalla de un teléfono (visible en la captura de cierre) — esto es exactamente el trabajo de Fase 2, no un bug de Fase 1.
- No se probó rotación, ciclo de vida completo de Android (background/foreground repetido), ni el comportamiento con una conexión USB inestable (la propia sesión de pruebas tuvo desconexiones intermitentes del cable, sin relación con la app).
- No se estimó cuánto tardó Fase 1 en total ni cuánto tardará Fase 2 — no hay base para poner fechas todavía.

## Orden recomendado para seguir

**Fase 1 cerrada.** Sigue: Fase 2 (adaptar la UI de escritorio a un layout táctil — la causa raíz del desajuste de proporciones ya visible). El punto 5 de este plan (nombre/manifest) sigue siendo la decisión del usuario pendiente — no bloquea nada técnico, pero conviene resolverla antes de la primera publicación real (el `.apk` actual usa el placeholder `org.internal.testbuild`, deliberadamente no apto para publicar).
