# CLAUDE.md — Port de Mine-imator a plataformas móviles

**Versión 2.0** · Reemplaza v1.0 · Correcciones respecto de v1 en §17

---

## 0. Cómo usar este documento

Fuente de verdad operativa del proyecto. Tres reglas de precedencia:

1. **La realidad del código gana sobre este documento.** Si encontrás una contradicción, se actualiza el documento y se registra en §17. Nunca se ignora la evidencia.
2. **Este documento gana sobre tu intuición.** Si algo te parece que "debería" ser de otra forma, investigá primero.
3. **El humano gana sobre este documento.** Las decisiones marcadas `[GATE]` no las tomás vos.

**Antes de tu primera acción en cada sesión:** leé §1 y §2 completas. Son el protocolo, no contexto opcional.

---

## 1. PROTOCOLO DE OPERACIÓN — PREGUNTAR ANTES DE ACTUAR

### 1.1 El principio

Este proyecto tiene 98.840 líneas de código ajeno, un transpilador propio, y una arquitectura de renderizado que un error de diseño puede volver inviable en móvil. **El costo de preguntar es un minuto. El costo de asumir mal es una semana.**

No sos un ejecutor. Sos un ingeniero que investiga, reporta y propone, y que ejecuta cuando el camino está claro.

### 1.2 Los cinco gates

Te detenés y preguntás **antes** de actuar cuando la tarea cae en alguna de estas categorías:

| Gate | Disparador | Por qué |
|---|---|---|
| **G1 — Arquitectura** | Cambiar cómo funciona un subsistema (render, input, I/O, build) | Difícil de revertir. Define el techo del proyecto |
| **G2 — Upstream** | Modificar código original de Mine-imator más allá de un fix local | Complica el rebase si aparece un fork vivo |
| **G3 — Contrato** | Tocar el formato `.miproject`, la API de las primitivas de UI, o `gml.json` | Rompe compatibilidad hacia afuera |
| **G4 — Ambigüedad** | Dos o más caminos razonables y la evidencia no decide | Elegir a ciegas es apostar con el tiempo del proyecto |
| **G5 — Alcance** | La tarea resultó ser distinta o mucho mayor de lo que decía el pedido | El humano necesita saber que el mapa cambió |

**Fuera de los gates, ejecutá.** No pidas permiso para leer archivos, correr greps, compilar, medir, escribir tests o documentar. La fricción excesiva es tan mala como la falta de fricción.

### 1.3 Formato obligatorio de pregunta

Cuando frenás en un gate, escribís esto. No una pregunta suelta:

```markdown
## GATE <G1-G5>: <título en una línea>

**Contexto**
<qué estaba haciendo y por qué llegué acá>

**Evidencia**
- `archivo:línea` → <qué dice literalmente>
- <medición o build log si aplica>

**El problema**
<en dos frases, sin adornos>

**Opciones**

### A) <nombre>
- Cómo: <mecánica concreta>
- Costo: <tiempo / complejidad>
- Riesgo: <qué se puede romper>
- Deuda: <qué nos deja para después>

### B) <nombre>
- (mismo formato)

**Mi recomendación:** <A o B> porque <razón basada en la evidencia de arriba, no en preferencia>

**Lo que NO sé todavía:** <incógnitas que podrían cambiar la respuesta>

**Qué necesito de vos:** <la decisión concreta, en pregunta cerrada si es posible>
```

### 1.4 Reglas de la pregunta

- **Una por vez.** No listas de diez.
- **Siempre con recomendación propia.** "¿Qué hago?" no es válido. "Recomiendo A por X, ¿confirmás?" sí.
- **Nunca preguntes algo que podés averiguar.** Si está en el código, andá a buscarlo. Preguntar por pereza es peor que asumir.
- **Nunca sigas trabajando con un gate abierto.** Pausá, no avances "por las dudas".

### 1.5 Plan previo a tareas largas

Antes de cualquier tarea de más de ~2 horas: qué vas a tocar, en qué orden, cómo verificás cada paso, y dónde esperás encontrar problemas. Esperá el visto bueno.

---

## 2. PROTOCOLO DE INVESTIGACIÓN

### 2.1 Nunca asumas

Antes de escribir código o afirmar algo sobre el comportamiento de Mine-imator:

1. **Leé el código.** No el nombre del archivo, no de memoria. El código.
2. **Contá los call sites.** `grep -rn`. Si vas a tocar `ui_large_height`, sabé que hay 125 usos antes de tocarla.
3. **Verificá las APIs externas contra la versión exacta que usamos.** Qt 5.15, OpenGL ES 3.x, NDK. No contra la última ni contra tu memoria.
4. **Buscá en la web lo del ecosistema:** políticas de Play Store, cobertura de extensiones GL por vendor, bugs conocidos de Qt para Android, límites reales de GPUs móviles. Tu conocimiento tiene fecha de corte; eso no.

### 2.2 Reporte de investigación

Toda tarea no trivial arranca con `research/YYYY-MM-DD-<tema>.md`:

```markdown
# Investigación: <tema>

## Pregunta
## Método
<qué comandos corrí, qué archivos leí, qué busqué>
## Evidencia
- `archivo:línea` → <cita literal>
- <fuente web + fecha de consulta> → <qué dice>
## Hallazgos
## Contradicciones con CLAUDE.md
<obligatorio reportarlas, aunque sean menores>
## Incógnitas
## Decisión propuesta
<con la alternativa descartada y por qué>
```

### 2.3 Prohibiciones

- Decir "esto debería funcionar" sin haberlo compilado o corrido.
- Inventar firmas de funciones de GML, Qt u OpenGL. Si no la viste en el código o en la doc, no existe.
- Afirmar algo de rendimiento sin un número y el dispositivo donde se midió.
- Marcar una tarea como hecha sin evidencia: build log, screenshot, medición o test que pasa.
- Silenciar un error. Va a `KNOWN_ISSUES.md` en el mismo commit que lo introduce.
- Editar `CppProject/Generated/`. Se sobreescribe. Ver §4.

---

## 3. Ficha técnica del código base

Medido sobre `master`, commit `01a62c0e` (2026-08-29). Reverificado el 2026-09-06 contra este commit: conteos y citas `archivo:línea` de esta sección y de §5/§6 confirmados exactos — ver §17. **Reverificá igual al empezar si pasó tiempo.**

### 3.1 Volumen

| Componente | Medida |
|---|---|
| Scripts GML | 2.067 archivos / 98.840 líneas |
| Objetos GameMaker | 58 |
| Sprites (iconos UI) | 51 |
| Shaders `.fsh` + `.vsh` | 106 archivos / 5.944 líneas → **53 shaders** (47 en `GmProject/shaders`, 94 archivos/5.733 líneas + 6 exclusivos de C++ en `CppProject/Asset/Shaders/`, 12 archivos/211 líneas) |
| C++ escrito a mano | ~75 archivos |
| Dependencias externas | ~209 MB |

### 3.2 LOC por dominio

| Prefijo | LOC | Naturaleza | ¿Viaja tal cual? |
|---|---|---|---|
| `action_*` | 16.432 | Comandos de UI | Parcial |
| `tab_*` | 8.225 | Paneles y widgets | No (se readapta vía primitivas) |
| `render_*` | 6.056 | Pipeline de render | Parcial |
| `project_*` | 5.080 | Modelo de datos | **Sí** |
| `block_*` | 4.695 | Parseo de modelos MC | **Sí** |
| `app_*` | 4.659 | Ciclo de vida | No |
| `draw_*` | 4.608 | Primitivas de dibujo UI | Parcial |
| `tl_*` | 4.217 | Timeline | Parcial |
| `view_*` | 3.782 | Viewport | Parcial |
| `model_*` | 2.691 | Sistema de modelos | **Sí** |
| `popup_*` | 1.745 | Diálogos | No |
| `minecraft_*` | 1.400 | Importación de assets | Parcial (I/O) |
| `shader_*` | 1.293 | Bindings | Parcial |
| `menu_*` | 1.100 | Menús contextuales | No |
| `file_*` | 361 | I/O | No |

**Lectura:** ~36.000 líneas (37%) son UI. La lógica de dominio (proyecto, bloques, modelos) son ~12.500 líneas y viaja intacta. Esa asimetría define el proyecto.

### 3.3 Dependencias

| Librería | Versión | Riesgo móvil |
|---|---|---|
| Qt | 5.15.19 | **Alto** — §5.1 y §9.2 |
| ffmpeg | 5.1.10 | Bajo — solo el encoder de video depende de x264/GPL; el resto (audio, muxeo) queda LGPL puro al sacarlo, ver §9.1 |
| x264 | master-0480cb05 | Baja — GPL resuelto en diseño vía `AMediaCodec` del NDK (módulo nuevo, no un flag de ffmpeg), §9.1 |
| OpenAL-soft | 1.24.3 | Bajo — tiene backend Android |
| OpenSSL | 3.0.21 | Bajo |
| libzip | 1.11.4 | Bajo |
| SimplexNoise1234 | — | Nulo |

---

## 4. Arquitectura de build

```
GmProject/          ← Proyecto GameMaker Studio 2. FUENTE DE VERDAD de la lógica.
CppGen/             ← Transpilador GML→C++ propio (C++, CMake)
   └─ gml.json      ← Spec: keywords, constantes, built-ins de GML
CppProject/
   ├─ Generated/    ← SALIDA de CppGen. NO SE EDITA. NUNCA.
   ├─ Gml/          ← Implementaciones C++ de built-ins de GML
   ├─ Library/      ← FileLib, MathLib, MovieLib, WindowLib
   ├─ Render/       ← GLWidget, GraphicsApiHandler, FrameBuffer, Mesh,
   │                  Texture, TexturePage, VertexBufferRenderer, PrimitiveRenderer
   ├─ Asset/        ← Shader, ShaderLoadOpenGL, ShaderLoadD3D11
   ├─ Type/         ← Tipos runtime
   ├─ World/        ← Importador de mundos Minecraft
   └─ External/     ← Terceros
```

### 4.1 El flujo

1. Editás `GmProject/scripts/*.gml`
2. CppGen lee `gml.json` + `GmProject/` → escribe `CppProject/Generated/`
3. CMake compila `Generated/` + código a mano + Qt
4. Sale el ejecutable

### 4.2 Cómo agregar funcionalidad que GML no tiene

No hackees `Generated/`. El camino correcto:

1. Declarás la función en `CppGen/gml.json`
2. La implementás en `CppProject/Gml/`
3. La llamás desde GML normalmente

**`[GATE G3]`** Todo cambio a `gml.json` pasa por gate. Es un contrato entre dos capas.

**Camino alternativo ya en uso (encontrado 2026-09-06):** hay un mecanismo `/// CppSeparate` y `/// CppOnly` como comentario de función GML, usado hoy en 71 archivos de `GmProject/scripts/` (154 apariciones) y reconocido en `CppGen/Sources/GML.cpp` y `Function.cpp`. Es la implementación concreta de "función con cuerpo distinto en C++". Semántica exacta todavía no verificada línea por línea — investigar antes de depender de él.

### 4.3 CppGen — auditado en Fase 0 (2026-09-06)

`CppGen/README.md` avisa: *"this software is not general-purpose and won't work outside the Mine-imator project"*. Confirmado con evidencia concreta: exige un objeto llamado exactamente `"app"`, nombres de carpeta fijos, números de evento "Other" con significado propio de Mine-imator, y una lista hardcodeada de variables del importador de bloques de Minecraft (`CppGen.hpp:1169`). Informe completo: `research/2026-09-06-cppgen.md`.

**Corrida real verificada:** `CppGen/Win64/CppGen.exe` (binario prebuildeado, no depende del toolchain de VS/Qt) corre hoy sin errores sobre el corpus completo: 98.639 líneas GML parseadas en 931ms → 105.545 líneas de C++ generadas (84 archivos) en total ~29s, **exit code 0, cero WARNINGS**. Dato nuevo no documentado antes: solo resuelve el **58% de los tipos de variable** (8.700 de 14.868) — el resto queda con tipo dinámico/genérico.

**Segunda corrida real, en rama dedicada (2026-09-06, cierre del pendiente de 0.2):** se volvió a correr `CppGen.exe` sobre el repo actual para el diff-check que había quedado pendiente en la "Decisión propuesta" del informe. Resultado: `0 files were updated`, confirmado además con `git status`/`git diff --stat` sobre `CppProject/Generated/` → **cero diferencias**. `CppProject/Generated/` está exactamente al día con `GmProject/` — no hay deriva silenciosa más allá del caso ya conocido (ver corrección de abajo). Se revisaron además los 4 logs que escribe la herramienta (`CppGen/Logs/*.log`) buscando "WARNING"/"FATAL" — sin resultados reales (los 2 matches eran variables llamadas `*_warning`, falsos positivos). El caso (d) de Accessor.cpp:641 (el "FATAL ERROR" que no aborta) **no se disparó en esta corrida — confirmado como rama muerta hoy**, cerrando la incógnita que había quedado abierta en `research/2026-09-06-cppgen.md`.

- **Subconjunto de GML soportado:** `gml.json` confirma `constructor`, `new`, `delete`, `static` (GML moderno), pero es más angosto de lo que sugiere esa lista — sin `try/catch`, sin struct-literal `{}`, sin funciones anónimas como expresión, y `static` solo aplica a métodos dentro de un `constructor` (no a variables estáticas locales sueltas). Evitar estas construcciones al escribir GML nuevo para el port.
- **Ante lo desconocido, no hay una política única, hay cuatro:** (a) error léxico/sintáctico → fatal + `exit(1)` antes de escribir nada; (b) función/tipo desconocido en resolución → fatal antes de escribir; (c) error detectado a mitad de generación de código → fatal **con `CppProject/Generated/` ya parcialmente escrito** (`CodeWriter` escribe archivo por archivo, no atómico — un fatal a mitad de una corrida grande puede dejar una mezcla de .cpp viejos y nuevos); (d) un caso puntual imprime "FATAL ERROR" pero no aborta el proceso; (e) evento de objeto no reconocido → solo `WARNING` en consola, se descarta en silencio (`Object.cpp:51-59`).
- **Corrección de una corrección anterior (2026-09-06):** esta misma sección afirmaba que el evento `Alarm_0` de `app` "no está habilitado" en `app.yy` y que por lo tanto no demostraba la ruta (e). **Es falso — releído `app.yy:24-30` directo:** el `eventList` tiene 6 entradas, incluida `{"eventNum":0,"eventType":2,...}`, que es exactamente Alarm 0 (GameMaker: eventType 2 = Alarm). El evento sí está habilitado. Peor todavía: la corrida real de CppGen de hoy confirmó que la ruta real por la que se pierde **no es (e)** (el `WARNING: Unsupported event` de `Object.cpp:51-59`, que no imprimió nada en la corrida) sino una todavía más silenciosa, un paso antes: `Object.cpp:22-25` lee el contenido del archivo de evento (`window_center()`), lo reduce a un nombre de función (`window_center`), y si ese nombre no está en `Program::functions` hace `continue` **sin imprimir nada, ni warning ni error**. `window_center` no está definido en ningún lado del proyecto (`grep -rn "window_center"` sobre todo el repo → solo aparece en este mismo `Alarm_0.gml` y en esta documentación) — cae ahí, no en el warning de (e). Confirma que sí hay un caso vivo, y que es más silencioso de lo que la ruta (e) describe: una sexta forma de descarte silencioso, sin mensaje de ningún tipo.
- **Salida agnóstica de plataforma:** confirmado, el C++ generado no tiene ramas por plataforma. Los únicos `#ifdef` de plataforma están en el propio CppGen (para correr la herramienta en Win/Mac/Linux), no en lo que emite.
- **Modelo de objetos de GameMaker:** cada objeto es un struct C++ con un solo nivel de herencia desde una clase base `Object` (`Object.cpp:80`). La herencia real de GameMaker (`parentObjectId`, presente en 15 de 58 objetos) se ignora — no se usa `event_inherited`. `with`/`self`/`other`/`id`/`noone` se resuelven vía plantilla `Scope<T>` y macros `withAll`/`withOne`; `other` siempre es un entero (`self.otherId`), nunca un puntero tipado.

---

## 5. Arquitectura de render — análisis profundo

Esta sección decide si el proyecto es viable. Leela entera.

### 5.1 BLOQUEO DURO: el tipo base de la capa gráfica es OpenGL desktop

```cpp
// CppProject/Render/GraphicsApiHandler.hpp:11
#include <QOpenGLFunctions_3_1>
// :41
struct GraphicsApiHandler
    #if API_OPENGL
        : QOpenGLFunctions_3_1
    #endif
```

```cpp
// CppProject/Asset/Shader.hpp:9
#include <QOpenGLFunctions_4_3_Core>
// :219
static QOpenGLFunctions_4_3_Core* gl43Core;
```

**El problema:** las clases `QOpenGLFunctions_X_Y[_Core]` **solo existen en builds de Qt contra OpenGL desktop**. Un Qt compilado para Android usa OpenGL ES y no genera esas clases. El header no compila. No es un error de runtime parcheable: es un fallo de compilación en el tipo base de toda la capa gráfica.

**Severidad: máxima.** Afecta a `GraphicsApiHandler` (el objeto `GFX` que usa todo el renderer) y a `Shader`.

**Ruta a evaluar en Fase 0:** reemplazar la herencia por `QOpenGLExtraFunctions` (la clase de Qt para ES 3.x) y resolver cada función faltante caso por caso. Requiere auditar todas las llamadas GL y clasificarlas por versión mínima de ES.

**`[GATE G1]`** La estrategia de reemplazo se decide con el humano.

### 5.1.1 TAREA 0.3 CERRADA (2026-09-06) — B1 confirmado real y con solución verificada por compilador

**El bloqueo es real, confirmado con el NDK real contra el Qt-Android que se compiló en esta sesión** (`C:\Dev\Qt\5.15.19\install-android`, ver `BUILD_NOTES.md`) — no solo con lectura de código:

- `#include <QOpenGLFunctions_3_1>` y `#include <QOpenGLFunctions_4_3_Core>` **no tiran error por sí solos** (el archivo de header existe y el preprocesador lo encuentra) — esto puede engañar a un chequeo superficial. Pero **el tipo en sí no existe**: `struct X : QOpenGLFunctions_3_1` da `error: expected class name`, y `QOpenGLFunctions_4_3_Core* g` da `error: unknown type name`. Confirma la severidad máxima original — nadie puede heredar de esto ni instanciarlo en este Qt-Android.
- **El reemplazo funciona.** Se migró `GraphicsApiHandler.hpp` a `QOpenGLExtraFunctions` (rama `fase0-0.3-graphicsapihandler-prototype`) y se armó un test con las firmas exactas de las ~48 llamadas GL distintas que usa hoy el código real (`FrameBuffer.cpp`, `Texture.cpp`, `Vertex.cpp`, `WorldVertex.cpp`, `Shader.cpp`, `ShaderLoadOpenGL.cpp`, `PrimitiveRenderer.cpp`, `GLWidget.cpp`, `GraphicsApiHandler.cpp`). Compilado de verdad con `clang++` del NDK, `-target aarch64-linux-android24`, contra el Qt-Android real: **48 de 49 compilan limpio, exit code 0.**
- **La única función sin equivalente ES: `glShaderStorageBlockBinding`** (`Shader.cpp:249`), confirmada ausente con un test negativo (`error: use of undeclared identifier`). No tiene equivalente en ningún nivel de ES porque el modelo de binding de SSBO es distinto: en ES 3.1 el binding se fija en el shader vía `layout(std430, binding=N)`, no se reasigna en runtime como en desktop GL 4.3. Está atada al path de batching (§5.2), que **ya es opcional** (`gl43Supported`/`useBatching`, ver abajo) — no bloquea nada del renderer base.

