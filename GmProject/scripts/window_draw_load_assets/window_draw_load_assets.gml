/// window_draw_load_assets()

function window_draw_load_assets()
{
	if (!minecraft_assets_load())
	{
		error("errorloadassets")
		game_end()
		return 0
	}
	
	// Background
	draw_clear(c_level_top)
	
	if (load_assets_stage = "done")
	{
		load_assets_stage = "exit"
		return 0
	}
	else if (load_assets_stage = "exit")
	{
		window_state = "startup"
		app_startup_interface()
		
		// Deactivate instances for better performance
		instance_deactivate_object(obj_deactivate)
		
		return 0
	}
	
	// Custom Android loading screen (user-provided design, 2026-09-11 - Canva mockup): a
	// diagonal-seam layout with a rotating render on the left and the logo/credits/progress
	// text on the right, sized for a phone's wide landscape screen instead of reusing the
	// desktop's fixed 740x450 dialog below (which the Android branch further down only
	// STRETCHES to fill the screen - a different, older fix for the same "doesn't fit a
	// phone" problem, KI-1/KI-2, KNOWN_ISSUES.md). Fully separate code path, gated on
	// platform_get() so desktop's dialog-style screen (proven, used for years) is untouched.
	// load_assets_progress/app.setting_minecraft_assets_version ARE the real Minecraft-
	// asset-loading state (correct to read directly) - but the render image + its credit are
	// this screen's OWN system (android_load_render/_credit, app_startup_window.gml),
	// deliberately independent of load_assets_splash/load_assets_credits (the desktop
	// dialog's splash, picked at a different time by minecraft_assets_load_startup.gml for a
	// different screen - explicit user request, 2026-09-12: this screen shouldn't depend on
	// that). Logo is still spr_load_assets (explicitly called out as a placeholder by the
	// user - the mockup's own clapperboard icon is provisional and swappable later).
	if (platform_get() == e_platform.ANDROID)
	{
		var w, h, splitx1, splitx2, panelcx;
		w = window_width
		h = window_height

		// Data/LoadRenders/renders.json - a manifest of its own, separate from Data/Splashes/
		// splashes.json, though it currently points AT files still physically living in
		// Splashes/ (reusing the existing art/credits by reference costs zero extra APK size
		// - swap in dedicated new art later just by adding files + entries here, no code
		// change needed). Picked once, lazily, the first time this screen actually draws
		// (not at app_startup_window.gml's own init time - irandom() needs randomize() to
		// have already run, app_event_create.gml, which happens after that script).
		if (android_load_render == null)
		{
			if (file_exists_lib(load_renders_directory + "renders.json"))
			{
				var map, renderlist, picked;
				map = json_load(load_renders_directory + "renders.json")
				renderlist = map[?"renders"]
				picked = renderlist[|irandom(ds_list_size(renderlist) - 1)]

				if (file_exists_lib(data_directory + picked[?"file"]))
				{
					android_load_render = sprite_add(data_directory + picked[?"file"], 0, 0, 0, 0, 0)
					android_load_render_credit = picked[?"credit"]
				}

				ds_map_destroy(map)
			}
		}

		// This screen's own logo (2026-09-12 remake, replacing the placeholder
		// spr_load_assets clapperboard here only - desktop's dialog below still draws
		// spr_load_assets itself, untouched). sprite_add()'d sprites default to a top-left
		// origin (0,0), unlike spr_load_assets (a proper GameMaker sprite resource with a
		// centered origin baked in via its .yy) - the draw call below accounts for that
		// manually instead of assuming (panelcx, logoy) is already the sprite's center.
		if (android_load_logo == null && file_exists_lib(load_renders_directory + "logo.png"))
			android_load_logo = sprite_add(load_renders_directory + "logo.png", 0, 0, 0, 0, 0)

		content_x = 0
		content_y = 0
		content_width = w
		content_height = h

		// Seam between the render (left) and logo/credits (right) sides - slants so the
		// panel is NARROWER at the top and WIDER at the bottom, matching the reference
		// mockup (flipped 2026-09-12, third check against it - user: "el coso blanco...
		// tu lo colocaste al reves" - the previous pass had this backwards, wider at the
		// top instead).
		//
		// Widened 2026-09-12 (device screenshot, real font/render finally loading for the
		// first time - see data_directory_seed_android.gml fix same day): at the old 0.70/
		// 0.78 split the panel was only ~22-30% of screen width, not enough room for "Mine-
		// imator 2.0.2" and the credit line at the mockup's font size - both overflowed past
		// the panel on both sides. 0.52/0.60 roughly doubles the available width.
		splitx1 = w * 0.60
		splitx2 = w * 0.52

		// panelcx used to be anchored on max(splitx1, splitx2) - always the BOTTOM edge here,
		// since splitx2 > splitx1 - which is the panel's narrowest point. The logo/version/
		// credit text sits near the top (logoy = h*0.32), where the panel is wider, so
		// centering against the narrow bottom edge pushed the text too far right relative to
		// the actual (wider) panel there, spilling text off the LEFT edge onto the render
		// image - confirmed on device, 2026-09-12 (the "A" of "ART BY..." was cut off).
		// Interpolate the panel's real edge at the text block's own vertical middle instead.
		var textblock_y, splitx_text;
		textblock_y = h * 0.40
		splitx_text = lerp(splitx1, splitx2, textblock_y / h)
		panelcx = (splitx_text + w) / 2

		// Render, "cover"-fit (like CSS background-size:cover), full-bleed behind everything -
		// drawn as a single plain draw_sprite_ext(), same safe call desktop's own loading
		// screen uses below. The diagonal look comes entirely from the solid right panel
		// drawn ON TOP of it right after, not from clipping the image itself: texture-mapped
		// primitives (draw_vertex_texture_color + render_set_texture, tried first) need a
		// shader/render context (render_shader_obj, read by render_set_texture.gml) that
		// plain 2D screens don't have set up yet this early in the app's lifecycle -
		// confirmed root cause via precise log bisection on a real device, 2026-09-11
		// ("Invalid id 0 in Find:86" crashing inside render_set_texture() itself, before even
		// inspecting its texture argument, regardless of whether that argument was a raw
		// texture, a sprite id, or a surface id). Color-only primitives (draw_vertex_color,
		// used below for the panel/seam) don't touch render_set_texture at all and are
		// unaffected.
		if (android_load_render != null)
		{
			// sprite_add()'d sprites default to origin (0,0) - top-left, not centered - so
			// the draw position has to be the scaled image's own top-left corner, not the
			// screen center directly, or the whole image lands shifted down-right (confirmed
			// on a real device, 2026-09-11: only a small corner of the image was visible,
			// right where the top-left of a huge shifted image happened to peek out from
			// under the right panel).
			// Bilinear filtering, not this engine's default point/nearest filtering (kept
			// off elsewhere for Mine-imator's own crisp pixel-art UI) - this image gets
			// scaled up to 2-3x its native size to cover the screen (the renders are 550x450
			// stills, "cover"-fit onto a much bigger canvas), and at that much upscale point
			// filtering reads as chunky/blocky rather than just soft (user: "no este tan
			// pixel todo, mas liso"). Off again right after so nothing else on this screen
			// (or after it) is affected.
			var tw, th, imgscale;
			tw = sprite_get_width(android_load_render)
			th = sprite_get_height(android_load_render)
			imgscale = max(w / tw, h / th)
			gpu_set_tex_filter(true)
			draw_sprite_ext(android_load_render, 0, (w - tw * imgscale) / 2, (h - th * imgscale) / 2, imgscale, imgscale, 0, c_white, 1)
			gpu_set_tex_filter(false)
		}
		else
			draw_box(0, 0, w, h, false, c_level_top, 1)

		// Right panel, diagonal-edged solid color, drawn over the image above - this is
		// what actually gives the screen its diagonal look.
		draw_primitive_begin(pr_trianglestrip)
		draw_vertex_color(splitx1, 0, c_level_bottom, 1)
		draw_vertex_color(w, 0, c_level_bottom, 1)
		draw_vertex_color(splitx2, h, c_level_bottom, 1)
		draw_vertex_color(w, h, c_level_bottom, 1)
		draw_primitive_end()

		// Accent seam line along the diagonal
		var seamw = 6;
		draw_primitive_begin(pr_trianglestrip)
		draw_vertex_color(splitx1 - seamw, 0, c_accent, 1)
		draw_vertex_color(splitx1, 0, c_accent, 1)
		draw_vertex_color(splitx2 - seamw, h, c_accent, 1)
		draw_vertex_color(splitx2, h, c_accent, 1)
		draw_primitive_end()

		// Logo + "BY:"/credit + "LOADiNG ASSETS"/version/percent, centered in the right
		// panel - rebuilt 2026-09-12 against the actual Canva reference the user finally
		// resent (the earlier passes were built from a text description of it, not the
		// image itself, and drifted: an extra "Mine-imator X.X.X" line that isn't in the
		// reference at all, a small logo, and progress text in the wrong slot). The
		// reference's stack, top to bottom: big logo, "BY:" (accent green), author name,
		// "LOADiNG ASSETS" + version number (version in accent green), then the percent
		// on its own line. No app-version line anywhere in it.
		//
		// "LOADiNG ASSETS <version>" used to be ONE line - too wide for the panel at this
		// font size (confirmed: the combined string ran past the screen's right edge,
		// user: "loading queda un poco fuera del cuadro"). Split into 3 short stacked
		// lines instead (label / version / percent), each comfortably inside the panel on
		// its own, rather than trying to cram everything into one wide centered line.
		// Logo size and line spacing used to be chosen against an assumed w/h of ~1650x720
		// (this screen's own physical pixel dimensions, from the reference mockup and every
		// screenshot taken of it) - but window_width/window_height are LOGICAL units, which
		// on this device came back as 1000x436 (confirmed via a temporary debug log(),
		// removed after use), not the physical 1650x720 - App->scale (1.65 here,
		// interface_scale_default_get()'s Android branch, B27/B29) sits between the two. A
		// fixed pixel value (a gap, a line height) written against the wrong 720-tall mental
		// model ends up 1.65x bigger on screen than intended once multiplied through - that
		// gap compounded over 5 stacked text lines is exactly what pushed the percent line
		// down into the progress bar and made the whole stack read "misplaced" against the
		// reference. Fixed by budgeting the real height explicitly instead of guessing: pick
		// line spacing first (close to the font's own 32px so lines don't touch), then give
		// the logo whatever vertical room is left over, capped by panel width too so it
		// can't outgrow the seam.
		// 4 lines now (BY, credit, "LOADiNG ASSETS <version>" combined, percent) - the user
		// resent the reference a second time to settle this: version sits on the SAME line
		// as "LOADiNG ASSETS", and percent is right-aligned under it on its own line below,
		// not a 3rd standalone line. Re-combining frees a whole line's worth of height
		// budget back for the logo too.
		// Margins/gaps tightened 2026-09-12 (user: "el by subelo un poco mas", "el logo hazlo
		// grande") - topmargin/botmargin/gap_logo all shrunk, which both pulls BY closer to
		// the logo AND frees more height budget for the logo itself (still fits by the same
		// construction as before - see the layout-budget comment above).
		var logoy, logoscale, panelw, lineh, contenty, topmargin, botmargin, gap_logo, gap_group, gap_pct, textstack_h, logo_budget_h, pctscale, pctlineh;
		panelw = w - max(splitx1, splitx2)
		lineh = 34
		topmargin = 10
		botmargin = 10
		gap_logo = 4
		gap_group = 10
		gap_pct = 8

		// The percent line renders at pctscale (1.35x the other lines' font size, see below) -
		// budgeting it at the same flat lineh as the other 3 lines left it ~9px taller than its
		// reserved slot, pushing it (and the progress bar right under it) past the bottom edge
		// (user: "el porcentaje y el numero se sale de la pantalla").
		pctscale = 1.35
		pctlineh = lineh * pctscale
		textstack_h = lineh * 3 + pctlineh + gap_logo + gap_group + gap_pct
		logo_budget_h = h - topmargin - botmargin - textstack_h

		// Prefer the new remade logo (android_load_logo, loaded above) once it's ready,
		// falling back to the shared placeholder spr_load_assets until then/if the file is
		// ever missing. sprite_add()'d sprites default to a top-left origin, unlike
		// spr_load_assets's own centered one - drawn from its own top-left corner instead
		// of assuming (panelcx, logoy) is already its center, same fix as android_load_render
		// needed above for the same reason.
		var logosprite, logow, logoh;
		logosprite = (android_load_logo != null) ? android_load_logo : spr_load_assets;
		logow = sprite_get_width(logosprite)
		logoh = sprite_get_height(logosprite)

		logoscale = min((panelw * 0.75) / logow, logo_budget_h / logoh)
		logoy = topmargin + (logoh * logoscale) / 2

		// Bilinear filtering here too (user: "y un poco el logo" - also a bit the logo,
		// same "no tan pixel" note as the render above) - the new logo art is a 500x500
		// source scaled DOWN to fit its budgeted height, and point filtering (this engine's
		// default) aliases fine diagonal edges on a downscale just as visibly as it blocks
		// up an upscale.
		gpu_set_tex_filter(true)
		if (android_load_logo != null)
			draw_sprite_ext(logosprite, 0, panelcx - (logow * logoscale) / 2, logoy - (logoh * logoscale) / 2, logoscale, logoscale, 0, c_white, 1)
		else
			draw_sprite_ext(logosprite, 0, panelcx, logoy, logoscale, logoscale, 0, c_white, 1)
		gpu_set_tex_filter(false)

		contenty = logoy + (logoh * logoscale) / 2 + gap_logo

		// "BY:" - the colon is drawn as 2 small manual squares, same reasoning as the
		// version's dots below: this font's ":" hits the same FreeType 0-width-bitmap skip
		// (Font.cpp:289) as "." and "-", confirmed missing on device just like the others.
		var byt, byw, bycolonw, byx, colonsize;
		byt = "BY"
		draw_set_font(font_loadscreen_pixel)
		byw = string_width(byt)
		colonsize = 5
		bycolonw = byw + 5 + colonsize
		byx = panelcx - bycolonw / 2

		draw_label(byt, byx, contenty, fa_left, fa_top, c_accent, 1, font_loadscreen_pixel)
		draw_box(byx + byw + 5, contenty + 6, colonsize, colonsize, false, c_accent, 1)
		draw_box(byx + byw + 5, contenty + 18, colonsize, colonsize, false, c_accent, 1)

		if (android_load_render_credit != "")
			draw_label(android_load_render_credit, panelcx, contenty + lineh, fa_center, fa_top, c_text_secondary, a_text_secondary, font_loadscreen_pixel)

		// "LOADiNG ASSETS " (white) + Minecraft asset version (accent green), one line -
		// the two colors drawn as separate draw_label calls side by side (draw_label has no
		// rich-text/multi-color support), the whole unit centered via string_width. Fits
		// now that the panel's real logical width is known (400 units here, not the ~660
		// this line was wrongly designed against before window_width/height turned out to
		// be logical 1000x436, not physical 1650x720 - see the layout-budget comment above).
		//
		// The version's periods are drawn as small manual squares, not the font's own "."
		// glyph: confirmed on device (24px AND 32px, zoomed 6x on an actual screenshot,
		// zero ink either time) that CppProject/Asset/Font.cpp:289 silently skips drawing
		// any glyph whose FreeType-rasterized bitmap comes back 0-width - this font's "."
		// hits that path at both sizes tested, so it renders as an invisible gap (the
		// character's ADVANCE width is still reserved, just nothing is drawn there) rather
		// than erroring. Root cause is inside Font.cpp itself (shared with desktop, not an
		// Android-only bug) - not something to fix from GML, so worked around here instead.
		var line3y, loadingtext, versionparts, dotsize, dash, totalwidth, drawx, baseline, line3_right;
		line3y = contenty + lineh * 2 + gap_group
		loadingtext = "LOADiNG ASSETS "
		versionparts = string_split(app.setting_minecraft_assets_version, ".")
		dotsize = 5
		dash = 4
		baseline = line3y + 25

		draw_set_font(font_loadscreen_pixel)
		totalwidth = string_width(loadingtext)
		for (var i = 0; i < array_length(versionparts); i++)
		{
			totalwidth += string_width(versionparts[i])
			if (i < array_length(versionparts) - 1)
				totalwidth += dotsize + dash * 2
		}

		// Centered on this line's OWN local panel center, not the shared panelcx (computed
		// once at textblock_y=h*0.40 for the logo/BY/credit block above it) - a fixed "+10"
		// nudge here was a band-aid for the old diagonal direction and broke again the
		// moment the diagonal flipped (user: "loading se vuelve a salir un poco, tirala un
		// poquito a la derecha"). Interpolating the real edge at this line's actual y is
		// correct regardless of which way the seam slants or how far down this line sits.
		var line3_splitx, line3_panelcx;
		line3_splitx = lerp(splitx1, splitx2, line3y / h)
		line3_panelcx = (line3_splitx + w) / 2

		drawx = line3_panelcx - totalwidth / 2
		line3_right = drawx + totalwidth

		draw_label(loadingtext, drawx, line3y, fa_left, fa_top, c_text_secondary, a_text_secondary, font_loadscreen_pixel)
		drawx += string_width(loadingtext)

		for (var i = 0; i < array_length(versionparts); i++)
		{
			draw_label(versionparts[i], drawx, line3y, fa_left, fa_top, c_accent, 1, font_loadscreen_pixel)
			drawx += string_width(versionparts[i])

			if (i < array_length(versionparts) - 1)
			{
				drawx += dash
				draw_box(drawx, baseline, dotsize, dotsize, false, c_accent, 1)
				drawx += dotsize + dash
			}
		}

		// Percent, right-aligned to line 3's own right edge (matches the reference: "X%"
		// tucked under the tail end of the version number above it, not centered on the
		// panel). The manual "%" itself got bigger, more distinct eye squares this round
		// (6px, was 5) against the diagonal's step squares (4px, unchanged) - user: the
		// previous attempt's circle-ends "casi no se distinguen del trazo del medio".
		// Number + "%" both bigger 2026-09-12 (user: "el numero y el % estan un poco mas
		// grande") - font_loadscreen_pixel is one fixed size (32) shared with every other
		// label on this screen, so scaling just this line uses draw_text_transformed
		// (xscale/yscale) instead of a second font resource. The manual "%" glyph's own
		// coordinates scale by the same factor so it stays proportional to the number.
		var percenty, percenttext, pctw, pctgap, eyeradius, totalpctwidth, pctnumwidth, numy;
		percenty = line3y + lineh + gap_pct
		percenttext = string(floor(load_assets_progress * 100))
		pctw = 18 * pctscale
		pctgap = 6 * pctscale
		eyeradius = 3.5 * pctscale

		draw_set_font(font_loadscreen_pixel)
		pctnumwidth = string_width(percenttext) * pctscale
		totalpctwidth = pctnumwidth + pctgap + pctw
		drawx = line3_right - totalpctwidth

		// The number renders noticeably taller (pctscale of a 32px font) than the compact "%"
		// glyph next to it (a fixed ~22*pctscale design height, see below) - top-aligning both
		// at the same percenty left the number hanging visibly lower than the "%", instead of
		// sitting next to it (user: "sube el numero para que quede al lado del porcentaje").
		// Raise the number so its own vertical center lines up with the "%" symbol's center
		// (percenty + 11*pctscale) instead.
		numy = percenty - 5 * pctscale

		draw_set_halign(fa_left)
		draw_set_valign(fa_top)
		draw_set_color(c_text_secondary)
		draw_set_alpha(a_text_secondary)
		draw_text_transformed(drawx, numy, percenttext, pctscale, pctscale, 0)
		draw_set_color(c_white)
		draw_set_alpha(1)
		drawx += pctnumwidth + pctgap

		// "%" rebuilt as two filled circles joined by a line, not the earlier blocky
		// squares (user: "no este tan pixel todo, mas liso" + "el 40% se ve mal" - both the
		// shape and the general pixel-block look were the complaint). draw_circle_ext's
		// detail parameter (12 here) controls smoothness directly, unlike a square which
		// has no smooth version at any size.
		var pctbottomy, pcttopy;
		pctbottomy = percenty + 22 * pctscale - eyeradius
		pcttopy = percenty + eyeradius

		draw_set_color(c_text_secondary)
		draw_set_alpha(a_text_secondary)
		draw_line_width(drawx + eyeradius, pctbottomy, drawx + pctw - eyeradius, pcttopy, 2)
		draw_set_alpha(1)

		draw_circle_ext(drawx + eyeradius, pctbottomy, eyeradius, false, 12, c_text_secondary, a_text_secondary)
		draw_circle_ext(drawx + pctw - eyeradius, pcttopy, eyeradius, false, 12, c_text_secondary, a_text_secondary)

		// Progress bar, full width - same fill mechanic as the desktop version below
		draw_box(0, h - 8, w, 8, false, c_level_top, 1)
		draw_box(0, h - 8, w * load_assets_progress, 8, false, c_accent, 1)

		current_step++
		return 0
	}

	// Stretch the fixed 740x450 desktop dialog to fill the real window instead of
	// floating small in the middle with empty space around it - a phone has no
	// small-floating-window concept to center this box against in the first place
	// (explicit user request, 2026-09-09: "que ocupe todo el espacio", "se vea la barra
	// de proceso"). Non-uniform (independent x/y factors) since the goal is filling the
	// screen, not preserving the desktop box's 740:450 aspect ratio. On desktop this is a
	// no-op: window_set_size() actually shrinks the real window to 740x450
	// (AppWindow::UpdateSize()), so scale_x/scale_y are always 1 there.
	//
	// box_w/box_h overscan window_width/window_height by a small margin - only on the TOP
	// and LEFT edges (xoff/yoff go negative; the right and bottom edges stay exactly at
	// window_width/window_height, where they already read correctly) - because that's
	// specifically where a thin black/gray gap showed up on a real device (2026-09-09),
	// not desktop behaviour: window_get_width()/height() came back a little short of the
	// true visible screen even with the status bar hidden via showFullScreen(). Fixing
	// that by forcing the native window's own geometry (AppHandler.cpp) backfired badly
	// (MIUI reinterpreted it as a floating-window request instead of true fullscreen,
	// reverted). Overscanning the drawing itself, instead, doesn't touch any window/
	// native state.
	//
	// GML has no platform check without a new gml.json entry (G3 gate) - gated instead on
	// whether we're actually in the stretched regime (scale_x/scale_y already far above
	// 1, only possible when window_set_size() did NOT shrink the real window, i.e.
	// Android). True no-op on desktop, where window_set_size() really does shrink the
	// window to 740x450 and these first scale_x/scale_y come back at ~1.
	var scale_x, scale_y, xoff, yoff, box_w, box_h;
	scale_x = window_width / 740
	scale_y = window_height / 450
	box_w = (scale_x > 1.5 ? window_width * 1.06 : window_width)
	box_h = (scale_y > 1.5 ? window_height * 1.06 : window_height)
	xoff = window_width - box_w
	yoff = window_height - box_h
	scale_x = box_w / 740
	scale_y = box_h / 450

	content_x = xoff + 28 * scale_x
	content_y = yoff + 28 * scale_y
	content_width = box_w - 56 * scale_x
	content_height = box_h - 56 * scale_y

	draw_box(xoff, yoff, box_w, box_h, false, c_level_middle, 1)

	// Pattern
	var pattern = (setting_theme = theme_light ? 0 : 1);
	draw_sprite_ext(spr_pattern_left, pattern, xoff, yoff, (138 * scale_x) / sprite_get_width(spr_pattern_left), box_h / sprite_get_height(spr_pattern_left), 0, c_white, 1)

	draw_sprite_ext(spr_load_assets, 0, xoff + 95 * scale_x, yoff + 207 * scale_y, scale_x, scale_y, 0, c_white, 1)

	draw_label("Mine-imator " + string(mineimator_version), xoff + 95 * scale_x, yoff + 289 * scale_y, fa_middle, fa_bottom, c_text_secondary, a_text_secondary, font_heading)
	draw_label(string(string_upper(mineimator_version_sub)), xoff + 95 * scale_x, yoff + (289 + 12) * scale_y, fa_middle, fa_bottom, c_text_secondary, a_text_secondary, font_subheading)
	draw_label(string(string_upper(mineimator_version_extra)), xoff + 95 * scale_x, yoff + (289 + (mineimator_version_sub = "" ? 16 : 26)) * scale_y, fa_middle, fa_bottom, c_text_tertiary, a_text_tertiary, font_subheading)
	draw_label(text_get("startuploadingassets", app.setting_minecraft_assets_version, floor(load_assets_progress * 100)), xoff + 95 * scale_x, yoff + 437 * scale_y, fa_middle, fa_bottom, c_text_tertiary, a_text_tertiary, font_caption)

	// Splash
	if (load_assets_splash != null)
		draw_sprite_ext(load_assets_splash, 0, xoff + 190 * scale_x, yoff, scale_x, scale_y, 0, c_white, 1)
	else
		draw_box(xoff + 190 * scale_x, yoff, 550 * scale_x, box_h, false, c_level_bottom, 1)

	if (load_assets_splash = null || sprite_get_width(load_assets_splash) = 550)
		draw_gradient(xoff + 190 * scale_x, yoff, shadow_size * scale_x, box_h, c_black, shadow_alpha, 0, 0, shadow_alpha)

	// Splash credits
	if (load_assets_credits != "")
		draw_label(text_get("startupsplashauthor", load_assets_credits), xoff + 95 * scale_x, yoff + (289 + 31) * scale_y, fa_middle, fa_top, c_text_tertiary, a_text_tertiary, font_caption)

	draw_box(xoff, yoff + box_h - 8 * scale_y, box_w, 8 * scale_y, false, c_level_top, .8)
	draw_box(xoff, yoff + box_h - 8 * scale_y, box_w * load_assets_progress, 8 * scale_y, false, c_accent, 1)

	draw_outline(xoff, yoff, box_w, box_h, 1, c_border, a_border, true)
	draw_dropshadow(xoff, yoff, box_w, box_h, c_black, 1)

	current_step++
}
