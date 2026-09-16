/// directory_find(directory)
/// @arg directory
/// @desc Returns an array of subdirectory names (not full paths) directly inside the given directory.

function directory_find(dir)
{
	var ret, f;
	ret = array()

	f = directory_find_first(dir)
	while (f != "")
	{
		ret[array_length(ret)] = f
		f = directory_find_next()
	}
	directory_find_close()

	return ret
}