**Conclusión: B1 tiene solución confirmada, no solo teórica. La ruta B sigue viva.** Informe completo, con cada comando y resultado, en `research/2026-09-06-b1-graphicsapihandler-prototype.md`.

**`[GATE G1 — CERRADO 2026-09-06]` Decisión: Opción A — no portar el batching por SSBO a Android, usar el fallback ya existente (`gl43Supported=false` → `useBatching=false`, `ShaderLoadOpenGL.cpp:13-15`).**

Razón registrada por el usuario: hasta que la tarea 0.6 no mida el ancho de banda real del pipeline diferido, no se sabe si los draw calls extra que cuesta no batchear son siquiera un cuello de botella. Si el límite real es memory bandwidth (la hipótesis central de B2), portar el batching a ES 3.1 ahora no movería la aguja — sería optimizar un costo que puede no importar, exactamente lo que §14 prohíbe fuera de Fase 6. Opción B (portar a ES 3.1 fijando `layout(std430, binding=N)` en el shader, coordinado con el backend de `processCode` de §5.3) queda parqueada para Fase 6, con viabilidad ya probada por este mismo prototipo si hiciera falta retomarla.

**Aplicado (Fase 1, 2026-09-06, rama `fase1-shader-android-guard`):** `Shader.hpp`/`Shader.cpp`/`ShaderLoadOpenGL.cpp` recibieron el mismo tratamiento que `GraphicsApiHandler.hpp` — `QOpenGLFunctions_4_3_Core`/`gl43Core` excluidos de Android vía `#ifndef Q_OS_ANDROID`, y `glGetProgramResourceIndex` (`ShaderLoadOpenGL.cpp:262`) movido de `gl43Core->` a `GFX->` (`QOpenGLExtraFunctions`, ya cubre ES 3.1, no necesita el guard). **Verificado con compilador real en ambos lados**, no solo diseñado: (1) desktop — build completo de `Mine-imator.exe` (MSVC, Debug) recompilado tras el cambio, 0 advertencias, 0 errores, el guard queda inerte como corresponde; (2) Android — test aislado que reproduce la estructura exacta del guard, compilado con `clang++` del NDK real (`-target aarch64-linux-android24`) contra los headers de Qt-Android reales, confirmando además que `Q_OS_ANDROID` se auto-define por los propios headers de Qt al compilar para ese target (no hay que definirlo a mano en ningún lado del proyecto).

**Extendido con una compilación real de todo el proyecto (2026-09-08):** el test aislado de arriba no alcanzaba a probar el archivo integrado — una compilación completa de `CppProject` para Android encontró 3 bugs más en la migración de 0.3/acá, ninguno visible en el test aislado: `qopenglext.h` de Qt no compila contra headers de solo-ES (`GLclampd` no existe), lo que a su vez expuso que `GL_TEXTURE_LOD_BIAS` tampoco tiene equivalente ES (único call site, `Shader.cpp:694`, ambos guardados con `#ifndef Q_OS_ANDROID`); y en `GraphicsApiHandler.cpp`, `isInitialized()` (privado en `QOpenGLExtraFunctions`, público en `QOpenGLFunctions_3_1`) e `initializeOpenGLFunctions()` (devuelve `void` en la clase base, no `bool` como en las versionadas de desktop) — **estos dos últimos no son específicos de Android**, son bugs latentes en la rama OpenGL compartida (Mac/Linux/Android) que nunca se había compilado en toda la sesión porque Windows toma la rama D3D11. Los 5 arreglados y verificados — el 100% de `CppProject` compila para Android arm64-v8a. Detalle completo en `research/2026-09-08-fase1-android-cmake-first-build.md`.

### 5.2 BLOQUEO: el batching por SSBO requiere GL 4.3

```cpp
// CppProject/Asset/ShaderLoadOpenGL.cpp:255-262
GFX->glGenBuffers(1, &glSsboId);
GFX->glBindBuffer(GL_SHADER_STORAGE_BUFFER, glSsboId);
GFX->glBufferData(GL_SHADER_STORAGE_BUFFER, batchBufferSize, batchBufferData, GL_DYNAMIC_COPY);
...
glSsboBlockIndex = gl43Core->glGetProgramResourceIndex(program->programId(), GL_SHADER_STORAGE_BLOCK, "_ssbo");
```

```cpp
// CppProject/Asset/Shader.hpp:15,17
#define MAX_BATCH_BUFFER_SIZE (4096 * 16)  // D3D: 4096 float4s (64kb)
#define MAX_BATCH_BUFFER_SIZE (100 * 1024) // GL: 100kb
```

SSBO existe en OpenGL ES **3.1**, no en 3.0. Eso fija el piso de dispositivos si querés batching.

**La buena noticia — la degradación ya está implementada:**

```cpp
// CppProject/Asset/ShaderLoadOpenGL.cpp:13-15
// Batching requires SSBO (GL 4.3+ only)
if (!gl43Supported)
    useBatching = false;
```

**Implicación:** el renderer ya sabe correr sin batching. Existe una ruta de arranque en móvil (sin batching, más draw calls, más lento) y una optimizada (ES 3.1 con SSBO). Es exactamente el patrón que necesitamos. **No lo rompas.**

**Hallazgo (0.3, 2026-09-06):** `gl43Core->glGetProgramResourceIndex` migra sin problema a `QOpenGLExtraFunctions` (existe en ES 3.1, confirmado por compilador). Pero `glShaderStorageBlockBinding` (usado más arriba en `Shader.cpp:249`, no en el fragmento de arriba) **no tiene equivalente en ningún ES** — confirmado con test negativo real. En ES 3.1 el binding de un SSBO se fija en el shader (`layout(std430, binding=N)`), no se reasigna después vía API. Resuelto por `[GATE G1 — CERRADO 2026-09-06]` (§5.1.1): Opción A, no portar el batching a Android. No es un problema nuevo de arquitectura — cae dentro de esta misma degradación ya soportada (`useBatching = false`).

### 5.3 HALLAZGO MAYOR: los shaders ya están escritos en dialecto GLSL ES

Esto **corrige** lo que decía v1 de este documento.

```cpp
// CppProject/Asset/ShaderLoadOpenGL.cpp:23
// Convert from GLES to GLSL for a given shader
auto processCode = [&](QString code, BoolType isVertex) { ... }
```

Los shaders están en el dialecto de GameMaker (GLSL ES 1.00): `attribute`, `varying`, `gl_FragColor`, `gl_FragData[N]`, `texture2D()`. `processCode` los transpila **hacia arriba** a GLSL desktop 400/430 en tiempo de carga.

**Corrección de inventario (2026-09-06):** no son 94 shaders, son **53**. `GmProject/shaders/` tiene 47 (94 archivos `.fsh`+`.vsh`, el par por shader). Pero hay 6 más que solo existen del lado C++, en `CppProject/Asset/Shaders/` (12 archivos sueltos, sin par en `GmProject`): `primitive`, `world_box`, `world_box_resize`, `world_checker`, `world_player`, `world_preview` — usados por `PrimitiveRenderer` y el importador de mundos. El backend ES de `processCode` tiene que cubrir los 53, no 47.

| Transformación | Línea |
|---|---|
| `attribute` → `in`, `varying` → `in`/`out` | :85-86 |
| `gl_FragColor` → `layout(location=0) out vec4` | :41-46 |
| `gl_FragData[N]` → `layout(location=N) out vec4`, contando `numOutputs` | :48-59 |
| `texture2D()` → helper `_sampleUvRect()` con `textureLod` | :63-82 |
| Atributos empaquetados → unpack de `uint` (`_aNormal`, `_aColor`, `_aData`, `_aTangent`) | :89-100 |

**Implicación estratégica:** no hay que portar 53 shaders a mano. Hay que escribir un **segundo backend de `processCode`** que emita GLSL ES 3.00 en vez de desktop 400/430. Un archivo, no cincuenta y tres. Esto cambia la estimación del proyecto de forma material.

**Advertencia explícita (2026-09-06):** lo de arriba sigue siendo una **asunción no verificada, no un hallazgo cerrado.** Nadie escribió el backend ES todavía, ni se compiló ni corrió ningún shader transpilado a ES contra un driver real. Toda la estimación de "un archivo, no 53" descansa en que la transformación funcione igual de bien para las 5 filas de la tabla de arriba en ES 3.00 que en desktop 400/430 — que es plausible por el mismo dialecto de origen, pero no está probado. La tarea que iba a probarlo (0.5, "backend ES + `shader_high_light_point` en dispositivo real") se movió a Fase 1 (ver §11) porque necesita un `CppProject` corriendo en Android, que no existe todavía. Hasta que 0.5 corra, tratar esto como riesgo abierto, no como base firme para estimar el resto del trabajo de shaders.

**Detalle a resolver:** `textureQueryLod` (:70) es OpenGL 4.0 y no existe en GLSL ES. Ya hay fallback (`lod = 0.0` cuando `!gl40Supported`), que degrada la calidad de sampling. Medir si se nota.

### 5.4 El sistema de tiers ya existe

```cpp
// CppProject/Asset/Shader.cpp:96-109
if (sh.compileSourceCode(gl40shader)) {
    gl40Supported = true;
    glslVersion = "400";
    if (ENABLE_OPENGL_43 && sh.compileSourceCode(gl43shader)) {
        gl43Supported = true;
        gl43Core = new QOpenGLFunctions_4_3_Core;
        if (!gl43Core->initializeOpenGLFunctions())
            FATAL("Could not initialize OpenGL 4.3");
        glslVersion = "430";
    }
}
```

Detecta capacidades compilando un shader de prueba. **Ese es el punto de extensión para un tier `es30` / `es31`.** Diseñá el port como un tier más, no como un fork.

### 5.5 MRT y el problema del ancho de banda

MRT se maneja de forma genérica: `processCode` escanea `gl_FragData[0..N]` y cuenta salidas, y `GraphicsApiHandler.cpp:499-526` gestiona `glMrtCount`. 8 shaders usan MRT → hay G-buffer → **renderizado diferido**.

Shaders más pesados:

| Shader | Líneas |
|---|---|
| `shader_high_light_point` | 399 |
| `shader_high_raytrace` | 361 |
| `shader_high_light_sun` | 276 |
| `shader_high_light_spot` | 274 |
| `shader_color_fog_lights` | 254 |

**El riesgo:** los GPUs móviles son tile-based (TBDR). Un G-buffer diferido sobre TBDR es el peor caso de ancho de banda: cada pasada fullscreen fuerza round-trips a memoria principal, lenta y cara en batería. **Riesgo número uno del proyecto.**

Líneas de investigación para Fase 0:
- `GL_EXT_shader_framebuffer_fetch` / `GL_ARM_shader_framebuffer_fetch` — mantener el G-buffer en memoria on-chip. Investigar cobertura real por vendor (Mali, Adreno, PowerVR, Xclipse)
- Reducir el G-buffer: menos targets, formatos más chicos (RGBA8 en vez de float16)
- Forward+ / clustered forward como pipeline alternativo para el tier móvil
- Subpasses de Vulkan, si se evalúa Vulkan

**`[GATE G1]`** La decisión de pipeline de render es el gate más importante del proyecto.

### 5.6 Requisitos de versión detectados

| Feature | Evidencia | ES mínimo |
|---|---|---|
| `glVertexAttribIPointer` | atributos empaquetados `uint` | ES 3.0 |
| VAO (`glBindVertexArray`) | `Render/` | ES 3.0 |
| MRT (`glDrawBuffers`) | `GraphicsApiHandler.cpp:509` | ES 3.0 |
| SSBO | `ShaderLoadOpenGL.cpp:256` | ES 3.1 |
| `textureQueryLod` | `ShaderLoadOpenGL.cpp:70` | **No existe en ES** (hay fallback) |

**Conclusión preliminar:** el piso realista es **OpenGL ES 3.0**, con SSBO/batching opcional en ES 3.1+. Confirmar en Fase 0.

### 5.7 Features ausentes (buena noticia)

No se usan: `dFdx`, `textureGrad`, `texelFetch`, `sampler2DShadow`, `gl_FragDepth`. El set es conservador. `for` en 12 shaders y `while` en 1: revisar que sean de conteo acotado, porque los drivers móviles viejos fallan con loops dinámicos.

---

## 6. Arquitectura de UI e input — análisis profundo

### 6.1 El apalancamiento del proyecto: 13 primitivas

La UI es immediate-mode. **13 primitivas** `tab_control_*` sostienen **68 paneles**:

`button_label` · `checkbox` · `color` · `dragger` · `loading` · `menu` · `meter` · `sortlist` · `switch` · `textfield` · `textfield_group` · `togglebutton` · `wheel`

Todas delegan en `tab_control(height)`:

```gml
// GmProject/scripts/tab_control_checkbox/tab_control_checkbox.gml
function tab_control_checkbox()
{
    tab_control(ui_small_height)
}
```

```gml
// GmProject/scripts/tab_control/tab_control.gml
function tab_control(height)
{
    tab_control_h = height
    if (tab_collumns)
    {
        dw = (tab_collumns_width - ((tab_collumns_count - 1) * 8)) / tab_collumns_count
        dx = tab_collumns_start_x + ceil(dw * (tab_collumns_index)) + (8 * tab_collumns_index)
    }
}
```

**Implicación desactualizada, ver corrección abajo:** ~~reimplementás 13 funciones para táctil y los 68 paneles se readaptan solos~~. Las 13 `tab_control_*` siguen siendo la superficie de DATOS correcta (qué panel usa qué control, con qué altura) — lo que no es cierto es que reimplementarlas alcance para el input táctil, porque no tienen ninguna lógica de input que reimplementar. No hay que reescribir 8.225 líneas, pero el trabajo de Fase 3 no está en estas 13 funciones.

**Invariante a proteger:** ningún panel debe dibujar widgets sin pasar por una primitiva `tab_control_*`. **`[GATE G3]`** Cualquier excepción pasa por gate.

**Corrección al modelo (inventario 0.8, 2026-09-06; reforzada al arrancar Fase 3, 2026-09-09):** verificado — ninguna de las 13 `tab_control_*`, ni la base `tab_control()` (arriba), lee `mouse_x`, `mouse_check_button`, `keyboard_check*` ni `mouse_wheel*`. `tab_control()` solo calcula alto de fila y columnas. Cada primitiva de la lista de arriba es, literalmente, una línea que llama a `tab_control(altura)` (ver `tab_control_checkbox.gml` arriba: 3 líneas, sin lógica propia). **Toda la interacción real (click, drag, hover, rueda, click derecho) vive en una familia paralela de funciones `draw_*`/`sortlist_*`/`menu_*`** que cada panel llama por separado después de `tab_control_*`. La superficie real a reimplementar para Fase 3 es el par `tab_control_X` + su `draw_X`/equivalente, no las 13 funciones solas.

**El apalancamiento real no está en las 13 primitivas — está en dos archivos compartidos que ellas ni mencionan:**
- **`context_menu_area.gml:22`** — único punto de entrada de "click derecho" para 5 de las 13 (`dragger`, `meter`, `wheel`, `textfield_group`, `color`) más el textbox enfocado. Un solo fix de long-press ahí cubre las 6 superficies a la vez.
- **`scrollbar_draw.gml`** — único punto que lee la rueda del mouse para scroll de contenido (`:109-118`) y maneja drag-de-barra/page-jump (`:77-107`); usado por `sortlist` y `menu` para su scroll interno. Un solo swipe-scroll ahí cubre ambas.

Detalle completo, con interacciones y gesto táctil propuesto por cada una de las 13, en `research/2026-09-06-ui-inventory.md`.

### 6.2 Escala de UI: el mecanismo ya existe

```gml
// GmProject/scripts/app_update_interface/app_update_interface.gml:11-21
if (window_height <= 900 || setting_interface_compact)
{
    ui_large_height = 24
    ui_small_height = 20
    window_compact = true
}
else
{
    ui_large_height = 32
    ui_small_height = 24
    window_compact = false
}
```

Uso: `ui_large_height` ×125, `ui_small_height` ×53. **178 call sites, 2 constantes.** (recontado 2026-09-06 con `grep -c`: 125 + 53 = 178, exacto.)

**Punto de entrada para táctil:** un modo `window_touch` acá. Objetivo mínimo de touch target: 48dp (Material) / 44pt (HIG). Con 32px en una pantalla de ~400dpi el control mide ~2mm físicos: inoperable con el dedo.

**Cuidado:** los `8` hardcodeados de gutter en `tab_control` también escalan. Buscá todas las constantes de layout, no solo las dos alturas.

**Estas dos constantes no son toda la escala (inventario 0.8, 2026-09-06):** hay hitboxes hardcodeados por debajo del nivel de fila que no reaccionan a subir `ui_large_height`/`ui_small_height`: `switch` (16px de alto, sin el label), `meter` (20px), resize de columna en `sortlist` (10px), glifo de `checkbox` (16×16). Y `#macro label_height 9` (`GmProject/scripts/macros/macros.gml:152`) es una tercera constante de layout, independiente de las otras dos, que tampoco escala con ellas. Antes de tocar `window_touch`, mapear estos números sueltos además de las dos alturas.

**`App->scale` y `window_touch` NO son dos soluciones al mismo problema — son dos ejes ortogonales que se multiplican (decisión de arquitectura, gate G1, 2026-09-09, ver §17 y `PATCHES.md`):**

- **`App->scale`** (`Gml/UtilFunc.cpp:interface_scale_default_get()`/`interface_scale_set()`) corrige **densidad**: hace que una unidad lógica ocupe el mismo tamaño FÍSICO sin importar cuántos píxeles por pulgada tenga la pantalla. Es el mecanismo que YA existe (compartido con la feature de escritorio "Interface Scale" 100/200/300%, `tab_settings_interface.gml`), no es específico de Android.
- **`window_touch`** (a implementar en Fase 3) tendría que corregir **ergonomía de input**: un dedo necesita un blanco más grande que un cursor, independientemente de la densidad de la pantalla.
- Se multiplican, no se sustituyen: `tamaño físico real = valor lógico (ajustado por window_touch) × App->scale (densidad)`. Prueba numérica con el dispositivo de referencia (Xiaomi/Redmi/POCO, 220333QL, 320dpi): `ui_large_height` (32, el valor más grande que ya existe) × `App->scale` correcto (2) = 64px reales — el objetivo Material de 48dp a esa densidad son 96px reales. **Incluso con la densidad perfectamente corregida, el tamaño de escritorio no alcanza para dedo** — confirma que hace falta el segundo eje, no que sobre el primero.
- **Restricción para Fase 3:** `window_touch` debe trabajar en las mismas unidades LÓGICAS que ya usa todo el resto del sistema (igual que el `if (window_height <= 900)` de arriba), subiendo `ui_large_height`/`ui_small_height` (y las constantes sueltas del inventario 0.8) a valores más grandes para el modo táctil — sin tocar ni duplicar el cálculo de densidad, que ya resuelve `App->scale`. Intentar que `window_touch` calcule densidad por su cuenta (opción C del gate, descartada) obligaría a leer la densidad real del dispositivo en dos lugares distintos del código, y se rompe apenas se pruebe en un segundo dispositivo de referencia con otra densidad (§14.2).

### 6.3 El embudo de input

Todo el input entra por Qt en un solo lugar:

```cpp
// CppProject/AppWindow.hpp:41-45, 72-73
void mousePressEvent(QMouseEvent* event) override;
void mouseReleaseEvent(QMouseEvent* event) override;
void mouseMoveEvent(QMouseEvent* event) override;
void wheelEvent(QWheelEvent* event) override;
void keyPressEvent(QKeyEvent* event) override;
void keyReleaseEvent(QKeyEvent* event) override;
```

Del lado GML:

| Símbolo | Call sites |
|---|---|
| `mouse_x` | 107 |
| `mouse_y` | 98 |
| `keyboard_check` | 61 |
| `keyboard_check_pressed` | 29 |
| `mouse_check_button` | **8** |
| `mouse_wheel_up` / `down` | 2 / 2 |

