# Fase 1, punto 1 — Librerías externas para Android (2026-09-08)

## Pregunta

¿Qué hace falta compilar/conseguir para que el link de `CppProject` para Android arm64-v8a resuelva todos los símbolos externos (zip, OpenAL, FFmpeg, FreeType→zlib/libpng), y cómo se consigue cada uno?

## Método

Para cada dependencia: confirmar por qué hace falta (símbolo real, no supuesto), buscar si el NDK ya la trae, y si no, compilarla desde la fuente ya presente en `C:/Dev` contra el toolchain del NDK (`android.toolchain.cmake`, `arm64-v8a`, `android-29`), verificando cada resultado con `llvm-nm` y con un intento de build real del proyecto completo.

## Hallazgos

### 1. zlib — no hace falta compilar nada

El NDK r27 trae un zlib de sistema completo y sin prefijo (`usr/include/zlib.h` + `usr/lib/aarch64-linux-android/29/libz.so`). El único motivo por el que el proyecto no lo usaba directamente es que `CMakeLists.txt` agregaba incondicionalmente `QtZlib` (la copia interna de Qt) al include path — esa copia define `Z_PREFIX`, que hace que `zconf.h` renombre cada símbolo público con un macro de preprocesador (`#define inflate z_inflate`, etc.) para que el uso interno de Qt no choque con un zlib de la app. `GZIP.cpp`/`NBT.cpp` llaman `inflate()` en el código fuente; en desktop eso se reescribe a `z_inflate()` por el macro. En Android, sacando `QtZlib` del include path (guardado con `if(NOT ANDROID)`), `<zlib.h>` resuelve a la cabecera plana del NDK — mismo código fuente, sin cambios, ahora linkea contra el símbolo plano. Confirmado también que el `FreeType` prebuilt de Qt para Android (`libqtfreetype_arm64-v8a.a`) necesita el zlib plano (símbolo `inflate` sin prefijo), así que la misma librería de sistema sirve para los dos consumidores.

### 2. libpng — se compiló desde la fuente empaquetada de Qt

`llvm-nm -u libqtfreetype_arm64-v8a.a | grep png_` confirmó por linker (no por suposición) que el FreeType de Qt para Android necesita `libpng` real (bitmaps de color embebidos en fuentes). El NDK no trae libpng de sistema (a diferencia de zlib — se buscó explícitamente en `usr/lib`/`usr/include` y no está). Mine-imator no toca libpng directamente (grep sin resultados).

Qt empaqueta su propio libpng (`qt5/qtbase/src/3rdparty/libpng`, versión 1.6.47) pero **sin** soporte CMake — solo un `.pro` de qmake. Se escribió un `CMakeLists.txt` standalone (`C:/Dev/build-android-libpng/CMakeLists.txt`, fuera del árbol de Qt) que replica exactamente la lista de fuentes y los `DEFINES` de `libpng.pro` (`PNG_ARM_NEON_OPT=0`, etc.). Compilado como estática (`libqtlibpng.a`) — la licencia de libpng es permisiva, no hay requisito LGPL de "reemplazable" como con FFmpeg. Copiado a `CppProject/External/Android/libqtlibpng.a`, linkeado antes que `z` en el `CMakeLists.txt` del proyecto.

### 3. OpenAL-soft — compilación directa, sin sorpresas

La fuente (`openal-soft-1.24.3`) ya trae su propio `XCompile-Android.txt` confirmando el patrón estándar (toolchain del NDK, sin flags especiales más allá de lo ya usado). Configurado con `LIBTYPE=SHARED`, sin ejemplos/utils. CMake detectó y habilitó el backend `OpenSL` (nativo de Android) automáticamente — no se intentó Oboe (no está descargado como dependencia, y OpenSL es funcionalmente suficiente para esta fase; Oboe daría menor latencia pero no está en el alcance de "que arranque y dibuje"). Resultado: `libopenal.so`, copiado a `External/Android/`.

### 4. libzip — compilación directa, deshabilitando codecs opcionales

