/// project_export_external_do(tree_uri)
/// @arg tree_uri
/// @desc Entry point once android_pick_folder_tree() has resolved to a real tree (2026-09-16).

function project_export_external_do(tree_uri)
{
	var root_doc = android_folder_tree_root_doc(tree_uri);
	if (root_doc = "")
		return false

	return project_export_external_dir(project_folder + "/", root_doc)
}
