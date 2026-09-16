# Fase 1 — CMake/Gradle para Android + primer intento de compilación real completa

## Pregunta

Punto 2 del plan (`research/PHASE1_PLAN.md`): armar la rama Android del `CMakeLists.txt` y el empaquetado (`androiddeployqt`). De paso, con la infraestructura ya armada, correr un intento de compilación real de **todo** `CppProject` para Android — no un test aislado como en 0.3 — para cerrar de una vez el punto 4 (barrido de APIs desktop-only), que un grep nunca podía cerrar del todo.

## Método

1. Investigado el mecanismo real de Qt 5.15 + CMake + Android: `Qt5AndroidSupport.cmake` (se incluye automático vía `find_package(Qt5)` al targetear Android), que genera `android_deployment_settings.json` y los targets `apk`/`aab` para `androiddeployqt`.
2. Creado `CppProject/Android/` (manifest, `build.gradle`, wrapper de Gradle) como `QT_ANDROID_PACKAGE_SOURCE_DIR` — copia de las plantillas de Qt con dos fixes (AGP 7.0.2→8.7.0, `jcenter()`→`mavenCentral()`) porque las plantillas de Qt están desactualizadas contra lo que hay instalado en esta máquina (SDK build-tools 34.0.0, JDK 17 — verificado con la matriz de compatibilidad real de Google).
3. Extendida la rama de plataforma del `CMakeLists.txt` (`elseif(ANDROID)`): `QT_INSTALL_DIR` apuntando a `install-android`, target como `add_library(SHARED)` en vez de `add_executable`, variables `ANDROID_MIN_SDK_VERSION=29`/`ANDROID_TARGET_SDK_VERSION=34`, exclusión de `libx264` (B5), y guardado del bloque de copia de datafiles/`install()` (no aplica a Android, `androiddeployqt` empaqueta distinto — queda como hueco nuevo, no resuelto, ver Incógnitas).
4. **No se quedó en "debería andar"**: se corrió un `cmake` configure real contra el NDK (`CMAKE_TOOLCHAIN_FILE` del NDK r27, `ANDROID_ABI=arm64-v8a`, `ANDROID_PLATFORM=android-29`) y, tras resolverlo, un `cmake --build` real con `ninja`, sobre **todo** `CppProject` — no un archivo aislado. Se repitió 7 veces, arreglando un problema real por vez y volviendo a compilar, cada vez verificando además que el build de escritorio (Windows/MSVC) siguiera compilando limpio tras cada cambio (no se rompió ninguna vez).
5. Para llegar a compilar de verdad sin tener todavía las librerías reales de `CppProject/External/Android/` (punto 1 del plan, no hecho), se crearon `.so` **vacíos** como placeholder — truco deliberado para que el validador de dependencias de `ninja` dejara pasar la fase de compilación y llegara al link, revelando errores de compilación reales en vez de solo la ausencia de librerías. Se explicita esto porque la primera vez que se hizo, el resultado ("exit code 0") se malinterpretó sin revisar el log real — corregido en el momento, ver Hallazgo 0.

## Evidencia y hallazgos, en el orden real en que aparecieron

### Hallazgo 0 — "exit code 0" del wrapper de shell no significa que el build haya compilado nada

Primer intento: `ninja` reportó como fallo la ausencia de `libzip.so` **antes de compilar un solo archivo real** — confirmado con `find *.o`, que solo mostró el test interno de detección de compilador de CMake. El "exit code 0" que reportó la notificación de la tarea en background era del **comando de shell** (`cmake --build . | tee log`), no del build en sí — `tee` "tuvo éxito" en el sentido de shell aunque el build fallara. Lección aplicada de inmediato: leer el log real, nunca confiar en el código de salida reportado en una notificación.

### Hallazgo 1 — `<version>` de FFmpeg pisa el header estándar de C++ (20 errores en cascada, 1 causa real)

Con los `.so` vacíos puestos, la primera compilación real dio **20 errores** de apariencia dispar (`ptrdiff_t` no declarado, plantillas de átomos rotas) más `error: expected unqualified-id` en un archivo llamado literalmente `C:/Dev/FFmpeg/ffmpeg-5.1.10/version` (contenido: `5.1.10`). Causa real: el `CMakeLists.txt` agregaba la raíz completa de FFmpeg como directorio de include (`target_include_directories`) para plataformas no-Windows — y esa raíz tiene su propio archivo llamado `version` (sin extensión), que Clang+libc++ del NDK encuentra en vez del header estándar `<version>` (macros de feature-test de C++17/20), corrompiendo el resto de la cadena de includes de `<algorithm>`.

**Ya estaba resuelto para macOS** (mismo compilador Clang+libc++): un comentario existente, `"Fix FFmpeg include issue with VERSION"`, usa `-idirafter` en vez de `-I` para ese path en la rama `APPLE`. Extendido a `if(APPLE OR ANDROID)` — los 20 errores desaparecieron enteros en el siguiente intento, confirmando que eran todos la misma causa.