`FileLib.cpp` solo usa `zip_open`/`zip_fopen_index` (zip plano, sin cifrado) — confirmado por grep antes de decidir qué deshabilitar. Configurado con `BUILD_SHARED_LIBS=ON` y todos los codecs opcionales apagados (`ENABLE_BZIP2/LZMA/ZSTD/OPENSSL/GNUTLS/MBEDTLS/COMMONCRYPTO/WINDOWS_CRYPTO=OFF`), ya que Mine-imator no los necesita. CMake resolvió `ZLIB` automáticamente contra el zlib de sistema del NDK (`Found ZLIB: .../libz.so`), confirmando independientemente el hallazgo del punto 1. Resultado: `libzip.so`.

**Nota, no bloqueante:** el `zipconf.h` compartido en `External/Sources/zipconf.h` (usado también por Android) define `ZIP_STATIC`, mientras que un `zipconf.h` generado de verdad para Android no lo define. Se comparó contra `zip.h`: `ZIP_EXTERN` solo depende de `ZIP_STATIC` bajo `#ifdef _WIN32` — en cualquier otra plataforma cae a `__attribute__((visibility("default")))` si `ZIP_STATIC` NO está, o queda vacío si SÍ está. El proyecto no define `-fvisibility=hidden` en ningún lado (grep sin resultados), así que la visibilidad por defecto del compilador ya es pública — el `ZIP_STATIC` heredado del archivo compartido no cambia el comportamiento real en Android. Confirmado, no es necesario un `zipconf.h` separado por plataforma (a diferencia de `avconfig.h`, ver punto 5).

### 5. FFmpeg sin x264/GPL — la pieza más compleja, dos problemas reales encontrados

Configuración replicada de `Setup.ps1:380-405` (mismos `--enable-parser/decoder/demuxer/muxer`), quitando `--enable-libx264`/`--enable-gpl`/el encoder `libx264` (per B5), agregando `--enable-shared --disable-static` (LGPL exige que sea reemplazable — en Android eso significa `.so` dinámico, no estático) y apuntando `--cc`/`--cxx`/`--ar`/`--ranlib`/`--strip`/`--nm`/`--sysroot` al toolchain del NDK (`aarch64-linux-android29-clang`, etc.). `--disable-asm` para la primera compilación real (evita la complejidad de ensamblador ARM NEON en este primer intento; posible optimización futura, no bloquea "que arranque y dibuje").

**Problema 1 — `make` del NDK no sirve para esto.** El `make.exe` que trae el NDK (`prebuilt/windows-x86_64/bin/make.exe`) es un binario nativo de Windows sin capa de traducción de rutas POSIX. El `Makefile` que genera `configure` (corrido bajo Git Bash) usa rutas estilo `/c/Dev/FFmpeg/...`; el `make.exe` nativo no las entiende (`No such file or directory` para un archivo que sí existe) y además no puede ejecutar los wrappers de compilador del NDK sin extensión (son scripts bash, no `.exe`/`.cmd`, y `CreateProcess` de Windows no entiende shebang). Esto es exactamente el problema que `Setup.ps1` ya resuelve para el build de escritorio usando MSYS2 (`Invoke-MsysBash`) — pero MSYS2 no estaba instalado en esta máquina. **Se instaló MSYS2** (tarball base oficial, `C:/Dev/msys64`, misma ruta que `Setup.ps1` ya espera) con `pacman -S make pkgconf nasm diffutils`. Con el `bash`+`make` de MSYS2 (y el toolchain del NDK primero en el `PATH`), `configure`+`make`+`make install` corrieron sin problemas.

