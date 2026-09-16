/// file_dialog_save_movie_png(filename)
/// @arg filename

function file_dialog_save_movie_png(fn)
{
	// PNG sequence export produces MANY files (one per frame, export_update.gml) from what
	// SAF only ever grants ONE destination for - the same per-document-vs-many-files mismatch
	// as the project-folder picker (popup_saveas_draw.gml/popup_newproject_draw.gml,
	// 2026-09-15), just discovered on the export side instead. No dialog to skip around it
	// this time (the OTHER exports - object/particles/video/image - stayed real SAF saves,
	// this is the one shape that structurally can't be), so the adaptation here is the same
	// one used for the project folder: skip Android's picker entirely and write straight into
	// a fixed, always-writable app folder that needs no permission/SAF dance at all - the
	// frames are still fully reachable afterward (any file browser, or the toast's own "view"
	// link, export_done_movie.gml), just not through a folder the user picked by hand.
	if (platform_get() == e_platform.ANDROID)
	{
		var dir = user_directory_get() + "Exports/";
		if (!directory_exists_lib(dir))
			directory_create_lib(dir)
		return dir + filename_get_valid(fn)
	}

	return file_dialog_save(text_get("filedialogsavemoviepng") + " (*.png)|*.png", filename_get_valid(fn), project_folder, text_get("filedialogsavemoviecaption"))
}
