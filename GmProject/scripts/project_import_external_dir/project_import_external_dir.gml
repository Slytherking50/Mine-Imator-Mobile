/// project_import_external_dir(tree_uri, doc_uri, local_dir)
/// @arg tree_uri
/// @arg doc_uri
/// @arg local_dir
/// @desc Recursively copies doc_uri's children (files/subfolders, from an externally picked SAF
/// tree - 2026-09-16, follow-up to B39) into local_dir, which must already exist. Returns the
/// local path of a .miproject file found along the way, or "" if none - lets the caller offer
/// to open it right away instead of just dumping files with no next step.
///
/// Reads this level's ENTIRE child list into arrays before recursing into any subfolder -
/// android_folder_tree_list_* (FileFunc.cpp) holds a single Cursor, not a stack of them, so
/// starting a nested listing before this level's is fully drained and closed would silently
/// invalidate it mid-loop.

function project_import_external_dir(tree_uri, doc_uri, local_dir)
{
	var found_project = "";
	var names = array();
	var uris = array();
	var is_dirs = array();

	if (android_folder_tree_list_first(tree_uri, doc_uri))
	{
		do
		{
			array_add(names, android_folder_tree_list_name())
			array_add(uris, android_folder_tree_list_uri())
			array_add(is_dirs, android_folder_tree_list_is_dir())
		}
		until (!android_folder_tree_list_next())

		android_folder_tree_list_close()
	}

	for (var i = 0; i < array_length(names); i++)
	{
		if (is_dirs[i])
		{
			var child_local_dir = local_dir + names[i] + "/";
			directory_create_lib(child_local_dir)

			var sub_found = project_import_external_dir(tree_uri, uris[i], child_local_dir);
			if (sub_found != "")
				found_project = sub_found
		}
		else
		{
			var local_path = local_dir + names[i];
			if (android_folder_tree_read_file(uris[i], local_path) && filename_ext(names[i]) = ".miproject")
				found_project = local_path
		}
	}

	return found_project
}
