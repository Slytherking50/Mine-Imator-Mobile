/// filename_new_ext(filename, newextension)
/// @arg filename
/// @arg newextension
/// @desc Changes the filename extension, accepting a new value with a leading dot, eg. ".png"

function filename_new_ext(fn, newext)
{
	// A content:// URI (Android SAF save-dialog result, 2026-09-15) already has the right
	// extension baked into its associated document by the native picker itself
	// (get_save_filename_ext's setDefaultSuffix) - the URI string has no ".ext" of its own to
	// find/replace, so the loop below would either corrupt it (append newext onto an opaque
	// numeric document id) or silently do nothing useful. Passed through unchanged instead.
	if (string_pos("content://", fn) = 1)
		return fn

	var p;

	for (p = string_length(fn); p >= 0; p--)
	{
		var c = string_char_at(fn, p);
		
		if (p = 0 || c = "\\" || c = "/")
			return fn + newext
		
		if (c = ".")
			break
	}
	
	return string_copy(fn, 1, p - 1) + newext
}