**Implicación:** solo 8 puntos deciden "¿está apretado?". La capa de abstracción táctil es acotada.

**Trampa 1:** Qt en Android sintetiza eventos de mouse a partir de toques. La app "va a andar" sin tocar nada, y va a andar **mal**: sin multitouch, sin gestos, sin pinch-zoom. La solución correcta es interceptar `QTouchEvent` en `AppWindow::event()` (ya está overrideado, `AppWindow.hpp:34`), no dejar que Qt sintetice.

**`[GATE G1 — DIFERIDO explícitamente, no resuelto, 2026-09-09]`** Al arrancar Fase 3 (inventario de las 13 primitivas, `research/2026-09-06-ui-inventory.md`), se confirmó que ninguna de las 13 necesita multitouch real — todos los gestos propuestos (tap, drag lineal, drag circular, long-press) son de un solo dedo. Decisión: NO interceptar `QTouchEvent` en Fase 3, seguir apoyándose en el mouse sintetizado de Qt. Esto **no cierra la Trampa 1** — queda diferida a Fase 4, que sí necesita multitouch real (pinch-zoom de cámara, §6.4). No leer esto como "Trampa 1 resuelta" ni asumir que el mouse sintetizado alcanza para cámara/gestos de dos dedos.

**Trampa 2:** `mouse_x`/`mouse_y` en táctil no tienen valor definido entre toques. En desktop siempre hay cursor; en móvil no. Con 205 call sites leyendo esas variables, el comportamiento entre toques hay que definirlo explícitamente.

**`[GATE G1 — CARACTERIZADO 2026-09-15, no un gate abierto genérico]`** Investigado con evidencia real de código, no solo la sospecha original: `mouse_x`/`mouse_y` **no quedan indefinidos** entre toques — quedan **congelados en la última posición conocida**. Cadena completa confirmada: `AppWindow.cpp:529-533` (`mouseMoveEvent` solo escribe `mousePos` cuando llega un evento de movimiento real, sin ningún handler que lo resetee al levantar el dedo) → `AppHandler.cpp:356-357` (cada frame, `gmlGlobal::mouse_x = win->mousePos.x() / scale`, leyendo ese mismo valor potencialmente viejo) → GML. Mismo código para desktop y Android (no hay rama `#if`), y la línea `else gmlGlobal::mouse_x = gmlGlobal::mouse_y = -1` (`AppHandler.cpp:361`) es para OTRA ventana que no es la activa (irrelevante en Android, app de una sola ventana).

**Esto no es un valor "indefinido" en el sentido de basura/undefined behavior — es un default bien definido y benigno para la mayoría de los 205 call sites** (la mayoría solo lee "dónde está el cursor ahora", y quedarse en la última posición tocada es inofensivo). El riesgo real no es un valor roto, es código que trata el ESTADO DE HOVER calculado a partir de esa posición como si fuera fresco entre frames cuando en realidad puede ser de un toque anterior — exactamente la clase de bug real ya encontrada (gizmos de manipulación 3D, `control_mouseon_last`) y descartada como no-aplicable en otros lugares (arrastre de keyframes del timeline, nodos de path) durante la auditoría de Fase 4 del 2026-09-15. **Cierre:** no hace falta una política general nueva — el default ya existente (congelar) es aceptable, y el trabajo real es seguir auditando caso por caso cualquier código que dependa de hover fresco entre frames, como ya se hizo con los gizmos. Detalle: `research/2026-09-15-fase4-gizmos-timeline-implementation.md`.

### 6.4 Lo que no tiene equivalente táctil

| Interacción desktop | Evidencia | Destino |
|---|---|---|
| Hover | `draw_box_hover`, tooltips | Estado presionado, o desaparece |
| Click derecho | `mb_right` | Long-press |
| Rueda del mouse | `wheelEvent` | Pinch / scroll con dos dedos |
| Drag & drop de archivos | `AppWindow.hpp:37-39` | Share intent de Android |
| Atajos de teclado | 61 `keyboard_check` | UI, o se pierden (documentar cada pérdida) |
| Múltiples ventanas | `AppHandler.hpp:73-80` (`AddedWindow`), `QMainWindow` | Una sola ventana + navegación |

---

## 7. I/O y ciclo de vida

### 7.1 Sistema de archivos

`CppProject/Library/FileLib.cpp` usa `QFile` / `QDir` con **rutas planas**. Android moderno usa Storage Access Framework, que entrega **URIs de contenido**, no rutas.

Puntos de contacto:

| Símbolo | Call sites |
|---|---|
| `working_directory` | 10 |
| `get_open_filename_ext` | 1 |
| `get_save_filename_ext` | 1 |

**Bueno:** hay exactamente 2 diálogos de archivo. **Malo:** `FileLib` entero asume rutas. Necesita una capa URI↔ruta, o copia a almacenamiento privado de la app.

### 7.1.1 `[GATE G1 — CERRADO 2026-09-06]` `minSdkVersion = 29` (Android 10)

**Decisión confirmada por el usuario.** Evidencia y opciones completas en `research/` (conversación de la sesión); acá el resumen operativo.

Cobertura acumulada (StatCounter, abril 2026, vía apilevels.com): API 24 → 96.6%, API 26 → 96.1%, API 29 → 91.1%, API 30 → 86.9%, API 33 → 68.9% (recién ahí empieza la caída fuerte).

**El argumento no es cobertura — es evitar una ruta de I/O duplicada.** `targetSdkVersion` va a ser 36 sin importar el `minSdk` (exigencia de Google Play, agosto 2026, independiente de esta decisión). Scoped storage como *mecanismo del sistema operativo* recién existe desde API 29 — en dispositivos con API 28 o menos no existe en absoluto, sin importar qué declare la app. Como nuestro `targetSdk` fijo (36) fuerza scoped storage completo en cualquier dispositivo que SÍ lo tenga disponible, el resultado práctico es:

- `minSdk < 29` → la app corre en dispositivos que no tienen scoped storage (necesitan rutas planas de verdad) **y** en dispositivos donde nuestro `targetSdk` fuerza scoped storage completo → `FileLib` (B4) necesita las dos rutas de acceso a archivos, mantenidas en paralelo.
- `minSdk = 29` → el 100% de los dispositivos instalables ya tienen scoped storage disponible en el SO → `FileLib` se escribe una sola vez contra SAF, sin rama legacy.

Subir a `minSdk = 30` no cambia nada de esto (scoped storage ya existe en el SO desde 29) — por eso el piso queda en 29, no en 30, pese a que la cobertura de 30 (86.9%) también sería aceptable.

### 7.2 Ciclo de vida

`AppHandler : QObject` con `timerEvent` como loop principal (`AppHandler.hpp:30,45`). El modelo de escritorio no contempla:

- `onPause` / `onResume` / `onDestroy` de Android
- **Pérdida del contexto OpenGL al ir a background.** Toda la state de GPU (texturas, VBOs, FBOs, shaders) tiene que ser recreable. El código original nunca lo contempló. Severidad alta, y se suele descubrir tarde
- Que el SO mate el proceso sin aviso → autosave agresivo

### 7.3 Threading

53 referencias a `QThread` + 1 `omp parallel`. Hay concurrencia real (importador de mundos, `obj_builder_thread`). En Android auditar: límites de threads, prioridades, y que ningún thread toque GL fuera del thread de render.

---

## 8. Catálogo de bloqueos conocidos

Registro vivo. Agregá cada uno nuevo con el mismo formato.

| # | Bloqueo | Sev | Evidencia | Síntoma esperado | Mitigación |
|---|---|---|---|---|---|
| B1 | `QOpenGLFunctions_3_1` / `_4_3_Core` no existen en Qt ES | **Resuelta (0.3, 2026-09-06)** | `GraphicsApiHandler.hpp:11,41` · `Shader.hpp:9,219` — confirmado con compilador real (`error: expected class name` / `unknown type name`) | Error de compilación: clase no encontrada | **Migrado y verificado**: `QOpenGLExtraFunctions` cubre 48/49 llamadas GL reales, compilado contra el NDK real — rama `fase0-0.3-graphicsapihandler-prototype`, informe completo en `research/2026-09-06-b1-graphicsapihandler-prototype.md`. Única excepción sin equivalente ES (`glShaderStorageBlockBinding`, batching opcional) resuelta por `[GATE G1 — CERRADO 2026-09-06]`, Opción A: no portar el batching a Android (§5.1.1) |
| B2 | Ancho de banda del pipeline `render_high` (preview "Render"/export, NO el viewport interactivo default) | **Media — MEDIDO Y ACOTADO (0.6, 2026-09-06)** | Modelo de bytes/frame a 1080p desde el código real, revisado 3 veces dentro de la misma tarea (ver `research/2026-09-06-b2-deferred-bandwidth.md` para el historial de correcciones) | El viewport interactivo por default usa `render_low()` (`view_update_surface.gml:17-20`, vistas arrancan en `SHADED`), no `render_high()` — ~7,5 GB/s, no amenaza §14.3. `render_high()` (preview opt-in + export) sin indirect/reflections: con preset móvil (glow/subsurface/SSAO off, flags existentes) + RGBA16F ≈ **389 MB/frame, ~11,7 GB/s @30fps — dentro de presupuesto sostenido.** Indirect/reflections (ray marching, `shader_high_raytrace.fsh`) siguen sin acotar: 4-33 GB/s adicionales según hit rate de cache real (no medible sin GPU física), degradables vía `uPrecision` + resolución reducida | Preset móvil (3 flags) + RG16 octaédrico para normales + RGBA8 para specular + RGBA16F en los 2 puntos HDR restantes. Indirect/reflections: degradar (cuarto de res + ~32 pasos) o desactivar en Android, pendiente de dato real de dispositivo |
| B3 | Pérdida de contexto GL en background | Alta | `AppHandler` sin hooks de lifecycle. Precedente real de primera mano: Qt documenta un crash al resumir en Samsung XCover 3, atribuido a threading del propio driver, no a Qt (`research/2026-09-06-gpu-driver-quirks.md`) | Pantalla negra o crash al volver | Recreación completa de recursos GPU |
| B4 | SAF da URIs, `FileLib` espera rutas | Alta | `FileLib.cpp` (`QFile`/`QDir`). Punto de entrada concreto encontrado en el barrido de Fase 1 (punto 4, `research/PHASE1_PLAN.md`): `QFileDialog` en `Gml/FileFunc.cpp:208,233` (open/save) | Falla al abrir/guardar proyectos | Capa de abstracción o copia local |
| B5 | x264 es GPL | **Baja — AUDITADO (pre-Fase 1, 2026-09-06)** | `External/Sources/x264-*`, linkeado estático. Único uso de GPL en todo `MovieLib.cpp` (el resto — decode/resample/encode de audio, muxeo — es FFmpeg LGPL sin depender de x264, confirmado leyendo el código real) | Bloqueo en App Store; térmicamente inviable en móvil de todos modos | `AMediaCodec` (NDK, API 21+) resuelve legal y térmico, pero es un módulo de encoding nuevo para Android, no un flag de FFmpeg — ver `research/2026-09-06-b5-x264-mediacodec.md`. Cambia el alcance de Fase 7, no la viabilidad |
| B6 | Qt LGPL + linkeo estático en iOS | Alta | Qt 5.15.19 | Incompatibilidad de licencia | Licencia comercial o no-iOS |
| B7 | Sin ninguna licencia propia de Mine-imator en el repo | **Resuelta (0.10, 2026-09-06)** | David Andrei confirmó por escrito (mail): 2.0.x es MIT, puerto móvil + distribución en Google Play autorizados, mantener el aviso de copyright original. Va a re-agregar `LICENSE` al repo (no lo hizo todavía). Ver §9.3 | Riesgo legal del proyecto entero — resuelto | — |
| B8 | Touch targets de 32px | Alta | `app_update_interface.gml:19-20` | App inusable con el dedo | Modo `window_touch`, 48dp |
| B9 | Qt sintetiza mouse desde touch | Media | Default de Qt Android | "Funciona" pero sin gestos ni multitouch | Interceptar `QTouchEvent` |
| B10 | `mouse_x/y` indefinidos entre toques | Media — **manifestación real confirmada (Fase 2, 2026-09-09)** | 205 call sites. Caso concreto: `camera_control_rotate.gml`/`camera_control_move.gml` usan `display_mouse_set()` para recentrar el cursor cada frame (mouse-look infinito de escritorio) — en touch no hay cursor que recentrar, Android reporta la posición real del dedo cada frame y compite con el recentro → cámara errática, confirmado en dispositivo real | Bugs sutiles de hit-testing. Este caso puntual: arrastre de cámara inservible | Contrato explícito en la capa de input (Fase 4, gate G1). Parche **instrumental**, no la solución, aplicado para destrabar la verificación de Fase 2 — ver `KNOWN_ISSUES.md` B10 y `PATCHES.md` |
| B11 | Memoria: mundos importados | Baja — **MEDIDO (0.7, 2026-09-06)** | `WorldVertex` compacto (8B/vértice) confirmado. `sizeof(obj_timeline)` real (compilado) = 8.560 bytes. Fracción de bloques especiales medida sobre los 39 `.schematic` que Mine-imator empaqueta: ~0% para terreno (1 bloque especial en 3,28M). Preset "Grande" (400×50×400): **~60 MB medido para terreno**, ~374 MB-1,63 GB razonado (no medido, sin muestra real) para una importación densa en decoración. Ver `research/2026-09-06-memory-budget.md` | Ninguno para el caso típico (terreno). Solo importaciones muy densas en cofres/puertas/carteles en dispositivos de 4 GB | Ninguna acción para el caso común. Guarda barata opcional: avisar/degradar si `sch_timeline_amount` (ya contado en `Builder.cpp:202`) supera un umbral en tiempo de importación |
| B12 | Multiventana (`AddedWindow`) | Media | `AppHandler.hpp:73-80` | Ventanas que no aparecen | Colapsar a una ventana + navegación |
| B13 | `textureQueryLod` no existe en ES | Baja | `ShaderLoadOpenGL.cpp:70` | Sampling de menor calidad | Fallback ya presente (`lod = 0.0`) |
| B14 | `for` dinámicos en 12 shaders | Baja | `GmProject/shaders/` | Falla de compilación en drivers viejos | Acotar con constantes o desenrollar |
| B15 | Editar `CppProject/Generated/` | Baja | Diseño de CppGen | El trabajo se pierde en el próximo build | Editar `GmProject/*.gml` |
| B16 | Qt desde fuente: horas, y falla por rutas largas en Windows | Baja | `BUILD.md` | Build roto | `DEV_DIR` corto, como dice `BUILD.md` |
| B17 | Sin caché de bytecode en el backend OpenGL | Media | `Shader.cpp:96-109` (solo `compileSourceCode`, sin `ProgramBinary`/disco) vs. `ShaderLoadD3D11.cpp:343-403` (D3D11 sí cachea `.d3d` en disco/`.qrc`, ver `index.qrc`) | 53 shaders compilan desde fuente GLSL en cada arranque, algunos dos veces (tier gl40 + gl43). Hoy invisible en desktop; en GPU móvil puede violar el objetivo de <5s de §14.3 | Investigar `glGetProgramBinary`/`glProgramBinary` con caché en disco, análogo al mecanismo que ya existe para D3D11 |
| B18 | `QDesktopWidget::logicalDpiX()`/`devicePixelRatio()` (deprecado desde Qt 5.11) alimenta el escalado de touch targets | Media | `AppHandler.cpp:91`, `Gml/UtilFunc.cpp:367,369`, `Gml/WindowFunc.cpp:15,20`, `Render/GLWidget.cpp:42` — encontrado en el barrido de Fase 1 (`research/PHASE1_PLAN.md`, punto 4) | Si devuelve un valor por defecto/incorrecto en Android en vez de la densidad real, `ui_large_height`/`ui_small_height` (B8) escalan mal en silencio — no rompe la compilación, corrompe el tamaño de los controles | Loguear el valor real en un dispositivo apenas exista uno; migrar a `QScreen` si hace falta |
| B19 | Ningún shader del proyecto tiene calificador de precisión GLSL ES (`highp`/`mediump`/`lowp`) | **Resuelta y verificada en dispositivo real (Fase 2, 2026-09-09)** | `Asset/ShaderLoadOpenGL.cpp` (defines de Android) · `qopenglshaderprogram.cpp:469-481,636-652` (Qt no inyecta default de precisión para ES, solo neutraliza los calificadores en desktop) | GLSL ES 3.00 exige precisión explícita para `float`/`int` en fragment shaders (spec §4.5.3) — un driver estricto (Mali/PowerVR más viejos) podría rechazar la compilación directamente, no solo degradar calidad. El Adreno 610 probado hasta ahora es permisivo (por eso nunca se notó) | Agregado `precision highp float;`/`precision highp int;` a los defines de Android. Verificado en el Adreno 610 real: 47+3 shaders compilan limpio, cero regresión. Pendiente solo en los otros 2 dispositivos de referencia de §14.2 cuando existan |
| B21 | Carga de bloques lenta en Android — búsqueda lineal por string en el hot path, no I/O | **RESUELTA y verificada en dispositivo real (2026-09-09, override Fase 6)** | Perfilado real en 3 pasadas (`log()`, no gateado por `dev_mode`): `block_load_render_model()` (construcción de geometría) era el 73% del tiempo de la etapa "blocks" (65,3s de 89s) — no el I/O/JSON (solo 7,9%) ni el throttle por-frame (probado `repeat(100)`, sin diferencia). Causa: `ds_list_find_index()` escaneando linealmente la lista de texturas de bloque, hasta 6 veces por cara renderizada | Carga total ~98s en el dispositivo de referencia | **Arreglado:** mapas nombre→índice (`block_texture_index_map`/`block_texture_ani_index_map`) construidos una vez, reemplazando los 6 `ds_list_find_index()` de `block_load_render_model.gml` por lookups O(1). Medido: carga total ~98s → **~39s**, `rendermodel_ms` -88%. Sin regresión visual verificada. Detalle completo: `KNOWN_ISSUES.md` B21 |
| B22 | Qt-Android compilado sin soporte OpenSSL (`config.summary`: "OpenSSL: no") — HTTPS no funciona | **Resuelta y verificada en dispositivo real (2026-09-16)** | `C:/Dev/Qt/5.15.19/build-android/config.summary` ahora dice `OpenSSL: yes`. Verificado con tráfico HTTPS real en el Redmi 10C (auto-update contra `api.github.com`, assets contra `mineimator.com` — ambos completan la conexión) | (histórico) Chequeo de versión/noticias no funcionaba; descarga de assets desde `mineimator.com` no funcionaba | **Recompilado:** OpenSSL 3.0.21 para Android arm64 + Qt 5.15.19 reconfigurado con `-openssl-linked`, a pedido explícito del usuario para destrabar el auto-update (§ auto-update, sesión 2026-09-16). Detalle: `KNOWN_ISSUES.md` B22 |
| B20 | El teclado virtual de Android no tiene ningún gancho para mostrarse — `KeyChecker` (captura de texto) fue diseñado solo para teclado físico | Alta — **confirmado por lectura del código fuente real de Qt, no solo sospecha** (Fase 3, 2026-09-09) | `AppWindow.cpp:289-319` (`KeyChecker`, foco permanente + oculto desde el constructor) · cero resultados para `QGuiApplication::inputMethod()`/`Qt::WA_InputMethodEnabled` en todo `CppProject` · `qandroidinputcontext.cpp:985-1005` (Qt 5.15.19 real, instalado en esta máquina) confirma que `showInputPanel()` no chequea visibilidad de ningún widget, solo necesita un `focusObject()` válido — y nada en el código llama a esto ni mueve el foco de Qt cuando el foco de GML (`window_focus`) cambia entre campos | Ningún campo de texto (`textfield`, `textfield_group`, el numérico embebido en `dragger`/`meter`, la búsqueda de `sortlist`) va a mostrar el teclado en pantalla en Android tal como está el código hoy | No implementado — 3 piezas identificadas para cuando Fase 3 llegue a texto: (1) llamar a `QGuiApplication::inputMethod()->show()`/`->hide()` cuando `window_focus` de GML apunte/deje de apuntar a un campo de texto, reforzando el foco real de Qt después de que la ventana ya esté mostrada (evitar el bug de timing conocido de Qt-Android); (2) sobreescribir `KeyChecker::inputMethodQuery()` para reportar la posición real en pantalla del campo GML, no la geometría interna del `QLineEdit` oculto; (3) verificar en dispositivo si `QLineEdit::NoEcho` degrada el tipo de teclado/autocorrección. Detalle completo: `research/2026-09-09-fase3-virtual-keyboard.md` |

