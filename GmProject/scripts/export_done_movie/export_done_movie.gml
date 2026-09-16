/// export_done_movie()

function export_done_movie(cancel = false)
{
	var fn;
	
	render_free()
	
	if (exportmovie_format != "png")
	{
		movie_done()
		buffer_delete(exportmovie_buffer)

		// Android: copy the finished local encode onto the real picked content:// URI
		// (action_toolbar_exportmovie_save.gml redirected the encoder to temp_movie_file).
		// Skipped on cancel - a cancelled/partial encode has nothing worth delivering.
		if (!cancel && export_filename_content_uri != "")
			file_copy_lib(temp_movie_file, export_filename_content_uri)

		export_filename_content_uri = ""
	}
	
	surface_free(export_surface)
	export_surface = null
	window_state = ""
	
	render_watermark = false
	render_background = true
	render_hidden = false
	
	timeline_marker = exportmovie_marker_previous
	
	if (exportmovie_format = "png")
		fn = filename_new_ext(export_filename, "") + "_1.png"
	else
		fn = export_filename
	
	if (!cancel)
	{
		toast_new(e_toast.POSITIVE, text_get("alertexportmovie"))
		toast_add_action("alertexportmovieview", popup_open_url, fn)
	}
}
