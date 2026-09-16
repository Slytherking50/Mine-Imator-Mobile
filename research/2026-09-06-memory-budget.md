# Investigación: presupuesto de memoria con un mundo real importado (tarea 0.7)

## Pregunta

¿Cuánta memoria pico consume importar un mundo de Minecraft real, y cómo se compara contra dispositivos de 4/8/12 GB? ¿Qué tamaño de vertex buffers genera, y qué límite de importación (si alguno) hace falta imponer en Android?

**Actualización (2026-09-06, misma sesión):** la primera versión de este informe dejó dos números como estimaciones sin medir (`sizeof(obj_timeline)` por composición de campos, y la fracción de bloques `timeline=true` como rango razonado 1-10%), con un rango final de 14× demasiado ancho para decidir nada. Las dos se corrieron de verdad — la primera compilando contra el código real, la segunda parseando datos reales que ya vienen empaquetados con el producto (no hacía falta un mundo de Minecraft real ni Android). El resultado cambia el diagnóstico: el caso típico (importar terreno/paisaje) es trivial en cualquier dispositivo; el riesgo real quedó acotado a un escenario específico (importar una estructura muy decorada), y ese escenario también se acotó mejor, aunque no del todo.

## Método

1. Se rastreó el pipeline completo de import: `Preview`/`Region`/`Chunk`/`Section` y `Builder`/`obj_builder`, en `CppProject/World/` (sin cambios respecto a la versión anterior de este informe).
2. **`sizeof(obj_timeline)` real, compilado:** se armó un `.cpp` de una función (`sizeof_test.cpp`) que incluye `Generated/Scripts.hpp` y llama `sizeof()` sobre `obj_timeline`, `obj_block`, `VarType`, `ArrType`, `VecType`, `MatrixType` y `StringType`. Se compiló con `cl.exe` real (extraídos los `/I` y `/D` del `.vcxproj` que generó CMake para la build de escritorio de 0.1, `build-release/Mine-imator.vcxproj`) — sin tocar el build real del proyecto, sin necesitar linkear Qt (nada en el test llama código de Qt, solo declara tipos). Compiló y linkeó limpio, se ejecutó, e imprimió los tamaños reales.
3. **Fracción de bloques `timeline=true`, real, en dos partes:**
   - **A nivel de tipo de bloque:** se encontró que el archivo `.midata` que describe qué bloques necesitan timeline **no es externo como se pensó** — Mine-imator lo trae empaquetado (`install/Mine-imator/Data/Minecraft/1.20.2.midata`, 333 KB, JSON plano). Se parseó completo y se contó cuántas de las entradas de `"blocks"` tienen la clave `"timeline"`.
   - **A nivel de bloques colocados de verdad, no solo tipos:** Mine-imator también trae empaquetada su propia librería de escenografía (`install/Mine-imator/Schematics/`, 39 archivos `.schematic` reales — playas, bosques, montañas, ríos, cuevas, campos, árboles — pensados para uso real dentro del producto, no arbitrarios). Se escribió un lector NBT mínimo (gzip + parser de tags binario, ~90 líneas) para leer los 39 archivos reales, resolver cada bloque legado (`Blocks`/`Data`, formato numérico clásico) a su nombre moderno vía la tabla `legacy_block_id` de `install/Mine-imator/Data/legacy.midata` (también empaquetada, no externa), y cruzar contra la lista de `timeline=true` del punto anterior.
   - De paso, con la misma infraestructura, se midió también la **fracción de volumen sólido** y las **caras expuestas por bloque sólido** (los dos números que la versión anterior de este informe había razonado como rango sin medir, 30-60% y 0,5-1,5) — mismo método de vecino-a-vecino que usa `GenerateFaceTriangles` en el código real, aplicado a los 19 schematics de forma "de caja" (se excluyeron 20 árboles sueltos, menores a 5.000 posiciones, por no ser representativos de una importación en caja).
4. No se encontró ni se generó ninguna estructura/base construida por jugador (casa, aldea) — la librería empaquetada de Mine-imator es exclusivamente de naturaleza/terreno. Ese escenario sigue sin medición directa, ver Incógnitas.

## Evidencia

**`sizeof()` real, compilado y ejecutado contra el código actual:**

