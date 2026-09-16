/// app_update_interface()

function app_update_interface()
{
	if (update_interface_wait)
	{
		interface_update_instant()
		update_interface_wait = false
	}
	
	// Compact mode (small ui_large_height/ui_small_height) exists for small DESKTOP windows,
	// trading row height for information density - the opposite of what touch needs. A phone's
	// logical window_height is always small (this device: ~360 in landscape), so the
	// window_height<=900 check alone would put Android in compact mode on every device, every
	// time - shrinking row heights instead of growing them (confirmed on real device: buttons
	// too small to tap reliably). Excluded on Android so it always uses the larger, already
	// road-tested "normal" desktop values instead - a modest, deliberately small bump (24->32,
	// 20->24), not a new multiplier invented for this.
	if ((window_height <= 900 || setting_interface_compact) && platform_get() != e_platform.ANDROID)
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

	// toolbar_size used to be a flat 28 set once at startup, disconnected from
	// ui_large_height/ui_small_height (CLAUDE.md §6.2) - now derived here every frame like
	// they are, keeping today's value (28) exactly in normal mode (32-4).
	toolbar_size = ui_large_height - 4

	// ui_touch_* - internal hitbox/glyph geometry that's smaller than a full row, hardcoded
	// with no name anywhere in the codebase before Fase 3 paso 1 (CLAUDE.md §6.2, inventario
	// 0.8). Contrato de §17 (2026-09-11, segunda corrección al modelo de §6.1): estos globals,
	// no las 13 tab_control_*, son el punto real de apalancamiento para la geometría interna
	// de cada primitiva - ninguna firma de función cambia, cada draw_* sigue leyendo el mismo
	// nombre de variable que ya tenía, solo que ahora varía por plataforma en vez de ser un
	// número fijo adentro de la primitiva.
	//
	// ui_touch_sortlist_resize_width: la franja para redimensionar una columna de sortlist
	// (sortlist_draw.gml) es hoy 10px fijos en TODAS las plataformas - inviable al dedo (el
	// inventario ya lo marcaba como el peor caso: "ni siquiera es cómodo con mouse"). 3x en
	// Android, sigue siendo angosta pero deja de ser imposible; cero cambio en desktop.
	//
	// ui_touch_meter_thumb_height: alto del hitbox del thumb del slider (draw_meter.gml) -
	// arrastrarlo con el dedo necesita más margen vertical que con un cursor de mouse (mismo
	// razonamiento que sortlist). checkbox_glyph_size NO se toca a propósito: su hitbox de
	// click ya cubre la fila entera (draw_checkbox.gml), agrandar el glifo ahí es legibilidad,
	// no targeting - confirmado en research/2026-09-06-ui-inventory.md, no es el mismo problema.
	ui_touch_meter_thumb_height = (platform_get() == e_platform.ANDROID) ? 32 : 20
	ui_touch_sortlist_resize_width = (platform_get() == e_platform.ANDROID) ? 30 : 10
	ui_touch_checkbox_glyph_size = 16

	// ui_touch_textfield_height: los 13 call sites de draw_textfield que hoy hardcodean 24
	// (inventario B) no se corrigen apuntando a ui_small_height - ese "24" es un valor propio
	// deliberado, distinto de ui_small_height a propósito (tab_control_textfield.gml: en modo
	// compacto de escritorio ui_small_height baja a 20 pero el textfield se queda en 24 fijo).
	// Reusar ui_small_height ahí habría achicado los textfields en modo compacto de escritorio,
	// algo que nunca pasaba antes - variable nueva en su lugar, 24 en desktop siempre (cero
	// cambio), más grande solo en Android.
	ui_touch_textfield_height = (platform_get() == e_platform.ANDROID) ? 40 : 24

	// ui_touch_wheel_radius: draw_wheel.gml's radius default already stopped being a bare
	// literal in an earlier pass (tied to ui_large_height so it isn't duplicated), but that
	// alone never made it bigger for touch - Android forces the same "normal" ui_large_height
	// as desktop (see the top of this function), so the wheel dial ended up the same size on
	// both, unlike every other item in this list. Flagged in the original inventory as needing
	// its own bump: dragging a rotation dial by finger needs more hit tolerance than a mouse
	// cursor, same reasoning as the meter thumb and the 3D viewport gizmo above. 32 on Android
	// (vs. 24 today) mirrors ui_touch_meter_thumb_height's bump for consistency; desktop keeps
	// computing from ui_large_height exactly as before, zero change there.
	ui_touch_wheel_radius = (platform_get() == e_platform.ANDROID) ? 32 : (ui_large_height + 16) / 2

	// view_3d_control_size/view_3d_control_width used to be #macro (macros.gml), fixed for
	// every platform - the move/rotate/scale gizmo in the 3D viewport, another touch target
	// too small for a finger (confirmed by user report, 2026-09-09). Bigger on Android: 2x
	// the hit-test tolerance width, 1.5x the on-screen visual size (kept smaller than the
	// tolerance bump on purpose - a much bigger gizmo would clutter/obscure the scene, the
	// tolerance can be generous without the graphic itself needing to match 1:1). Desktop
	// values unchanged.
	if (platform_get() == e_platform.ANDROID)
	{
		view_3d_control_size = 0.2125 * 1.5
		view_3d_control_width = 20 * 2
	}
	else
	{
		view_3d_control_size = 0.2125
		view_3d_control_width = 20
	}

	/*
	if (current_time < update_interface_timeout)
		interface_update()
	*/
}