### Hallazgo 2 — `qopenglext.h` de Qt no compila contra headers de solo-ES (`GLclampd` no existe en ES)

`Shader.cpp`/`ShaderLoadOpenGL.cpp` incluyen `qopenglext.h` de Qt directo (`#undef __glext_h_` + `#include <qopenglext.h>`), sin relación con el trabajo de 0.3 sobre `QOpenGLExtraFunctions` — es el registro completo de extensiones de Khronos que Qt empaqueta, y declara tipos exclusivos de desktop (`GLclampd`, de `GL_EXT_depth_bounds_test`) que no existen en ningún header de ES. Guardado con `#ifndef Q_OS_ANDROID` en los dos archivos. Reveló un uso real de una constante sin la misma suerte (Hallazgo 3).

### Hallazgo 3 — `GL_TEXTURE_LOD_BIAS` no existe en ES en ningún nivel

Con el include guardado, apareció `error: use of undeclared identifier 'GL_TEXTURE_LOD_BIAS'` en `Shader.cpp:694` (`GFX->glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_LOD_BIAS, GFX->lodBias)`), dentro del loop de binding de texturas por sampler. A diferencia de todo lo auditado en 0.3 (que inventarió **funciones** GL), esto es una **constante** sin equivalente ES — el bias de LOD en ES solo existe como argumento opcional de `texture()` en el shader, no como estado fijo por textura. Único call site en todo el proyecto. Guardado con `#ifndef Q_OS_ANDROID` (Android no aplica bias de LOD por ahora — no es funcionalidad core, es un ajuste de nitidez de mipmaps; si hiciera falta más adelante, necesitaría pasarse como uniform al shader, coordinado con el backend ES de 0.5, no antes).

### Hallazgo 4 y 5 — dos bugs reales en la rama OpenGL compartida, **no específicos de Android**

Con lo anterior resuelto, `GraphicsApiHandler.cpp` (el mismo archivo que 0.3 migró a `QOpenGLExtraFunctions`) falló con 3 errores:
- `isInitialized()` es privado en `QOpenGLExtraFunctions` (era público en `QOpenGLFunctions_3_1`, la clase que reemplazó 0.3). Arreglado: como `glContext` empieza en `nullptr` y se asigna en la primera línea de `Init()`, sirve como guardia de idempotencia sin necesitar el método de Qt.
- `initializeOpenGLFunctions()` devuelve `void` en la clase base `QOpenGLFunctions` (confirmado leyendo `qopenglfunctions.h:270` real) — las clases específicas de versión desktop (`_3_1`, `_4_3_Core`, etc.) la sobrescriben devolviendo `bool`, pero `QOpenGLExtraFunctions` no. Arreglado sacando el chequeo de retorno (ya no hay nada que chequear — `QOpenGLExtraFunctions` no promete una versión contra la cual poder fallar).

**Ninguno de los dos es específico de Android.** `GraphicsApiHandler.cpp` compila bajo `#if API_OPENGL`/`#else` — es la rama que usan Mac y Linux, no Windows (que usa D3D11 exclusivamente). Esta rama **nunca se había compilado en ningún punto de esta sesión** — 0.3 solo probó un fragmento aislado, no el archivo real integrado al proyecto. Confirma algo importante para la disciplina de verificación de acá en adelante: "compilé el archivo real, no un test aislado" y "lo compilé para Windows" no son la misma garantía cuando Windows toma una rama de código completamente distinta.

### Hallazgo 6 — `QThread::create()` no está disponible en esta build de Qt-Android

`World/Builder.cpp` usaba `QThread::create([...]{ ... })` para comprimir el caché de mundos en un hilo aparte. Error real: `no member named 'create' in 'QThread'`, con una cascada de errores de "captura implícita" en el lambda como síntoma secundario (una vez que `QThread::create(...)` no resuelve, el compilador pierde la pista del scope del lambda que le sigue como argumento). Causa raíz, confirmada leyendo `qthread.h` real: `QThread::create` está enteramente condicionado a `QT_CONFIG(cxx11_future)`, que Qt detecta en su propio momento de configure — **esta build de Qt-para-Android no tiene `std::future`/`std::async` disponibles** con esta combinación de NDK/libc++. Arreglado con el patrón clásico pre-C++11 (subclase de `QThread` con `run()`), sin depender de esa feature — único call site en todo el proyecto.

### Hallazgo 7 — símbolos sin resolver al linkear (esperados, no bugs)