| Tipo | `sizeof()` real | Estimación anterior (por composición) |
|---|---|---|
| `obj_timeline` | **8.560 bytes** | ~4.377 (subestimaba ~2×) |
| `obj_block` | 1.512 bytes | — (no estimado antes) |
| `VarType` | 40 bytes | ~16 (subestimaba) |
| `ArrType` | 24 bytes | ~24 (acertada) |
| `VecType` | 56 bytes | ~40 |
| `MatrixType` | 136 bytes | ~136 (acertada, `Matrix` ya estaba confirmado) |
| `StringType` | 32 bytes | ~8 (asumía un wrapper fino tipo puntero; tiene SSO inline, no es tan fino) |

La estimación por composición de campos era la fuente correcta de magnitud (mismo orden), pero se quedaba corta por subestimar `VarType`/`StringType` — el número real es el que hay que usar de acá en adelante.

**Fracción de tipos de bloque con `timeline=true` (real, medido desde el `.midata` empaquetado, 1.20.2):** **27 de 285 tipos de bloque = 9,47%.** Lista completa: `bed, sticky_piston, piston, chest, sign, door, wall_sign, hanging_sign, wall_hanging_sign, lever, pressure_plate, button, trapdoor, fence_gate, enchanting_table, ender_chest, tripwire_hook, mob_head, mob_wall_head, trapped_chest, weighted_pressure_plate, standing_banner, wall_banner, shulker_box, conduit, bell, decorated_pot`. Es un techo teórico (asume ponderación uniforme entre tipos, que ningún mundo real tiene), no una fracción de bloques colocados.

**Fracción de bloques colocados con `timeline=true` (real, medido sobre 3.284.555 bloques sólidos de los 39 schematics empaquetados de Mine-imator):** **1 bloque (`chest`) — 0,00003%.** Prácticamente cero para contenido de tipo terreno/paisaje, que es exactamente lo que esta librería representa (y lo que la mayoría de una importación de mundo real también es — piedra, tierra, agua, troncos, hojas: ninguno de esos 27 tipos).

**Fracción de volumen sólido (real, medido sobre 19 schematics "de caja", 7.173.148 posiciones):** **45,8%** agregado (rango por archivo: 12,8%-97,8%, dependiendo de si es terreno submarino denso o un campo con árboles sueltos). Confirma casi exacto el punto medio del rango razonado anterior (30-60%).

**Caras expuestas por bloque sólido (real, medido con el mismo chequeo de 6 vecinos que usa `GenerateFaceTriangles`, sobre los mismos 19 schematics):** **0,294 agregado** (rango por archivo: 0,10-1,97). Más bajo que el rango razonado anterior (0,5-1,5) — el razonamiento previo sobreestimaba este número.

**Sin cambios respecto a la versión anterior, siguen confirmados por código:** presets de importación (`Import.cpp:82-90`), `WorldVertex` = 8 bytes/vértice, índices = 4 bytes, `obj_block` es plantilla por tipo no por instancia (`Builder.cpp:16-20`).

## Hallazgos

### 1. El caso típico (terreno/paisaje) es trivial en cualquier dispositivo — ya no es una estimación, está medido

Con los 3 números reales (45,8% sólido, 0,294 caras/bloque sólido, ~0% de bloques con timeline) aplicados a los 3 presets:

| Preset | Volumen | Sólidos (45,8%) | Caras (×0,294) | Memoria malla (×56B) | Objetos timeline (~0%) | **Total, escenario terreno** |
|---|---|---|---|---|---|---|
| Pequeño | 50.000 | 22.900 | 6.733 | 0,38 MB | ~0 | **~0,4 MB** |
| Mediano | 1.200.000 | 549.600 | 161.582 | 9,05 MB | ~0 | **~9 MB** |
| Grande | 8.000.000 | 3.664.000 | 1.077.216 | 60,3 MB | ~0 | **~60 MB** |

El preset "Grande" completo, importando algo del tipo de lo que Mine-imator ya empaqueta como escenografía de ejemplo, usa **~60 MB** — trivial contra cualquiera de los tres tiers (4/8/12 GB). Esto cierra la preocupación original de B11 para el caso de uso más común.

### 2. El riesgo real (y sigue siendo real) es una importación densa en bloques especiales — más acotado que antes, no medido del todo

No hay ninguna estructura construida por jugador en la librería empaquetada de Mine-imator para medir este caso directamente. Usando el techo real de tipo de bloque (9,47%) como referencia — sabiendo que ningún mundo real llega a esa cifra en bloques *colocados*, porque paredes/piso/techo de cualquier estructura siguen siendo bloques normales — se razona un rango de 1-5% de bloques especiales para una importación "densa en decoración" (aldea, base con muchos cofres/puertas), ahora con el tamaño de objeto real:

