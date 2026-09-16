/// data_directory_seed_android()
// Seeds data_directory (a real, writable directory on Android too - see macros.gml) from the
// bundled Qt resource copy of GmProject/datafiles/Data, on first run and whenever
// DATA_BUNDLE_VERSION changes. No-op on every other platform.
//
// data_directory is NOT pointed straight at an immutable ":/Data/" resource path because two
// real files under it get written to at runtime: language_add.gml (importing a custom
// language) and app_event_http.gml (installing a downloaded Minecraft asset version).
// Confirmed by grep before choosing this design, not assumed.
//
// Verified by size, not just existence, so a truncated/corrupt copy gets redone.
// DATA_BUNDLE_VERSION forces a full re-copy on app update even if a file's size happens to
// match - bump it whenever GmProject/datafiles/Data's bundled contents change.
//
// Maintenance: DATA_BUNDLE_FILES must be kept in sync by hand with the Android .qrc entries
// in CMakeLists.txt (ASSET_RESOURCE_ENTRIES). Data/Libraries and Data/Minecraft are excluded
// on purpose - see CMakeLists.txt and KNOWN_ISSUES.md for why - except Minecraft/Game Base.
// midata and .zip (KNOWN_ISSUES.md B25, renamed from "placeholder" 2026-09-11), a from-scratch
// fallback resource pack so the app has something to load when no real Minecraft version is
// present yet (otherwise app_startup() fails outright, not just "no blocks").

function data_directory_seed_android()
{
	if (platform_get() != e_platform.ANDROID)
		return true

	directory_create_lib(data_directory)
	directory_create_lib(fonts_directory)
	directory_create_lib(languages_directory)
	directory_create_lib(render_directory)
	directory_create_lib(splash_directory)
	directory_create_lib(minecraft_directory)
	directory_create_lib(load_renders_directory)

	var DATA_BUNDLE_VERSION = 12;
	var DATA_BUNDLE_FILES = [
		"Fonts/noto_bold.ttf", "Fonts/noto_regular.ttf", "Fonts/noto_semibold.ttf",
		"Fonts/notomono_regular.ttf", "Fonts/rubik_bold.ttf", "Fonts/rubik_medium.ttf",
		"Fonts/8bit_arcade_in.ttf",
		"Languages/english.milanguage", "Languages/spanish_latam.milanguage",
		"LoadRenders/renders.json", "LoadRenders/logo.png",
		"Render/balanced.mirender", "Render/extreme.mirender", "Render/performance.mirender",
		"Splashes/apple.png", "Splashes/cave.png", "Splashes/dangerous_temple.png",
		"Splashes/deep_discovery.png", "Splashes/desert.png", "Splashes/disco.png",
		"Splashes/dolphins_grace.png", "Splashes/duality_of_noob.png", "Splashes/enderman.png",
		"Splashes/forest.png", "Splashes/hween.png", "Splashes/lush_cave.png",
		"Splashes/meet_the_pyro.png", "Splashes/mushrooms.png", "Splashes/oasis.png",
		"Splashes/peaceful_creeper.png", "Splashes/pillage_and_destroy.png", "Splashes/portal.png",
		"Splashes/rain.png", "Splashes/splashes.json", "Splashes/stealthy_ocelot.png",
		"Splashes/sunset.png", "Splashes/the_peaceful_dream.png", "Splashes/trails_and_tales.png",
		"Splashes/untitled_splash.png", "Splashes/untitled_splash_2.png", "Splashes/you_cant_hide.png",
		"languages.midata", "legacy.midata",
		"Minecraft/Game Base.midata", "Minecraft/Game Base.zip"
	];

	var version_file = data_directory + ".bundle_version";
	var force_reseed = true;

	if (file_exists_lib(version_file))
	{
		var vf = file_text_open_read(version_file);
		force_reseed = (real(file_text_read_string(vf)) != DATA_BUNDLE_VERSION)
		file_text_close(vf)
	}

	var copied = 0;
	for (var i = 0; i < array_length(DATA_BUNDLE_FILES); i++)
	{
		var relpath = DATA_BUNDLE_FILES[i];
		var srcpath = ":/Data/" + relpath;
		var dstpath = data_directory + relpath;

		var srcsize = file_size_lib(srcpath);
		if (srcsize < 0)
		{
			log("data_directory_seed_android: bundled resource missing", srcpath)
			continue
		}

		if (force_reseed || file_size_lib(dstpath) != srcsize)
		{
			if (!file_copy_lib(srcpath, dstpath))
			{
				log("data_directory_seed_android: could not copy", srcpath)
				continue
			}
			copied++
		}
	}

	if (copied > 0)
		log("data_directory_seed_android: (re)seeded files", copied)

	var vf_out = file_text_open_write(version_file);
	file_text_write_string(vf_out, string(DATA_BUNDLE_VERSION))
	file_text_close(vf_out)

	return true
}