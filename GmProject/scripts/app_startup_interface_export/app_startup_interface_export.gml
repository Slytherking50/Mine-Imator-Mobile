/// app_startup_interface_export()

function app_startup_interface_export()
{
	export_surface = null
	export_sample = 0
	export_filename = ""
	// Android video export only (2026-09-15) - holds the real picked content:// destination
	// while movie_start() encodes to temp_movie_file instead (macros.gml); copied onto this
	// URI once the encode finishes (export_done_movie.gml). Empty outside that window.
	export_filename_content_uri = ""
	export_escape_time = 0
	
	exportmovie_format = ""
	exportmovie_marker_previous = 0
	exportmovie_marker_start = 0
	exportmovie_marker_end = 0
	exportmovie_frame = 0
	exportmovie_frame_rate = 0
	exportmovie_framespersecond = 0
	exportmovie_high_quality = true
	exportmovie_start = null
	exportmovie_buffer = null
}
