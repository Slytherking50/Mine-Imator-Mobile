/// view_toolbar_draw_touch(view, centerx, y)
/// @arg view
/// @arg centerx
/// @arg y

// Android-only touch reflow of view_toolbar_draw.gml (2026-09-15, explicit user request +
// reference screenshot: bigger labeled buttons in one horizontal bar, centered above the
// viewport, instead of desktop's 24px unlabeled icon strip pinned under the workbench at
// top-left - same §6.2 "32px -> 48dp mínimo" reasoning already applied to the joystick/gizmos,
// here for the tool switcher itself). Same settings, same click behavior, same button order as
// view_toolbar_draw.gml (including the setting_separate_tool_modes branch and its own button
// set/order) - only the layout changes. Global/Local space toggle from the reference image
// deliberately NOT included: it's a Community Build feature, not part of base Mine-imator
// (CLAUDE.md GATE G2/§9.4) - logged to IDEAS.md instead of built here.

function view_toolbar_draw_touch(view, centerx, yy)
{
	var btnsize, btnwidth, gap, labelh, pad, height, dividerw;
	btnsize = 40
	btnwidth = 60
	gap = 6
	labelh = 14
	pad = 8
	height = btnsize + labelh + 10
	dividerw = 1

	// Same button set/order as view_toolbar_draw.gml's two branches - "|" marks the divider
	// that branch draws with draw_divide() before its own non-separate-mode Scale button.
	// "multiselect" appended after its own divider (B38, 2026-09-16) - has no desktop
	// equivalent (view_toolbar_draw.gml doesn't get it), see touch_multiselect_active.gml.
	var buttons = setting_separate_tool_modes
		? ["select", "move", "rotate", "scale", "bend", "transform", "|", "multiselect"]
		: ["move", "rotate", "bend", "|", "scale", "|", "multiselect"];

	var count = array_length(buttons);
	var innerwidth = gap * (count - 1);
	for (var i = 0; i < count; i++)
		innerwidth += (buttons[i] == "|") ? dividerw : btnwidth

	var xx = centerx - innerwidth / 2;
	var boxx2 = xx - pad;
	var width = innerwidth + pad * 2;

	if (boxx2 + width < content_x || boxx2 > content_x + content_width || yy + height < content_y || yy > content_y + content_height)
	{
		view.toolbar_mouseon = bench_button_hover
		return 0
	}

	microani_prefix = string(view)

	if ((app_mouse_box(boxx2, yy, width, height) && !popup_mouseon && !toast_mouseon && !context_menu_mouseon && !(view_second.show && view_second.mouseon)) || bench_button_hover)
		view.toolbar_mouseon = true
	else
		view.toolbar_mouseon = false

	if (view.toolbar_mouseon)
		content_mouseon = true

	if (app_mouse_box(boxx2 - 64, yy - 64, width + 128, height + 128) && !popup_mouseon && !toast_mouseon && !context_menu_mouseon && !(view_second.show && view_second.mouseon))
		view.toolbar_alpha_goal = 1
	else
		view.toolbar_alpha_goal = .8

	// Fade fully out (not just dim to .8 like the desktop toolbar does) while the workbench
	// settings popup is open (2026-09-15, user report - screenshot showed a "Escalar" button
	// floating over the popup's character preview). Unlike the desktop toolbar's top-left
	// corner, this one is centered at the SAME y the popup opens at (bench_settings.posy =
	// benchy, view_draw.gml) and commonly overlaps it in x too - dimming to .8 wasn't enough
	// to read as "behind" a popup that's meant to be modal. Clicks were already safe either
	// way (content_mouseon already goes false under popup_mouseon), this only fixes the look.
	if (window_busy = "bench")
		view.toolbar_alpha_goal = 0

	draw_set_alpha(view.toolbar_alpha)

	draw_dropshadow(boxx2, yy, width, height, c_black, 1)
	draw_box(boxx2, yy, width, height, false, c_level_top, 1)
	draw_outline(boxx2, yy, width, height, 1, c_border, a_border, true)

	var bx, iconx, icony, active, name, icon, labelkey;
	bx = xx
	icony = yy + 5

	for (var i = 0; i < count; i++)
	{
		var entry = buttons[i];

		if (entry == "|")
		{
			draw_divide_vertical(bx, icony, btnsize)
			bx += dividerw + gap
			continue
		}

		active = false
		name = ""
		icon = 0
		labelkey = ""

		switch (entry)
		{
			case "select":
				active = setting_tool_select
				name = "viewtoolselect"
				icon = icons.SELECT
				labelkey = "viewtoolbarselect"
				break

			case "move":
				active = setting_tool_move
				name = "viewtoolmove"
				icon = icons.MOVE
				labelkey = "viewtoolbarmove"
				break

			case "rotate":
				active = setting_tool_rotate
				name = "viewtoolrotate"
				icon = icons.ROTATE
				labelkey = "viewtoolbarrotate"
				break

			case "scale":
				active = setting_tool_scale
				name = "viewtoolscale"
				icon = icons.SCALE
				labelkey = "viewtoolbarscale"
				break

			case "bend":
				active = setting_tool_bend
				name = "viewtoolbend"
				icon = icons.BEND
				labelkey = "viewtoolbarbend"
				break

			case "transform":
				active = setting_tool_transform
				name = "viewtooltransform"
				icon = icons.MULTITRANSFORM
				labelkey = "viewtoolbartransform"
				break

			case "multiselect":
				active = touch_multiselect
				name = "viewtoolmultiselect"
				icon = icons.BOX_SELECT
				labelkey = "viewtoolbarmultiselect"
				break
		}

		iconx = bx + (btnwidth - btnsize) / 2

		if (draw_button_icon(name, iconx, icony, btnsize, btnsize, active, icon))
		{
			switch (entry)
			{
				case "select":
					action_tools_disable_all()
					setting_tool_select = true
					break

				case "move":
					if (setting_separate_tool_modes)
					{
						action_tools_disable_all()
						setting_tool_move = true
					}
					else
					{
						setting_tool_move = !setting_tool_move
						setting_tool_scale = false
					}
					break

				case "rotate":
					if (setting_separate_tool_modes)
					{
						action_tools_disable_all()
						setting_tool_rotate = true
					}
					else
					{
						setting_tool_rotate = !setting_tool_rotate
						setting_tool_scale = false
					}
					break

				case "scale":
					if (setting_separate_tool_modes)
					{
						action_tools_disable_all()
						setting_tool_scale = true
					}
					else
					{
						setting_tool_scale = !setting_tool_scale

						if (setting_tool_scale)
						{
							setting_tool_move = false
							setting_tool_rotate = false
							setting_tool_bend = false
						}
					}
					break

				case "bend":
					if (setting_separate_tool_modes)
					{
						action_tools_disable_all()
						setting_tool_bend = true
					}
					else
					{
						setting_tool_bend = !setting_tool_bend
						setting_tool_scale = false
					}
					break

				case "transform":
					action_tools_disable_all()
					setting_tool_transform = true
					break

				case "multiselect":
					touch_multiselect = !touch_multiselect
					break
			}
		}

		draw_label(text_get(labelkey), bx + btnwidth / 2, icony + btnsize + 2, fa_center, fa_top, active ? c_accent : c_text_secondary, active ? 1 : a_text_secondary, font_caption)

		bx += btnwidth + gap
	}

	microani_prefix = ""
	draw_set_alpha(1)

	view.toolbar_height = height
}