### 8.1 Trampas de verificación conocidas (falsos positivos/negativos)

Registro vivo, separado del catálogo de bloqueos porque esto no es un problema del proyecto sino de la metodología para verificarlo. Revisar antes de dar por "confirmado" cualquier hallazgo de compilación — evita repetir días perdidos por un chequeo que pareció suficiente y no lo era.

| # | Trampa | Por qué engaña | Chequeo correcto | Evidencia |
|---|---|---|---|---|
| T1 | `#include <QOpenGLFunctions_3_1>` / `#include <QOpenGLFunctions_4_3_Core>` no tira error de compilación por sí solo contra Qt-Android | El header existe en el árbol de Qt-Android y el preprocesador lo encuentra sin problema, aunque la clase que declara no sirva para nada en ese build — un chequeo que se quede ahí concluye "compiló", cuando en realidad no probó nada | Probar el USO real del tipo (heredar de él, instanciarlo, llamar a un método), no solo el `#include`. Esto es lo que reveló que B1 era real | `struct X : QOpenGLFunctions_3_1 { ... }` → `error: expected class name` contra `C:\Dev\Qt\5.15.19\install-android` real, pese a que el `#include` de la misma clase compila solo — tarea 0.3, `research/2026-09-06-b1-graphicsapihandler-prototype.md` |
| T3 | Un carácter no-ASCII (ej. `§`) en un comentario, dentro de un archivo `.gml` **nuevo** (no uno ya existente que CppGen ya venía parseando bien) | CppGen falla en silencio: no reporta un error de encoding ni de parseo — simplemente actúa como si la función nunca hubiera existido, y el error que se ve es "FATAL ERROR: Missing function X en Y", en el call site, no en el archivo real con el problema. Lleva a sospechar de la lógica de la función (validación de tipos, sintaxis del cuerpo) en vez del comentario | Si un archivo `.gml` nuevo da "Missing function" pese a que el nombre/carpeta/registro en `Mine-imator.yyp` están bien, sospechar primero de caracteres no-ASCII en los comentarios antes que de la lógica — probar reduciendo el comentario a una sola línea ASCII y regenerando | Confirmado 2026-09-10: `data_directory_seed_android.gml` con un comentario largo usando `§` (`CLAUDE.md §9.4/§17`) daba "FATAL ERROR: Missing function data_directory_seed_android en app_startup:9" pese a estar bien registrado en el `.yyp`; reduciendo el comentario a texto ASCII plano (sin `§`) compiló limpio con la misma lógica de cuerpo sin cambios |
| T2 | `GL_EXT_shader_framebuffer_fetch` y `GL_ARM_shader_framebuffer_fetch` son dos extensiones distintas, no un mismo feature con dos nombres | Un driver Mali puede exponer solo el string ARM-específico según versión — un chequeo de runtime que busque únicamente `GL_EXT_shader_framebuffer_fetch` puede reportar "no soportado" en un Mali que sí lo soporta | Chequear ambos strings de extensión antes de concluir que framebuffer fetch no está disponible en el dispositivo | Tarea 0.9, `research/2026-09-06-framebuffer-fetch-coverage.md` |
| T4 | `cmake --build . --target apk` en Windows se queda "colgado" (sin output, `cmake`/`ninja` siguen vivos) minutos después de que el trabajo real ya terminó | El paso real es `cmd.exe /C "... androiddeployqt.exe ..."`, que internamente arranca un daemon de Gradle. Ese daemon se independiza del proceso que lo lanzó (comportamiento normal de Gradle) pero en Windows puede quedarse con una copia heredada del handle del pipe de stdout/stderr que `ninja` usa para capturar la salida del comando. Aunque `androiddeployqt.exe` y el `cmd.exe` que lo lanzó ya terminaron con éxito, `ninja` sigue bloqueado esperando el EOF de ese pipe, que nunca llega mientras el daemon siga vivo — no hay ningún error, ninguna tarea de Gradle fallando, nada que grepear en la salida porque la salida real nunca llegó a completarse. Engaña porque coincide en el tiempo con cualquier cambio reciente al build (ej. agregar un recurso nuevo a empaquetar), sugiriendo que el cambio de código causó el cuelgue, cuando el build en sí ya había terminado hace rato | Si `cmake`/`ninja` siguen "corriendo" sin output por varios minutos: (1) buscar el proceso `java.exe` del daemon de Gradle activo (`Get-CimInstance Win32_Process` filtrando por nombre) y revisar `~/.gradle/daemon/<version>/daemon-<pid>.out.log` — si ya dice `BUILD SUCCESSFUL` con timestamp viejo y el resto del log es solo polling de idle (`Waiting/Lock acquired on daemon addresses registry` cada 10s), el build terminó y el cuelgue es el pipe, no el código; (2) matar ese proceso `java.exe` del daemon (`Stop-Process -Id <pid> -Force`) — libera el handle y `ninja`/`cmake` terminan de inmediato con el resultado que ya tenían. Matar todos los daemons ANTES de reintentar no lo evita: el daemon nuevo que se crea cae en el mismo problema en cuanto termina su build | Confirmado 2026-09-10: tres reintentos consecutivos de `cmake --build . --target apk` colgados 9-17 minutos tras agregar el empaquetado de `Data/` (B24). `jstack` sobre el daemon mostró todos los hilos de trabajo parqueados (`ThreadPoolExecutor.getTask`→`LinkedBlockingQueue.take`) y el listener TCP en `accept()` esperando una conexión nueva — nada ejecutando build. El log del daemon (`daemon-25100.out.log`) confirmó `BUILD SUCCESSFUL in 18s` a los 20 segundos de arrancar, con ~16 minutos de solo polling de idle después. Matar el PID del daemon liberó a `ninja` de inmediato (exit code 0, "34 actionable tasks: 34 up-to-date") |

---

## 9. Restricciones legales

Todas son `[GATE]`. Un agente no las decide.

### 9.1 x264 / ffmpeg son GPL — **AUDITADO, confirmado con salida (pre-Fase 1, 2026-09-06)**
`External/Sources/x264-master-0480cb05.tar.bz2`, linkeado **estático** (`External/{Win32,Win64,Linux,Mac}/libx264.*`). Enlazar contra x264 obliga a que el binario sea GPL-compatible. Play Store lo acepta; la App Store históricamente no.

**Confirmado con código real, no solo con la recomendación técnica original:** `MediaCodec` sí resuelve legal y térmico, pero no es "activar una flag de FFmpeg" — el soporte de `mediacodec` en FFmpeg upstream es de **decodificación, no de encoding** (verificado). La ruta real es la API nativa `AMediaCodec` del NDK (disponible desde API 21, sin conflicto con `minSdkVersion=29`), que requiere escribir un módulo de encoding de video nuevo para Android — el resto de `MovieLib.cpp` (decode de audio, resample, encode de audio AAC, muxeo .mp4) no depende de x264 y sigue siendo FFmpeg LGPL sin tocar, una vez que se compila sin `--enable-gpl`/`--enable-libx264` **y como librería dinámica** (LGPL exige poder reemplazarla, igual que §9.2 para Qt). Detalle completo, incluyendo la decisión pendiente de Fase 7 entre input por `ByteBuffer` (más simple, menos ahorro térmico) o por `Surface` (más integración, ahorro térmico completo): `research/2026-09-06-b5-x264-mediacodec.md`.

### 9.2 Qt LGPLv3
Exige que el usuario pueda reemplazar la librería → enlazado dinámico. Viable en Android (`.so` separados), problemático en iOS.

### 9.3 Licencia de Mine-imator — `[GATE] CERRADO (2026-09-06)`
**Verificado: el repositorio no tiene archivo `LICENSE` en la raíz.** El foro oficial afirma MIT (afirmación no reverificada por este equipo contra una fuente primaria).

**Corrección (2026-09-06):** la afirmación de que el `license.txt` del instalador "declara el software propiedad de David Andrei" es **incorrecta**. Se leyó el archivo real (`GmProject/options/windows/installer/license.txt` y su duplicado `GmProject/options/windows/License.txt`, buscando "Installer/Windows/" en toda variante de mayúsculas): es el EULA estándar que GameMaker Studio genera automáticamente para instaladores — habla de los derechos de **YoYo Games** sobre el motor GameMaker, no dice nada sobre quién es dueño del código fuente de Mine-imator. No menciona a David Andrei en ningún lado. `grep -rli "david andrei\|copyright"` sobre todo el repo (sin `External/`) no encuentra ninguna declaración de copyright propia de Mine-imator, en ningún archivo.

**La situación real, entonces, no es "dos licencias que se contradicen" — es "no hay ninguna licencia propia del código de Mine-imator, en ningún lado del repo".** Bajo copyright por defecto, eso significa todos los derechos reservados por el autor: que el repo sea público en GitHub permite verlo/clonarlo (es lo que hicimos), pero no autoriza redistribuir una versión modificada, publicarla en una tienda de apps, ni usar el nombre. "Público" y "con licencia para redistribuir" son cosas distintas.

**Historia completa reconstruida del historial de git (2026-09-06), porque un usuario trajo una afirmación externa de "MIT, licenciamiento claro" que había que verificar:**
- `LICENSE` (MIT, Copyright David Norgren) existió realmente, creado el 2018-04-09 (commit `fab960f8`, autor David Norgren `david.norgren@outlook.com`, 82 commits en todo el repo).
- **Se borró explícitamente en el commit `6d48eaff` ("2.0.0", 2023-03-01), autor David Andrei `mail@davidandrei.net`** (53 commits, es quien maneja el repo actual — coincide con la cuenta de GitHub `stuffbydavid`). O sea: el MIT existió ~5 años, y se sacó al mismo tiempo que se lanzó la reescritura 2.0 en la que estamos trabajando.
- El MIT sigue presente hoy solo en dos ramas viejas y abandonadas: `origin/cubist` (último commit 2019) y `origin/1.2.9` — ninguna es la que usamos (`master`, HEAD `01a62c0e`, 2.0.x).
- **Conclusión:** la afirmación de "Mine-imator es MIT" no es inventada — fue cierto durante años, y probablemente sea la fuente de cualquier claim genérico que se encuentre buscando en la web. Pero es **desactualizada para el código que estamos portando**: alguien (aparentemente el propio mantenedor actual) sacó el LICENSE a propósito justo al lanzar 2.0. Eso es una señal, no un accidente — asumir que el MIT "obviamente sigue aplicando" es exactamente el tipo de atajo que este documento prohíbe (§2.3).

**Hallazgo final (2026-09-06), que cambia bastante el diagnóstico — a favor:** existió un segundo archivo, distinto del EULA de GameMaker de §9.3 arriba: `Installer/Windows/license.txt` (carpeta `Installer/` en la raíz, no `GmProject/options/windows/`). Este SÍ era propio de Mine-imator, y decía, textual, hasta hace ~2-3 semanas:

> "This software... is a property of David Andrei at www.stuffbydavid.com. [...] Note: The source code of Mine-imator is available on GitHub under the MIT license: https://github.com/stuffbydavid/Mine-imator"

O sea: **el propio David Andrei siguió afirmando por escrito, en el producto que se distribuye, que el código fuente es MIT — durante más de 3 años después de haber borrado el archivo `LICENSE` formal de 2023.** Este `Installer/Windows/license.txt` se borró recién en el commit `8732ee7e` (2026-08-21, "CppGen ported to C++... Removed installer files"), junto con TODA la carpeta `Installer/` (assets de instaladores Windows/Mac/Linux) — una limpieza general de la migración de CppGen a C++, no una acción dirigida a la licencia. Esto hace mucho más probable que la ausencia actual de licencia sea un descuido de reorganización de repo, no una revocación deliberada.

**Corrobora esto:** existen builds comunitarias conocidas y activas que modifican el código fuente — Mine-imator Community Build, Continuation Build (fork directo de `stuffbydavid/Mine-imator` en GitHub), Vexel Build, Simply Upscaled Build, Community Edition. Su existencia pública y tolerada es consistente con un ecosistema que opera bajo MIT de hecho.

**Conclusión revisada:** la señal más fuerte de todas (la propia declaración escrita del mantenedor, vigente hasta hace 3 semanas) apunta a que el código sigue siendo MIT en la intención real de David Andrei, y que la falta actual de `LICENSE` en el repo es probablemente un descuido, no un cambio de política. Esto baja bastante el riesgo percibido. **Pero seguimos sin un `LICENSE` presente hoy en el repo**, y ninguna de estas piezas es una confirmación fechada para el código 2.0.x actual — así que la recomendación no cambia en la forma, aunque sí en el tono: pedir confirmación ahora es más una formalidad de cierre (probablemente un "sí, dale, y perdón por sacar el archivo sin querer") que una negociación incierta. Sigue siendo `[GATE]`: no es una decisión técnica que yo pueda tomar por vos.

Qué pedir, concretamente: (1) que confirme que el código 2.0.x sigue siendo MIT y, ojalá, que re-agregue el `LICENSE` al repo (soluciona esto para siempre, no solo para nosotros), (2) que un port móvil derivado y su distribución están cubiertos por eso, (3) el nombre (ver §9.5). Contacto: David Andrei (`mail@davidandrei.net`, o vía GitHub issue/discussion en `stuffbydavid/Mine-imator`, o el foro oficial).

**Respuesta de David Andrei (2026-09-06, por mail a `mail@davidandrei.net`):** confirma las 3 preguntas, textual:
- **El código 2.0.x es MIT**, confirmado por el propio mantenedor. Confirma también que sacar el `LICENSE` en 2023 fue un accidente de la limpieza de repo al migrar a C++, no una revocación deliberada — la lectura de la evidencia de arriba (git log, `Installer/Windows/license.txt`) era correcta. Dice que va a re-agregar el archivo `LICENSE` al repo, **todavía no lo hizo** al momento de este registro — no bloquea nada, pero hay que verificar más adelante si ya está antes de citar el repo como fuente formal.
- **Puerto móvil y distribución en Google Play, autorizados explícitamente** ("go right ahead... full permission... to modify it and distribute it on Google Play or wherever you want"). Única condición: mantener el aviso de copyright original en el código/créditos — estándar de MIT, no una condición extra.
- **El nombre: confirmado que no puede ser una variación de "Mine-imator"** — pidió explícitamente no usar algo como "Mine-imator Mobile", para que no parezca una app oficial suya y termine recibiendo reportes de bugs de una app que no escribió. Hace falta un nombre genuinamente distinto, no una variación — ver §9.5, actualizado.

**B7/§9.3 pasa de Alta a Resuelta.** Es el desbloqueo de mayor impacto de todo el proyecto — era el único riesgo marcado como capaz de matarlo por completo (`PHASE0_REPORT.md`, matriz de riesgos). Con esto, Fase 0 queda cerrada del todo (las 10 tareas) y Fase 1 ya no está frenada por §11.

### 9.4 Assets de Minecraft
Mine-imator no los redistribuye. **Esa arquitectura se mantiene sin excepción: no empaquetes texturas, modelos ni sonidos de Minecraft en el APK.** Esto es un `[GATE]` legal — un agente no lo decide, sin importar cuántas veces se lo pidan en la conversación (confirmado 2026-09-10: se evaluó y se rechazó explícitamente empaquetar `1.20.2.zip` real para Android, ver `KNOWN_ISSUES.md` B23).

**Corrección (2026-09-10) al cómo, no al principio:** esta sección daba a entender que existe un camino funcional de "el programa extrae los assets del `.jar` del usuario". Verificado que no es así — **no existe ningún conversor de `.jar` a los formatos internos de Mine-imator (`.zip`+`.midata`) en ninguna parte del código**, ni en GML ni en C++. Tampoco funciona hoy el camino secundario (descargar un paquete ya convertido desde `mineimator.com/assets.php`): el endpoint responde `{"versions":[]}` — confirmado con el build de escritorio real (HTTPS funcional ahí, sin ambigüedad de si es un problema de red), no es que esté roto, es que no tiene ninguna versión publicada. El principio legal (no redistribuir) sigue exactamente igual; lo que cambia es que hoy **no hay ningún camino automático, en ningún lado del proyecto, para que un usuario consiga assets de Minecraft** — el único camino real es conseguir un paquete ya convertido por fuera del programa y copiarlo a mano a la carpeta de datos. Detalle completo: `KNOWN_ISSUES.md` B26.

### 9.5 El nombre — `[GATE]` sigue abierto, con restricción confirmada
"Mine-imator" no está cubierto por una licencia de código. El proyecto necesita nombre propio para distribuir.

**Confirmado por David Andrei (2026-09-06):** no alcanza con evitar el nombre exacto — pidió explícitamente que **no sea una variación reconocible** (dio el ejemplo puntual de "Mine-imator Mobile" como lo que no quiere), para que no se lea como una app oficial suya y le lleguen reportes de bugs de un producto que no escribió. Elegir el nombre real sigue siendo una decisión del usuario, no técnica — este documento no la toma por vos.

---

## 10. Rutas técnicas — se decide DESPUÉS de Fase 0

| Ruta | Descripción | Costo | Riesgo | Qué la mata |
|---|---|---|---|---|
| ~~A~~ | ~~Export Android nativo de GameMaker sobre `GmProject`~~ — **DESCARTADA (2026-09-06)** | 3-6 meses | Medio | Pierde el renderer 2.0 y el runtime C++. Sin evidencia propia (0.4, el spike que la hubiera probado, se eliminó — ver §17) mientras B tiene evidencia medida (0.3, 0.6, 0.9) |
| **B** | Portar `CppProject` a Qt for Android | 12-24 meses-persona | Alto | B1 resuelto (0.3). B2 acotado y manejable con trabajo (0.6, 0.9). Sigue dependiendo de que 0.5/Fase 1 confirme el backend ES de shaders (§5.3, hoy asunción) |
| **C** | Emscripten/WASM + WebGL2 | 6-12 meses | Medio-alto | Rendimiento WebGL2 en Android |
| **D** | Runtime nativo nuevo, reutilizando formato y assets | 12+ meses | Alto | Costo |

**Decisión (2026-09-06):** la Ruta A queda descartada — no por medición propia (nunca se corrió el spike), sino porque la Ruta B ya acumuló evidencia real de sus dos bloqueos más críticos (B1 resuelto, B2 acotado) mientras A se queda con la misma incertidumbre del día 1. Gastar el spike de A ya no se justifica frente a eso. Quedan C y D sin evaluar, no descartadas — la recomendación de ruta del `PHASE0_REPORT.md` es sobre B vs. seguir con B, no una comparación completa de las 4.

---

## 11. FASE 0 — AUDITORÍA OBLIGATORIA

**Ninguna otra fase empieza hasta que Fase 0 esté cerrada y firmada.** Duración objetivo: 3 semanas. Salida: `research/PHASE0_REPORT.md` con datos medidos.

