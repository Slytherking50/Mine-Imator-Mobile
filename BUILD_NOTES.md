# BUILD_NOTES

Registro de fallas y fixes al compilar Mine-imator 2.0.2 sin modificar (tarea 0.1, §11).

## Entorno final que funcionó
- Windows 11 25H2 64-bit
- Visual Studio Community 2022 (17.14.37614.0) — workload "Desktop development with C++" + componentes "C++ CMake tools for Windows" y "Git for Windows"
- Strawberry Perl 5.42.2 (build nativo MSWin32-x64, vía `winget install StrawberryPerl.StrawberryPerl`)
- `DEV_DIR=C:\Dev` (usuario, sin `/M` — no hizo falta admin para el resto del proceso)

## Fallas encontradas y fix

### F1 — VS2019 preexistente no alcanza
**Síntoma:** `WinUtils.ps1:38-41` tira `"Unsupported Visual Studio version 16.11...`. `Get-VisualStudioCMake` tampoco encuentra `cmake.exe` bajo la instalación de VS2019 existente.
**Causa:** el script exige explícitamente VS mayor 17 (2022) o 18 (2026); solo había VS2019 (16.x) instalado, y sin el componente de CMake.
**Fix:** instalar VS2022 Community con workload "Desktop development with C++" + componente individual "C++ CMake tools for Windows" + "Git for Windows". Verificado con `vswhere -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 Microsoft.VisualStudio.Component.VC.CMake.Project` → matchea VS2022 Community.
**No rompe nada:** VS2019 quedó instalado en paralelo sin conflicto.

### F2 — PATH desactualizado en sesiones de terminal ya abiertas
**Síntoma:** tras instalar Strawberry Perl vía `winget`, `Get-Command perl` no lo encuentra en una sesión de PowerShell ya abierta (sí en una `git-bash` nueva, pero resolviendo el Perl de Cygwin de Git, no el de Strawberry).
**Causa:** el proceso hereda el `PATH` que tenía al arrancar; los cambios de `winget`/instaladores al registro no se propagan a procesos ya vivos.
**Fix:** antes de correr `Setup.ps1`, refrescar `$env:PATH` explícitamente desde el registro en la misma sesión:
```powershell
$env:PATH = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [Environment]::GetEnvironmentVariable("Path","User")
```
Confirmado: con esto, `Get-Command perl.exe` resuelve a `C:\Strawberry\perl\bin\perl.exe` (nativo), no al de Git.

### F3 — Advertencia "vswhere.exe no reconocido" durante `Import-VisualStudioEnvironment`
**Síntoma:** al correr `Setup.ps1` (acción Qt), aparece `"vswhere.exe" no se reconoce como un comando interno o externo...` justo después de extraer `jom`, antes de "Configuring OpenSSL version 3.0.21".
**Confirmado benigno:** el build siguió y compiló OpenSSL, FFmpeg/x264, OpenAL, Libzip, y luego Qt5Core/Qt5DBus/Qt5Network/Qt5Sql completos sin un solo error real (revisado el log completo con `grep -i "error|fatal"`, cero matches genuinos — todos los "error" son nombres de archivo tipo `qsystemerror.cpp`). Es una diagnóstica interna de `VsDevCmd.bat` que no afecta nada. No requiere acción.

### F4 — Corte por apagado de PC a mitad de la compilación de Qt (2026-09-06)
**Síntoma:** el proceso de `Setup.ps1` terminó con `[exited with code 4]` justo al entrar a compilar QtGui (durante `syncqt.pl`/generación de fwd-include headers), con dos `WARNING: Failure to find: .../qt5gui_metatypes.json` como últimas líneas.
**Causa:** apagado de la PC a pedido del usuario, no un error de build — no hay ningún error de compilador/linker en las ~2500 líneas de log previas; Qt5Core, Qt5DBus, Qt5Network y Qt5Sql habían compilado limpio.
**Fix:** `Setup.ps1` no soporta resume incremental — `Build-Qt` borra `build/` e `install/` incondicionalmente al arrancar, y además pide confirmación interactiva (`Read-Host`) si `C:\Dev\Qt\5.15.19` ya existe, lo cual cuelga una sesión no interactiva. Se borró `C:\Dev\Qt\5.15.19` a mano antes de reintentar, para evitar el cuelgue. Se pierde el progreso parcial de Qt (hay que recompilarlo entero); OpenSSL/FFmpeg/OpenAL/Libzip no se rehacen (ya están extraídos en `C:\Dev` y copiados a `CppProject/External/Win64`).
**Nota operativa:** si va a haber otro corte de sesión previsible (apagado, etc.), mejor avisar *antes* de lanzar un paso largo como el build de Qt, no a mitad de camino — así se evita perder un progreso de build que no es recuperable incrementalmente.

