# Ideas post-v1.0

Registro exigido por `CLAUDE.md` §13.4: todo impulso de "quedaría mejor si..." o feature que no sea del Mine-imator base va acá, no directo al código. Se discuten después de v1.0, no durante el port.

| Fecha | Idea | Origen | Por qué no ahora |
|---|---|---|---|
| 2026-09-15 | Toggle Global/Local para el espacio de transformación del gizmo (mundial vs. local al objeto), con botones dedicados en la barra de herramientas | Pedido del usuario, con imagen de referencia mostrando la barra de herramientas de **Mine-imator Community Build** (fork comunitario, no el Mine-imator base `stuffbydavid/Mine-imator` que este proyecto porta) | `[GATE G2 — Upstream]`: agregar una feature exclusiva de un fork desvía el proyecto de ser un port fiel del Mine-imator base. Código actual (`view_control_move.gml`) siempre arma la matriz del gizmo en espacio local del objeto (`matrix_parent` + rotación propia) — no existe ninguna rama de espacio mundial hoy, así que implementarlo es una feature nueva de punta a punta, no portar algo existente. El usuario decidió explícitamente postergarlo en vez de implementarlo ahora |