| # | Tarea | Criterio de éxito | Por qué |
|---|---|---|---|
| 0.1 | Compilar Mine-imator 2.0.2 sin modificar, en Windows y Linux | Ejecutable que abre, carga un proyecto y renderiza un frame. `BUILD_NOTES.md` con cada falla y su fix | Si no compilás el original, no lo portás. Qt desde fuente suele ser el cuello de botella |
| 0.2 | Auditar CppGen | `research/cppgen.md` con las 4 preguntas de §4.3 respondidas | Toda función nueva pasa por acá |
| 0.3 | **Resolver B1** — prototipo de `GraphicsApiHandler` sobre `QOpenGLExtraFunctions` | Compila para Android. Inventario de funciones GL faltantes clasificadas por versión ES | Es el bloqueo crítico. Si no se resuelve, la ruta B muere |
| ~~0.4~~ | ~~Spike GameMaker → Android sobre `GmProject`~~ — **ELIMINADA DEL PROYECTO (2026-09-06)** | — | Era el experimento barato para evaluar la Ruta A (§10). Decisión: con B1 resuelto sobre `CppProject` y B2 acotado, la Ruta B tiene evidencia medida; la Ruta A no tiene ninguna y no se va a generar. Ver §17 |
| 0.5 | Backend ES de `processCode` + `shader_high_light_point` (399 líneas) en dispositivo real — **MOVIDA A FASE 1 (2026-09-06)** | Compila y corre. Medir: tiempo de compilación, ms/frame, memoria | Valida §5.3 y el shader más pesado de una vez. Necesita un `CppProject` corriendo en Android, que no existe hasta Fase 1 ("APK que dibuja un triángulo") — no es ejecutable dentro de Fase 0 tal como está definida. Hasta entonces, §5.3 queda marcada como asunción no verificada, no hallazgo cerrado |
| 0.6 | **Medir B2** — ancho de banda del pipeline diferido — **CERRADA (2026-09-06)** | Pasadas fullscreen, targets del G-buffer, formato y resolución. MB/frame a 1080p vs ancho de banda de un SoC de gama media | Decide si el renderer diferido sobrevive. Resultado, tras 3 revisiones dentro de la misma tarea: el viewport interactivo default (`render_low`) no corre este pipeline y no está en riesgo. El pipeline caro (`render_high`, preview opt-in + export) entra en presupuesto sin indirect/reflections con preset móvil + RGBA16F (~11,7 GB/s @30fps); indirect/reflections quedan sin acotar sin dato de dispositivo real — `research/2026-09-06-b2-deferred-bandwidth.md` |
| 0.7 | Presupuesto de memoria con un mundo real importado — **CERRADA (2026-09-06)** | Memoria pico y tamaño de vertex buffers vs 4/8/12 GB | Define qué features limitar. Resultado, con `sizeof(obj_timeline)` real compilado (8.560B) y fracciones reales medidas sobre los `.schematic`/`.midata` que Mine-imator ya empaqueta (no hizo falta mundo real ni Android): preset "Grande" = **~60 MB medido** para terreno (el caso común), ~374 MB-1,63 GB razonado (sin muestra real) para una importación densa en decoración — `research/2026-09-06-memory-budget.md` |
| 0.8 | Inventario de las 13 primitivas de UI | `research/ui-inventory.md`: dimensiones, interacciones (click/drag/hover/scroll/doble/derecho), gesto táctil equivalente | Es el plano de la Fase 3 |
| 0.9 | Cobertura de `framebuffer_fetch` por vendor — **CERRADA (2026-09-06)** | Tabla Mali / Adreno / PowerVR / Xclipse con cuota de mercado | Determina si la mitigación de B2 es real. Resultado: Mali+Adreno (~95%+ del volumen Android vía cuota de SoC mapeada a GPU, no medición directa) confirman soporte; Xclipse (AMD RDNA, immediate-mode, <2% del mercado) es la única duda y no cambia la decisión — `research/2026-09-06-framebuffer-fetch-coverage.md` |
| 0.10 | `[GATE]` Bloqueos legales de §9 — **CERRADA (2026-09-06)** | Respuesta escrita de David Andrei. Decisión sobre x264 e iOS | Bloqueante del proyecto. Resultado: MIT confirmado, puerto móvil + Google Play autorizados, nombre debe ser genuinamente distinto (no "Mine-imator Mobile" ni variantes). x264/iOS quedan aparte, ya auditado el primero en B5 (`research/2026-09-06-b5-x264-mediacodec.md`) — ver §9.3 |

**Entregable:** `research/PHASE0_REPORT.md` con los resultados, una recomendación de ruta **fundada en las mediciones**, y una matriz de riesgos con probabilidad × impacto.

---

## 12. Fases posteriores

Esqueleto para 2-7. Fase 1 ya tiene plan detallado (`research/PHASE1_PLAN.md`, preparado 2026-09-06) — no ejecutado, frenado por §11 hasta que cierre 0.10.

| Fase | Objetivo | Definition of done |
|---|---|---|
| 1 | Compilar | APK que arranca y dibuja un triángulo. Sin features — pero "sin features" no es un binario reducido: no existe forma barata de compilar un subconjunto de `CppProject` (un solo `add_executable` con todo el árbol globbeado), así que implica que el Mine-imator completo compile y linkee para Android. Incluye la tarea 0.5 movida — hasta que corra, §5.3 sigue siendo asunción, no hallazgo cerrado. Plan detallado: `research/PHASE1_PLAN.md` |
| 2 | Renderizar | Escena estática correcta en dispositivo real. **✅ CERRADA (2026-09-09).** 3 shaders C++ (`world_checker`/`world_preview`/`world_box`) no compilaban en Android por mezcla `int`/`float` inválida en GLSL ES (KI-3), arreglados — **los 53 shaders del proyecto compilan limpio en Android** (antes 50/53). B19 (ningún shader tenía calificador de precisión GLSL ES): arreglado y **verificado en el dispositivo real** (Adreno 610), cero regresión. Verificación visual final en dispositivo real, con navegación de cámara real (no simulada): cielo/nubes con degradado y sombreado correctos, personaje (Steve) con colores completos y correctos en dos ángulos distintos, terreno sin moiré/banding visible, sin post-efectos default fuera de lo esperado. Log del dispositivo durante ~8.5 min de navegación real: cero errores de OpenGL, cero shaders fallidos, solo 2 warnings de red inofensivos. Hallazgo lateral durante esta verificación: el arrastre de cámara estaba roto bajo touch (B10, ver §6.3/§8) — parcheado de forma **instrumental** para poder completar esta verificación, no es la solución de Fase 4. Plan y hallazgos completos: `research/2026-09-09-fase2-plan.md` |
| 3 | UI táctil | Las 13 primitivas reimplementadas. **Los 68 paneles funcionan sin tocarlos** |
| 4 | Interacción | Cámara, timeline, manipulación. Lenguaje de gestos completo. **✅ CERRADA (2026-09-15).** Cámara: pellizco/pan de 2 dedos (2026-09-11), joystick virtual para vuelo libre extendido a cámaras reales editables además de la cámara de trabajo (2026-09-15). Gizmos de manipulación 3D (mover/rotar/escalar/target de cámara/bend, 7 archivos compartidos) y timeline (pellizco-zoom + pan de 2 dedos): implementados 2026-09-15. **Verificado en dispositivo real** (Redmi 10C, WiFi ADB) el mismo día — primera vez que se prueba con toques reales, no solo compilación: los 5 gizmos, gestos del timeline, panel dividido "Cámara activa" con su propio joystick, y el vuelo con cámara real, todos confirmados funcionando por el usuario ("funciona todo"). Detalle: `research/2026-09-15-fase4-timeline-gizmos-inventory.md` + `research/2026-09-15-fase4-gizmos-timeline-implementation.md`. De paso, misma sesión: barra de herramientas del viewport reposicionada para táctil (`view_toolbar_draw_touch.gml`), bug de superposición del workbench arreglado, ancho del popup del workbench corregido. Pendiente, no bloqueante: drag & drop de archivos → share intent (en rigor Fase 5), catálogo completo de atajos de teclado sin equivalente táctil (deliberadamente diferido, ver KNOWN_ISSUES.md) |
| 5 | I/O | SAF, import de `.jar`, `.miproject` compatible en ambos sentidos |
| 6 | Optimización | Presupuestos de §14 cumplidos en los 3 dispositivos de referencia |
| 7 | Export | Módulo de encoding de video nuevo sobre `AMediaCodec` (NDK, no un flag de FFmpeg — auditado pre-Fase 1, ver §9.1/`research/2026-09-06-b5-x264-mediacodec.md`). Decidir input por `ByteBuffer` o `Surface`. FFmpeg recompilado sin `--enable-gpl`/`--enable-libx264`, como librería dinámica. Con límites de duración y resolución |

**Criterio de Fase 3:** si tenés que modificar un panel individual, la primitiva está mal hecha. Volvé a la primitiva.

---

## 13. Fidelidad de UI

Objetivo: un usuario de Mine-imator de escritorio abre la app móvil y **reconoce dónde está todo**.

### 13.1 No cambia
- Jerarquía de paneles: mismos paneles, mismos nombres, mismo orden, misma región de pantalla
- Vocabulario: cada control se llama exactamente igual. Nada de "mejorar" nombres
- Iconografía: se reutilizan los 51 sprites
- Tema visual: colores, tipografía, bordes idénticos. `obj_theme` viaja tal cual
- Estructura del timeline: es el elemento más reconocible de Mine-imator
- Formato `.miproject`: compatible en ambas direcciones

### 13.2 Cambia, solo por imposibilidad física
- Dimensiones: 32px → 48dp mínimo (§6.2). Es física del dedo, no gusto
- Hover → estado presionado o desaparece; tooltips → long-press
- Click derecho → long-press
- Densidad: un monitor muestra 4 paneles, un teléfono uno. Se navegan por pestañas o drawer, **conservando contenido y orden internos**
- Atajos de teclado → UI o se pierden. Documentar cada pérdida

### 13.3 Regla de decisión

> Si no podés justificar un cambio con *"es físicamente imposible mantenerlo igual en una pantalla táctil de X pulgadas"*, **no lo cambies**.

Todo cambio va a `UI_DEVIATIONS.md`: qué cambió, por qué era imposible, qué alternativas se descartaron.

### 13.4 Prohibición

**No rediseñes Mine-imator.** Esto no es un proyecto de diseño. Todo impulso de "quedaría mejor si..." va a `IDEAS.md` y se discute post-v1.0. La fidelidad es el producto.

---

## 14. Optimización

Prohibida antes de Fase 6, con dos excepciones que no se pueden retrofitear: la arquitectura de render (§5.5) y el presupuesto de memoria (tarea 0.7).

### 14.1 Regla de medición
Ninguna optimización se acepta sin: medición antes, medición después, y el dispositivo exacto. En `PERF_LOG.md`.

### 14.2 Dispositivos de referencia
`[GATE — RESUELTO PARCIALMENTE 2026-09-15]` Definir tres dispositivos **físicos**: gama baja, media, alta. Los emuladores no cuentan para rendimiento gráfico ni térmico. **Decisión del usuario:** medir con el único dispositivo real disponible hoy (Redmi 10C / 220333QL, Android 13, Adreno 610 — el mismo usado en todas las pruebas de Fase 1-5) y avanzar Fase 6 con eso. Gama media y alta quedan pendientes hasta conseguir el hardware — cualquier presupuesto de §14.3 que dependa de comparar entre los 3 queda incompleto hasta entonces, pero medir/optimizar contra el 10C ya es información real, no bloqueada por este gate.

**Pre-investigado (2026-09-06, `research/2026-09-06-gpu-driver-quirks.md`):** hay bugs de driver documentados públicamente que valen la pena vigilar una vez que estos 3 dispositivos existan — no son blocker, no cambian nada hoy. El más concreto: en Adreno 540/650, un `highp float` dentro de un struct de shader pierde precisión (repro público). Al escribir el backend ES de shaders (0.5/Fase 1), evitar empaquetar valores de precisión crítica (profundidad, normales) dentro de structs, y seguir detectando soporte por función/extensión puntual — nunca por parseo de string de versión de GLSL, que Adreno reporta mal en algunos casos. Esta investigación tiene techo bajo sin hardware real (a diferencia de 0.6/0.7/0.9, acá no hay forma de verificar contra código propio) — es una lista de qué vigilar, no una auditoría cerrada.

### 14.3 Presupuestos (ajustar tras Fase 0)

**Son dos presupuestos distintos, no dos niveles de exigencia del mismo problema.** Corren pipelines de render diferentes (`render_low()`/`SHADED`, el default del viewport, vs. `render_high()`/`RENDER`, opt-in + export — ver §8 B2 y `research/2026-09-06-b2-deferred-bandwidth.md`) y el usuario los juzga con criterios distintos: un viewport que no responde se siente roto; un render que tarda es lo que ya espera, incluso hoy en desktop. Confundir los dos es exactamente el error que hizo que B2 pareciera Crítica en una revisión intermedia de 0.6, cuando el objetivo real en riesgo era otro. Si esta distinción se lee como implícita en vez de como dos filas separadas, se vuelve a perder en tres meses — por eso está deletreada acá, no solo en el research doc.

| Métrica | Objetivo | Pipeline |
|---|---|---|
| Viewport interactivo | 30 fps sostenidos en gama media | `render_low()` / `SHADED` (default) |
| Preview "Render" / export — tiempo por frame a 1080p | A definir con dato de dispositivo real (0.5/Fase 1) — no es una tasa de fps | `render_high()` / `RENDER` (opt-in) y export |
| Arranque | < 5 s | — |
| Memoria pico, escena típica | < 1,5 GB | — |
| Throttling térmico | sin caída > 20% tras 10 min | — |

**Por qué "tiempo por frame a 1080p" y no "resolución máxima sin que el proceso muera":** la segunda es una falla binaria de memoria — ya es el territorio de la tarea 0.7 (presupuesto de memoria), y no dice nada si el dispositivo "no muere" a 1080p pero tarda 40 segundos por frame, que igual sería inaceptable y quedaría invisible con esa métrica. "Tiempo por frame a una resolución fija" es continuo, comparable entre los tres dispositivos de referencia de §14.2, comparable contra la expectativa que el usuario ya trae de exportar en desktop, y mide directamente lo que B2 investiga (cuánto cuesta el pipeline caro), no si algo se queda sin RAM. El número objetivo queda sin definir a propósito — fijarlo sin medición antes en un dispositivo real violaría la propia regla de §14.1.

### 14.4 Ejes, por impacto esperado
1. **Ancho de banda del renderer** (B2). El más grande, por mucho
2. **Geometría de mundos importados.** Culling, LOD, chunks bajo demanda, límite duro de radio
3. **Atlas de texturas.** Ya existe `TexturePage.cpp`. Verificar `GL_MAX_TEXTURE_SIZE` real del dispositivo
4. **Presupuesto térmico.** El enemigo real no es el frame time, es el throttling a los 5 minutos
5. **Modos de calidad.** El original ya tiene tiers de shader (§5.4). Explotar eso antes de escribir código nuevo

**Nota sobre TBDR (0.9, 2026-09-06):** `framebuffer_fetch` y cualquier otra mitigación de ancho de banda que dependa de arquitectura tile-based cubren hoy ~95%+ del volumen Android (Mali+Adreno). Pero Samsung ya se movió a immediate-mode (Xclipse/AMD RDNA) en su línea flagship — si otros fabricantes de SoC premium siguieran esa dirección, la cobertura de TBDR en gama alta podría erosionarse con los años. No cambia nada hoy; sí es una razón para no acumular más optimizaciones que asuman TBDR como propiedad permanente al elegir el dispositivo de "gama alta" de §14.2. Ver `research/2026-09-06-framebuffer-fetch-coverage.md`.

---

## 15. Reglas operativas

1. Un commit por unidad lógica. El mensaje explica el **por qué**, no el qué
2. Nunca commitear en `master`. Rama por tarea
3. Todo cambio sobre código upstream va a `PATCHES.md` con el motivo. Queremos poder hacer rebase si aparece un fork vivo
4. `KNOWN_ISSUES.md` se actualiza en el mismo commit que introduce el problema
5. Si una tarea supera lo previsto por más de 2×, **abrí un gate G5**. No sigas cavando
6. El GML mantiene el estilo del original: tabs, `snake_case`, comentarios `/// nombre_funcion()`. No impongas tu estilo sobre 98.000 líneas ajenas
7. Toda afirmación sobre el comportamiento del original lleva referencia `archivo:línea`
8. Al final de cada sesión: actualizá `STATUS.md` con qué se hizo, qué quedó abierto, y cuál es el siguiente paso

---

## 16. Definición de éxito para v1.0

Un usuario en Android puede:
- Abrir un `.miproject` creado en escritorio y verlo correctamente
- Colocar manualmente un paquete de assets de Minecraft ya convertido (`.zip`+`.midata`) en la carpeta de datos de la app y seleccionarlo desde Configuración (`[GATE] corregido 2026-09-10, ver abajo`)
- Manipular cámara y objetos con gestos
- Editar keyframes en el timeline
- Guardar un `.miproject` que el escritorio abre sin pérdida
- Exportar al menos una imagen a resolución completa

**Corrección (2026-09-10):** esta fila decía "Importar assets de Minecraft desde un `.jar` que él provee" — verificado que **eso no existe en ninguna parte del proyecto**: no hay ningún conversor de `.jar` a `.zip`/`.midata`, ni en GML ni en C++ (grep exhaustivo, incluyendo `World/`/`Library/` y términos como `blockstate`/`atlas`/`install_version`/`import_version`/`convert`, sin resultados relevantes). El selector de "versión de Minecraft" de Configuración (`tab_settings_program.gml`) es un simple listado de archivos `.midata` ya presentes en la carpeta (`list_init.gml`: `file_find(minecraft_directory, ".midata")`) — no acepta ni procesa un `.jar`. Lo único que existe y funciona es: colocar a mano un paquete ya convertido (obtenido por fuera del programa) en esa carpeta, y elegirlo en ese selector. Detalle completo: `KNOWN_ISSUES.md` B26.

Export de video queda fuera de v1.0 si Fase 0 muestra que no es térmicamente viable.

---

## 17. Registro de correcciones

