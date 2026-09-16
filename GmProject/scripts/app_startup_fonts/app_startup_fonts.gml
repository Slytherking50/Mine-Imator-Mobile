/// app_startup_fonts()

function app_startup_fonts()
{
	font_subheading = font_add(fonts_directory + "rubik_medium.ttf", 8.5, false, false, 32, 1024)
	font_label = font_add(fonts_directory + "noto_bold.ttf", 9, false, false, 32, 1024)
	font_value = font_add(fonts_directory + "noto_regular.ttf", 9, false, false, 32, 1024)
	font_digits = font_add(fonts_directory + "notomono_regular.ttf", 9, false, false, 32, 1024)
	font_caption = font_add(fonts_directory + "noto_regular.ttf", 8, false, false, 32, 1024)
	font_button = font_add(fonts_directory + "rubik_medium.ttf", 9.5, false, false, 32, 1024)
	
	// Special-case fonts
	font_upgrade = font_add(fonts_directory + "noto_regular.ttf", 18, false, false, 32, 1024)
	font_heading = font_add(fonts_directory + "rubik_medium.ttf", 10, false, false, 32, 1024)
	font_body_big = font_add(fonts_directory + "noto_regular.ttf", 12, false, false, 32, 1024)
	font_heading_big = font_add(fonts_directory + "rubik_medium.ttf", 13, false, false, 32, 1024)

	// Android-only custom loading screen (window_draw_load_assets.gml, 2026-09-11 reference
	// mockup) - "8-bit Arcade" by Ansimuz/daaams (Data/Fonts/8bit_arcade_LICENSE.txt: "100%
	// free, personal and commercial", the exact font named in the reference, not a
	// substitute). Created here unconditionally like every other font above (harmless,
	// negligible cost on desktop even though nothing there uses it) rather than gating font
	// creation itself on platform_get() - keeps this file's existing pattern of "just list
	// every font" instead of adding the first platform branch to it.
	//
	// Size bumped 24->32, 2026-09-12: at 24px, "." and "-" rendered as invisible gaps on
	// device ("Mine-imator 2.0.2" read as "MINEIMATOR 202"). Root-caused by reading
	// CppProject/Asset/Font.cpp:289 - RenderText() silently skips any glyph whose FreeType-
	// rasterized bitmap comes back with width 0, no fallback box. Confirmed with Windows'
	// own GDI+ renderer that this font DOES define ink for "." and "-" (PrivateFontCollection
	// test, both chars produced visible pixels) - so the glyph data exists, but FreeType's
	// specific rasterizer/hinting at this exact point size apparently rounds this font's
	// very small period/hyphen marks down to a 0px-wide bitmap, a font+size-specific FreeType
	// quirk, not a missing-glyph problem. A bigger point size gives the rasterizer more
	// sub-pixel room before that rounding kicks in.
	font_loadscreen_pixel = font_add(fonts_directory + "8bit_arcade_in.ttf", 32, false, false, 32, 1024)
}
