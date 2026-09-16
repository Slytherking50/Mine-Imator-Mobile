# Fase 1 — Empaquetado real del APK (androiddeployqt/Gradle) (2026-09-08)

## Pregunta

Con el `.so` de Mine-imator ya compilando y linkeando para Android (`research/2026-09-08-fase1-external-libraries-android.md`), ¿el paso de empaquetado real (`androiddeployqt` + Gradle, nunca antes intentado en este proyecto) también funciona, o hay más sorpresas?

## Método

Correr el target `apk` que genera `Qt5AndroidSupport.cmake` (`cmake --build . --target apk`), arreglando cada problema real que aparezca, verificando el resultado con herramientas (`aapt list`), no asumiendo éxito por el código de salida del wrapper.

## Hallazgos

### 1. `androiddeployqt.exe` no existía en la instalación de Qt-Android

`find_program(ANDROID_DEPLOY_QT androiddeployqt)` (dentro de `Qt5AndroidSupport.cmake`) devolvía `NOTFOUND`. Confirmado con `find`: el binario no está en `install-android/bin` ni en ningún lado de la instalación. Sí está su fuente (`qt5/qtbase/src/tools/androiddeployqt/`, parte de qtbase, `option(host_build)`) y, más útil todavía, un **build parcial ya iniciado** en el árbol de build original de Qt-Android (`build-android/src/tools/androiddeployqt/`: `Makefile` real + un `.o` de recursos ya compilado, pero nunca el binario final). Se terminó ese build con `mingw32-make release` (el host de esta instalación de Qt usa `win32-g++`/MinGW para sus herramientas de host, no MSVC — confirmado con `qmake -query QMAKE_SPEC`), usando el `mingw32-make` que ya trae Strawberry Perl. Compiló limpio, se copió a `install-android/bin/androiddeployqt.exe`.

### 2. `find_program`/`find_library` no encontraban nada fuera del sysroot del NDK, aun con las herramientas ya en el lugar correcto

Dos problemas de la misma familia, uno tras otro:

- `find_program(ANDROID_DEPLOY_QT androiddeployqt)` seguía devolviendo `NOTFOUND` incluso después de compilar el binario. La causa real no fue el modo de cross-compile (`CMAKE_FIND_ROOT_PATH_MODE_PROGRAM` ya estaba en `BOTH` desde el arranque de este árbol de build, pasado por línea de comandos) sino que `install-android/bin` simplemente no estaba en ninguna lista de búsqueda (ni `PATH` del proceso, ni `CMAKE_PROGRAM_PATH`). Arreglado agregando `CMAKE_PROGRAM_PATH` con `${QT_INSTALL_DIR}/bin` antes de `find_package(Qt5)`.
- Con `androiddeployqt` ya encontrado, `android_deployment_settings.json` salía con `"architectures": {}` vacío → `androiddeployqt` fallaba con "No target architecture defined in json file". Causa: el módulo de Qt decide qué arquitecturas incluir probando `find_library(Qt5Core_${abi}_Probe Qt5Core_${abi})` para cada ABI soportada — y ese `find_library`, al cross-compilar, se restringe por defecto a `CMAKE_FIND_ROOT_PATH` (el sysroot del NDK), que no incluye el prefijo de instalación de Qt. El archivo `libQt5Core_arm64-v8a.so` existe (confirmado con `find`), pero fuera de esa raíz. Arreglado con el patrón estándar de CMake para un segundo prefijo de cross-compile: `list(APPEND CMAKE_FIND_ROOT_PATH "${QT_INSTALL_DIR}")`.

Ninguno de los dos arreglos fue "bajar la guardia" del cross-compile (no se tocó `ONLY`→`ALWAYS` ni nada por el estilo) — fue decirle a CMake dónde más mirar, sin abrir la búsqueda a cualquier cosa del sistema host.

### 3. AGP 8.x ya no infiere el namespace del `AndroidManifest.xml`