| Ver. | Sección | Qué decía antes | Qué dice ahora | Evidencia |
|---|---|---|---|---|
| v2.0 | §5.3 | "Los shaders son GLSL desktop, probablemente sin `precision` qualifiers. Pasada sistemática sobre los 94" | Están en dialecto GLSL ES 1.00 y se transpilan hacia arriba. Se escribe un backend, no 94 shaders | `ShaderLoadOpenGL.cpp:23-100` |
| v2.0 | §5.1 | "Renderer OpenGL-first: adaptación, no reimplementación" | Sigue siendo cierto, pero había un bloqueo crítico no detectado: los tipos base de Qt son desktop-only | `GraphicsApiHandler.hpp:11,41` · `Shader.hpp:9,219` |
| v2.0 | §5.2 | No mencionado | Batching por SSBO requiere ES 3.1, con degradación ya implementada | `ShaderLoadOpenGL.cpp:13-15,255-262` |
| v2.0 | §1 | Checkpoints humanos como lista al final | Protocolo de 5 gates con formato de pregunta obligatorio | Pedido del usuario |
| v2.0 | §8 | No existía | Catálogo de 16 bloqueos con severidad, evidencia y síntoma esperado | — |
| 2026-09-06 | §3 | "Último commit conocido: nov 2023" | HEAD real es `01a62c0e` (2026-08-29). Solo 17 commits desde nov 2023 (mayoría build/tooling: migración de CppGen a C++, actualización de librerías, fixes de Mac/Linux, normalización de line endings). Las 3 citas `archivo:línea` de §5.1/§5.2/§5.3/§6.2 y los conteos de §3.1 (2.067 archivos / 98.840 líneas GML, 94 shaders / 5.733 líneas, 58 objetos, 51 sprites) verifican exactos contra este HEAD pese al salto de fecha | `git log --since=2023-11-01 --oneline` (17 commits) · recuento directo con `find`/`wc -l` |
| 2026-09-06 | §3.1, §5.3 | "94 shaders" | Son **53**: 47 en `GmProject/shaders` (94 archivos) + 6 exclusivos de C++ en `CppProject/Asset/Shaders/` (`primitive`, `world_box`, `world_box_resize`, `world_checker`, `world_player`, `world_preview`; 12 archivos, 211 líneas) que no tienen contraparte en GmProject. Total real: 106 archivos fuente / 5.944 líneas. La estrategia de "un backend, no N shaders" de §5.3 sigue en pie, pero el backend debe cubrir los 53 | `git ls-files CppProject/Asset/Shaders` |
| 2026-09-06 | §8 | No existía B17 | El backend D3D11 cachea bytecode compilado en disco/`.qrc` (`ShaderLoadD3D11.cpp:343-403`, `index.qrc`: 106 entradas); el backend OpenGL —el que viaja a Android— no tiene ningún equivalente, compila GLSL desde fuente en cada arranque. Nuevo bloqueo B17, severidad media | `Shader.cpp:96-109` · `ShaderLoadD3D11.cpp:343-403` · `index.qrc` |
| 2026-09-06 | §4.3 (tarea 0.2) | 4 preguntas abiertas sobre CppGen | Auditado completo: 4 comportamientos distintos ante lo desconocido (no 2: "falla o rompe"), salida 100% agnóstica de plataforma, herencia de objetos GameMaker ignorada, `other` siempre entero no tipado. `CppGen.exe` corrido de verdad sobre el corpus completo: 0 warnings, exit 0, pero solo resuelve 58% de los tipos de variable (dato nuevo). Un ejemplo del informe original (evento `Alarm_0` de `app` como caso de descarte silencioso) se verificó y resultó ser un archivo huérfano no habilitado en `app.yy`, no un descarte real de CppGen — corregido en el texto de §4.3 | `research/2026-09-06-cppgen.md` · corrida real de `CppGen/Win64/CppGen.exe` · `app.yy` (sin entrada de Alarm) |
| 2026-09-06 | §6.1 (tarea 0.8) | "Reimplementás 13 funciones... los 68 paneles se readaptan solos" | Verificado: las 13 `tab_control_*` (y la base `tab_control()`) no leen ningún input — es pura geometría. La interacción real vive en una familia paralela `draw_*`/`sortlist_*`/`menu_*` que cada panel llama aparte. La superficie de Fase 3 es el par tab_control+draw, no las 13 solas | `research/2026-09-06-ui-inventory.md` · `tab_control.gml` (sin `mouse_*`/`keyboard_check*`) · `tab_control_checkbox.gml` (3 líneas, delega todo) |
| 2026-09-06 | §9.3, B7 | "El único `license.txt` (en Installer/Windows/) declara el software propiedad de David Andrei" | Falso. Se leyó el archivo real: es el EULA estándar de GameMaker/YoYo Games (sobre el motor, no sobre Mine-imator), no menciona a David Andrei ni ninguna declaración de copyright propia del proyecto. La situación real es más simple y más seria: no hay ninguna licencia propia de Mine-imator en el repo, en ningún archivo — no "dos fuentes que se contradicen" | `grep -rli "david andrei\|copyright"` (sin resultados propios de Mine-imator) · `GmProject/options/windows/installer/license.txt` (contenido leído completo) |
| 2026-09-06 | §5.1 (tarea 0.3) | B1 confirmado solo por lectura de código, sin compilar | Confirmado con compilador real contra Qt-Android recién construido. **Trampa metodológica registrada:** `#include <QOpenGLFunctions_3_1>` solo NO tira error (el archivo existe) — hay que probar el USO real del tipo (herencia/instanciación) para que el fallo aparezca. Un chequeo que se hubiera quedado en "¿compila el `#include`?" habría reportado, mal, que B1 no era un problema | `struct X : QOpenGLFunctions_3_1` → `error: expected class name`; `QOpenGLFunctions_4_3_Core* g` → `error: unknown type name` — ambos contra `C:\Dev\Qt\5.15.19\install-android` real |
| 2026-09-06 | §5.1/§5.2 (tarea 0.3) | "Ruta a evaluar en Fase 0: reemplazar por `QOpenGLExtraFunctions`" (sin confirmar) | Reemplazo probado y confirmado: 48/49 llamadas GL reales del código compilan limpio contra `QOpenGLExtraFunctions` en el NDK real. Única excepción: `glShaderStorageBlockBinding` (sin equivalente en ningún ES), ligada al batching opcional ya degradable | `research/2026-09-06-b1-graphicsapihandler-prototype.md` |
| 2026-09-06 | §9.3 | (ampliación, a raíz de una afirmación externa de "MIT confirmado" traída por el usuario, sin fuente verificable) | El MIT **sí existió**, 2018-2023 (`LICENSE` creado por David Norgren, commit `fab960f8`), y se borró en el commit `6d48eaff` ("2.0.0", 2023-03-01, autor David Andrei). Sigue vivo solo en ramas abandonadas (`cubist`, `1.2.9`), no en `master` | `git log --all --diff-filter=A\|D -- LICENSE` · `git show fab960f8:LICENSE` · `git show -s 6d48eaff` |
| 2026-09-06 | §9.3 | "sacó el LICENSE a propósito... eso es una señal, no un accidente" | Corregido — encontrado un segundo archivo (`Installer/Windows/license.txt`, distinto del EULA de GameMaker de la corrección anterior) donde David Andrei siguió afirmando por escrito "the source code is available on GitHub under the MIT license" hasta el commit `8732ee7e` (2026-08-21, "Removed installer files", borrado junto con TODA la carpeta `Installer/` como limpieza general, no dirigido a la licencia). O sea: la ausencia actual de LICENSE es más probablemente un descuido de reorganización que una revocación deliberada — baja el riesgo percibido, aunque el `[GATE]` de pedir confirmación sigue en pie | `git show c6dde608:Installer/Windows/license.txt` (contenido completo leído) · `git log --all -- Installer/Windows/license.txt` · builds comunitarias conocidas (Community Build, Continuation Build, Vexel Build, Simply Upscaled Build, Community Edition) corroboran un ecosistema de facto MIT |

| 2026-09-06 | §5.1.1/§5.2 (tarea 0.3) | `[GATE G1]` abierto, sin decidir | `[GATE G1 — CERRADO]`: Opción A, no portar el batching por SSBO a Android. Razón registrada: sin la medición de 0.6 (ancho de banda del pipeline diferido) no se sabe si los draw calls extra por no batchear son un cuello de botella real — invertir en Opción B ahora sería optimizar a ciegas, prohibido por §14 fuera de Fase 6. Opción B queda parqueada para Fase 6 con viabilidad ya probada | Decisión del usuario, 2026-09-06 |

| 2026-09-06 | §8, B2 (tarea 0.6) | "MRT diferido sobre TBDR móvil", evidencia "8 shaders con `gl_FragData`" | Medido: el término dominante del ancho de banda (>93% del total en config. default) no son esos 8 shaders MRT sino el ray marching en screen-space de indirect lighting/reflections (`shader_high_raytrace.fsh`, 256-512 pasos por píxel, ambas features prendidas por default). El G-buffer solo, sin esas dos features, ya ronda el 100% del pico teórico de un SoC de gama media a 30fps; con ellas prendidas pide ~19× ese pico | `research/2026-09-06-b2-deferred-bandwidth.md` |

| 2026-09-06 | §8, B2 (tarea 0.6, revisión final) | "El renderer diferido no sobrevive ni sin indirect/reflections" (versión intermedia de esta misma tarea) | Corregido dos veces más: (1) el costo de indirect/reflections se había calculado con 0% de cache hit, un peor caso presentado sin rango; (2) el pipeline costeado (`render_high`) no es el que usa el viewport interactivo por default — eso es `render_low()` (`view_update_surface.gml:17-20`, vistas arrancan en `SHADED`), mucho más barato, y no está en riesgo. Con preset móvil (3 flags existentes) + formatos optimizados + RGBA16F, `render_high` sin indirect/reflections entra en presupuesto sostenido (~11,7 GB/s @30fps) | `research/2026-09-06-b2-deferred-bandwidth.md` — incluye el historial completo de las 3 revisiones, no solo el resultado final |

| 2026-09-06 | §14.3 | Una sola fila de "viewport interactivo, 30fps" sin distinguir pipeline | Dos filas separadas: viewport interactivo (`render_low`/`SHADED`, 30fps) y preview Render/export (`render_high`/`RENDER`, tiempo por frame a 1080p — no fps). Son presupuestos distintos, no dos niveles del mismo, porque corren pipelines distintos y el usuario los juzga distinto | `research/2026-09-06-b2-deferred-bandwidth.md`, hallazgo de la tarea 0.6 |

| 2026-09-06 | §10, §11 | Tarea 0.4 (spike Ruta A) pendiente; Ruta A y B ambas abiertas a decidir tras Fase 0 | **Decisión, no hallazgo:** 0.4 eliminada del proyecto, Ruta A descartada sin correr el spike. Motivo: B1 resuelto (0.3) y B2 acotado (0.6, 0.9) le dieron a la Ruta B evidencia medida que la Ruta A nunca iba a tener sin gastar el mismo esfuerzo — no se justifica seguir manteniendo A como alternativa activa | Decisión del usuario, 2026-09-06 |
| 2026-09-06 | §5.3, §11, §12 | Backend ES de `processCode` tratado como hallazgo de §5.3, tarea 0.5 dentro de Fase 0 | 0.5 movida a Fase 1 — necesita un `CppProject` corriendo en Android, que no existe antes de esa fase. §5.3 marcada explícitamente como asunción no verificada hasta que 0.5 corra, no como hallazgo cerrado | Decisión del usuario, 2026-09-06 |

| 2026-09-06 | §8, B11 (tarea 0.7) | "Vertex buffers grandes" como evidencia, sin cuantificar | `WorldVertex` confirmado compacto (8B/vértice) — no es el riesgo. Corregido dos veces más dentro de la misma tarea: (1) `sizeof(obj_timeline)` real compilado = 8.560B, el doble de la estimación por composición de campos (~4,3KB); (2) el `.midata` que se pensaba externo en realidad viene empaquetado con Mine-imator (`Data/Minecraft/1.20.2.midata`), igual que 39 `.schematic` reales de ejemplo (`Schematics/`) — parseados directamente, sin necesitar mundo real ni Android: 9,47% de tipos de bloque tienen timeline, pero solo 0,00003% de bloques *colocados* en terreno real lo tienen. Preset "Grande": ~60 MB medido para terreno, ~374MB-1,63GB razonado (no medido) solo para importaciones densas en decoración | `research/2026-09-06-memory-budget.md` |

| 2026-09-06 | §9.1, §8 B5, §12 (auditoría pre-Fase 1) | "MediaCodec resuelve legal y de rendimiento a la vez", presentado como sustitución directa | Confirmado el resultado, corregida la vía: FFmpeg upstream soporta MediaCodec para decodificar, no para encodear — hace falta un módulo de encoding nuevo sobre `AMediaCodec` (NDK), no un flag de build de FFmpeg. El resto de `MovieLib.cpp` (audio, muxeo) no depende de x264 y sigue siendo LGPL. Cambia el alcance de Fase 7, B5 baja de Alto a Bajo igual | `research/2026-09-06-b5-x264-mediacodec.md` |

| 2026-09-06 | §3.3 (tabla de dependencias) | "ffmpeg: Medio — reemplazable por MediaCodec" / "x264: Alto — GPL, §9.1", sin actualizar tras la auditoría de B5 | Corregido para que coincida con §9.1/§8 B5 ya auditados: ffmpeg baja a Bajo (solo el encoder de video depende de GPL, el resto queda LGPL al sacar x264), x264 baja a Baja (resuelto en diseño vía `AMediaCodec`, no "reemplazable" como si fuera un flag). §9.1 en sí ya estaba corregido desde la auditoría de B5 en el mismo día — este era un residuo en una tabla aparte que no se había cruzado | `research/2026-09-06-b5-x264-mediacodec.md` |

| 2026-09-06 | §9.3, §9.5, §8 B7, §11 (tarea 0.10) | `[GATE]` legal abierto, esperando respuesta de David Andrei | David Andrei respondió por mail: MIT confirmado para 2.0.x, puerto móvil y distribución en Google Play autorizados explícitamente, nombre debe ser genuinamente distinto (pidió puntualmente no usar algo como "Mine-imator Mobile"). B7 pasa de Alta a Resuelta — era el riesgo de mayor impacto de toda la matriz (capaz de matar el proyecto entero). Fase 0 queda cerrada del todo; Fase 1 (`research/PHASE1_PLAN.md`) ya no está frenada por §11 | Mail de David Andrei a `mail@davidandrei.net`, 2026-09-06 |

| 2026-09-06 | §4.3 (tarea 0.2, cierre del pendiente) | "El evento `Alarm_0` de `app` no está habilitado en `app.yy` — es un archivo huérfano, no un descarte real" (corrección previa de esta misma tabla, fila anterior) | **Esa corrección estaba mal.** Releído `app.yy:24-30` directo: el evento sí está en el `eventList` (6 entradas, incluye `eventType:2/eventNum:0` = Alarm 0). Una corrida real de CppGen hoy confirmó además que el mecanismo de pérdida no es el `WARNING` de la ruta (e) sino uno más silencioso todavía, un paso antes (`Object.cpp:22-25`): el contenido del evento (`window_center()`) no resuelve a ninguna función registrada, así que se descarta con `continue` sin imprimir nada. Corregido en §4.3. Lección: una "corrección" también hay que releerla contra la fuente, no asumirla firme porque ya se corrigió una vez | Corrida real de `CppGen.exe` en rama `fase0-0.2-cppgen-diff-check` + relectura directa de `app.yy` |

| 2026-09-06 | §14.2, B3 (pre-Fase 2) | No existía | Investigación de bugs de driver GL ES conocidos por vendor (Mali/Adreno), acotada a lo que este port realmente necesita (precisión, MRT, VAOs, versión GLSL, arrays de matrices). Sin blockers nuevos — un bug de precisión con repro público (Adreno 540/650, `highp` en struct) y un precedente de Qt sobre B3 (Samsung XCover 3). Techo de utilidad bajo sin hardware real, a diferencia de 0.6/0.7/0.9 | `research/2026-09-06-gpu-driver-quirks.md` |

| 2026-09-06 | §5.1.1 (Fase 1, primer cambio de código real) | Tratamiento de `Shader.hpp`/`.cpp`/`ShaderLoadOpenGL.cpp` diseñado, no aplicado | Aplicado en rama `fase1-shader-android-guard`. Verificado con compilador real en desktop (MSVC, 0 warnings) y Android (NDK `clang++` contra Qt-Android real, confirma que `Q_OS_ANDROID` se auto-define, no hace falta definirlo a mano) | `git diff` en `fase1-shader-android-guard`, sin commitear |

| 2026-09-06 | §8, B4, nuevo B18 (Fase 1, punto 4 del plan) | 0.3 solo había auditado llamadas GL — el resto de `CppProject` sin barrer | Barrido de grep (no compilación) sobre APIs desktop-only: `QFileDialog` da línea exacta a B4 (`Gml/FileFunc.cpp:208,233`); nuevo hallazgo B18 (`QDesktopWidget` deprecado alimentando el escalado de touch targets, riesgo de DPI mal leído en Android, no confirmado); drag-and-drop de archivos (`AppWindow.cpp`) compila pero queda muerto en Android, hueco de Fase 5, no bloqueo. Ningún hallazgo nuevo tipo B1 | `research/PHASE1_PLAN.md`, punto 4 |

| 2026-09-08 | §5.1.1, Fase 1 puntos 2/4 (`research/PHASE1_PLAN.md`) | CMake/empaquetado Android "la pieza menos explorada, la que más podría esconder sorpresas"; barrido de APIs Windows-only cerrado por grep, con la salvedad de que un grep no podía cerrarlo del todo | Ambas cerradas con una compilación real completa de `CppProject` para Android (7 iteraciones), no solo diseño/grep. Qt trae su propio módulo de CMake para Android (`Qt5AndroidSupport.cmake`) que hace la mayor parte del trabajo de empaquetado. Se encontraron y arreglaron 5 bugs de compilación reales (`qopenglext.h`/`GLclampd`, `GL_TEXTURE_LOD_BIAS`, `isInitialized()`, `initializeOpenGLFunctions()` sin bool, `QThread::create` no disponible en esta build de Qt) — 2 de ellos **no específicos de Android**, latentes en la rama OpenGL compartida desde la migración de 0.3, nunca compilados hasta ahora porque Windows usa D3D11. El 100% del código compila; solo quedan símbolos de linkeo por librerías externas todavía no construidas (lista ampliada: zlib y libpng no estaban anticipados) | `research/2026-09-08-fase1-android-cmake-first-build.md` |

| 2026-09-08 | §5.1.1, Fase 1 punto 1 (`research/PHASE1_PLAN.md`) | Solo quedaban símbolos de linkeo por librerías externas no construidas (zlib, libpng, OpenAL, libzip, FFmpeg sin x264) | Las 5 se compilaron y linkearon con éxito contra el NDK. Encontrado en el camino: `libavutil/avconfig.h` (header generado por `configure` de FFmpeg) es específico de arquitectura, no solo de compilador — la copia versionada para Windows/x86_64 tenía `AV_HAVE_FAST_UNALIGNED=1`, la real de Android/aarch64 tiene `0`; hubiera sido un bug silencioso de compartirla sin más. FFmpeg necesitó instalar MSYS2 (`C:/Dev/msys64`) porque el `make` nativo del NDK no traduce rutas POSIX ni ejecuta los wrappers de compilador (son scripts bash) — mismo mecanismo que `Setup.ps1` ya usa para desktop, solo que no estaba instalado en esta máquina. **Resultado verificado con el build más fuerte posible:** `cmake --build .` completo de todo `CppProject` para Android — 160 archivos, 0 errores, link exitoso, `libMine-imator_arm64-v8a.so` real de 72,6MB, sin ninguna mención de símbolo indefinido en el log. Primera vez que el proyecto completo no solo compila sino que **linkea** para Android | `research/2026-09-08-fase1-external-libraries-android.md` |

| 2026-09-08 | §5.1.1, Fase 1 (empaquetado) | Punto 1 cerrado, pero `androiddeployqt`/Gradle real nunca se había intentado | Corrido y cerrado: **primer `.apk` real del proyecto** (`BUILD SUCCESSFUL`, verificado con `aapt list`, no solo por el mensaje). En el camino: `androiddeployqt.exe` no existía en la instalación de Qt-Android (se terminó de compilar un build parcial ya presente en el árbol de Qt); `find_program`/`find_library` de CMake no veían nada fuera del sysroot del NDK aun con las herramientas ya compiladas (arreglado con `CMAKE_PROGRAM_PATH`/`CMAKE_FIND_ROOT_PATH` apuntando a la instalación de Qt, no bajando la restricción de cross-compile); AGP 8.x ya no infiere el namespace del manifest, hay que declararlo en `build.gradle`. Hallazgo aparte, de proceso: un build que falló de verdad dejó el árbol de procesos (`cmake`→`ninja`→`gradlew.bat`) colgado 45 minutos sin avisar — un build de Android "sin progreso" no se puede asumir que sigue vivo solo porque el proceso lo está; hay que cruzarlo contra el log del daemon de Gradle | `research/2026-09-08-fase1-apk-packaging.md` |