**Problema 2 — `libavutil/avconfig.h` es específico de arquitectura, no solo de compilador.** `MovieLib.cpp` incluye `libavcodec/avcodec.h`, que transitivamente necesita `libavutil/avconfig.h` — un header generado por `configure`, no parte de la fuente pura de FFmpeg (confirmado: no existe en ningún lado del checkout limpio de `ffmpeg-5.1.10`, solo en `build*/libavutil/avconfig.h` tras correr `configure`). El proyecto ya tenía una copia versionada de este archivo en `CppProject/External/Sources/libavutil/avconfig.h` (generada alguna vez para Windows/x86_64) que el include path comparte entre todas las plataformas sin distinción. Comparando esa copia contra la generada de verdad para `aarch64-linux-android29`: **difieren** — `AV_HAVE_FAST_UNALIGNED` es `1` en la de Windows y `0` en la de Android real (aarch64 no garantiza acceso rápido a memoria desalineada de la misma forma que x86_64). Esto no es cosmético: ese define cambia qué implementación usan varias rutas internas de `libavutil` (lectura/escritura de enteros sin alinear). Iba a haber sido un bug real, silencioso y específico de Android si se hubiera usado la copia de Windows sin darse cuenta — **no era un problema de "cross-compile" en general, sino algo que solo se ve comparando ambas copias generadas de verdad.**

Arreglado en `CMakeLists.txt`: para `ANDROID`, se agrega `EXTERNAL_PLATFORM_DIR` (que ahora incluye `libavutil/avconfig.h`, copiado de una corrida real de `configure` contra el NDK) al include path **antes** que `External/Sources`, así la copia correcta gana por orden de búsqueda sin tocar el comportamiento de Windows.

Con licencia resultante confirmada por el propio `configure`: `License: LGPL version 2.1 or later` — confirma por herramienta, no por lectura de flags, que sacar `--enable-gpl`/`--enable-libx264` efectivamente saca el código GPL (per B5).

Resultado: `libavcodec.so`, `libavformat.so`, `libavutil.so`, `libswresample.so`, `libswscale.so` — copiados a `External/Android/`, cada uno confirmado con símbolos reales exportados (`llvm-nm -D libavcodec.so` → 155 símbolos `T`, no un stub vacío).

## Resultado final — verificado con build real, no solo con las piezas sueltas

Con las 5 librerías + libpng + el fix de `avconfig.h` en su lugar, se corrió `cmake --build .` completo sobre `build-android-test/` (reconfigurado desde cero): **160 archivos compilados, 0 errores, link exitoso.** `android-build/libs/arm64-v8a/libMine-imator_arm64-v8a.so` generado, 72.6 MB, sin ninguna mención de "undefined reference"/"undefined symbol" en todo el log (grep explícito, sin resultados). **Es la primera vez que el 100% de `CppProject` compila Y linkea para Android — no solo compila.**

## Contradicciones

Ninguna con hallazgos previos. El hallazgo del punto 5 (avconfig.h específico de plataforma) es nuevo, no anticipado en `research/2026-09-08-fase1-android-cmake-first-build.md` (esa sesión llegó solo hasta errores de compilación, nunca llegó al link real de FFmpeg).

## Incógnitas que quedan

- `--disable-asm` en FFmpeg: se dejó así para la primera compilación real. Si el rendimiento de decodificación de audio/video importa en la práctica, vale la pena revisar si vale la pena habilitar asm ARM NEON más adelante — no bloquea esta fase.
- No se probó `androiddeployqt`/Gradle real todavía (empaquetar el `.so` en un `.apk` real) — el alcance de esta sesión fue el link de C++, no el armado final del paquete.
- Sigue sin resolverse el hueco de datafiles/assets (`Data/`, `Particles/`, `Schematics/`, shaders) — ver `research/2026-09-08-fase1-android-cmake-first-build.md`.
- No se corrió nada en un dispositivo/emulador real todavía — esto es compilación + link en el host, nada más.
- MSYS2 quedó instalado en `C:/Dev/msys64` con `make`/`pkgconf`/`nasm`/`diffutils` — si se necesita reconstruir FFmpeg (nueva versión, flags distintos), ya está listo, no hace falta reinstalar.

## Decisión

Punto 1 de `PHASE1_PLAN.md` — **cerrado y validado con build real.** Las 5 librerías compiladas están en `CppProject/External/Android/`, wireadas en `CMakeLists.txt`, y el proyecto completo linkea. Sigue: probar `androiddeployqt`/Gradle real, y resolver el hueco de datafiles/assets.