## 0.1 CERRADA (2026-09-06)

Qt 5.15.19 compiló e instaló completo (`C:\Dev\Qt\5.15.19\install`). `Setup.ps1 Release` configuró CMake (encontró Qt, las 5 libs externas, OpenMP) y compiló+instaló `Mine-imator.exe` sin errores en `install/Mine-imator/`.

**Verificación de runtime, no solo de compilación:** se lanzó el ejecutable, quedó respondiendo (`Get-Process` → `Responding: True`), y se tomó una captura de pantalla real que muestra: splash "MINE-IMATOR v2.0.2 TRIAL", diálogo de bienvenida, y un modelo 3D de personaje con su rig de animación (círculos rojo/azul) renderizado en el viewport. Cumple el criterio de éxito de 0.1 (§11): "Ejecutable que abre, carga un proyecto y renderiza un frame." Proceso cerrado después de verificar.

**Entorno final documentado en la sección de arriba (VS2022 + Strawberry Perl + DEV_DIR=C:\Dev) es el que funciona de punta a punta.**

**Corrección (2026-09-06):** este documento decía antes que "OpenSSL/FFmpeg/OpenAL/Libzip se compilaron" durante esta sesión. Es falso — verificado con `git status`/`git ls-files`: los `.lib`/`.a` en `CppProject/External/Win64` ya venían **commiteados en el repo**, prebuildeados por el equipo de Mine-imator. `Setup.ps1` (acción `Qt`) solo extrae sus fuentes (`Ensure-SourceArchive`) para que Qt genere headers de OpenSSL — nunca se ejecutaron `Build-FFmpeg`/`Build-OpenAL`/`Build-Libzip`/build completo de OpenSSL en esta sesión, y por lo tanto **nunca se verificó que MSYS2 esté instalado** (de hecho no lo está: `C:\Dev\msys64` no existe). Si en algún momento hay que recompilar esas libs desde cero (por ejemplo al portar a otra arquitectura), hace falta instalar MSYS2 primero (`BUILD.md`, sección "Building libraries").

## Pendiente de completar
- (cerrado — ver arriba)

## Qt para Android — configure logrado (2026-09-06), build real todavía no arrancado

Objetivo: un Qt 5.15.19 compilado contra el NDK (target Android, OpenGL ES) para poder empezar 0.3 (migrar `GraphicsApiHandler`/`Shader` fuera de `QOpenGLFunctions_3_1`/`_4_3_Core`, que no existen en Qt-Android). `Setup.ps1` no contempla esto — es un `configure.bat` manual, nunca antes probado en este repo.

### Fallas encontradas y resueltas, en orden

