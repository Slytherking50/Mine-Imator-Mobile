/// draw_dragger(name, x, y, width, value, multiplier, min, max, default, snap, textbox, script, [captionwidth, [showcaption, [disabled, [tip]]]])
/// @arg name
/// @arg x
/// @arg y
/// @arg width
/// @arg value
/// @arg multiplier
/// @arg min
/// @arg max
/// @arg default
/// @arg snap
/// @arg textbox
/// @arg script
/// @arg [captionwidth
/// @arg [showcaption
/// @arg [disabled
/// @arg [tip]]]]

function draw_dragger(name, xx, yy, wid, value, mul, minval, maxval, def, snapval, tbx, script, capwidth = null, showcaption = true, disabled = false, tip = "")
{
	var caption, hei, fieldx, dragmouseon;
	
	hei = ui_small_height
	
	if (capwidth = null && showcaption)
		capwidth = dw - wid
	else if (!showcaption)
		capwidth = 0
	
	draw_set_font(font_label)
	
	if (capwidth > 0)
		caption = string_limit(text_get(name), min(capwidth, dw - wid))
	else
		caption = string_limit(text_get(name), dw - wid)
	
	if (xx + wid + capwidth < content_x || xx > content_x + content_width || yy + hei < content_y || yy > content_y + content_height)
	{
		if (textbox_jump)
			ds_list_add(textbox_list, [tbx, content_tab, yy, content_y, content_height])
		
		return 0
	}
	
	if (!disabled)
		context_menu_area(xx, yy, wid + capwidth, hei, "contextmenuvalue", value, e_context_type.NUMBER, script, def)
	
	fieldx = xx + capwidth
	
	dragmouseon = app_mouse_box(fieldx, yy, wid, hei) && content_mouseon && (window_focus != string(tbx)) && !disabled
	
	// Drag
	if (dragmouseon && mouse_left_pressed)
		window_focus = name + "press"
	
	// Mouse pressed
	if (window_focus = name + "press")
	{
		mouse_cursor = cr_size_we
		
		if (!mouse_left)
		{
			window_busy = ""
			app_mouse_clear()
			
			// Select textbox
			if (app_mouse_box(fieldx, yy, wid, hei) && !disabled)
			{
				tbx.text = string_decimals(value)
				window_focus = string(tbx)
				window_busy = ""
			}
		}
		// mouse_move > 5 (total displacement since press, not mouse_dx's raw per-frame delta)
		// - Fase 3, CLAUDE.md §6.2/inventario 0.8: on touch, a stationary finger still jitters
		// a few px/frame from digitizer noise, so "any dx" fired a drag on almost every tap,
		// never letting the numeric textbox open. Same 5px threshold view_update.gml already
		// uses (camera orbit vs. click) - not new to this codebase, and harmless on desktop
		// (a few px of mouse wobble before a click is imperceptible).
		else if (mouse_move > 5)
		{
			dragger_drag_value = value
			window_busy = name + "drag" // Start dragging
			window_focus = ""
		}
	}
	
	// Is dragging
	if (window_busy = name + "drag")
	{
		mouse_cursor = cr_none

		// INSTRUMENTAL, mismo motivo y mismo fix que camera_control_rotate.gml/
		// camera_control_move.gml (B10, KNOWN_ISSUES.md): window_mouse_set() ->
		// display_mouse_set() intenta recentrar el cursor cada frame para poder arrastrar
		// sin límite en escritorio, pero en touch Android reporta la posición REAL del dedo
		// sin importar qué fuerce el código - el recentro nunca "funciona", así que
		// (mouse_x - mouse_click_x) sigue siendo el desplazamiento total real (no el delta de
		// este frame) y se sigue sumando cada frame sin límite, disparando el valor a un
		// extremo casi al instante. En Android se usa mouse_dx (delta real entre frames, ya
		// calculado en app_update_mouse.gml) sin recentrar nada.
		if (platform_get() == e_platform.ANDROID)
			dragger_drag_value += mouse_dx * mul * dragger_multiplier
		else
		{
			dragger_drag_value += (mouse_x - mouse_click_x) * mul * dragger_multiplier
			window_mouse_set(mouse_click_x, mouse_click_y)
		}
		
		var d;
		
		if (app.setting_unlimited_values)
			d = snap(dragger_drag_value, snapval) - value;
		else
			d = clamp(snap(dragger_drag_value, snapval), minval, maxval) - value;
		
		if (d <> 0)
		{
			script_execute(script, d, true)
			tbx.text = string_decimals(value + d)
		}
		
		if (!mouse_left)
		{
			window_busy = ""
			app_mouse_clear()
		}
	}
	
	if (draw_inputbox(name, fieldx, yy, wid, hei, string(def), tbx, null, disabled, false, font_digits, e_inputbox.RIGHT) && script != null)
	{
		var val = eval(tbx.text, def);
		script_execute(script, app.setting_unlimited_values ? snap(val, snapval) : clamp(snap(val, snapval), minval, maxval), false)
	}
	
	if (value < minval || value > maxval)
		draw_box(fieldx, yy, wid, hei, false, c_error, a_accent_overlay)
	else if ((abs(maxval) + abs(minval)) < 100000)
	{
		// Idle
		var perc = percent(value, minval, maxval);
		draw_box(fieldx, yy, wid * perc, hei, false, c_accent_hover, a_accent_overlay)
	}
	
	if (window_busy = name + "drag")
		current_microani.active.value = true
	
	// Set cursor
	if (dragmouseon)
		mouse_cursor = cr_size_we
	
	// Use microanimation from inputbox to determine color
	var labelcolor, labelalpha;
	labelcolor = merge_color(c_text_secondary, c_text_main, microani_arr[e_microani.HOVER])
	labelcolor = merge_color(labelcolor, c_accent, microani_arr[e_microani.ACTIVE])
	labelcolor = merge_color(labelcolor, c_text_tertiary, microani_arr[e_microani.DISABLED])
	
	labelalpha = lerp(a_text_secondary, a_text_main, microani_arr[e_microani.HOVER])
	labelalpha = lerp(labelalpha, a_accent, microani_arr[e_microani.ACTIVE])
	labelalpha = lerp(labelalpha, a_text_tertiary, microani_arr[e_microani.DISABLED])
	
	if (showcaption)
	{
		draw_label(caption, xx, yy + hei/2, fa_left, fa_middle, labelcolor, labelalpha, font_label)
		
		if (xx + string_width(caption) + 28 < fieldx)
			draw_help_circle(tip, xx + string_width(caption) + 4, yy + (hei/2) - 10, disabled)
	}
	
	// Idle
	if (window_busy != name + "drag" && window_busy != name + "press" && window_focus != string(tbx))
		tbx.text = string_decimals(value)
}
