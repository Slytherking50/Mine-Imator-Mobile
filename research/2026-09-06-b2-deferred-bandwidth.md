# Investigación: Medición de B2 — ancho de banda del pipeline diferido (tarea 0.6)

## Pregunta

¿Cuánto ancho de banda de memoria consume el renderer de Mine-imator por frame, a 1080p, y cómo se compara contra el de un SoC Android de gama media? ¿Contra qué objetivo de §14.3 corresponde medirlo, y sobrevive el render diferido en móvil — tal cual, degradado, o no sobrevive?

**Historia de esta investigación, porque cambió de forma dos veces y hay que dejar el rastro:** la primera pasada costeó `render_high()` completo, incluyendo indirect lighting/reflections, y concluyó "crítico, ~19-40× el presupuesto". Una revisión encontró dos errores: (1) el ray marching de indirect/reflections se costeó con 0% de cache hit, un peor caso, no una estimación; (2) al recalcular el G-buffer con formatos optimizados, apareció que mi propio bucket original de "G-buffer + composite" (640 MB) estaba mal armado — le faltaba SSAO entero y subestimaba la acumulación de samples, y **el G-buffer nunca fue la mayoría del costo real** (era ~7% de ~1,2 GB, no ~ 70% de 640 MB). Una tercera revisión encontró el error más importante: **el pipeline que se estaba costeando (`render_high()`) no es el que corre en el viewport interactivo por default** — eso corre por `render_low()`, mucho más barato. Las tres correcciones están documentadas abajo con su evidencia, no solo el resultado final.

## Método

1. No hay dispositivo Android ni build de `CppProject` para Android — esto es un modelo de bytes construido desde el código real (formatos de superficie, conteo de pasadas y de pasos de shader), no una medición de profiler. Se documenta así de explícito en cada número.
2. Se rastreó `render_high()` completo y cada sub-script que llama, incluyendo los que la primera pasada de esta investigación no había abierto: `render_high_ssao`, `render_high_glow`, `render_high_subsurface_scatter`, `render_post` (el dispatcher de post-efectos) y sus 12 sub-efectos.
3. Para cada superficie, formato real vía `surface_require` → `surface_create_ext2` (`RenderFunc.cpp:369`) → `FrameBuffer.cpp:197` (`hdr ? GL_RGBA32F : GL_RGBA`, depth `GL_DEPTH24_STENCIL8`).
4. Para cada shader con loop (`shader_high_raytrace.fsh`, `shader_high_subsurface_scatter.fsh`), se leyó el shader completo, no solo el nombre — un intento inicial de costear `shader_high_subsurface_scatter` a partir de su constante `#define MAX_SAMPLES 65` habría sobreestimado el costo ~4,3×; el loop real tiene un `break` en `i >= uSamples` (`:67`), con `uSamples` derivado de `project_render_subsurface_samples` (default 7 → ~14 iteraciones reales, no 65).
5. **Se verificó qué pipeline corre en el viewport interactivo real**, no se asumió que era `render_high()`: `view_update_surface.gml:17-20` decide entre `render_high()`/`render_low()` según `view.quality`, y `app_startup_interface_views.gml:35,51` confirma que las vistas arrancan en `e_view_mode.SHADED` (→ `render_low()`), no en `RENDER`. `view_draw.gml:19-20` confirma que el propio proyecto trata `RENDER` como modo caro/exclusivo (auto-baja una vista a `SHADED` si las dos piden `RENDER`).
6. Para los SoCs de referencia (Snapdragon 695, Dimensity 6100+/700, Snapdragon 6 Gen 1), se resolvió una ambigüedad de unidades entre fuentes (algunas decían "Gbit/s", otras "GB/s" para el mismo número ~17) recalculando desde la fórmula estándar (data rate × ancho de bus en bytes) con bus de 64 bits, la única combinación que reproduce el número reportado por múltiples fuentes independientes.

## Evidencia

### Formato real de las superficies del G-buffer (sin cambios respecto a la versión anterior de este informe)