| Preset | Sólidos (45,8%) | Objetos timeline (1-5%) | Memoria objetos (×8.560B real) | + malla (~terreno) | **Total, escenario decorado** |
|---|---|---|---|---|---|
| Pequeño | 22.900 | 229-1.145 | 2-9,8 MB | 0,4 MB | **~2,4-10,2 MB** |
| Mediano | 549.600 | 5.496-27.480 | 47-235,2 MB | 9 MB | **~56-244 MB** |
| Grande | 3.664.000 | 36.640-183.200 | 313,6-1.568 MB | 60 MB | **~374 MB - 1,63 GB** |

El rango de "Grande" bajó de 170 MB-2,47 GB (informe anterior) a ~374 MB-1,63 GB — más angosto, y con el extremo superior más difícil de alcanzar en la práctica de lo que sugería el 10% original (el 9,47% es un techo teórico de *tipos*, no algo que un mundo real se acerque a igualar en *bloques colocados*). Sigue siendo el único escenario con riesgo real en un dispositivo de 4 GB, y sigue sin poder cerrarse del todo sin una estructura real para medir.

### 3. Lo que faltaba medir sin Android, ya se midió sin Android

Confirma el Hallazgo 3 de la versión anterior de este informe: todo lo de arriba se cerró con el build de escritorio existente (para el `sizeof`) y con datos que Mine-imator ya trae empaquetados (para las fracciones) — cero dependencia de Android, cero necesidad de un dispositivo físico.

## Contradicciones con CLAUDE.md

- B11 (§8) decía "Vertex buffers grandes" sin cuantificar — confirmado que no es el riesgo (§14.4 ya lo tenía mal enfocado). El riesgo real, medido, es específico a importaciones densas en decoración, no al tamaño de importación en sí.
- Versión anterior de este mismo informe (dentro de esta sesión) presentaba un rango de 170 MB-2,47 GB para "Grande" sin distinguir terreno de estructura decorada — con datos reales, el caso terreno es trivial (~60 MB) y solo el caso decorado conserva incertidumbre real, y esa incertidumbre es más angosta de lo que parecía.
- §14.3 ("Memoria pico, escena típica < 1,5 GB"): con datos reales, una importación "Grande" de terreno (~60 MB) no la amenaza en absoluto; una importación "Grande" densa en decoración, en el extremo alto del rango (~1,63 GB), sí la superaría por sí sola.

## Incógnitas

- **La única que queda abierta de fondo:** no hay una estructura real construida por un jugador para medir la fracción de bloques especiales en ese escenario específico — se sigue razonando (1-5%), aunque ahora anclado a un techo de tipo real (9,47%) en vez de a una suposición sin referencia. Cerrarla del todo requiere un mundo/schematic real de una base o aldea — no viene con Mine-imator, habría que conseguirlo o generarlo aparte.
- No se contempló la memoria de biomas/paletas/estados de bloque ni de texturas del atlas (eje 3 de §14.4) — adicional a lo modelado acá.
- No se verificó si existe un límite manual de selección por encima del preset "Grande" en la UI.
- El orden de bytes exacto (`(y*Length+z)*Width+x`) usado para leer los `.schematic` en el script de medición se infirió del formato clásico Schematica/MCEdit, no se verificó línea por línea contra el parser NBT real de Mine-imator (que está en GML, no en el C++ auditado) — los totales de sólidos/caras no dependen del orden de recorrido (son sumas), así que esto no afecta los números reportados aunque hubiera un error de orden, pero se anota por transparencia.

## Decisión propuesta

**El preset "Grande" es seguro para importaciones de tipo terreno (~60 MB medido, no un rango) y no necesita restricción para ese caso.** El riesgo remanente es específico a importaciones muy densas en bloques especiales (aldeas, bases con muchos cofres/puertas/carteles concentrados), con un rango de ~374 MB a ~1,63 GB para el preset "Grande" — más acotado que antes pero no cerrado del todo. Recomendación: no bloquear el preset "Grande" en general (el caso común es trivial), pero si se quiere una barrera de seguridad barata, contar `sch_timeline_amount` durante la importación real (ya lo hace `Builder.cpp:202`) y avisar/degradar si supera un umbral razonable (por ejemplo, activar carga incremental en vez de todo de una vez) — es una guarda barata contra el único escenario que todavía no está cerrado con datos reales.
