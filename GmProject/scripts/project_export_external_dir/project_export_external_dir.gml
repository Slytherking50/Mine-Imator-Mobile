/// project_export_external_dir(local_dir, parent_doc_uri)
/// @arg local_dir
/// @arg parent_doc_uri
/// @desc Recursively mirrors local_dir's files/subfolders as children of parent_doc_uri (a SAF
/// tree document, 2026-09-16 - see action_project_export_external.gml). Uses file_find_first/
/// _next directly rather than the file_find() wrapper, which filters by extension - this needs
/// every file regardless of type. Returns false if anything failed, but doesn't stop copying
/// the rest - one bad file/folder shouldn't lose everything else already exported.

function project_export_external_dir(local_dir, parent_doc_uri)
{
	var ok = true;

	var f = file_find_first(local_dir + "*", 0);
	while (f != "")
	{
		if (!android_folder_tree_write_file(parent_doc_uri, f, local_dir + f))
			ok = false
		f = file_find_next()
	}
	file_find_close()

	var dirs = directory_find(local_dir);
	for (var i = 0; i < array_length(dirs); i++)
	{
		var child_doc = android_folder_tree_create_dir(parent_doc_uri, dirs[i]);
		if (child_doc = "")
		{
			ok = false
			continue
		}

		if (!project_export_external_dir(local_dir + dirs[i] + "/", child_doc))
			ok = false
	}

	return ok
}
