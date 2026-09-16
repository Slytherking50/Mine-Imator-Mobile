/// toolbar_draw()

function toolbar_draw()
{
	content_x = 0
	content_y = 0
	content_width = window_width
	content_height = toolbar_size
	content_mouseon = (app_mouse_box(content_x, content_y, content_width, content_height) && !popup_mouseon && !toast_mouseon && !context_menu_mouseon)
	
	dx = content_x + 10
	dy = content_y
	
	// Background
	draw_box(content_x, content_y, content_width, content_height, false, c_level_top, 1)
	draw_divide(content_x, content_y + content_height, content_width)
	draw_gradient(content_x, content_y + content_height, content_width, shadow_size, c_black, shadow_alpha, shadow_alpha, 0, 0)
	
	var capwid, padding;
	padding = 0
	
	draw_set_font(font_value)
	
	capwid = string_width(text_get("toolbarfile")) + 16
	toolbar_draw_button("toolbarfile", dx, dy, capwid)
	dx += capwid + padding
	
	if (window_state = "")
	{
		capwid = string_width(text_get("toolbaredit")) + 16
		toolbar_draw_button("toolbaredit", dx, dy, capwid)
		dx += capwid + padding
		
		capwid = string_width(text_get("toolbarrender")) + 16
		toolbar_draw_button("toolbarrender", dx, dy, capwid)
		dx += capwid + padding
	}
	
	capwid = string_width(text_get("toolbarview")) + 16
	toolbar_draw_button("toolbarview", dx, dy, capwid)
	dx += capwid + padding
	
	capwid = string_width(text_get("toolbarhelp")) + 16
	toolbar_draw_button("toolbarhelp", dx, dy, capwid)
	dx += capwid + padding
	
	dx += 8
	draw_label(text_get("toolbarbackup"), dx, dy + 22, fa_left, fa_bottom, c_text_secondary, a_text_secondary * clamp(backup_text_ani, 0, 1), font_value)

	// "Simple mode" button label
	if (!setting_advanced_mode)
	{
		if (draw_button_label("toolbarsimplemode", content_x + content_width - 10, dy, null, null, e_button.TOOLBAR, null, fa_right))
		{
			if (trial_version)
			{
				popup_show(popup_upgrade)
				popup_upgrade.page = 1
				popup_upgrade.open_advanced = true
			}
			else
				popup_show(popup_advanced)
		}
	}

	// Undo/Redo (Android, 2026-09-15, explicit user request) - Ctrl+Z/Ctrl+Y have no touch
	// equivalent (§6.4/§13.2) and were only reachable two taps deep (Editar menu -> Deshacer/
	// Rehacer, list_init_context_menu.gml's "toolbaredit" case, whose exact action_toolbar_
	// undo/redo + disabled conditions this mirrors) - undo is used too constantly while
	// working to bury it there on touch. Anchored top-right, same corner desktop's simple-mode
	// button uses (mutually exclusive with it in practice: that button only shows when
	// !setting_advanced_mode, which defaults true on Android - settings_startup.gml - so there's
	// no real collision, just the same reserved corner).
	if (platform_get() == e_platform.ANDROID && window_state = "")
	{
		var undobtnsize, undobtnx;
		undobtnsize = 32
		undobtnx = content_x + content_width - 10 - undobtnsize

		if (draw_button_icon("toolbarredo", undobtnx, dy + 4, undobtnsize, undobtnsize, false, icons.REDO, null, (history_pos = 0)))
			action_toolbar_redo()
		undobtnx -= undobtnsize + 4

		if (draw_button_icon("toolbarundo", undobtnx, dy + 4, undobtnsize, undobtnsize, false, icons.UNDO, null, (history_pos = history_amount)))
			action_toolbar_undo()
	}
}