| Superficie | Color | Depth/stencil propio |
|---|---|---|
| diffuse | RGBA8 (4B/px) | GL_DEPTH24_STENCIL8 (4B/px) |
| material | RGBA8 (4B/px) | GL_DEPTH24_STENCIL8 (4B/px) |
| emissive | RGBA8 (4B/px) | GL_DEPTH24_STENCIL8 (4B/px) |
| specular | RGBA32F (16B/px) | — |
| depth (empaquetado como color) | RGBA8 (4B/px) | GL_DEPTH24_STENCIL8 (4B/px) |
| normal | RGBA32F (16B/px) | GL_DEPTH24_STENCIL8 (4B/px) |

`SetMRTIndex` (`GraphicsApiHandler.cpp:181-217`/`:497-514`) confirma que un grupo MRT comparte el FBO/depth del primer surface del grupo — así que las 3 pasadas de geometría (diffuse, depth+normal MRT, material+emissive MRT) escriben **un depth por pasada** (3 en total), no 5 simultáneos. Consolidar los depth buffers en uno solo ahorra memoria asignada (relevante para 0.7) pero no ancho de banda por frame — cada pasada sigue escribiendo su depth una vez, sea el mismo buffer físico o no.

### El viewport interactivo por default no usa este pipeline

```
// view_update_surface.gml:17-20
if (view.quality = e_view_mode.RENDER)
    render_high()
else
    render_low()

// app_startup_interface_views.gml:35,51
view_main.quality = e_view_mode.SHADED
view_second.quality = e_view_mode.SHADED
```

`render_low()` (`render_low.gml`): un solo surface RGBA8+depth, una pasada forward (`render_world(COLOR_FOG_LIGHTS)`), alpha fix, y `render_post()` (mismo post stack que `render_high`, así que glow —default ON— aplica igual). Sin G-buffer, sin SSAO, sin sombras, sin indirect, sin reflections.

Dentro de `render_high()` en modo `RENDER`, mover la cámara **no** reduce la calidad de cada frame — resetea `render_samples` a 1 (`render_update_samples.gml:13,20`), y el pipeline completo (`render_high_passes` → shadows → indirect → ssao → scene → reflections → tonemap → fog → post con `sceneeffects=true`) corre una vez entera por frame mientras se está moviendo (`render_high.gml`: `samplestart=render_samples-1, sampleend=render_samples`, rango de exactamente 1). Cuando la cámara está quieta y ya se acumularon los samples target, ese bloque completo se saltea (`if (render_samples_done) { samplestart=0; sampleend=0 }`) y solo corre el post-stack final (`posteffects=true`) una vez. La acumulación ahorra *cuántas veces* se corre el pipeline caro en total, no lo abarata por corrida individual.

### El shader de subsurface scattering, corregido

```glsl
// shader_high_subsurface_scatter.fsh
#define MAX_SAMPLES 65
...
for (int i = 1; i < MAX_SAMPLES; i++)
{
    if (i >= uSamples || (abs(rad.x + rad.y) < 0.001))
        break;
    ...
    texture2D(uSSSRangeBuffer, sampleCoord);   // siempre
    texture2D(uDepthBuffer, sampleCoord);      // eager, sin garantía de short-circuit en ||
    texture2D(uDirect, sampleCoord);           // si no se corta antes con continue
}
```

`uSamples` viene de `render_subsurface_size = (project_render_subsurface_samples * 2) + 1` = 15 con el default (`project_render_subsurface_samples = 7`). El loop real corta en ~14 iteraciones, no en 65.

### SoCs de referencia (sin cambios): Snapdragon 695 / Dimensity 6100+ ~17 GB/s pico teórico, Snapdragon 6 Gen 1 ~22 GB/s. Sostenido real estimado (~50-55% del pico, regla general de la industria, no medido): ~9-12 GB/s.

## Hallazgos

### 1. Contra qué objetivo se mide cada cosa

| Escenario | Pipeline | Objetivo relevante |
|---|---|---|
| Edición normal, cámara moviéndose | `render_low()` (SHADED, default) | §14.3 "30 fps interactivos" |
| Preview "Render" (opt-in, botón de UI) | `render_high()` | Sin objetivo explícito en §14.3 hoy — UX de preview, tolerable si es más lento |
| Export final | `render_high()` (`export_update.gml:66`) | Presupuesto de *tiempo de export*, no de fps — tampoco existe hoy en §14.3 |

