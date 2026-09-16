# Investigación: Prototipo de GraphicsApiHandler sobre QOpenGLExtraFunctions (tarea 0.3, resuelve/confirma B1)

## Pregunta

¿Tiene solución real B1 (`QOpenGLFunctions_3_1`/`_4_3_Core` no existen en Qt-Android)? Si se migra `GraphicsApiHandler`/`Shader` a `QOpenGLExtraFunctions`, ¿compila contra un Qt-Android real, y qué funciones GL usadas hoy por el código no tienen equivalente, clasificadas por versión de ES?

## Método

1. Se creó la rama `fase0-0.3-graphicsapihandler-prototype` (§15.2 — nunca en master).
2. Se confirmó primero, con el compilador real (no solo lectura de código), que el problema original existe: se intentó heredar de `QOpenGLFunctions_3_1` e instanciar `QOpenGLFunctions_4_3_Core` contra el Qt-Android compilado en esta sesión (`C:\Dev\Qt\5.15.19\install-android`, NDK r27, `clang++ -target aarch64-linux-android24`).
3. Se migró `CppProject/Render/GraphicsApiHandler.hpp`: `#include <QOpenGLFunctions_3_1>` → `#include <QOpenGLExtraFunctions>`, y la herencia de `GraphicsApiHandler` del mismo modo. `Shader.hpp` (que declara `gl43Core`) **no se tocó** — ver Hallazgos, es justamente donde aparece la única función sin equivalente.
4. Se armó un inventario completo de llamadas GL reales con `grep` sobre `CppProject/Render` y `CppProject/Asset`: patrón `GFX->gl[A-Za-z0-9_]+|gl43Core->gl[A-Za-z0-9_]+` más una pasada adicional por llamadas directas (sin prefijo) dentro de `GraphicsApiHandler.cpp` (que hereda las funciones GL directamente).
5. Se escribió un test aislado (`gl_inventory_test.cpp`) que hereda de `QOpenGLExtraFunctions` (igual que el `GraphicsApiHandler` real) y llama a cada una de las ~49 funciones distintas encontradas, con las firmas reales de OpenGL ES. Se compiló con el `clang++` del NDK real contra los headers del Qt-Android real, `-fsyntax-only`-equivalente (`-c`, sin linkear).
6. Para la función que no compiló, se verificó con un test negativo separado que el fallo es real (no un error de configuración del test), y se buscó en todo el árbol de headers de este Qt-Android (`grep -rl`) en qué clases SÍ existe, para confirmar que es exclusiva de las clases desktop.
7. No se intentó compilar los `.cpp` reales completos: arrastran `Generated/GmlFunc.hpp`, `AppHandler.hpp`, `AppWindow.hpp` y el resto del árbol de dependencias de la app — fuera de alcance para un prototipo de Fase 0 (eso es Fase 1, "APK que arranca y dibuja un triángulo"). El test aislado es un compromiso deliberado: prueba las firmas reales contra el compilador y headers reales, sin necesitar todo el árbol de build de Android todavía inexistente para `CppProject`.

## Evidencia

- `struct X : QOpenGLFunctions_3_1 { void f() { initializeOpenGLFunctions(); glBindTexture(0,0); } }` compilado contra Qt-Android real → `error: expected class name`, `error: use of undeclared identifier 'initializeOpenGLFunctions'`, `error: use of undeclared identifier 'glBindTexture'`. Confirma B1: el tipo no existe, aunque el `#include` de la línea 1 no tira error por sí solo (trampa metodológica, registrada en CLAUDE.md §17).
- `QOpenGLFunctions_4_3_Core* g = nullptr;` contra el mismo Qt → `error: unknown type name 'QOpenGLFunctions_4_3_Core'`. Mismo patrón para `Shader.hpp:219` (`gl43Core`).
- `CppProject/Render/GraphicsApiHandler.hpp:11,42` → migrado a `#include <QOpenGLExtraFunctions>` / `: QOpenGLExtraFunctions`.
- Inventario completo de llamadas GL reales (49 funciones distintas, ver tabla abajo) extraído de: `FrameBuffer.cpp`, `Texture.cpp`, `Render/Vertex.cpp`, `World/WorldVertex.cpp`, `Asset/Shader.cpp`, `Asset/ShaderLoadOpenGL.cpp`, `Render/PrimitiveRenderer.cpp`, `Render/GLWidget.cpp`, `Render/GraphicsApiHandler.cpp`.
- `gl_inventory_test.cpp` compilado con `C:\Android\ndk\27.3.13750724\...\clang++.exe -target aarch64-linux-android24 ... ` contra `C:\Dev\Qt\5.15.19\install-android\include\...` → **exit code 0, sin salida** (48 de 49 funciones).
- `glShaderStorageBlockBinding(0,0,0);` en el mismo contexto → `error: use of undeclared identifier 'glShaderStorageBlockBinding'`. `grep -rl glShaderStorageBlockBinding` sobre todo `install-android/include` → solo aparece en `qopenglfunctions_4_3_core.h`, `_4_4_*`, `_4_5_*` y `qopenglextensions.h` (todas clases/extensiones **desktop**), nunca en `qopenglextrafunctions.h` ni en ningún header de la familia ES.

## Hallazgos

### 1. B1 es real y está confirmado por compilador, no solo por lectura de código
Coincide con lo que decía CLAUDE.md §5.1, pero ahora con evidencia de compilación real contra el Qt-Android construido en esta sesión, no solo inspección de `configure.json`/mkspecs.

### 2. El reemplazo por `QOpenGLExtraFunctions` funciona para prácticamente todo el uso real
48 de 49 funciones GL usadas hoy en el renderer compilan limpio. Tabla completa:

| Función | Dónde se usa | Disponible en `QOpenGLExtraFunctions` | Versión ES mínima |
|---|---|---|---|
| glDeleteFramebuffers, glDeleteTextures, glDeleteRenderbuffers, glGenFramebuffers, glGenTextures, glGenRenderbuffers, glBindTexture, glTexImage2D, glBindRenderbuffer, glRenderbufferStorage, glGetIntegerv, glBindFramebuffer, glFramebufferTexture2D, glFramebufferRenderbuffer, glCheckFramebufferStatus, glViewport, glReadPixels, glEnableVertexAttribArray, glActiveTexture, glTexParameteri, glBindBuffer, glBufferSubData, glDrawElements, glDeleteBuffers, glGenBuffers, glBufferData, glDisable, glEnable, glGenerateMipmap, glVertexAttribPointer, glGetString, glFrontFace, glDepthMask, glDepthFunc, glGetError, glClearColor, glClear, glCullFace, glBlendFuncSeparate, glStencilOp, glStencilFunc, glColorMask, glStencilMask | `FrameBuffer.cpp`, `Texture.cpp`, `GraphicsApiHandler.cpp` | Sí | ES 2.0 |
| glVertexAttribIPointer, glBindVertexArray, glGenVertexArrays, glDrawBuffers | `Render/Vertex.cpp`, `World/WorldVertex.cpp`, `Asset/Shader.cpp`, `GLWidget.cpp`, `FrameBuffer.cpp` (MRT, ver B2) | Sí | ES 3.0 |
| glBindBufferBase, glGetProgramResourceIndex | `Asset/Shader.cpp`, `ShaderLoadOpenGL.cpp` (SSBO/batching) | Sí | ES 3.1 |
| **glShaderStorageBlockBinding** | `Asset/Shader.cpp:249` (SSBO/batching) | **No — ningún ES** | — (solo desktop GL 4.3+) |

### 3. La única función sin equivalente ES está atada al batching opcional, que ya tiene fallback
`glShaderStorageBlockBinding` remapea en runtime a qué binding point apunta un bloque SSBO nombrado en el shader — un concepto que **no existe en OpenGL ES**: en ES 3.1 el binding se fija en el shader mismo (`layout(std430, binding=N) buffer ...`), no se reasigna después por API. Esto no es una limitación menor del driver, es una diferencia real de modelo entre desktop GL 4.3 y ES 3.1.

Esto solo importa si se porta el batching por SSBO (§5.2) — y el código **ya sabe correr sin batching** (`if (!gl43Supported) useBatching = false`, `ShaderLoadOpenGL.cpp:13-15`), exactamente la misma degradación que ya usa hoy en desktop cuando no hay GL 4.3.

### 4. `Shader.hpp` necesita el mismo tratamiento que `GraphicsApiHandler.hpp`, todavía no aplicado
`Shader.hpp:9` (`#include <QOpenGLFunctions_4_3_Core>`) y `:219` (`static QOpenGLFunctions_4_3_Core* gl43Core;`) están dentro de `#if API_OPENGL` sin excepción para Android — hoy rompen la compilación en Android tal cual están. No se tocó en este prototipo a propósito: cómo resolverlo depende de la decisión del gate de abajo (no tiene sentido decidir la forma del fix antes de saber si se porta el batching o no).

## Contradicciones con CLAUDE.md

- §5.1 decía "el header no compila" — cierto en efecto, pero impreciso en la causa: el `#include` en sí no falla, falla el USO del tipo (herencia/instanciación). Un chequeo que solo probara "¿compila el `#include`?" habría concluido, incorrectamente, que B1 no es un problema. Corregido en §5.1.1 y §17.
- §5.2 no mencionaba que el propio SSBO tuviera una función sin equivalente ES — solo decía "SSBO existe en ES 3.1". Cierto que SSBO como concepto existe en ES 3.1, pero la función puntual que usa el código para asignar su binding no. Corregido en §5.2.

## Incógnitas

- No se verificó en un dispositivo/GPU real que `QOpenGLExtraFunctions` resuelva los punteros de función correctamente en runtime (esto es compilación, no ejecución — la tarea 0.5 del plan, "shader más pesado en dispositivo real", es donde corresponde esa verificación).
- No se compilaron los `.cpp` reales completos (ver Método, punto 7) — el test aislado prueba las firmas, no la integración completa con `Generated/`, moc, etc. Cuando exista un `CMakeLists.txt` que targetee Android (todavía no existe), conviene repetir esta verificación con el archivo real.
- No se investigó si hay OTRAS funciones GL usadas en archivos fuera de `CppProject/Render` y `CppProject/Asset` (por ejemplo, si algún shader o código de `World/` usa GL directamente en otro archivo no revisado).

## Decisión propuesta

**B1 tiene solución confirmada — la ruta B (portar `CppProject` a Qt for Android) sigue viva.** Migrar `GraphicsApiHandler.hpp` (ya prototipado) y `Shader.hpp` (pendiente, depende del gate) a `QOpenGLExtraFunctions`.

Para la única función sin equivalente (`glShaderStorageBlockBinding`), corresponde `[GATE G1]` — no se decide acá, ver mensaje de chat de la sesión con las opciones A (no portar batching a Android, usar el fallback ya existente) y B (portar batching a ES 3.1 vía `layout(binding=N)` fijo en el shader, coordinando el backend de `processCode` de §5.3 con la asignación de índices en `Shader.cpp`).

Alternativa descartada: intentar emular `glShaderStorageBlockBinding` con alguna llamada ES equivalente — **no existe tal función**, cualquier "reemplazo" sería en realidad reescribir el mecanismo de binding, que es exactamente la opción B del gate, no un simple mapeo 1 a 1.