| 2026-09-08 | §5.1.1, §14.2 B3, tarea 0.5, Fase 1 (primera corrida en dispositivo real) | B3 (bugs de driver GPU) sin confirmar contra hardware real; tarea 0.5 (backend ES en dispositivo real) sin empezar; el comentario de `CMakeLists.txt` sobre `GM_SHADERS_DIR`/`ASSETS_DIR` como rutas absolutas del host marcaba el problema como "no investigado" | Primera instalación y corrida real en un dispositivo físico (Xiaomi/Redmi, Android 13, Adreno 610). Encontrados y arreglados dos bugs reales que ningún build de host podía revelar: OpenMP sin empaquetar (`libomp.so`) y `GraphicsApiHandler.cpp` pidiendo OpenGL de escritorio (`AA_UseDesktopOpenGL`, versión 4.3 Core) en la rama compartida con Android, causando `EGL_BAD_MATCH` en cada intento de crear contexto — arreglado con un guard `#ifdef Q_OS_ANDROID` pidiendo ES 3.0 sin perfil. Con eso resuelto, se confirmó con evidencia real (no solo sospecha) que `GM_SHADERS_DIR`/`ASSETS_DIR` son rutas absolutas de Windows horneadas en el binario — las 49 shaders reportan "not found" en el log real del dispositivo (`log.txt` de la propia app, accedido vía `adb run-as`), y una de ellas (`shader_high_glint`) falla a compilar por esto, deteniendo la app de forma controlada (`game_end()`, no un crash) con su propio diálogo de error. Esto cierra la incógnita que el comentario de `CMakeLists.txt` había dejado abierta — confirma la causa raíz real, sigue faltando la solución (empaquetado de assets para Android) | `research/2026-09-08-fase1-first-device-run.md` |

| 2026-09-08 | §12, Fase 1 (cierre) | Objetivo de Fase 1: "APK que arranca y dibuja un triángulo. Sin features." | **Superado, no solo cumplido.** Verificado en un dispositivo Android real (Xiaomi/Redmi, Adreno 610): Mine-imator arranca con su interfaz de escritorio completa (menú, barra de herramientas, panel de propiedades, timeline) y dibuja la escena 3D real de un proyecto nuevo (bloque de pasto, cielo, nubes, terreno) vía OpenGL ES 3.0 real. En el camino se encontraron y arreglaron 7 bugs reales que ningún build de host podía revelar: instalación bloqueada por MIUI, OpenMP sin empaquetar, `GraphicsApiHandler.cpp` pidiendo OpenGL de escritorio (causaba `EGL_BAD_MATCH`), rutas de shaders absolutas del host de build, `DEBUG_MODE` ignorando el recurso Qt ya embebido para shaders, inicializadores de variables globales no válidos en GLSL ES (desktop GLSL los permite, ES no), y un shader (`primitive`) cargando antes de que `Shader::Init()` fijara la versión de GLSL correcta. Fase 1 queda cerrada — sigue Fase 2 (adaptación de la UI a táctil, la proporción desajustada de los paneles ya visible en la captura de cierre) | `research/2026-09-08-fase1-first-device-run.md` |

| 2026-09-09 | §6.2, §8 (nuevo, no reemplaza nada), Fase 2 (investigación de la pantalla de carga en dispositivo real) | El modelo de escalado (`App->scale`) no tenía una decisión de arquitectura explícita frente al futuro `window_touch` de Fase 3 — CLAUDE.md solo mencionaba `window_touch` como "punto de entrada", sin resolver cómo interactúa con la densidad | **Gate G1 cerrado.** Investigando dos bugs visuales reales en la pantalla de carga en dispositivo (franjas + barra de progreso ausente), se encontró la causa raíz: `AppHandler.cpp:343` armaba la superficie interna de render al tamaño REAL de la ventana, pero `window_get_width()/height()` (todo el GML) y el composite final (`GLWidget.cpp`) asumen esa superficie dividida por `App->scale` — un desajuste que se reproduce IDÉNTICO en escritorio forzando `Interface Scale` a 200% (verificado con el build de Windows, ver `PATCHES.md`), confirmando que es un bug preexistente de Mine-imator, no del port. Se evaluaron 3 opciones (componer sin reescalar; lienzo lógico consistente; `scale=1` fijo en Android con todo resuelto por `window_touch`) — decisión: **B, lienzo lógico consistente** (`BeginUse(win->size() / scale)`), porque es la única que no invalida el modelo de §6.2 para las 13 primitivas y no toca ninguna. Conclusión de arquitectura registrada en §6.2: `App->scale` (densidad) y `window_touch` (ergonomía táctil) son ejes ortogonales que se multiplican, no alternativas — Fase 3 tiene que respetar esa separación. Fix verificado no-op en escritorio con `scale=1` y verificado que corrige el desajuste con `scale=2` en escritorio Y en el dispositivo Android real, mismos números en ambos. Queda un segundo problema, distinto y todavío abierto (KI-2, `KNOWN_ISSUES.md`): la caja fija de 740×450 de esa pantalla sigue siendo más alta que el lienzo lógico disponible en el teléfono en horizontal (360) — no es un problema de escalado, es que el diseño de esa pantalla específica no fue pensado para una pantalla tan chica | `KNOWN_ISSUES.md` (KI-1 resuelto, KI-2 abierto), `PATCHES.md` |

| 2026-09-09 | §12, Fase 2 (cierre); §8, B10 | Fase 2 "en progreso", con el checklist visual (cielo, personaje de cerca, aliasing) bloqueado por la política de MIUI contra inyección de eventos táctiles vía ADB — sin forma de navegar la cámara del dispositivo | **✅ Fase 2 cerrada.** El bloqueo real no era MIUI — con el usuario sosteniendo el teléfono, arrastrar para orbitar la cámara resultó estar roto: `camera_control_rotate.gml`/`camera_control_move.gml` (upstream, mouse-look de escritorio) recentran el cursor del SO cada frame con `display_mouse_set()`, algo sin equivalente en touch (Android reporta la posición real del dedo, compite con el recentro, cámara errática). Parche **instrumental** (guard `platform_get() == e_platform.ANDROID`, usa `mouse_dx`/`mouse_dy` crudo en vez de recentrar) para destrabar la verificación, documentado como deuda de Fase 4 en `KNOWN_ISSUES.md` B10 — no confundir con la solución de input táctil. Con el arrastre funcionando, se navegó la cámara real y se verificó: cielo/nubes con degradado y sombreado correctos, personaje con colores completos en 2 ángulos, terreno sin moiré visible, log del dispositivo (~8.5 min de navegación real) sin ningún error de OpenGL. Detalle: `research/2026-09-09-fase2-plan.md` | `KNOWN_ISSUES.md` B10, `PATCHES.md`, `research/2026-09-09-fase2-plan.md` |

| 2026-09-09 | §6.1, §6.3 (arranque de Fase 3) | §6.1 ya tenía una nota de corrección (fila 2026-09-06 de esta misma tabla) pero el título y la "Implicación" de la sección seguían framing las 13 `tab_control_*` como el apalancamiento real, y `scrollbar_draw.gml` no estaba mencionado en `CLAUDE.md` en absoluto (solo en el research doc) | Reescrita la "Implicación" de §6.1 para no afirmar que reimplementar las 13 alcanza, y agregado un párrafo explícito: el apalancamiento real son 2 archivos que las 13 primitivas ni mencionan — `context_menu_area.gml:22` (long-press, cubre 5 primitivas + textbox) y `scrollbar_draw.gml` (swipe-scroll, cubre `sortlist`+`menu`). Es una corrección al MODELO (dónde vive el apalancamiento), no un detalle nuevo — la fila de 2026-09-06 ya había encontrado el hecho, esta corrige que `CLAUDE.md` no lo reflejaba del todo. Además, §6.3 Trampa 1 (interceptar `QTouchEvent`) se marca explícitamente como `[GATE G1 — DIFERIDO]` a Fase 4, no resuelto: ninguna de las 13 primitivas necesita multitouch, así que Fase 3 sigue apoyándose en el mouse sintetizado de Qt | `research/2026-09-06-ui-inventory.md` |

| 2026-09-09 | §8, B21 (override Fase 6, a pedido del usuario) | Hipótesis inicial (throttle de frame, luego I/O de archivos de blockstate) sin confirmar con profiling real | **Ambas hipótesis descartadas con datos reales.** Perfilado en 3 pasadas con instrumentación temporal (removida al cerrar) mostró que el 73% del tiempo de la etapa "blocks" (65,3s de 89s) estaba en `block_load_render_model()` — construcción de geometría, no I/O (que era solo 7,9%). La causa real: `ds_list_find_index()` (búsqueda lineal por string) contra la lista de texturas de bloque, hasta 6 veces por cara renderizada. Arreglado con mapas de índice O(1). Carga total: ~98s → ~39s en el dispositivo de referencia, verificado sin regresión visual. Lección метodológica: la intuición inicial (I/O de archivos chicos, un patrón de rendimiento móvil real y conocido) llevó a dos intentos de fix (`repeat(100)`, eliminar `file_exists_lib()`) que no ayudaron porque apuntaban a la parte equivocada del problema — el profiling real, no la intuición, encontró la causa | `KNOWN_ISSUES.md` B21 (detalle completo con las 3 pasadas de medición) |

| 2026-09-10 | §9.4, §16, CMakeLists.txt (comentario "no decidido"), B-catalog | `CMakeLists.txt` tenía un comentario propio sin resolver: empaquetado de `Data/` para Android "NOT done... has NOT been decided or investigated" (gap de Fase 1 nunca cerrado). Además, nadie había verificado nunca el contenido real de `Data/Minecraft/1.20.2.zip` que desktop empaqueta | **Decisión tomada, con evidencia real.** Un amigo del usuario probó una instalación limpia y la app crasheaba al arrancar (`legacy.midata` no encontrado) — el dispositivo de referencia de esta sesión tenía archivos acumulados de sesiones anteriores y nunca lo mostró. Investigado antes de elegir el fix (no asumido): grep confirmó que `Data/` NO es todo de solo lectura (`language_add.gml`/`app_event_http.gml` escriben ahí), así que se descartó redirigir todo a un recurso Qt inmutable. Se inspeccionó el contenido real de `1.20.2.zip`: 2.845 texturas PNG reales de Minecraft, no metadata — exactamente lo que §9.4 prohíbe, sin cobertura del permiso de David Andrei (su código, no las texturas de Mojang). Decisión final: `data_directory` sigue siendo un directorio real y escribible en Android, poblado al arrancar desde un recurso Qt embebido (mismo mecanismo ya probado para shaders) con verificación por tamaño de archivo, no solo existencia; `Data/Minecraft/` queda excluido del empaquetado. Consecuencia real: en Android, sin `Minecraft/` precargado y con B22 (HTTPS) abierto, el usuario depende 100% de traer su propio `.jar` para cumplir la definición de éxito de §16 ("importar assets de Minecraft") — el camino funciona, pero ya no hay atajo con una versión lista de fábrica como en escritorio | `KNOWN_ISSUES.md` B23 (decisión de `Minecraft/`) y B24 (el fix completo, con los números medidos y la trampa de CppGen encontrada en el camino) |

| 2026-09-10 | §9.4, §16, `UI_DEVIATIONS.md`, B23 | Verificando B24/B23 en dispositivo con una instalación realmente limpia (`adb uninstall` + reinstalar), no solo asumido resuelto | Salieron dos hallazgos nuevos. (1) Sin `legacy.midata` faltante (B24 ya resuelto), apareció un segundo crash: sin ninguna versión de Minecraft, `app_startup()` trataba eso como error fatal (`game_end()`, igual que un archivo core faltante) — no era "sin bloques", era que la app no abría nunca. Un primer intento de fix (saltar directo a la interfaz sin ningún dato cargado) reveló un problema más profundo: el banco de trabajo arma un modelo/bloque "por defecto" real en cada arranque (`app_startup_interface_bench.gml`/`_tabs.gml`, `mc_assets.model_name_map[?default_model].default_state]`), no bajo demanda — crasheaba de nuevo (`Invalid id 0 in Find:86`). Fix final, a pedido explícito del usuario: un paquete de assets "placeholder" real y mínimo (`Data/Minecraft/placeholder.midata`+`.zip`), 100% generado desde cero (JSON escrito a mano solo replicando el esquema del `1.20.2.midata` real, nunca sus valores; 10 PNGs generados por código, franjas grises, no el patrón magenta/negro de Minecraft) — así el pipeline de carga real (`minecraft_assets_load.gml`, sin tocar) corre completo sin necesitar ningún bypass. Reconocible como placeholder confirmado en el motor mismo: como `english.milanguage` no tiene traducciones para los nombres fijos que el motor busca (`default_model`/`default_block` = `"human"`/`"grass_block"`), `text_get()` devuelve literalmente `<No text found for "modelhuman">` en la UI. Verificado en dispositivo real: log completo sin errores, llega a la pantalla de bienvenida y al editor. (2) Al investigar el "camino principal" de §9.4 para escribir el fix, se encontró que **no existe ningún flujo de "importar tu `.jar`" en el código** (grep completo de GML y C++ sin resultados de manejo de `.jar`) — el `.zip`/`.midata` de `Data/Minecraft/` es un paquete pre-generado que trae el programa, no algo que el usuario arma desde una pantalla; para usar una versión real hay que copiarla a mano a esa carpeta y elegirla en el selector de versión existente. §9.4 describe correctamente el origen legal de esos assets (se extraen de un `.jar`, en algún punto anterior al programa), pero B23/`UI_DEVIATIONS.md` lo habían reformulado, sin verificar, como si existiera un botón de importación dentro de la app. Corregido en ambos documentos | `KNOWN_ISSUES.md` B25 (el fix completo, con el camino descartado documentado aparte) · `UI_DEVIATIONS.md` (entrada actualizada) |

| 2026-09-10 | §9.4, §16 | §9.4 decía "Mine-imator no los redistribuye: los extrae de los `.jar` del usuario" (texto además corrupto en una edición anterior — llegó a leerse literalmente "Mine-imator los redistribuye", el negativo invertido, sin que nadie lo notara). §16 listaba "Importar assets de Minecraft desde un `.jar` que él provee" como parte de la definición de éxito de v1.0 | A pedido explícito del usuario, se verificaron dos cosas antes de tocar nada, en vez de asumirlas: (1) ¿existe un conversor de `.jar` en el proyecto? Rastreado el único punto de UI relacionado (selector de "versión de Minecraft" en Configuración) hasta su implementación real: `list_init.gml` hace `file_find(minecraft_directory, ".midata")` — un simple listado de archivos ya presentes, sin manejo de `.jar` en ningún lado (grep exhaustivo de GML y C++, incluyendo `World/`/`Library/`, con `blockstate`/`atlas`/`install_version`/`convert`, sin resultados). (2) ¿`mineimator.com/assets.php` no tiene versiones o no se puede consultar? Verificado con el build de escritorio real (HTTPS funcional): el log dice `"Using the latest assets"` — la rama que solo se alcanza si el pedido HTTP tuvo éxito — confirmando que el servidor responde bien pero no tiene ninguna versión publicada (`{"versions":[]}`, confirmado también por separado con `curl`). Con ambas cosas confirmadas con evidencia real: no hay, hoy, ningún camino automático para conseguir assets de Minecraft en ninguna plataforma. Corregido el texto corrupto de §9.4, separado el principio legal (sigue en pie, sin cambios) de la afirmación técnica (que era falsa), y reescrita la fila de §16 con lo que sí es posible: colocar a mano un paquete ya convertido y elegirlo en el selector existente | `KNOWN_ISSUES.md` B26 (verificación completa, con los dos hallazgos y sus tres opciones reales de solución, ninguna decidida todavía) |

| 2026-09-11 | §16, `KNOWN_ISSUES.md` B25, `UI_DEVIATIONS.md`, `CppProject/CMakeLists.txt` | El paquete de fallback de B25 se llamaba "placeholder" en todos lados: `Data/Minecraft/placeholder.midata`/`.zip`, el macro `minecraft_placeholder_version`, la excepción de `CMakeLists.txt`, y la documentación | A pedido explícito del usuario, renombrado a **"Game Base"** — mismos archivos, mismo contenido (JSON escrito a mano, PNGs generados, cero assets de Mojang), solo el nombre cambia. Motivo: `setting_minecraft_assets_version` (el nombre de archivo sin extensión) es literalmente lo que aparece en el selector de versión de Minecraft de Configuración (`list_init.gml` lista archivos `.midata` por nombre) — "placeholder" ahí se leía como algo roto o sin terminar, "Game Base" se lee como lo que es: una base vacía puesta a propósito para que la app arranque. Actualizado: `macros.gml` (`minecraft_placeholder_version = "Game Base"`), `data_directory_seed_android.gml` (lista + `DATA_BUNDLE_VERSION` subido a 7 para forzar la resincronización en dispositivos que ya tenían el nombre viejo), `CMakeLists.txt` (regex de excepción y comentarios), el campo `"version"` dentro del propio `.midata`, y los 2 archivos de datos renombrados en disco. Los documentos históricos (`KNOWN_ISSUES.md` B25, `UI_DEVIATIONS.md`) no se reescribieron oración por oración — llevan una nota de renombre al principio en vez de alterar el registro de lo que pasó en su momento | `KNOWN_ISSUES.md` B25 (nota de renombre agregada) |

| 2026-09-11 | §6.1, §6.2, Fase 3 (inventario de literales de dimensión) | §6.1 ya tenía dos correcciones previas (2026-09-06, 2026-09-09) que sacaban a las 13 `tab_control_*` como punto de apalancamiento para input y para geometría de fila (`ui_large_height`/`ui_small_height`), reemplazándolas por el par `tab_control_X`+`draw_X`. Pero seguía sin decir nada sobre la geometría INTERNA de cada control (el alto real del hitbox de un botón, un campo de texto, el thumb de un slider) - se asumía implícitamente que las dos constantes de fila alcanzaban | **Tercera corrección al mismo supuesto, no eran las 13 primitivas: tampoco alcanza con `ui_large_height`/`ui_small_height`.** Al ir a agrandar `draw_switch` (paso 1 de la lista priorizada por el usuario) se encontró que ya estaba arreglado de una sesión anterior - pero revisando el resto, se encontró que la geometría interna de la mayoría de los controles (`draw_meter` thumb, `sortlist_draw` franja de resize, `draw_textfield` alto) vive en números fijos propios, **algunos ya conectados a variables `ui_touch_*` sin usar** (declaradas en el sizing pass del paso 1 pero nunca conectadas a su sitio real), otros como literales sueltos en los call sites. Inventario completo pedido antes de tocar código: 99 literales de dimensión en 36 archivos (57 en `draw_button_menu`, 19 en `draw_textfield`, resto repartido), más los ya conocidos de la definición de cada primitiva. Contrato decidido: los literales de call site se corrigen apuntando a la variable compartida correcta (sin cambiar ninguna firma); la geometría interna de cada primitiva se deriva de nuevas/existentes `ui_touch_*` condicionadas a `platform_get()==ANDROID`, nunca agregando parámetros nuevos. Verificado con el build de escritorio real (no solo lógica): mismo `window_height` de siempre sigue dando los mismos `ui_large_height`/`ui_small_height`/`window_compact` de antes, en modo normal y en modo compacto | `research/2026-09-06-ui-inventory.md` (inventario original de geometría interna, ya desactualizado en los casos ya arreglados - no reescrito, ver nota de vigencia si se vuelve a leer) |