**`render_low()`, costeado:** ~8B/px (pasada forward) + glow (~240MB, mismo shader que en `render_high`, ver abajo) + copia final ≈ **~250 MB/frame → ~7,5 GB/s @30fps**. Sobrevive sin margen de duda contra cualquier SoC de gama media. **El objetivo de §14.3 no está en riesgo por B2.**

### 2. `render_high()` sin indirect/reflections — recalculado con más cuidado que la vez anterior

| Etapa | MB (formato original) | MB (G-buffer optimizado: normal→RG16 octaédrico, specular→RGBA8) |
|---|---|---|
| G-buffer (3 pasadas geometría) | 91 | 66 |
| SSAO | 83 | 83 (no lo tocan los cambios de formato) |
| Composite de escena (glint+specular+lighting_apply) | 158 | 133 |
| Tonemap + acumulación de samples | 290 | 290 |
| Glow (default ON, `project_render_glow=true`) | 240 | 240 |
| Subsurface scattering (default ON, `project_render_subsurface_samples=7`, corregido de MAX_SAMPLES=65 a ~14 iteraciones reales) | ~400-406 | ~400-406 |
| **Total** | **~1.262-1.268 MB** | **~1.212-1.218 MB** |

Compartir un solo depth buffer entre las 3 pasadas: ahorra memoria (0.7), no bandwidth (ver Evidencia). Normal+specular optimizados solos ahorran solo ~4% del total — porque esos dos buffers nunca fueron la mayoría del costo; SSAO+glow+subsurface+acumulación sí lo son.

### 3. Preset móvil (flags existentes, sin cambio de arquitectura) + RGBA16F sobre lo que queda HDR

Apagar `project_render_glow`, `project_render_subsurface_samples=0` y SSAO (tres flags que ya existen, no requieren código nuevo):

| Etapa | MB |
|---|---|
| G-buffer (optimizado) | 66 |
| Composite de escena (optimizado) | 133 |
| Tonemap + acumulación | 290 |
| Glow, subsurface, SSAO | 0 |
| **Total** | **489 MB → ~14,7 GB/s @30fps** |

Sobre esto, `RGBA16F` en los dos puntos que siguen en `RGBA32F` (el read+write de `render_surface_shadows`/`resultsurf` dentro de `lighting_apply`, y el copy+shader de `render_high_tonemap`; los buffers de acumulación de samples ya eran RGBA8 y no cambian):

| Etapa | MB |
|---|---|
| G-buffer | 66 (ya sin RGBA32F) |
| Composite de escena | 99,5 |
| Tonemap + acumulación | 223,6 |
| **Total** | **389 MB → ~11,7 GB/s @30fps** |

**11,7 GB/s entra dentro del rango de ancho de banda sostenido real estimado (~9-12 GB/s) de un Snapdragon 695/Dimensity 6100+.** A 60fps (~23,3 GB/s) se pasa, pero para un modo de preview opcional (no el objetivo de §14.3, que es sobre el viewport default) es un target razonable.

### 4. Indirect lighting / reflections — sigue siendo la pieza más incierta

Rango de costo combinado (indirect + reflections, `shader_high_raytrace.fsh`, 256-512 pasos según `uPrecision`) según hit rate de cache de textura asumido (no medido — no hay forma de conocer el real sin GPU física):

| Hit rate asumido | GB combinado | GB/s @30fps |
|---|---|---|
| 0% (cota superior, sin crédito de caché) | 5,52 | 166 |
| 80% | 1,10 | 33 |
| 90% | 0,55 | 16,6 |
| 95% | 0,28 | 8,3 |

**Degradado** (cuarto de resolución = 960×540 + 32 pasos, usando `uPrecision` como la perilla que ya existe — reducción de 41,6× vs. default de 333 pasos a res completa, 64× vs. el máximo de 512): costo combinado en el peor caso (0% cache) ≈ **0,13 GB → ~4 GB/s @30fps**, dentro de presupuesto incluso sin crédito de caché. El pipeline ya tiene infraestructura de acumulación temporal (`render_samples`/`render_high_samples_add`, construida para TAA) que serviría igual para converger un SSR de menos pasos por frame.

