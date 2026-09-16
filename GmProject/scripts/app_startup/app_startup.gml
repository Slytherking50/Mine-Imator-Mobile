/// app_startup()

function app_startup()
{
	startup_error = true

	// Android only (no-op elsewhere) - seeds data_directory from the bundled Qt resource
	// before anything below checks for legacy_file/language_file. CLAUDE.md section 17, 2026-09-10.
	data_directory_seed_android()

	if (!lib_startup())
		return false

	if (!is_cpp()) // Skip file lib in C++
		if (!file_lib_startup())
			return false

	if (!file_exists_lib(legacy_file))
		return missing_file(legacy_file)

	if (!file_exists_lib(language_file))
		return missing_file(language_file)

	vertex_format_startup()
	if (!shader_startup())
		return false

	// Fase 6 (PERF_LOG.md) - timing the ~1.5s unexplained gap between shader_startup() (already
	// measured, ~2s real) and minecraft_assets_startup(). Android-only, log() not debug() so it
	// shows up in log.txt without needing dev_mode - same pattern as the shader/current_step
	// instrumentation already used for this same investigation. Remove once the gap is found.
	var android_startup_timing = (platform_get() == e_platform.ANDROID)
	var android_startup_t = current_time

	if (!legacy_startup())
		return false
	if (android_startup_timing)
	{
		log("startup timing: legacy_startup", current_time - android_startup_t)
		android_startup_t = current_time
	}

	app_startup_lists()
	if (android_startup_timing)
	{
		log("startup timing: app_startup_lists", current_time - android_startup_t)
		android_startup_t = current_time
	}

	app_startup_collapse()
	if (android_startup_timing)
	{
		log("startup timing: app_startup_collapse", current_time - android_startup_t)
		android_startup_t = current_time
	}

	app_startup_micro_animations()
	if (android_startup_timing)
	{
		log("startup timing: app_startup_micro_animations", current_time - android_startup_t)
		android_startup_t = current_time
	}

	app_startup_window()
	if (android_startup_timing)
	{
		log("startup timing: app_startup_window", current_time - android_startup_t)
		android_startup_t = current_time
	}

	app_startup_themes()
	if (android_startup_timing)
	{
		log("startup timing: app_startup_themes", current_time - android_startup_t)
		android_startup_t = current_time
	}

	app_startup_fonts()
	if (android_startup_timing)
	{
		log("startup timing: app_startup_fonts", current_time - android_startup_t)
		android_startup_t = current_time
	}

	app_startup_interface_lists()
	if (android_startup_timing)
	{
		log("startup timing: app_startup_interface_lists", current_time - android_startup_t)
		android_startup_t = current_time
	}

	app_startup_keybinds()
	if (android_startup_timing)
	{
		log("startup timing: app_startup_keybinds", current_time - android_startup_t)
		android_startup_t = current_time
	}

	app_startup_recent()
	if (android_startup_timing)
	{
		log("startup timing: app_startup_recent", current_time - android_startup_t)
		android_startup_t = current_time
	}

	toasts_startup()
	if (android_startup_timing)
	{
		log("startup timing: toasts_startup", current_time - android_startup_t)
		android_startup_t = current_time
	}

	json_startup()
	if (android_startup_timing)
	{
		log("startup timing: json_startup", current_time - android_startup_t)
		android_startup_t = current_time
	}

	settings_startup()
	if (android_startup_timing)
	{
		log("startup timing: settings_startup", current_time - android_startup_t)
		android_startup_t = current_time
	}

	project_startup()
	if (android_startup_timing)
	{
		log("startup timing: project_startup", current_time - android_startup_t)
		android_startup_t = current_time
	}

	render_startup()
	if (android_startup_timing)
	{
		log("startup timing: render_startup", current_time - android_startup_t)
		android_startup_t = current_time
	}

	camera_startup()
	if (android_startup_timing)
	{
		log("startup timing: camera_startup", current_time - android_startup_t)
		android_startup_t = current_time
	}

	if (!minecraft_assets_startup())
		return false

	startup_error = false

	return true
}
