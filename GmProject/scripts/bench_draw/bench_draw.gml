/// bench_draw()

function bench_draw()
{
	if (bench_show_ani_type = "" && bench_show_ani = 0)
		return 0
	
	var func, ani;
	var sdx, sdy, ymax;
	
	// Animate
	func = ""
	if (bench_show_ani_type = "show")
	{
		bench_show_ani = test_reduced_motion(1, min(1, bench_show_ani + 0.1 * delta))
		if (bench_show_ani = 1)
			bench_show_ani_type = ""
		func = "easeoutcirc"
	}
	else if (bench_show_ani_type = "hide")
	{
		bench_show_ani = test_reduced_motion(0, max(0, bench_show_ani - 0.1 * delta))
		if (bench_show_ani = 0)
			bench_show_ani_type = ""
		func = "easeincirc"
	}
	
	if (bench_show_ani = 0)
	{
		if (window_busy = "bench")
			window_busy = ""
		
		bench_settings.height = 0
		bench_settings.height_goal = bench_height
		return 0
	}
	else
		bench_settings.height = bench_settings.height_goal;//(bench_settings.height_goal - bench_settings.height) / max(1, 3 / delta)
	
	if (window_busy = "bench")
		window_busy = ""
	
	ani = ease(func, bench_show_ani)
	content_x = bench_settings.posx - (8 - (8 * ani))
	content_y = bench_settings.posy
	// content_width can't just stay a flat 534 on Android like it always has on desktop.
	// Desktop's App->scale resizes the real OS window along with it (AppWindow.cpp,
	// #ifndef Q_OS_ANDROID), so the LOGICAL canvas (window size / scale) stays put no matter
	// what scale desktop users pick - 534 has always been a safe, constant fraction of it.
	// Android is fullscreen at a fixed physical resolution, so raising interface_scale only
	// shrinks the logical canvas (GLWidget.cpp composites logical*scale back up to fill the
	// same physical screen) - bumping the Android default to 1.5 (interface_scale_default_get,
	// UtilFunc.cpp - beta tester report, "la UI se ve chica") shrunk that canvas by a third,
	// and this fixed-534 popup went from a comfortable ~27% of it to ~40%, overlapping the
	// timeline transport bar below and crowding the properties panel on the right (screenshot,
	// 2026-09-11). Dividing by setting_interface_scale keeps its PHYSICAL on-screen footprint
	// exactly what it was before that bump, self-correcting for whatever scale ends up applied
	// (auto-detected or the user's own manual override in Settings) instead of a magic number
	// tied to today's 1.5. True no-op on desktop (scale-vs-window-size cancel out there anyway).
	// 534 became 660 on Android (2026-09-15, user report: right column - search box + name
	// list - looked disproportionately cramped). The category list at left is a FIXED 192
	// regardless of platform (touch-target width, deliberately not shrunk with the rest) - on
	// desktop that's a comfortable 36% of 534, but on Android's already-scaled-down 534/1.65
	// ≈ 324 canvas it ate 59%, squeezing the right column to ~108 logical px. 660/1.65 ≈ 400
	// keeps the category list back down to a saner ~48% share (right column ~184px, was ~108)
	// without touching its own fixed width and re-truncating its longer labels ("Modelo
	// personalizado"). Still self-corrects for whatever scale ends up applied, same as before.
	content_width = (platform_get() == e_platform.ANDROID) ? (660 / setting_interface_scale) : 534
	content_height = bench_settings.height
	content_mouseon = !popup_mouseon
	
	dx = content_x
	dy = content_y
	dw = content_width
	dh = content_height
	
	// Hide bench
	if (!app_mouse_box(content_x, content_y, content_width, content_height) && mouse_left_pressed && window_busy = "") 
	{
		bench_show_ani_type = "hide"
		window_focus = ""
		
		app_mouse_clear()
	}
	
	draw_set_alpha(ani)
	draw_dropshadow(content_x, content_y, content_width, content_height, c_black, 1)
	draw_box(content_x, content_y, content_width, content_height, false, c_level_top, 1)
	draw_outline(content_x, content_y, content_width, content_height, 1, c_border, a_border, true)
	
	clip_begin(content_x - 4, content_y - 4, content_width + 8, content_height + 8)
	
	// Draw workbench
	sdx = dx
	sdy = dy
	
	dy += 8
	
	// Left, asset types
	var types, divides, lefth, skipasset, typerowh;
	types = 13
	divides = 4
	// This is a dense 13-row list, not a single control - the general Android decision to
	// force full-size (32) rows everywhere (app_update_interface.gml, so buttons/fields stay
	// tappable) doesn't fit here: 13 full rows plus the settings panel next to them can't fit
	// any phone screen's height, full-size or not. Treated the same as window_compact already
	// is on desktop (compact trades row height for density on purpose) rather than the
	// touch-target sizing rest of Fase 3 uses - same tradeoff sortlist_draw.gml's own item
	// rows already make (ui_small_height, not ui_large_height) for the same reason.
	typerowh = (window_compact || platform_get() == e_platform.ANDROID) ? 28 : 32
	lefth = (types * typerowh) + (divides * 9)
	for (var i = 0; i < ds_list_size(bench_type_list.item); i++)
	{
		skipasset = false

		if (!setting_advanced_mode)
		{
			if (bench_type_list.item[|i].name = "typemodel" || bench_type_list.item[|i].name = "typebackground")
				skipasset = true
		}

		if (!skipasset)
		{
			list_item_draw(bench_type_list.item[|i], dx, dy, 192, typerowh, (bench_settings.type = bench_type_list.item[|i].value), 0, 5)
			dy += typerowh
		}
		
		if (i = 2 || i = 6 || i = 9)
		{
			draw_divide(dx + 5, dy + 4, 184)
			dy += 9
		}
	}
	dy += 8
	
	ymax = dy
	
	dy = sdy + 12
	dx += 192 + 12
	dw = (content_width - 192) - 24
	
	bench_draw_settings(dx, dy, dw, dh)
	
	ymax = max(dy, ymax)
	dy = ymax
	
	draw_divide_vertical(sdx + 193, sdy, bench_settings.height)
	bench_settings.height_goal = dy - sdy

	// This popup has never had a height cap - it grows to fit whatever the selected type needs
	// (a Character with material maps stacks preview+sortlist+states+3 texture buttons, easily
	// 400+px) with no scroll to reach the rest. Desktop windows are tall enough that this never
	// mattered; on a phone in landscape it doesn't fit, and the trailing "Add" button
	// (bench_draw_settings.gml, anchored at `sy + dh - 56`, i.e. the BOTTOM of this exact
	// height) ends up positioned past the visible/usable screen - reported as "los botones de
	// agregar no aparecen" (2026-09-11), not something the content_width fix above caused,
	// just a latent bug the phone's small screen exposes. Real fix is scrolling the middle
	// content; that's a bigger feature than this pass - capping height instead so the Add
	// button is always reachable, at the cost of clipping some content above it when a type
	// has a lot of options (KNOWN_ISSUES.md, filed as follow-up). No-op on desktop, where the
	// window has always had enough room.
	if (platform_get() == e_platform.ANDROID)
		bench_settings.height_goal = min(bench_settings.height_goal, window_height - bench_settings.posy - 16)

	clip_end()
	draw_set_alpha(1)
	
	if (window_busy = "" && bench_show_ani_type != "hide")
		window_busy = "bench"
}
