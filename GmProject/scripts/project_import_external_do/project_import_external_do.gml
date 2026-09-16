/// project_import_external_do(tree_uri)
/// @arg tree_uri
/// @desc Entry point once android_pick_folder_tree() has resolved to a real tree (2026-09-16,
/// follow-up to B39 - the import direction). Creates a new local project folder under
/// projects_directory_get() and mirrors the picked tree's contents into it. Returns the local
/// path of a .miproject file found inside, or "" if the tree had none (still copied whatever
/// was there either way - not necessarily an error, just not something to auto-open).

function project_import_external_do(tree_uri)
{
	var root_doc = android_folder_tree_root_doc(tree_uri);
	if (root_doc = "")
		return ""

	var folder_name = filename_name(filename_get_unique(projects_directory_get() + text_get("importexternalname")));
	var local_dir = projects_directory_get() + folder_name + "/";
	directory_create_lib(local_dir)

	return project_import_external_dir(tree_uri, root_doc, local_dir)
}
