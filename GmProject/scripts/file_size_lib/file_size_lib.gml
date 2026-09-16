/// file_size_lib(filename)
/// @arg filename
/// @desc Returns the file's size in bytes, or -1 if it doesn't exist. Works against ":/" Qt
/// resource paths too (Fase 3, CLAUDE.md §17, 2026-09-10 - Android Data/ bundle seeding).

function file_size_lib(fn)
{
	if (fn = "")
		return -1

	return external_call(lib_file_size, fn)
}
