/// popup_folder_picker_draw()
/// @desc Android-only replacement for "Cambiar carpeta" (Fase 5/B37) - desktop's version reuses
/// the save-file dialog as a folder picker (a trick with no SAF equivalent, see
/// popup_saveas_draw.gml's comment). This browses real subfolders of `working_directory` using
/// directory_find() (2026-09-16) instead of any content:// picker, so it stays plain filesystem
/// paths end to end - no rewrite of setting_project_folder's real-path callers needed.

function popup_folder_picker_draw()
{
	// (Re)scan the current directory only when it actually changed, not every frame.
	if (popup.path_scanned != popup.path)
	{
		popup.entries = directory_find(popup.path)
		popup.scroll.value = 0
		popup.scroll.value_goal = 0
		popup.path_scanned = popup.path
	}

	// Current location
	var shown = string_replace(popup.path, working_directory, "/");

	tab_control(24)
	tip_wrap = false
	tip_set(string_remove_newline(popup.path), dx, dy, dw - 28, 24)
	tip_wrap = true
	draw_label(string_limit(shown, dw - 28), dx, dy + 12, fa_left, fa_middle, c_text_secondary, a_text_secondary)
	if (draw_button_icon("folderpickerup", dx + dw - 24, dy, 24, 24, false, icons.ARROW_UP, null, (popup.path = working_directory), "folderpickerup"))
	{
		// filename_dir() on a trailing-slash path only strips that slash (same level) -
		// calling it twice is what actually reaches the parent (QFileInfo(...).path()
		// semantics, same helper FileFunc.cpp's other filename_* wrappers use).
		popup.path = filename_dir(filename_dir(popup.path)) + "/"
	}
	tab_next()

	// Subfolder list (fixed area + scroll, same pattern as draw_recent's "list" mode)
	var listh = 168;

	tab_control(listh)
	draw_outline(dx, dy, dw, listh, 1, c_border, a_border, true)

	if (array_length(popup.entries) = 0)
	{
		draw_set_font(font_label)
		draw_label(text_get("folderpickerempty"), dx + dw / 2, dy + listh / 2, fa_center, fa_middle, c_text_secondary, a_text_secondary)
	}
	else
	{
		var roww, itemh, liststart, listyy;
		itemh = 40
		roww = dw
		liststart = 0
		listyy = dy

		if (array_length(popup.entries) * itemh > listh)
		{
			window_scroll_focus = string(popup.scroll)
			scrollbar_draw(popup.scroll, e_scroll.VERTICAL, dx + dw - 12, dy, listh, array_length(popup.entries) * itemh)
			liststart = snap(popup.scroll.value / itemh, 1)
			roww -= 12
		}

		clip_begin(dx, dy, dw, listh)

		var rowy = listyy - (popup.scroll.needed ? (popup.scroll.value - liststart * itemh) : 0);

		for (var i = liststart; i < array_length(popup.entries); i++)
		{
			if (rowy + itemh > dy + listh)
				break

			var mouseon = app_mouse_box(dx, rowy, roww, itemh) && content_mouseon;

			microani_set("folderpickeritem" + string(i), null, mouseon, mouseon && mouse_left, false)
			draw_box(dx, rowy, roww, itemh, false, c_overlay, a_overlay * microani_arr[e_microani.HOVER])
			draw_box_hover(dx, rowy, roww, itemh, microani_arr[e_microani.HOVER])
			draw_box(dx, rowy, roww, itemh, false, c_accent_overlay, a_accent_overlay * microani_arr[e_microani.PRESS])
			microani_update(mouseon, mouseon && mouse_left, false)

			draw_image(spr_icons, icons.FOLDER, dx + 12, rowy + itemh / 2, 1, 1, c_text_secondary, a_text_secondary)
			draw_set_font(font_value)
			draw_label(string_limit(popup.entries[i], roww - 44), dx + 36, rowy + itemh / 2, fa_left, fa_middle, c_text_main, a_text_main)

			if (mouseon)
			{
				mouse_cursor = cr_handpoint
				if (mouse_left_released)
				{
					popup.path += popup.entries[i] + "/"
					app_mouse_clear()
					break
				}
			}

			rowy += itemh
		}

		clip_end()
	}
	tab_next()

	// New folder - only created on the explicit button tap below, never from
	// draw_textfield()'s own return value (that fires on every keystroke, not on submit -
	// confirmed by reading draw_inputbox.gml, which has no Enter-key handling of its own).
	tab_control_textfield(true)
	draw_textfield("folderpickernewname", dx, dy, dw - 32, ui_touch_textfield_height, popup.tbx_newfolder, null, text_get("folderpickernewfolder"), "none")
	if (draw_button_icon("folderpickernewfolderadd", dx + dw - 24, dy, 24, 24, false, icons.FOLDER_ADD, null, (popup.tbx_newfolder.text = ""), "folderpickernewfolder"))
	{
		var newname = filename_get_valid(popup.tbx_newfolder.text);
		if (newname != "" && directory_create_lib(popup.path + newname + "/"))
		{
			popup.tbx_newfolder.text = ""
			popup.path += newname + "/"
		}
	}
	tab_next()

	// Confirm
	tab_control_button_label()
	if (draw_button_label("folderpickerselect", dx + dw, dy, null, null, e_button.PRIMARY, null, e_anchor.RIGHT))
	{
		action_setting_project_folder(popup.path)
		popup_switch(popup_switch_from)
	}
	tab_next()
}