Con lo anterior resuelto, `androiddeployqt` corrió Gradle de verdad por primera vez — y Gradle falló en la fase de *configuración* (antes de compilar nada): `Namespace not specified. Specify a namespace in the module's build file`. La plantilla de `build.gradle` (heredada de Qt 5.15, pensada para AGP viejo) declara el paquete solo vía `package="..."` en el manifest, que es como se hacía hasta AGP 7. AGP 8 eliminó esa vía de inferencia (no es una advertencia, es un error duro). Arreglado agregando `namespace 'org.internal.testbuild'` al bloque `android {}` de `build.gradle`, con el mismo placeholder que ya tenía el manifest.

### 4. Un fallo real puede dejar el proceso colgado sin avisar — encontrado en producción, no en teoría

El primer intento con el bug del namespace **falló de verdad** (`BUILD FAILED in 28s`, confirmado en el log del daemon de Gradle) pero el proceso completo (`cmake.exe` → `ninja.exe` → `cmd.exe` → `gradlew.bat`) quedó colgado **45 minutos** sin devolver el control ni producir ninguna salida nueva — ni error, ni notificación de finalización. Confirmado con `Get-CimInstance Win32_Process`: `ninja.exe`/`cmake.exe` seguían vivos mucho después de que el daemon de Gradle ya había marcado el build como terminado (`Marking the daemon as idle`) y había cerrado la conexión. La causa exacta (algo en cómo `gradlew.bat` o `cmd.exe /C "..."` manejan el cierre bajo esta cadena de wrappers) no se investigó a fondo — el fix práctico fue matar el árbol de procesos (`Stop-Process`) y reintentar. **Lección para el resto de este proyecto:** un build de Android que "no progresa" no se puede asumir que sigue trabajando solo porque el proceso sigue vivo — hay que cruzarlo contra una fuente más confiable (el log del daemon de Gradle, en este caso) antes de esperar indefinidamente.

## Resultado

`BUILD SUCCESSFUL in 16s`, 34 tareas ejecutadas. Primer `.apk` real del proyecto:

`build-android-test/android-build/Mine-imator.apk` (20.9 MB)

Verificado con `aapt list` (no solo por el mensaje de éxito) que el `.apk` contiene todo lo esperado: `libMine-imator_arm64-v8a.so` (nuestro binario), las 4 librerías de Qt (`Qt5Core`, `Qt5Gui`, `Qt5Network`, `Qt5Widgets`), las 5 de FFmpeg, OpenAL, libzip, `libc++_shared.so`, y los plugins de Qt para Android (plataforma, formatos de imagen, estilo, bearer). `libqtlibpng.a` no aparece porque es estática — ya está absorbida dentro de `libMine-imator_arm64-v8a.so`, como se esperaba.

## Contradicciones

Ninguna con hallazgos previos.

## Incógnitas que quedan

- El `.apk` nunca se instaló ni se corrió en un dispositivo/emulador real — nada garantiza todavía que arranque, dibuje algo, o no crashee de inmediato.
- El hueco de datafiles/assets (`Data/`, `Particles/`, `Schematics/`, shaders) sigue sin resolver — es más probable que aparezca en cuanto se corra de verdad.
- La causa raíz exacta del cuelgue de `gradlew.bat`/`cmd.exe` (hallazgo 4) no se investigó — quedó resuelto por workaround (matar el proceso), no por diagnóstico completo. Si vuelve a pasar en futuras compilaciones, vale la pena investigarlo en serio.
- El manifest sigue con `package="org.internal.testbuild"`, que Gradle ahora marca como redundante/ignorado (recomienda sacarlo) — no bloqueante, cosmético.

## Decisión

Empaquetado real (`androiddeployqt`/Gradle) — **cerrado y validado con un `.apk` real, verificado con `aapt`.** Sigue: instalar y correr en un dispositivo/emulador real, y resolver el hueco de datafiles/assets que probablemente aparezca al hacerlo.