**F5 — Bootstrap de qmake apunta a una ruta MinGW inexistente de otra máquina.**
Síntoma: `configure.bat` intenta compilar con `D:\Prog\winlibs64ucrt_stage\mingw64\bin\x86_64-w64-mingw32-g++.exe` — ruta que no existe en esta PC (ni siquiera existe el disco `D:`).
Causa real (confirmada): Strawberry Perl trae su propio MinGW embebido en `C:\Strawberry\c\bin\` (paquete basado en WinLibs), con esa ruta de build ajena incrustada en los binarios (`grep -rl winlibs64ucrt_stage C:\Strawberry` matchea `addr2line.exe`, `gcc.exe`, `c++.exe`, etc.). Algo en la cadena de detección de Qt prioriza ese `c++`/`gcc` de Strawberry por sobre cualquier otro que esté en PATH.
Fix: instalar MSYS2 (`winget install MSYS2.MSYS2`) con `mingw-w64-x86_64-gcc` y `make`, y **excluir explícitamente `Strawberry\c\` del PATH** al armar el entorno (filtrar esa entrada, no alcanza con anteponer MSYS2).

**F6 — Falta `mingw32-make.exe`.**
MSYS2 solo trae `make.exe`. Qt/configure.bat busca específicamente `mingw32-make`. Fix: `cp make.exe mingw32-make.exe` en `C:\msys64\usr\bin\`.

**F7 — Mezcla de paths POSIX/Windows en headers generados por syncqt.**
Síntoma: `#include "../../../../../../../c/Dev/Qt/5.15.19/.../qglobal.h"` — ruta rota, mitad posix mitad relativa.
Causa: `C:\msys64\usr\bin\perl.exe` (MSYS2 trae su propio Perl como dependencia) tomaba precedencia sobre Strawberry Perl al tener `usr\bin` antes en el PATH. El Perl de MSYS2 reporta rutas en notación POSIX (`/c/Dev/...`), rompiendo el cálculo de rutas relativas de `syncqt.pl`.
Fix: orden de PATH final que funciona: `mingw64\bin` (gcc/g++) → `Strawberry\perl\bin` (perl real, rutas Windows) → `msys64\usr\bin` (make/sh) → resto del PATH sin `Strawberry\c\`.

**F8 — `NMAKE fatal error U1045` al generar el Makefile del target Android.**
Con el entorno de MSVC activo (para arreglar el bootstrap), el bootstrap funcionaba pero el Makefile generado para `android-clang` (que mezcla `\` y `/` en las rutas del NDK) es sintácticamente incompatible con `nmake`. **Conclusión: el target `android-clang` requiere GNU make de punta a punta, no se puede resolver el bootstrap con MSVC/nmake y despues usar GNU make para el resto** — hay que resolver el bootstrap con un GCC real (ver F5), no cambiar de herramienta de make a mitad de camino.

**F9 (activa, resuelta) — `NMAKE`/acceso denegado al invocar `clang++` del NDK.**
Con la ruta fantasma de F5 todavía sin resolver, el primer intento con NDK+nmake daba `0x80070005 Acceso denegado` al invocar clang++ — en realidad era la ruta fantasma la que fallaba, el mensaje de "acceso denegado" fue una pista falsa (el path real de clang++ del NDK funciona perfecto invocado a mano). Se resolvió como consecuencia de F5.

### Resultado: `configure.bat` para `android-clang arm64-v8a` corre limpio, exit code 0

Comando final que funciona (desde `build-android/`, PATH según F5/F7 arriba, sin entorno MSVC activo):
```powershell
qt5\qtbase\configure.bat -xplatform android-clang -android-ndk C:\Android\ndk\27.3.13750724 -android-sdk C:\Android -android-ndk-host windows-x86_64 -android-arch arm64-v8a -external-hostbindir C:\Dev\Qt\5.15.19\install\bin -opensource -confirm-license -nomake tests -nomake examples -prefix C:\Dev\Qt\5.15.19\install-android
```

### Hallazgo nuevo, directamente relevante a B1/0.3: el resumen de configure reporta **OpenGL ES 2.0: sí, ES 3.0/3.1/3.2: no**

**Causa raíz: es un falso negativo de capacidades por nivel de API, no una limitación real de la plataforma/NDK.** Esta distinción importa porque es exactamente el tipo de resultado que, leído sin investigar, lleva a descartar una ruta técnica viable por error.

Evidencia en `config.log`: el test `opengles3` falla al *linkear* (no al compilar) — `ld.lld: undefined symbol: glGetStringi/glReadBuffer/glUniformMatrix2x3fv/glMapBufferRange`, con el linker señalando que busca esos símbolos en `.../sysroot/usr/lib/aarch64-linux-android/**21**/libGLESv2.so`. El NDK expone stubs de `libGLESv2.so` **por nivel de API**, y el nivel 21 (default de Qt, porque no pasé `-android-ndk-platform`) solo expone símbolos de ES 2.0 en su stub — aunque ES 3.0 como especificación existe desde API 18 y el hardware real la soporta hace más de una década. El problema es enteramente del stub de link-time pedido, no de lo que el dispositivo/driver puede hacer en runtime.

**Corrección del diagnóstico inicial (2026-09-06):** `-android-ndk-platform android-24` **no alcanzó**. Reconfiguré con ese flag y el resumen siguió diciendo `OpenGL ES 3.0: no`. Investigué más — el nivel de API nunca fue la causa real:

- `config.log` mostró que, incluso apuntando al stub de nivel 24 (`.../sysroot/usr/lib/aarch64-linux-android/24/libGLESv2.so`), el linker sigue sin encontrar `glGetStringi`/`glReadBuffer`/`glUniformMatrix2x3fv`/`glMapBufferRange`.
- Verificado con `nm -D` sobre ese `.so`: esos símbolos genuinamente no están ahí, en ningún nivel de API de este NDK.
- Pero SÍ existen en un archivo separado: `libGLESv3.so` (confirmado con `find`, presente desde nivel 21 en adelante). Este NDK (r27) mantiene los símbolos de ES 3.0 en una librería propia, no fusionados en `libGLESv2.so` como asumen los mkspecs de Qt 5.15 (escritos para NDKs más viejos donde sí estaban fusionados).
- Probé a mano: agregar `-lGLESv3` a la línea de link del test real → linkea sin error, exit 0. Confirma la causa exacta.

**Causa raíz real: `QMAKE_LIBS_OPENGL_ES2 = -lGLESv2` en `mkspecs/features/android/default_pre.prf:68` no incluye `-lGLESv3`, y esta variable gobierna el link tanto del test de configure como del módulo QtGui real** — no era un problema de nivel de API, era una asunción desactualizada de Qt 5.15 sobre cómo el NDK organiza estas librerías. Esto es exactamente el tipo de falso negativo que hace descartar una ruta viable si no se investiga la causa hasta el final: "OpenGL ES 3.0: no" sonaba a "este NDK/target no da para ES 3.0", cuando en realidad el hardware, el NDK y el nivel de API elegido soportan ES 3.0 perfectamente — solo faltaba una librería en la línea de link.

**Fix aplicado:** editado `C:\Dev\Qt\5.15.19\qt5\qtbase\mkspecs\features\android\default_pre.prf:68` → `QMAKE_LIBS_OPENGL_ES2 = -lGLESv2 -lGLESv3`. Es un cambio en el clon local de Qt (`C:\Dev\Qt`), no en el repo de Mine-imator — no aplica ninguna regla de "no tocar Generated/" del proyecto, es infraestructura de build regenerable.

**Confirmado tras reconfigurar:** `OpenGL ES 2.0: yes`, `OpenGL ES 3.0: yes`, `OpenGL ES 3.1: yes`, `OpenGL ES 3.2: yes` (y de yapa, `Vulkan: yes`). El piso de §5.6 del CLAUDE.md (ES 3.0 mínimo, con SSBO/batching en ES 3.1+) queda cubierto de punta a punta con esta configuración de Qt.

**Comando final que funciona** (repetible desde cero, incluye el patch de `default_pre.prf` como prerrequisito):
```powershell
qt5\qtbase\configure.bat -xplatform android-clang -android-ndk C:\Android\ndk\27.3.13750724 -android-sdk C:\Android -android-ndk-host windows-x86_64 -android-ndk-platform android-24 -android-arch arm64-v8a -external-hostbindir C:\Dev\Qt\5.15.19\install\bin -opensource -confirm-license -nomake tests -nomake examples -prefix C:\Dev\Qt\5.15.19\install-android
```

### Build real en curso (2026-09-06)

Corriendo `mingw32-make -j16` (16 núcleos disponibles) desde `build-android/`.

**F10 — `androiddeployqt`/`androidtestrunner` no compilan: bug de GCC 16.2 (MSYS2) en su propio header `<limits>`.**
Síntoma: `error: exponent has no digits` / `error: unable to find numeric literal operator 'operator""Q'` en `C:/msys64/mingw64/include/c++/16.2.0/limits`, al compilar `src/tools/androiddeployqt/main.cpp` y `src/tools/androidtestrunner/main.cpp` (verificado con las líneas de comando reales del log: son `g++`, no el clang del NDK — estas dos son herramientas que corren en la PC del desarrollador, no binarios Android).
Causa: la flag `-U__STRICT_ANSI__` que usa el mkspec `win32-g++` para estos host-tools, combinada con `-std=c++11` y el header `<limits>` de GCC 16.2 (que declara literales `__float128` con sufijo `Q`, una extensión GNU), rompe en esta versión de GCC. No es nada del proyecto ni de Android — es una interacción específica MSYS2/GCC 16.2 + flags de Qt 5.15.
Impacto: `androiddeployqt` (empaqueta el APK final) y `androidtestrunner` (corre tests en el dispositivo) no se pueden compilar todavía. **No bloquea lo que necesitamos ahora** (compilar `GraphicsApiHandler`/`Shader` contra las librerías de Qt para 0.3) — son herramientas de fases posteriores (empaquetado real de APK, Fase 7 export / testing en dispositivo).
Fix aplicado por ahora: `mingw32-make -j16 -k` (sigue de largo pese al error) — confirmado que continúa y compila `QtGui` normalmente después. Fix real pendiente para cuando haga falta `androiddeployqt`: parchear esos dos `.pro`/mkspec para no pasar `-U__STRICT_ANSI__`, o compilarlos con `-std=c++17`, o esperar una versión de MSYS2 con GCC más vieja.

### CERRADO — Qt 5.15.19 para Android (arm64-v8a) instalado y verificado (2026-09-06)

`mingw32-make -j16 -k` y `mingw32-make install -k` corrieron de punta a punta. Único fallo real en ambos: F10 (`androiddeployqt`/`androidtestrunner`, no bloquea). Verificado con `grep -v` sobre el patrón de F10 que no quedó ningún otro error.

**Instalado en `C:\Dev\Qt\5.15.19\install-android\`:**
- Librerías: `Qt5Core`, `Qt5Gui`, `Qt5Widgets`, `Qt5OpenGL`, `Qt5Network`, `Qt5Sql`, `Qt5Xml`, `Qt5Concurrent`, `Qt5Test`, `Qt5PrintSupport` — todas `arm64-v8a`, todas con ES 3.0/3.1/3.2 confirmado.
- Plugins: `platforms/libplugins_platforms_qtforandroid_arm64-v8a.so` (el plugin QPA de Android — necesario para que la app arranque en el dispositivo), `imageformats` (gif/ico/jpeg), `sqldrivers/qsqlite`, `styles/qandroidstyle`, `bearer/qandroidbearer`.

**Esto es lo que hacía falta para arrancar 0.3.** Ya se puede compilar y linkear código C++ (como el `GraphicsApiHandler`/`Shader` migrados a `QOpenGLExtraFunctions`) contra este Qt, apuntando `CMAKE_PREFIX_PATH`/`QT_BASE_DIR` a `C:\Dev\Qt\5.15.19\install-android` en vez del de escritorio.

### Pendiente (para cuando se retome)
- F10 (`androiddeployqt`/`androidtestrunner`) — solo hace falta antes de empaquetar un APK real o correr tests en dispositivo, no para el prototipo de 0.3.
- Extender/duplicar `CppProject/CMakeLists.txt` para poder targetear este Qt-Android además del de escritorio (hoy solo conoce el de escritorio).
- Confirmar la decisión de `minSdkVersion` (GATE G1, todavía abierto) antes de fijar el `-android-ndk-platform` "de producto" definitivo — usamos `android-24` acá porque es el piso técnico de ES 3.0, pero el piso real de la app puede terminar siendo más alto (26 o 29, ver conversación).

## Corte de sesión 2026-09-06 — PC se apaga a mitad del build de Qt

**Checkpoint alcanzado antes del corte:** OpenSSL, FFmpeg/x264, OpenAL y Libzip ya compilados y copiados a `CppProject/External/Win64`. Qt clonado (`code.qt.io/qt/qtbase`) y configurado. `jom` llegó a linkear `qmake.exe` — es decir, la compilación de Qt en sí ya había arrancado quando se cortó. F3 (warning de `vswhere.exe`) nunca volvió a aparecer ni frenó nada — se puede marcar como benigno.

**Para retomar en la próxima sesión:**
1. `Build-Qt` en `Setup.ps1:573-579` pide confirmación interactiva (`Read-Host`) si `C:\Dev\Qt\5.15.19` ya existe — eso cuelga una terminal no interactiva esperando una respuesta que nunca llega. **Borrar esa carpeta a mano antes de re-correr** (`Remove-Item -Recurse -Force C:\Dev\Qt\5.15.19`) para evitar el cuelgue. No hay nada valioso ahí (es solo el checkout/build de Qt, 100% reproducible).
2. Volver a correr, desde `Mine-imator/`, refrescando PATH y DEV_DIR primero (ver F2 arriba):
   ```powershell
   $env:PATH = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [Environment]::GetEnvironmentVariable("Path","User")
   $env:DEV_DIR = "C:\Dev"
   .\Setup.ps1
   ```
3. El build de Qt se reinicia desde cero (no hay resume incremental en `Setup.ps1` — `Build-Qt` borra `build`/`install` incondicionalmente). OpenSSL/FFmpeg/OpenAL/Libzip **no** se vuelven a compilar (`Ensure-SourceArchive` detecta que las carpetas fuente ya existen en `C:\Dev` y no las re-extrae; sus binarios ya están copiados a `CppProject/External/Win64`).
