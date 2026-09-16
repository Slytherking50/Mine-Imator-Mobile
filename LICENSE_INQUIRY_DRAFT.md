# Borrador — mensaje para David Andrei

Dónde mandarlo: GitHub issue/discussion en `stuffbydavid/Mine-imator`, o el foro oficial (mineimatorforums.com), o el mail del commit (`mail@davidandrei.net`) si preferís algo más directo/privado. Un issue público en GitHub probablemente sea lo más rápido y lo más citable después.

Asunto sugerido: "Question about Mine-imator 2.0.x source license"

---

Hi David,

I'm looking into building a mobile (Android) port of Mine-imator on top of the current source in this repo, and I ran into some ambiguity about licensing that I'd like to clear up before investing real time in it.

What I found going through the repo history:

- There's no `LICENSE` file in the repo today. There was one (MIT, added in 2018) but it was removed in the `2.0.0` commit back in March 2023.
- The Windows installer used to ship a `license.txt` (removed a few weeks ago, in the "CppGen ported to C++" cleanup commit) that said: *"the source code of Mine-imator is available on GitHub under the MIT license."* That was still true as of that commit.

So my read is that both removals were probably just repo cleanup, not a deliberate change in licensing — but I don't want to assume. Could you confirm:

1. **Is the current 2.0.x source (this repo, as-is) still MIT?** If so, would you be open to adding a `LICENSE` file back to the repo root? That would settle this for good, not just for me.
2. **Would a mobile port and its distribution (e.g., on Google Play, under a different name) be okay under that license**, or is there anything you'd want handled differently for that case?
3. **The name** — I understand "Mine-imator" itself isn't something I could use for a separate distributed app. Just confirming that's the right assumption.

No rush — I know this is a side project for you too. Thanks for the clarification, and for building this in the first place.

---

**Notas para vos (no van en el mensaje):**
- Ajustá el tono si lo conocés personalmente o si preferís algo más formal/informal.
- Si querés, puedo agregar una mención a los blockers técnicos (x264 GPL, Qt LGPL) para preguntarle todo junto — pero son preguntas más de abogado que de él, capaz mejor no mezclarlas en el primer mensaje y ver qué contesta esto primero.
- Guardé la ruta exacta de la investigación (commits `fab960f8`, `6d48eaff`, `8732ee7e`) en `CLAUDE.md` §9.3 por si en algún momento necesitás citarlas con más detalle.
