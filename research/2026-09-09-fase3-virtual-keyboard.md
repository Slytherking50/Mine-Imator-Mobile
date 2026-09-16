# Investigación: teclado virtual de Android para el sistema de texto actual

## Pregunta

El plan de Fase 3 tenía la investigación del teclado en el paso 7 (textfield). El usuario pidió adelantarla al principio: ¿el mecanismo de captura de texto que ya existe (pensado para escritorio, con teclado físico) tiene algún problema con `QInputMethod`/el teclado en pantalla de Android, o el campo queda tapado? Se pidió **solo investigación, sin implementar nada.**

## Método

1. Grep de `keyboard_string`, `KeyChecker`, `inputMethodEvent`, `QInputMethod`, `Qt::WA_InputMethodEnabled`, `setInputMethodHints` sobre todo `CppProject` para encontrar el mecanismo real de captura de texto.
2. Lectura completa de `AppWindow.cpp` alrededor de la clase `KeyChecker` (constructor, `keyPressEvent`, `keyReleaseEvent`) y de dónde se instancia (`AppWindow::AppWindow()`).
3. Grep de `keyboard_show`/`virtual_keyboard`/`window_focus` sobre `GmProject` para descartar que exista ya un mecanismo GML de mostrar/ocultar el teclado.
4. Búsqueda web de comportamiento conocido de `QAndroidInputContext`/`showInputPanel()` con widgets de foco programático (no gatillado por un tap nativo de Android).
5. Lectura directa del código fuente real de Qt 5.15.19 instalado en esta máquina (`C:/Dev/Qt/5.15.19/qt5/qtbase/src/plugins/platforms/android/qandroidinputcontext.cpp`) — la MISMA versión que compila este proyecto, no una genérica de internet — para ver exactamente qué gatilla `showInputPanel()` y qué lo bloquea.

## Evidencia

- `AppWindow.cpp:289-319` → `KeyChecker` es un `QLineEdit` (`class KeyChecker : public QLineEdit` en `AppWindow.hpp`) creado una sola vez en `AppWindow::AppWindow()` (`glWidget = new GLWidget; ... new KeyChecker(glWidget);`), con:
  - `QLineEdit::setEchoMode(QLineEdit::NoEcho)` — modo password, no muestra texto (tiene sentido: es invisible, GML dibuja su propio texto).
  - Una conexión a `textChanged` que traduce cada cambio del `QLineEdit` interno a `gmlGlobal::keyboard_string` (agrega el último carácter insertado, o recorta uno si se borró) — este es el puente real hacia GML.
  - `QWidget::setFocus()` seguido inmediatamente de `QWidget::hide()` — foco permanente, visibilidad nula, **una sola vez, en el constructor de la ventana**, no en cada cambio de campo de texto de GML.
- `AppWindow.cpp:321-336` → `KeyChecker::keyPressEvent`/`keyReleaseEvent` reenvían cada tecla física a `App->SetKeyDown()` (para `keyboard_check`) y dejan que `QLineEdit::keyPressEvent()` base actualice el texto interno (que dispara `textChanged` → `keyboard_string`).
- `grep -rn "QGuiApplication::inputMethod|inputMethod()|setInputMethodHints|Qt::WA_InputMethodEnabled" CppProject/` → **cero resultados en todo el proyecto.** Nunca se llama a `QGuiApplication::inputMethod()->show()`/`->hide()`, nunca se configuran hints de teclado.
- `grep -rn "keyboard_show|virtual_keyboard|show_keyboard" GmProject/ CppProject/` → cero resultados. No existe ningún mecanismo, ni en GML ni en C++, para pedirle a Android que muestre el teclado en pantalla.
- `draw_inputbox.gml:159-169` (ya citado en `research/2026-09-06-ui-inventory.md`) → el "foco" de un campo de texto en GML es enteramente lógico: `window_focus = string(tbx)`, una variable GML de aplicación. **No tiene ninguna relación con el foco de Qt** (`qGuiApp->focusObject()`), que sigue siendo `KeyChecker` todo el tiempo, sin importar qué campo GML esté "enfocado".
- Código fuente real de Qt 5.15.19 (`qandroidinputcontext.cpp:985-1005`, `showInputPanel()`):
  ```cpp
  void QAndroidInputContext::showInputPanel()
  {
      if (QGuiApplication::applicationState() != Qt::ApplicationActive) { ... return; }
      QSharedPointer<QInputMethodQueryEvent> query = focusObjectInputMethodQuery();
      if (query.isNull())
          return;
      ...
      QRect rect = inputItemRectangle();
      QtAndroidInput::showSoftwareKeyboard(rect.left(), rect.top(), rect.width(), rect.height(), ...);
  }
  ```
  **No hay ningún chequeo de `isVisible()` de ningún widget, en ningún punto de esta función.** La única condición real es que `qGuiApp->focusObject()` no sea null y responda a `QInputMethodQueryEvent` (lo que un `QLineEdit` hace por diseño, visible o no). La visibilidad del widget en sí NO es lo que bloquea el teclado — coincide con que `KeyChecker`, pese a estar oculto, ya recibe eventos de teclado físico hoy en escritorio sin problema (foco lógico de Qt ≠ visibilidad).
- Búsqueda web (Qt Forum, hilo "setFocus and Virtual Keyboards") → problema documentado y ampliamente reportado: `setFocus()` seguido de un intento de mostrar el teclado falla cuando `setFocusObject()` (el que registra `m_focusObject` dentro de `QAndroidInputContext`) todavía no se disparó en el momento en que se pide mostrar el panel — típicamente porque el `setFocus()` ocurre antes de que la ventana nativa de Android exista. Cita literal encontrada: *"timing problem where setFocus is invoked, followed by inputMethod->show(), but setFocusObject is called much later in the chain, so when showInputPanel is invoked, there is no focus object yet, and nothing is made visible."*

