/// app_update_folder_tree_export()
/// @desc Polls for android_pick_folder_tree()'s result (2026-09-16, action_project_export_external.gml)
/// and runs the actual copy once the user has picked (or cancelled). Called every frame from
/// app_event_step.gml, same shape as the other app_update_* calls there - android_export_pending
/// keeps this a no-op on every frame nothing is pending, and always false on non-Android.

function app_update_folder_tree_export()
{
	if (!android_export_pending || !android_folder_tree_pick_done())
		return 0

	android_export_pending = false

	var tree_uri = android_folder_tree_result();
	if (tree_uri = "")
		return 0 // Cancelled - silent, same as backing out of any other file picker

	if (project_export_external_do(tree_uri))
		toast_new(e_toast.POSITIVE, text_get("toastexportexternalsuccess"))
	else
		toast_new(e_toast.NEGATIVE, text_get("toastexportexternalfail"))
}
