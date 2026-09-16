/// project_export_external_dir(tree_uri, local_dir, parent_doc_uri)
/// @arg tree_uri
/// @arg local_dir
/// @arg parent_doc_uri
/// @desc Recursively mirrors local_dir's files/subfolders as children of parent_doc_uri (a SAF
/// tree document, 2026-09-16 - see action_project_export_external.gml). Uses file_find_first/
/// _next directly rather than the file_find() wrapper, which filters by extension - this needs
/// every file regardless of type. Returns false if anything failed, but doesn't stop copying
/// the rest - one bad file/folder shouldn't lose everything else already exported.
///
/// Lists parent_doc_uri's EXISTING children first (2026-09-16, closes the "always creates a
/// new document" gap noted in KNOWN_ISSUES.md B39) - an existing file gets overwritten in place
/// instead of duplicated, an existing folder gets reused (recursed into) instead of a second
/// copy created alongside it. Same "drain this level before recursing" rule as
/// project_import_external_dir.gml - the underlying Cursor is one, not a stack.

function project_export_external_dir(tree_uri, local_dir, parent_doc_uri)
{
	var ok = true;
	var existing_names = array();
	var existing_uris = array();
	var existing_is_dirs = array();

	if (android_folder_tree_list_first(tree_uri, parent_doc_uri))
	{
		do
		{
			array_add(existing_names, android_folder_tree_list_name())
			array_add(existing_uris, android_folder_tree_list_uri())
			array_add(existing_is_dirs, android_folder_tree_list_is_dir())
		}
		until (!android_folder_tree_list_next())

		android_folder_tree_list_close()
	}

	var f = file_find_first(local_dir + "*", 0);
	while (f != "")
	{
		var existing_uri = "";
		for (var e = 0; e < array_length(existing_names); e++)
			if (existing_names[e] = f && !existing_is_dirs[e])
			{
				existing_uri = existing_uris[e]
				break
			}

		if (existing_uri != "")
		{
			if (!android_folder_tree_overwrite_file(existing_uri, local_dir + f))
				ok = false
		}
		else if (!android_folder_tree_write_file(parent_doc_uri, f, local_dir + f))
			ok = false

		f = file_find_next()
	}
	file_find_close()

	var dirs = directory_find(local_dir);
	for (var i = 0; i < array_length(dirs); i++)
	{
		var child_doc = "";
		for (var e = 0; e < array_length(existing_names); e++)
			if (existing_names[e] = dirs[i] && existing_is_dirs[e])
			{
				child_doc = existing_uris[e]
				break
			}

		if (child_doc = "")
			child_doc = android_folder_tree_create_dir(parent_doc_uri, dirs[i])

		if (child_doc = "")
		{
			ok = false
			continue
		}

		if (!project_export_external_dir(tree_uri, local_dir + dirs[i] + "/", child_doc))
			ok = false
	}

	return ok
}