## Hallazgos

1. **El mecanismo de texto actual (`KeyChecker`) no tiene ningún gancho que le pida a Android mostrar el teclado.** Fue diseñado exclusivamente para desktop: un único `QLineEdit` invisible, con foco permanente desde el arranque, que traduce teclas físicas a `keyboard_string`. El concepto de "foco" que usan los 68 paneles (`window_focus`, una variable GML) es completamente independiente del foco real de Qt — por diseño, ya que así puede quedar siempre enfocado sin que ningún panel lo sepa ni lo controle.
2. **La causa NO es que el widget esté oculto** — confirmado leyendo el código fuente real de `showInputPanel()`: no chequea `isVisible()`, solo necesita un `focusObject()` válido. El diagnóstico correcto es más específico y más grave: **nadie llama a `showInputPanel()`/`QGuiApplication::inputMethod()->show()` en ningún momento**, porque no hay código que lo haga y porque el foco de Qt (`KeyChecker`) nunca cambia cuando el foco de GML sí cambia entre campos. Aunque hoy, por la razón que sea, el teclado apareciera una vez (por ejemplo si Android decide mostrarlo espontáneamente al detectar un campo con foco al arrancar), no hay forma de que reaparezca al tocar un campo de texto distinto, porque no hay ningún evento de foco de Qt que lo dispare — el foco de Qt no se mueve nunca.
3. **Riesgo adicional, secundario:** `QLineEdit::NoEcho` (modo password) puede afectar los `Qt::ImHints` que Android usa para decidir el tipo de teclado/autocorrección/predicción de texto — no se pudo verificar sin dispositivo si esto degrada la UX del teclado (ej. mostrando el layout de "contraseña" en vez de texto normal) una vez que el teclado sí se muestre. Es una incógnita separada del bloqueo principal, no lo agrava.
4. **Esto no es específico de un solo `textfield`** — afecta a los 5+ lugares identificados en `research/2026-09-06-ui-inventory.md` que dependen de edición de texto: `textfield`, `textfield_group` (por subcampo), el textbox numérico embebido en `dragger` y en `meter`, y el campo de búsqueda de `sortlist`. Ningún de estos mostrará el teclado en Android hoy, tal como está el código.

## Contradicciones con CLAUDE.md

Ninguna nueva — esto refina el punto 2 de "Incógnitas" de `research/2026-09-06-ui-inventory.md" ("no se determinó el mecanismo... para long-press", en un punto relacionado pero distinto) y la Trampa 2 de §6.3 (`mouse_x`/`mouse_y` indefinidos entre toques) sin contradecirla — es un hallazgo nuevo, no documentado antes, sobre el mismo sistema de input.

## Incógnitas

- No se puede confirmar en el dispositivo real si el teclado aparece hoy por completo accidente (ej. algún comportamiento por defecto de Android al detectar CUALQUIER `EditText`-like con foco al arrancar la Activity) — la lectura de código dice que no debería, pero solo una prueba en dispositivo lo confirma con certeza total.
- No se determinó el efecto exacto de `QLineEdit::NoEcho` sobre `Qt::ImHints` en el teclado de Android una vez resuelto el bloqueo principal.
- No se diseñó la posición/tamaño que `KeyChecker::inputMethodQuery()` (heredado de `QLineEdit`, no sobreescrito) reportaría como `Qt::ImCursorRectangle` — al ser un widget oculto con geometría propia (probablemente 0×0 o el tamaño por defecto de un `QLineEdit` recién construido), es casi seguro que NO coincide con la posición real en pantalla del campo de texto que GML está dibujando. Android puede usar ese rect para decidir cómo reposicionar/scrollear la ventana al abrir el teclado — un rect incorrecto podría producir un reposicionamiento visualmente raro, aunque no bloquearía que el teclado se abra.

## Decisión propuesta (para cuando Fase 3 llegue al paso de texto — no implementado ahora)

El fix no es trivial pero tampoco es una reescritura: son 3 piezas, todas ya con precedente conocido en Qt:

1. **Disparar el show/hide explícito.** Cuando el `window_focus` de GML apunte a un campo de texto (o deje de hacerlo), llamar desde C++ (nueva función `CppOnly`/`CppSeparate`, siguiendo el mecanismo ya usado en 71 archivos, `CLAUDE.md` §4.2) a `QGuiApplication::inputMethod()->show()` / `->hide()`. Esto requiere que `KeyChecker` sea el `focusObject()` real de Qt en ese momento — evitar el bug de timing documentado (`setFocus()` antes de que la ventana exista) reforzando el foco (`clearFocus()`+`setFocus()`, o confirmando el estado) recién cuando la ventana ya está mostrada (`showFullScreen()` ya ejecutado), no en el constructor de `AppWindow`.
2. **Reportar la posición real.** Sobreescribir `KeyChecker::inputMethodQuery()` para devolver, al menos, `Qt::ImCursorRectangle` con las coordenadas reales en pantalla del campo GML actualmente enfocado (ya calculadas por `textbox_draw`/`draw_inputbox` para dibujar el cursor) en vez de la geometría interna del `QLineEdit` oculto.
3. **Verificar `NoEcho`/`ImHints` en dispositivo real** una vez lo anterior esté andando — ajustar el modo de eco o los hints si el teclado se comporta como "contraseña" en vez de texto normal.

Esto no cambia nada del mecanismo de `keyboard_string` (que ya funciona y es independiente de que el teclado esté visible o no) — solo agrega el llamado explícito de mostrar/ocultar y la posición correcta.