**Sumado al resto del pipeline optimizado (389 MB / 11,7 GB/s):** el combinado va de ~15,7 GB/s (degradado, cache optimista — viable en un SoC de gama media-alta como el Snapdragon 6 Gen 1) a ~44,7 GB/s (0% cache, se pasa incluso ahí). Es la única pieza de este análisis que de verdad necesita un profiler de GPU real para cerrarse — todo lo demás (G-buffer, composite, tonemap, glow, subsurface, SSAO) está acotado con razonable confianza desde el código fuente solo.

## Contradicciones con CLAUDE.md

- §8, B2 original: "MRT diferido sobre TBDR móvil", evidencia "8 shaders con `gl_FragData`". El término dominante nunca fue eso — es la combinación SSAO+composite+acumulación+glow+subsurface (todo lo que no es MRT del G-buffer), más el ray marching de indirect/reflections cuando está prendido.
- §14.3 no distingue el objetivo de "30 fps interactivos" entre modo `SHADED` (lo que corre por default) y `RENDER` (opt-in, mucho más caro) ni tiene una fila de presupuesto de tiempo de export. Esta ambigüedad hizo que la primera versión de este informe evaluara el pipeline equivocado contra el objetivo de §14.3. Recomendación: separar "viewport interactivo (SHADED)" de "preview Render / export (render_high)" como dos filas distintas en 14.3.
- Versión anterior de este mismo informe (dentro de esta sesión): declaraba B2 "crítico, no sobrevive ni sin indirect/reflections" a partir de un total (640 MB) que resultó estar incompleto (faltaba SSAO, subestimaba acumulación, asumía post-efectos apagados por default que en realidad estaban prendidos — y a la inversa, ya corregido acá). Y antes de eso, declaraba "no hay mitigación posible" para indirect/reflections, lo cual ignoraba que `uPrecision` y la resolución de render ya son perillas existentes. Ambos corregidos en este documento.

## Incógnitas

- El hit rate real de cache de textura del ray marcher sigue sin poder acotarse sin GPU física — es la única pieza donde la conclusión ("sobrevive degradado" vs. "no sobrevive ni degradado") depende de un rango de 8×, no de un número.
- No hay una fila de presupuesto para "tiempo de export por frame" en §14.3 — sería el marco correcto para juzgar si el costo de `render_high()` sin degradar es aceptable en ese contexto (tolerancia a más de 30fps si el usuario ya sabe que está exportando, análogo a un viewport de path-tracing).
- Los coeficientes de RGBA16F asumen que el rango dinámico de la escena no excede lo que half-float puede representar sin banding perceptible — no se validó contra ninguna escena real (ninguna existe todavía en un contexto Android).
- Sigue sin verificarse el costo de sombras por luz (sun cascades, point/spot atlas) — escala con la cantidad de luces de la escena, no con la resolución, y no se contó en ningún total de este documento.

## Decisión propuesta

**B2 no amenaza el objetivo real de §14.3** (el viewport interactivo por default usa `render_low()`, ~7,5 GB/s, sin margen de duda). **Sí sigue siendo relevante para el modo `RENDER`/preview y para el export final**, y ahí la situación mejoró sustancialmente respecto al diagnóstico anterior: con tres flags existentes apagados (glow, subsurface, SSAO — no arquitectura) más dos cambios de formato ya prototipados (normal→RG16 octaédrico, specular→RGBA8) más RGBA16F en los dos puntos HDR que quedan, el pipeline sin indirect/reflections cae a **~11,7 GB/s @30fps, dentro del presupuesto sostenido estimado.** Indirect/reflections quedan como la única pieza que realmente necesita datos de un dispositivo físico antes de decidir si entran (degradados) en el preset móvil o quedan fuera.

`framebuffer_fetch` (tarea 0.9) queda para el final: ataca específicamente el store/load de los MRT del G-buffer (~66-91 MB de un total de ~389-1.218 MB según escenario) — una fracción chica del problema real, que ya está dominado por SSAO/composite/acumulación/glow/subsurface y por indirect/reflections, ninguno de los cuales `framebuffer_fetch` toca.