Con el código 100% compilado, quedaron errores de **linkeo**, no de compilación:
- `glDeleteFramebuffers` (y el resto de `QOpenGLFunctions`) — el NDK separa símbolos ES2/ES3 en librerías versionadas (`libGLESv2.so`/`libGLESv3.so`), y hay que linkear explícitamente contra el sistema — a diferencia de escritorio, donde esto llega transitivo. Arreglado: `target_link_libraries(... GLESv3)`.
- `FT_Init_FreeType` y el resto de FreeType — `Asset/Font.cpp` llama FreeType directo (arquitectura ya sabida: la UI y el texto de Mine-imator se dibujan solos, no vía Qt Widgets nativos). Arreglado: se encontró que Qt trae su propio FreeType prebuildeado para Android (`install-android/lib/libqtfreetype_arm64-v8a.a`) y se linkeó.
- **Nuevo, todavía sin resolver:** linkear el FreeType de Qt reveló que a su vez necesita **zlib real** (`inflate`/`inflateEnd`/etc.) y **libpng real** (`png_create_read_struct`/etc.) — FreeType se compiló con soporte de fuentes PCF comprimidas y bitmaps embebidos en PNG. Ninguna de las dos existe todavía en `CppProject/External/Android/`.
- **Ya sabido, confirmado de nuevo:** `alGenSources`/`alcOpenDevice`/etc. de OpenAL — el `.so` usado era un placeholder vacío a propósito.
- El zlib **propio** de Mine-imator (`World/GZIP.cpp`, símbolos `z_gzopen`/`z_inflate`/etc. — el prefijo `z_` es el renombrado interno que usa Qt para su copia embebida de zlib) quedó sin confirmar en este último intento — el linker paró antes de llegar a reportarlo (`--error-limit`), pero por el mismo síntoma de Font.cpp, es казi seguro que también hace falta zlib real ahí.

## Contradicciones con CLAUDE.md

- **§11/0.3 y el `research/PHASE1_PLAN.md` original subestimaban el punto 4** ("barrido de APIs Windows-only") tratándolo como algo que un grep podía acotar razonablemente. La mitad de los bugs reales encontrados acá (`qopenglext.h`/`GLclampd`, `GL_TEXTURE_LOD_BIAS`, `isInitialized()`, `initializeOpenGLFunctions()` void) no son "APIs Windows-only" en absoluto — son diferencias de API entre clases de Qt (`QOpenGLFunctions_3_1` vs. `QOpenGLExtraFunctions`) y entre GL desktop y ES, invisibles a cualquier patrón de texto. Solo una compilación real los encuentra — confirma en la práctica lo que 0.3 ya había dicho en teoría sobre B1.
- **La lista de librerías externas necesarias (punto 1 del plan) estaba incompleta.** No se había anticipado que FreeType (vía Qt) necesita zlib y libpng reales además de las 5 librerías ya identificadas (OpenAL, libzip, FFmpeg×5). Corregido acá con evidencia de linker real, no supuesto.
- Confirma con evidencia nueva (no solo lectura de código) el patrón que 0.3/0.9 ya habían establecido: detectar soporte por función/símbolo puntual es más confiable que asumir "si compila en un lado, compila en todos" — la rama OpenGL de `GraphicsApiHandler.cpp` llevaba dos bugs reales sin que nadie los viera, simplemente porque nunca se había compilado.

## Incógnitas

- **Zlib real, para dos consumidores distintos:** FreeType (transitivo, símbolos planos `inflate`/etc.) y el `GZIP.cpp` propio de Mine-imator (símbolos `z_`-prefijados, que parecen ser el renombrado interno de Qt). No está confirmado si ambos pueden resolverse con la MISMA librería zlib, o si el segundo caso necesita específicamente compilar/usar la copia de zlib que trae Qt (con ese prefijo) en vez de un zlib genérico — pendiente de investigar cuando se aborde el punto 1 del plan.
- No se confirmó la lista completa de símbolos sin resolver más allá de lo que el linker reportó antes de su `--error-limit` — puede haber más, ocultos detrás de los ya encontrados (ej. libpng podría a su vez necesitar zlib también, y no se llegó a ver si hay algo más abajo de esa cadena).
- No se investigó si `androiddeployqt`/Gradle corren de verdad (el `build.gradle` corregido con AGP 8.7.0 nunca se ejecutó — el foco de esta pasada fue el compile+link de C++, no el empaquetado final del APK). Sigue siendo una incógnita real, ver `research/PHASE1_PLAN.md`.
- La copia de datafiles (`Data/`, `Particles/`, `Schematics/`) y el mecanismo de `install()` quedaron explícitamente excluidos para Android (`if(NOT ANDROID)`) sin ningún reemplazo — sigue sin decidirse si va como `assets/` de Android o embebido en el `.qrc` existente. No se tocó en esta pasada.
- No se corrió nada en un dispositivo/emulador real — todo lo de acá es compilación y link en el host, no ejecución.

## Decisión propuesta

**El punto 2 del plan (CMake/Gradle) queda funcionalmente resuelto y validado con una compilación real de las ~98.840 líneas del proyecto — no solo diseñado.** El punto 4 (barrido de APIs) queda cerrado con mucha más confianza que el grep original, con 5 bugs reales encontrados y arreglados, dos de ellos ni siquiera específicos de Android (bugs latentes en la rama OpenGL compartida). El punto 1 (librerías externas) queda con una lista confirmada y más completa que antes: OpenAL, libzip, zlib, libpng, FFmpeg (sin x264) — recomendado como el siguiente paso, porque es lo único que separa a este intento de un link exitoso.