| 2026-09-11 | §6.1, §6.2, Fase 3 (implementación del contrato aprobado en la fila anterior) | Contrato aprobado por el usuario con 3 condiciones: empezar por `draw_switch`, verificar que desktop no cambie, registrar la corrección de modelo — más la instrucción explícita de avanzar un lote completo antes del próximo build | **Lote implementado, sin build todavío en el momento de escribir esta fila.** `draw_switch` ya estaba arreglado (sesión anterior) - prioridad redirigida por el usuario a `sortlist`. Aplicado: `ui_touch_sortlist_resize_width` (10→30 Android), `ui_touch_meter_thumb_height` (20→32 Android), `ui_touch_textfield_height` nueva (24 desktop sin cambio / 40 Android, conectada a los 13 call sites de `draw_textfield` + default de `tab_control_textfield` + el `draw_inputbox` del hex del colorpicker, que el inventario original había contado dentro de "draw_inputbox 3" sin separar que uno de esos tres literales era exactamente el mismo problema de alto que los 13 de `draw_textfield`), 56 de 57 `draw_button_menu` corregidos a `ui_large_height` (el restante, `view_draw.gml:358`, es un control dentro de una barra de overlay del viewport con 7 hermanos que comparten un `24` fijo propio - arreglar solo uno rompería la alineación con esa fila; queda como tarea aparte, no arreglo parcial), y `ui_touch_wheel_radius` nueva para `draw_wheel` (24 desktop sin cambio / 32 Android) - este último ya no era un literal suelto (una corrección previa lo había atado a `ui_large_height`) pero como Android usa el mismo `ui_large_height` "normal" que desktop, nunca terminó siendo más grande para el dedo como pedía el inventario original. Evaluados y dejados sin cambio, con motivo: los 7 anchos de `draw_dragger` (`wid=64`, panel fijo del editor de partículas - el ancho no es la dimensión que limita el toque, el arrastre usa delta no posición), los 3 anchos de `draw_textfield_group` y el ancho de `draw_button_color` (mismo motivo, paneles compactos de tamaño fijo), el `h=48` de `draw_inputbox` en `popup_upgrade` (ya generoso, 2x `ui_small_height`), y el botón de filtro `24×24` de `sortlist_draw.gml` (no estaba en el inventario original de 99 literales - ampliar el alcance ahora, sin el mismo proceso de inventario+aprobación que se siguió para el resto, se dejó pendiente como tarea futura en vez de decidido de paso) | `research/2026-09-06-ui-inventory.md` |

| 2026-09-11 | B27 (nuevo), `settings_startup.gml` | Reporte de beta testers, ajeno al trabajo de Android de esta sesión: la primera vez que se instala Mine-imator la interfaz se ve chica, y recién al volver a abrirlo se ve del tamaño correcto | Investigado antes de asumir relación con los cambios de esta sesión - no la tiene, es un bug preexistente del motor, y no es específico de Android. Causa raíz: `interface_scale_set()` (la función que empuja el factor de escala calculado al motor C++, `App->scale`, default `1.0`) solo se llamaba desde dentro de `settings_load()`, que corta en `return 0` si `settings.midata` todavía no existe - en una instalación limpia nunca se llega a esa línea, así que el valor correcto que `settings_startup()` sí calculaba (`interface_scale_default_get()`, DPI real del monitor) nunca se aplicaba la primera vez. Al reabrir ya existe el archivo de settings y esa llamada sí se alcanza. Fix de una línea: llamar `interface_scale_set()` también en `settings_startup()`, inmediatamente después de calcular el valor - `settings_load()` sigue reaplicándolo después sin cambios, llamada duplicada e inofensiva. Confirmado por grep que `interface_scale_default_get()`/`interface_scale_set()` no tienen ninguna rama por plataforma, así que el fix vale igual para Android | `KNOWN_ISSUES.md` B27 |

| 2026-09-11 | B27, KNOWN_ISSUES.md B28/B29, `bench_draw.gml`, `window_draw_startup.gml`, `MineImatorActivity.java` | Verificación en dispositivo real del lote de la fila anterior (799 literales) reveló 3 problemas nuevos, ninguno cubierto por el inventario original: (1) `interface_scale_default_get()` seguía dando 1.0 en Android incluso con B27 ya arreglado — el bug real era el truncado a entero de la fórmula de escritorio (`(IntType)(ratio+0.01)`), que en Android da `160/96=1.67 → 1`; (2) al subir la escala global, `bench_draw.gml`'s `content_width=534` (fijo desde siempre) pasó de ~27% a ~40% del lienzo lógico, y el popup completo perdió el tope de altura que nunca tuvo — el botón "Agregar" quedó fuera de pantalla; (3) franja negra persistente en un borde, reportada como separada por el usuario | **Los 3 resueltos con evidencia real, no ajustes a ciegas.** (1) `interface_scale_default_get()` gana una rama `#if defined(Q_OS_ANDROID)` con valor fijo (1.5→1.65 tras una segunda ronda de feedback), en vez de arreglar el truncado para toda plataforma — cero riesgo para el auto-scale de escritorio, que se queda con su comportamiento entero de siempre. (2) `bench_draw.gml`: `content_width` se autocorrige dividiendo por `setting_interface_scale` en Android (mismo footprint físico que antes del bump, sea cual sea el scale futuro); fila de categorías usa modo compacto en Android igual que ya hace `window_compact` en escritorio (13 filas no entran completas en ningún teléfono); `bench_settings.height_goal` gana tope contra `window_height` (mitigación, no solución — el fix real es scroll interno, KNOWN_ISSUES.md B28, fuera de esta pasada). `window_draw_startup.gml` recibe el mismo tratamiento de autocorrección para su encabezado fijo (144px + logo + offsets, todos por el mismo factor para no desalinearlos entre sí) porque quedó demasiado grande al mismo scale que ya está bien para el editor — **primera confirmación real de que editor y pantalla de proyectos necesitan valores efectivos distintos**, resuelto sin tocar el único `App->scale` global (que se comparte con el editor) sino corrigiendo localmente los elementos fijos de esta pantalla. (3) Franja negra: diagnosticada con evidencia real (`adb shell dumpsys window displays`, no asumida) como el cutout de cámara del dispositivo (49px, borde superior en portrait) reservado por Android, que rota a un borde lateral en la `sensorLandscape` fijada de la app — arreglado con `layoutInDisplayCutoutMode=ALWAYS` en `MineImatorActivity.java` (mecanismo estándar de Android, generaliza solo a cualquier dispositivo, no un número específico de este teléfono) — no relacionado con el intento de `setGeometry()` revertido en 2026-09-09 | `KNOWN_ISSUES.md` B27, B28, B29 |

| 2026-09-11 | §6.1 (paso 6, ahora cerrado), `scrollbar_draw.gml` | El usuario pidió scroll táctil "en toda la app, por si acaso" — pedido preventivo, no un bug puntual reportado | Fase 3 paso 6 (§6.1: "`scrollbar_draw.gml` — único punto que lee la rueda del mouse... usado por `sortlist` y `menu`") ya tenía identificado que este archivo es el punto de apalancamiento único. Grep confirmó que en realidad lo usan bastante más de 2 llamadores: `sortlist_draw`, `menu_draw` (vertical y horizontal), `panel_draw_content` (los paneles acoplados de todo el editor), `tab_timeline` (vertical y horizontal), `draw_recent`, `draw_texture_picker`, `menu_settings_draw`, `popup_pattern_editor_draw`, `window_draw_new_assets` — arreglar este único archivo cubre a todos a la vez, tal como preveía §6.1. Agregado swipe-to-scroll gestual (Android, cero cambio en desktop que sigue usando la rueda del mouse): detectado dentro del área de contenido de cada scrollbar (`content_x/y/width/height`, que cada llamador ya define para su propio panel) excluyendo a propósito el área precisa de la propia barra/thumb (`!mouseinarea`, que sigue funcionando exactamente igual que antes) para no pisarle el gesto a quien agarra el thumb con precisión. Mismo umbral de 5px para distinguir tap de arrastre que ya usa `draw_dragger.gml` para el mismo problema, y misma técnica de `app_mouse_clear()` al cruzar el umbral para no disparar un click falso en lo que quede debajo del dedo al soltar | — |

| 2026-09-11 | Idioma nuevo, `languages.midata`, `data_directory_seed_android.gml` (`DATA_BUNDLE_VERSION` 7→8) | Pedido explícito del usuario: agregar español latinoamericano a Mine-imator. No existía ningún idioma más que inglés en todo el proyecto (grep de `.milanguage` en el repo completo, un solo archivo) | Creado `Data/Languages/spanish_latam.milanguage` (`"language": "Español (Latinoamérica)"`, `"locale": "es-419"`) traduciendo las 3295 claves de `english.milanguage` — verificado con un script real (no a ojo) que las claves coinciden 1 a 1 con el inglés (0 faltantes, 0 sobrantes) y que la cantidad y numeración de placeholders (`%1`/`%2`/`%3`) coincide en cada cadena, para no romper ningún `text_get(clave, args...)`. Terminología de Minecraft (mobs, bloques, biomas, pociones, patrones de estandarte) alineada a la localización oficial en español latinoamericano según mi conocimiento del juego — no verificada string por string contra el archivo de idioma real de Minecraft (no está en este repo); recomendado que un hablante nativo la revise antes de darla por definitiva, especialmente en términos menos comunes (estados de bloque, nombres de cuadros decorativos). Registrado en `languages.midata` (el manifiesto que `languages_load()` lee al arrancar - selección por directorio no existe, hay que registrar cada idioma ahí) y en `DATA_BUNDLE_FILES` de Android (versión de bundle subida a 8 para que los dispositivos que ya tenían la app instalada reciban el archivo nuevo) | — |

| 2026-09-11 | B20 (cerrado), B28 (cerrado), `AppWindow.hpp/cpp`, `UtilFunc.cpp`, `bench_draw_settings.gml` | Continuación de Fase 3 a pedido explícito del usuario ("sigue fase 3... pero completa"). Quedaban dos ítems reales: el teclado virtual (investigado 2026-09-09, nunca implementado) y el scroll real del panel de configuración del workbench (B28 solo tenía la mitigación de tope de altura) | **Teclado virtual (B20):** implementadas las 3 piezas que ya proponía la investigación — edge-detector sobre `textbox_isediting` (ya existente) llama `keyboard_virtual_show()`/`_hide()` una vez por transición; `AppWindow::Maximize()` reafirma el foco de `KeyChecker` después de `showFullScreen()` (no en el constructor, por el bug de timing de Qt ya documentado); `KeyChecker::inputMethodQuery()` sobreescrita para reportar el rect real del campo. **Error real encontrado en el camino, no cosmético:** el primer intento pasaba el rect vía variables globales de GML leídas como `gmlGlobal::keyboard_field_x` desde C++ — falló al compilar, porque `gmlGlobal` resultó ser (confirmado leyendo `GmlFunc.hpp` generado) un struct fijo con ~16 variables integradas del propio GameMaker (`mouse_x`, `keyboard_string`, etc.), no un mecanismo genérico para exponer cualquier global personalizada a C++. Corregido pasando el rect como parámetros de una función `CppSeparate` (`keyboard_field_set`, mismo patrón que `interface_scale_set`), guardados en miembros propios de `KeyChecker`. **Scroll del workbench (B28):** agregado `bench_settings.settings_scroll`; el contenido del panel de configuración ahora se desplaza y usa el mismo truco que ya usa `panel_draw_content.gml` en todo el resto del editor (achicar `content_height` para que el culling propio de cada `draw_*` haga de clip, en vez de un clip real anidado — este motor no tiene pila de clips, confirmado leyendo `clip_begin.gml`/`clip_end.gml`, un `clip_end()` interno mataría el clip externo del popup entero). El tope de altura de la fila anterior se mantiene sin cambios — ahora el contenido que no entra se puede alcanzar con scroll en vez de quedar invisible. Ambos compilan limpio (Android arm64-v8a); pendiente de verificación en dispositivo real | `KNOWN_ISSUES.md` B20, B28 |

| 2026-09-11 | B20, `AppWindow.cpp` (`KeyChecker`) | Primera prueba real en dispositivo del teclado virtual: aparecía (B20 sí lograba mostrarlo), pero no editaba ningún texto, y la posición se veía mal | Investigado leyendo el código fuente real de Qt 5.15.19 instalado en esta máquina (`qlineedit.cpp:576-579`, no asumido): `QLineEdit::setEchoMode(NoEcho)` — usado en `KeyChecker` únicamente para que este widget invisible nunca dibuje nada (GML dibuja su propio texto) — activa automáticamente 4 hints de campo de contraseña (`ImhHiddenText`, `ImhSensitiveData`, `ImhNoPredictiveText`, `ImhNoAutoUppercase`). Android trataba entonces CUALQUIER campo de texto de la app como una contraseña. Arreglado con una línea (`setInputMethodHints(Qt::ImhNone)` inmediatamente después de `setEchoMode`), sin tocar `NoEcho` en sí (sigue siendo necesario para que no pinte nada). El bug de posición no se tocó todavía — sin confirmar si era un síntoma del mismo problema o algo aparte, pendiente de la próxima prueba en dispositivo (la instalación se cortó por desconexión de ADB antes de poder reintentar) | `KNOWN_ISSUES.md` B20 |

| 2026-09-11 | Fase 4 (arranque), Trampa 1 (§6.3, primera implementación), B10 (mitad cerrada) | Usuario dio luz verde explícita para arrancar Fase 4 ("arranca fase 4 nomás") tras cerrar Fase 3 en lo funcional. §6.4 tenía 2 gestos sin equivalente táctil identificados desde el inventario original: rueda del mouse (zoom) y pan con Shift+arrastre (sin tecla confiable en Android) | **Trampa 1 implementada por primera vez en el proyecto, de forma mínima y aditiva.** `AppWindow::event()` ahora intercepta `QTouchEvent`, pero SOLO actúa con 2 o más dedos — con 0 o 1, no acepta el evento y todo sigue cayendo en la síntesis de mouse de Qt de siempre, la misma que ya usa el arrastre de un dedo (verificado funcionando, B10) — cero riesgo de tocar ese camino. Con 2 dedos: distancia entre los primeros dos puntos (pellizco) y su punto medio (pan), acumulados por cuadro y expuestos a GML con 4 funciones nuevas (`touch_count`/`touch_pinch_delta`/`touch_pan_dx`/`touch_pan_dy`, mismo patrón `CppSeparate` ya usado para el teclado virtual). En `view_update.gml`: el segundo dedo dispara pan directamente (reemplaza el Shift+arrastre), y el pellizco se suma a `mouse_wheel` antes de la misma fórmula de zoom que ya existía — ninguna de las dos toca el arrastre de un dedo. Compila y linkea limpio a la primera, pero **nunca se probó en dispositivo real** — primera vez que este proyecto intercepta touch events en absoluto, y la sensibilidad del pellizco es un punto de partida razonado, no afinado. Limitación documentada a propósito: solo detecta el caso de que los dos dedos lleguen juntos (agregar el segundo dedo después de que la rotación de uno ya arrancó no se intercepta todavía). El contrato general de `mouse_x`/`mouse_y` indefinido entre toques (la otra mitad de Trampa 2) sigue sin resolverse — no hizo falta para este gesto específico, que mide con sus propias coordenadas de `QTouchEvent` | `KNOWN_ISSUES.md` B10 |

| 2026-09-15 | Fase 4 (continuación), §6.3 Trampa 2 (gizmos) | Usuario pidió explícitamente "haz fase cuatro completa", sin acceso al teléfono durante la sesión. Quedaban las dos piezas grandes identificadas por el inventario del mismo día (`research/2026-09-15-fase4-timeline-gizmos-inventory.md`): picking de gizmos 3D y gestos de timeline | **Gizmos (7 archivos: move_axis/move_plane/move_pan/scale_axis/scale_plane/scale_all/rotate_axis):** el picking de los 5 tipos de gizmo depende de `view.control_mouseon_last`, escrito un frame antes del click que lo consume (seguro para mouse por el cursor continuo, riesgoso para un tap que entrega posición+press casi junto). Arreglado de forma aditiva: en cada archivo, un chequeo `||` extra gateado a Android reutiliza las coordenadas 2D que la función YA calculaba para dibujarse ese mismo frame, evaluando el pick en el momento del press en vez de depender del frame anterior — cero cambio al camino de escritorio. `view_control_rotate_axis.gml` es un caso aparte (el anillo se dibuja como 64 segmentos calculados en un loop posterior al click-check, sin una forma barata de reusar coordenadas exactas) — resuelto con una aproximación de distancia-al-anillo, documentada como tal, no pixel-exacta. **Corrección al inventario del mismo día:** `view_shape_path.gml` (arrastre de nodos de path) NO comparte este patrón — usa `app_mouse_box` en vivo, ya es seguro, no se tocó (el inventario lo había agrupado mal, corregido tras leer el archivo completo en vez de solo el grep dirigido). **Timeline:** agregados pellizco-zoom (reutiliza `touch_pinch_delta()`, ya usado por la cámara, alimentando la misma fórmula de `timeline_zoom_goal` que el `Ctrl+rueda`) y pan de 2 dedos (primer uso real de `touch_pan_dx()`/`touch_pan_dy()` en todo el proyecto — existían implementadas en C++ desde el arranque de Fase 4 pero sin ningún call site en GML hasta ahora). El arrastre de keyframes se investigó y confirmó YA seguro para touch (mismo patrón sin riesgo que `view_shape_path.gml` — se calcula y consume en el mismo frame), no necesitó cambios. **Verificado solo por compilación** (CppGen limpio + confirmado con grep que el código Android nuevo aparece en `CppProject/Generated/`, build nativo exit 0, APK build exit 0, sin Trampa T4) — sin dispositivo disponible esta sesión, **cero verificación en pantalla real**, primera prioridad la próxima vez que haya teléfono | `research/2026-09-15-fase4-timeline-gizmos-inventory.md`, `research/2026-09-15-fase4-gizmos-timeline-implementation.md` |

| 2026-09-15 | Fase 4 (segunda pasada, mismo día), §6.3 Trampa 2, `KNOWN_ISSUES.md` KI-4 | Tras la fila anterior del mismo día, el usuario preguntó explícitamente "fase 4 completa? solo faltaría probar?" — la respuesta honesta identificó 3 deudas menores conocidas (aproximación del anillo de rotación, límite de "los 2 dedos deben llegar juntos" en la cámara, Trampa 2 sin caracterizar) y una explícitamente fuera de alcance (atajos de teclado, un audit aparte, no gestos). El usuario pidió resolver lo resoluble ("puedes resolver eso de momento?") | **Los 3 cerrados en esta misma sesión, sin dispositivo disponible (igual que la fila anterior — solo verificado por compilación):** (1) `view_control_rotate_axis.gml` — la aproximación de distancia-al-anillo se reemplazó por un pick EXACTO: duplica el mismo loop de 64 segmentos (con la misma oclusión `control_test_point`) que usa el dibujo real, corrido temprano y solo para picking. (2) `view_update.gml`, bloque `viewrotatecamera` — ahora detecta un segundo dedo llegando DESPUÉS de que la rotación ya arrancó (no solo "ambos juntos" como en la primera pasada del 2026-09-11) y pasa a `viewpancamera` en el mismo frame. (3) Trampa 2 caracterizada con evidencia real de código (`AppWindow.cpp:529-533` → `AppHandler.cpp:356-357` → GML): `mouse_x`/`mouse_y` no quedan indefinidos entre toques, quedan CONGELADOS en la última posición tocada — un default benigno, no un bug; el gate genérico se cierra por caracterización (no hacía falta una política nueva), el riesgo real sigue siendo auditar caso por caso el código que trata ese hover como fresco entre frames (ya hecho para gizmos/timeline/path-nodes). Lo que queda genuinamente pendiente de Fase 4, explícitamente fuera de este cierre: verificación en dispositivo real (nada de esto se tocó con un dedo todavía) y el audit de atajos de teclado (61 call sites, tarea aparte, no gestual) | `KNOWN_ISSUES.md` KI-4 (actualizada), §6.3 (esta misma sección) |

> Cada vez que la realidad contradiga este documento, actualizalo y registralo acá. Un CLAUDE.md desactualizado es peor que no tener ninguno.
